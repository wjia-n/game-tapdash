import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/dash_themes.dart';

/// Persisted settings + stats for Tap Dash. Survives app restarts.
///
/// The ENTIRE profile is ONE order-preserving JSON string under
/// [TapDashSettings._kProfile] via setString. NEVER use setStringList for
/// player names: Android's SharedPreferences stores StringLists as an
/// unordered StringSet, which scrambles slot order across restarts.
class TapDashSettings extends ChangeNotifier {
  /// Required key: one order-preserving JSON string for the whole profile.
  static const _kProfile = 'tapdash_player_names_json';

  // Legacy keys (migrated once, then removed).
  static const _kLegacyBest = 'tapdash_best';
  static const _kLegacyNames = 'tapdash_player_names';

  static const defaultNames = ['Speedy', 'Flash', 'Bolt', 'Zippy'];

  /// Encode the full profile as one JSON string (order-preserving).
  static String encodeProfile(Map<String, Object?> profile) =>
      jsonEncode(profile);

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultNames[i] : s;
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  List<String> playerNames = List.of(defaultNames);
  String themeId = 'classic';
  int styleId = 0;
  int difficulty = 0; // 0 chill, 1 swift, 2 lightning (Pro)
  String mode = 'quick'; // quick | attack | bot
  int playerCount = 1; // 1..4 (pass-and-play); bot mode forces 1
  int botDifficulty = 1; // 0 easy, 1 medium, 2 hard
  bool isPro = false;

  // Lifetime stats.
  int bestQuickAvg = 0; // lowest average ms (0 = none yet)
  int bestAttack = 0; // highest score-attack score (0 = none yet)
  int botWins = 0;
  int botLosses = 0;
  int gamesPlayed = 0;

  /// Custom theme colors (ARGB ints). Pro feature.
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'idle': 0xFFF3E3C2,
    'waiting': 0xFFD23B3B,
    'armed': 0xFF2FA35C,
    'result': 0xFF2B5D8A,
    'falseStart': 0xFF6E2430,
    'accent': 0xFFE8A93D,
    'accentDark': 0xFFB97B1E,
    'card': 0xFFFFF8EA,
    'onCard': 0xFF4A2E1B,
  };

  /// Builds the user-designed custom theme from stored colors.
  DashThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return DashThemeDef(
      id: 'custom',
      name: 'My Creation',
      idleBg: c('idle'),
      waitingBg: c('waiting'),
      armedBg: c('armed'),
      resultBg: c('result'),
      falseStartBg: c('falseStart'),
      accent: c('accent'),
      accentDark: c('accentDark'),
      cardBg: c('card'),
      onDark: const Color(0xFFFFFFFF),
      onCard: c('onCard'),
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    final raw = p.getString(_kProfile);
    if (raw != null) {
      _decode(raw);
    } else {
      _migrateLegacy(p);
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  void _decode(String raw) {
    try {
      final d = jsonDecode(raw);
      if (d is List) {
        // Legacy names-only list format under the same key (older builds
        // stored just the name list here). Order is preserved in JSON.
        if (d.length == 4) {
          playerNames = [for (int i = 0; i < 4; i++) _cleanName(i, d[i])];
        }
        return; // everything else keeps defaults; gets re-saved below.
      }
      if (d is! Map) return;
      musicOn = d['music'] is bool ? d['music'] as bool : true;
      sfxOn = d['sfx'] is bool ? d['sfx'] as bool : true;
      volume = (d['volume'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.8;
      final names = d['names'];
      if (names is List && names.length == 4) {
        playerNames = [for (int i = 0; i < 4; i++) _cleanName(i, names[i])];
      }
      themeId = d['theme'] is String ? d['theme'] as String : 'classic';
      styleId = (d['style'] as num?)?.toInt().clamp(0, 7) ?? 0;
      difficulty = (d['difficulty'] as num?)?.toInt().clamp(0, 2) ?? 0;
      mode = d['mode'] is String ? d['mode'] as String : 'quick';
      if (mode != 'quick' && mode != 'attack' && mode != 'bot') mode = 'quick';
      playerCount = (d['players'] as num?)?.toInt().clamp(1, 4) ?? 1;
      botDifficulty = (d['botDiff'] as num?)?.toInt().clamp(0, 2) ?? 1;
      isPro = d['isPro'] is bool ? d['isPro'] as bool : false;
      bestQuickAvg = (d['bestQuick'] as num?)?.toInt() ?? 0;
      bestAttack = (d['bestAttack'] as num?)?.toInt() ?? 0;
      botWins = (d['botWins'] as num?)?.toInt() ?? 0;
      botLosses = (d['botLosses'] as num?)?.toInt() ?? 0;
      gamesPlayed = (d['games'] as num?)?.toInt() ?? 0;
      final custom = d['custom'];
      if (custom is Map) {
        for (final k in _defaultCustomColors.keys) {
          final v = custom[k];
          if (v is int) customColors[k] = v;
        }
      }
    } catch (_) {
      // Corrupt profile: keep defaults.
    }
  }

  /// One-time migration from the old v1 keys. The legacy StringList key may
  /// already be order-scrambled on Android — this is exactly the bug the
  /// single-JSON profile replaces. Only runs when no profile exists yet.
  Future<void> _migrateLegacy(SharedPreferences p) async {
    final legacyBest = p.getInt(_kLegacyBest);
    if (legacyBest != null && legacyBest > 0) bestQuickAvg = legacyBest;
    final legacy = p.getStringList(_kLegacyNames);
    if (legacy != null && legacy.length == 4) {
      playerNames = [for (int i = 0; i < 4; i++) _cleanName(i, legacy[i])];
    }
    await p.remove(_kLegacyBest);
    await p.remove(_kLegacyNames);
    await _save();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    final profile = <String, Object?>{
      'v': 1,
      'music': musicOn,
      'sfx': sfxOn,
      'volume': volume,
      'names': playerNames,
      'theme': themeId,
      'style': styleId,
      'difficulty': difficulty,
      'mode': mode,
      'players': playerCount,
      'botDiff': botDifficulty,
      'isPro': isPro,
      'bestQuick': bestQuickAvg,
      'bestAttack': bestAttack,
      'botWins': botWins,
      'botLosses': botLosses,
      'games': gamesPlayed,
      'custom': Map.of(customColors),
    };
    await p.setString(_kProfile, encodeProfile(profile));
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || DashThemes.isProTheme(themeId)) {
      themeId = 'classic';
      changed = true;
    }
    if (DasherStyles.isPro(styleId)) {
      styleId = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom theme creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(int index, String name) async {
    if (index < 0 || index > 3) return;
    final clean = name.trim();
    playerNames[index] = clean.isEmpty ? defaultNames[index] : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || DashThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setStyle(int v) async {
    v = v.clamp(0, DasherStyles.all.length - 1);
    if (!isPro && DasherStyles.isPro(v)) return;
    styleId = v;
    notifyListeners();
    await _save();
  }

  Future<void> setDifficulty(int v) async {
    v = v.clamp(0, 2);
    if (!isPro && v > 1) return; // Lightning is a Pro feature
    difficulty = v;
    notifyListeners();
    await _save();
  }

  Future<void> setMode(String v) async {
    if (v != 'quick' && v != 'attack' && v != 'bot') return;
    mode = v;
    if (mode == 'bot' || mode == 'attack') playerCount = 1;
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerCount(int v) async {
    if (mode == 'bot' || mode == 'attack') return;
    playerCount = v.clamp(1, 4);
    notifyListeners();
    await _save();
  }

  Future<void> setBotDifficulty(int v) async {
    botDifficulty = v.clamp(0, 2);
    notifyListeners();
    await _save();
  }

  /// Record a finished Quick Match. [avgMs] is the player's average.
  Future<void> recordQuick(int avgMs) async {
    gamesPlayed++;
    if (bestQuickAvg == 0 || avgMs < bestQuickAvg) bestQuickAvg = avgMs;
    notifyListeners();
    await _save();
  }

  /// Record a finished Score Attack. [score] is the final score.
  Future<void> recordAttack(int score) async {
    gamesPlayed++;
    if (score > bestAttack) bestAttack = score;
    notifyListeners();
    await _save();
  }

  /// Record a finished Vs-Bot match. [humanWon] true if the human won.
  Future<void> recordBot(bool humanWon) async {
    gamesPlayed++;
    if (humanWon) {
      botWins++;
    } else {
      botLosses++;
    }
    notifyListeners();
    await _save();
  }

  Future<void> resetStats() async {
    bestQuickAvg = 0;
    bestAttack = 0;
    botWins = 0;
    botLosses = 0;
    gamesPlayed = 0;
    notifyListeners();
    await _save();
  }
}
