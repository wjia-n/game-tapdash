import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Tap Dash engine: reaction-time arcade game.
//
// The screen waits RED ("wait for it…") and the player must tap the instant
// it turns GREEN. Tapping early is a false start. Lowest average wins.
//
// The ENGINE owns every phase transition on its own timers; the UI only
// renders. A watchdog recovers any phase found without a live timer, so
// stuck states are impossible by construction. Pause freezes the phase
// timer; resume re-arms the current phase.
//
// Timer layout (deliberately SEPARATE, never one shared timer — a shared
// timer lets the bot-tap and the armed-timeout cancel each other):
//   _timer      — phase transitions (countdown ticks, decoy waits, green,
//                 result auto-advance).
//   _armedTimer — armed-timeout (non-bot modes): nobody taps in 10s → miss.
//   _botTimer   — Robo-Dash's own tap delay (bot mode only).
// ---------------------------------------------------------------------------

enum DashMode { quick, attack, bot }

enum DashDifficulty { chill, swift, lightning }

/// Phases owned entirely by the engine. The UI only renders.
/// [idle] = waiting for the player to tap-to-start (match start or pass).
/// [countdown] = 3-2-1 ticks. [waiting] = red, green not yet shown.
/// [decoy] = amber trick flash (lightning only) — tapping is a false start.
/// [armed] = GREEN, reaction clock running. [result] = showing the round
/// outcome (input locked, auto-advances). [over] = match finished.
enum DashPhase { idle, countdown, waiting, decoy, armed, result, over }

enum DashEvent {
  countdownTick,
  go,
  decoy,
  tapValid,
  falseStart,
  roundResult,
  matchEnd,
  turnReady,
}

class _QueuedEvent {
  final int delayMs;
  final bool isDecoy;
  _QueuedEvent(this.delayMs, this.isDecoy);
}

class TapDashEngine extends ChangeNotifier {
  final DashMode mode;
  final List<String> playerNames; // length == playerCount (quick) or 1
  final int playerCount;
  final DashDifficulty difficulty;
  final int botDifficulty; // 0 easy, 1 medium, 2 hard (bot mode)

  static const int roundsPerMatch = 5;
  static const int falseStartPenaltyMs = 1200; // RULES §8
  static const int attackMaxStrikes = 3;
  static const int armedTimeoutMs = 10000; // tap within 10s of green (RULES §13)

  DashPhase phase = DashPhase.idle;
  bool paused = false;
  String banner = '';

  int currentPlayer = 0;
  int round = 0; // 0-based round within the current player's turn / match
  int countdownValue = 3;

  // Quick mode: per-player recorded times (false starts = penalty).
  late final List<List<int>> times;

  // Score Attack: running score + strikes.
  int attackScore = 0;
  int attackStrikes = 0;
  int attackRounds = 0;

  // Vs Bot: round wins.
  int humanRoundWins = 0;
  int botRoundWins = 0;
  int botReactionMs = 0; // this round's bot tap delay (set when armed)

  int? lastMs; // last valid tap, ms (null on false start)
  bool lastFalseStart = false;
  bool lastRoundHumanWon = true;

  void Function(DashEvent)? onEvent;

  final _rand = Random();
  Timer? _timer; // phase-transition timer
  Timer? _armedTimer; // armed-timeout (non-bot modes)
  Timer? _botTimer; // bot's own tap delay (bot mode only)
  Timer? _watchdog; // stuck-state recovery
  bool _disposed = false;

  DateTime? _armedAt;
  int _pausedArmedElapsedMs = -1; // -1 = not paused mid-armed
  int _pausedBotRemainingMs = -1; // -1 = not paused mid-bot-wait
  final List<_QueuedEvent> _pending = [];
  int _countdownLeft = 0;

  TapDashEngine({
    required this.mode,
    required this.playerNames,
    required this.playerCount,
    required this.difficulty,
    this.botDifficulty = 1,
  }) {
    times = List.generate(playerCount, (_) => <int>[]);
    banner = 'Tap to start!';
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) => _recover());
  }

  String get currentName =>
      playerNames[currentPlayer.clamp(0, playerNames.length - 1)];

  static const botName = 'Robo-Dash';

  // ------------------------------------------------------------ difficulties
  int get _minWait => switch (difficulty) {
        DashDifficulty.chill => 1500,
        DashDifficulty.swift => 1000,
        DashDifficulty.lightning => 800,
      };

  int get _maxWait => switch (difficulty) {
        DashDifficulty.chill => 3500,
        DashDifficulty.swift => 2600,
        DashDifficulty.lightning => 2000,
      };

  bool get _decoysOn => difficulty == DashDifficulty.lightning;

  int _rollBotReaction() {
    final base = switch (botDifficulty) {
      0 => 520,
      2 => 250,
      _ => 360,
    };
    final jitter = switch (botDifficulty) {
      0 => 90,
      2 => 45,
      _ => 70,
    };
    return base + _rand.nextInt(jitter * 2 + 1) - jitter;
  }

  // ------------------------------------------------------------- lifecycle
  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _cancelArmedTimers();
    _watchdog?.cancel();
    super.dispose();
  }

  /// The phase timer is armed exactly like a hardware one-shot: cancel any
  /// previous arming first, so there is never more than one live.
  void _arm(Duration d, void Function() fn) {
    if (_disposed || paused) return;
    _timer?.cancel();
    _timer = Timer(d, () {
      _timer = null;
      if (!_disposed && !paused) fn();
    });
  }

  /// Cancel the armed-phase one-shots (timeout + bot tap).
  void _cancelArmedTimers() {
    _armedTimer?.cancel();
    _armedTimer = null;
    _botTimer?.cancel();
    _botTimer = null;
  }

  /// Pause: freeze the phase timer. Resume re-arms the current phase.
  void setPaused(bool v) {
    if (paused == v || _disposed) return;
    paused = v;
    if (v) {
      if (phase == DashPhase.armed && _armedAt != null) {
        final elapsed =
            DateTime.now().difference(_armedAt!).inMilliseconds;
        _pausedArmedElapsedMs = elapsed;
        if (mode == DashMode.bot && _botTimer != null) {
          // The bot keeps its remaining wait so pausing is never an exploit.
          _pausedBotRemainingMs = (botReactionMs - elapsed).clamp(0, 1 << 30);
        }
      }
      _timer?.cancel();
      _timer = null;
      _cancelArmedTimers();
    } else {
      _recover();
    }
    notifyListeners();
  }

  /// Watchdog: if the timers for the current phase ever die without
  /// progress, recover. This makes stuck states impossible by construction.
  /// Respects [paused]. Never double-arms: each phase re-arms only when its
  /// timer is missing.
  void _recover() {
    if (_disposed || paused) return;
    if (phase == DashPhase.over || phase == DashPhase.idle) return;
    if (phase == DashPhase.armed) {
      if (_armedTimer != null || _botTimer != null) return; // still live
      // Reaction clock survives: re-anchor _armedAt from paused elapsed or
      // keep running if a timer died some other way.
      if (_pausedArmedElapsedMs >= 0 && _armedAt != null) {
        _armedAt = DateTime.now().subtract(
            Duration(milliseconds: _pausedArmedElapsedMs));
        _pausedArmedElapsedMs = -1;
      }
      if (mode == DashMode.bot) {
        final remaining = _pausedBotRemainingMs >= 0
            ? _pausedBotRemainingMs
            : botReactionMs;
        _pausedBotRemainingMs = -1;
        _armBotTap(Duration(milliseconds: remaining));
      } else {
        _armArmedTimeout();
      }
      return;
    }
    if (_timer != null) return; // phase progress already scheduled
    if (phase == DashPhase.countdown) {
      _runCountdown();
    } else if (phase == DashPhase.waiting) {
      _scheduleNext();
    } else if (phase == DashPhase.decoy) {
      _endDecoy();
    } else if (phase == DashPhase.result) {
      _afterResult();
    }
  }

  // ----------------------------------------------------------------- flow
  /// Match entry. Resets everything and parks in [idle] for tap-to-start.
  void startMatch() {
    // A restart must never leave a stale timer behind: cancel everything.
    _timer?.cancel();
    _timer = null;
    _cancelArmedTimers();
    _pending.clear();
    _pausedArmedElapsedMs = -1;
    _pausedBotRemainingMs = -1;
    paused = false;
    for (final t in times) {
      t.clear();
    }
    currentPlayer = 0;
    round = 0;
    attackScore = 0;
    attackStrikes = 0;
    attackRounds = 0;
    humanRoundWins = 0;
    botRoundWins = 0;
    lastMs = null;
    lastFalseStart = false;
    phase = DashPhase.idle;
    banner = _startBanner();
    notifyListeners();
  }

  String _startBanner() {
    if (mode == DashMode.bot) return 'Beat $botName — tap to start!';
    if (mode == DashMode.attack) return '3 false starts end it — tap to start!';
    if (playerCount > 1) return 'Pass to ${playerNames[0]} — tap to start!';
    return 'Tap to start!';
  }

  /// The one legal tap entry point. Every tap in every phase is handled
  /// here — nothing the player can do leads nowhere.
  void tap() {
    if (_disposed || paused || phase == DashPhase.over) return;
    switch (phase) {
      case DashPhase.idle:
        _beginRound();
        break;
      case DashPhase.countdown:
      case DashPhase.waiting:
      case DashPhase.decoy:
        _falseStart();
        break;
      case DashPhase.armed:
        _validTap();
        break;
      case DashPhase.result:
        break; // locked while the result shows; auto-advances
      case DashPhase.over:
        break;
    }
  }

  void _beginRound() {
    lastMs = null;
    lastFalseStart = false;
    _pending.clear();
    phase = DashPhase.countdown;
    _countdownLeft = 3;
    countdownValue = 3;
    banner = mode == DashMode.bot && round == 0 && currentPlayer == 0
        ? 'Round 1 — wait for green!'
        : _roundBanner();
    notifyListeners();
    _runCountdown();
  }

  String _roundBanner() {
    if (mode == DashMode.attack) {
      return 'Round ${attackRounds + 1} — wait for green!';
    }
    if (mode == DashMode.bot) {
      return 'Round ${round + 1}/$roundsPerMatch — wait for green!';
    }
    final r = times[currentPlayer].length + 1;
    final who = playerCount > 1 ? '${playerNames[currentPlayer]} — ' : '';
    return '$who Round $r/$roundsPerMatch — wait for green!';
  }

  void _runCountdown() {
    if (_disposed || paused || phase != DashPhase.countdown) return;
    countdownValue = _countdownLeft;
    onEvent?.call(DashEvent.countdownTick);
    notifyListeners();
    _countdownLeft--;
    if (_countdownLeft <= 0) {
      _arm(const Duration(milliseconds: 650), _beginWaiting);
    } else {
      _arm(const Duration(milliseconds: 650), _runCountdown);
    }
  }

  /// Build the round's event queue: decoys (lightning) then green.
  void _beginWaiting() {
    if (_disposed || paused || phase != DashPhase.countdown) return;
    phase = DashPhase.waiting;
    _pending.clear();
    final greenDelay =
        _minWait + _rand.nextInt(_maxWait - _minWait + 1);
    if (_decoysOn) {
      final nDecoys = _rand.nextInt(3); // 0..2 trick flashes
      final marks = <int>{
        for (int i = 0; i < nDecoys; i++)
          (greenDelay * (0.35 + _rand.nextDouble() * 0.45)).round(),
      }.toList()
        ..sort();
      int prev = 0;
      for (final m in marks) {
        _pending.add(_QueuedEvent(m - prev, true));
        prev = m;
      }
      _pending.add(_QueuedEvent(greenDelay - prev, false));
    } else {
      _pending.add(_QueuedEvent(greenDelay, false));
    }
    notifyListeners();
    _scheduleNext();
  }

  void _scheduleNext() {
    if (_disposed || paused || phase != DashPhase.waiting) return;
    if (_pending.isEmpty) {
      _fireGreen();
      return;
    }
    final ev = _pending.removeAt(0);
    _arm(Duration(milliseconds: ev.delayMs),
        ev.isDecoy ? _fireDecoy : _fireGreen);
  }

  void _fireDecoy() {
    if (_disposed || paused || phase != DashPhase.waiting) return;
    phase = DashPhase.decoy;
    onEvent?.call(DashEvent.decoy);
    notifyListeners();
    _arm(const Duration(milliseconds: 400), _endDecoy);
  }

  void _endDecoy() {
    if (_disposed || paused || phase != DashPhase.decoy) return;
    phase = DashPhase.waiting;
    notifyListeners();
    _scheduleNext();
  }

  void _fireGreen() {
    if (_disposed || paused) return;
    if (phase != DashPhase.waiting && phase != DashPhase.decoy) return;
    phase = DashPhase.armed;
    _armedAt = DateTime.now();
    _pausedArmedElapsedMs = -1;
    _pausedBotRemainingMs = -1;
    if (mode == DashMode.bot) {
      botReactionMs = _rollBotReaction();
      _armBotTap();
    } else {
      _armArmedTimeout();
    }
    onEvent?.call(DashEvent.go);
    notifyListeners();
  }

  /// If the player never taps after green, the round scores as a miss
  /// instead of hanging forever (RULES §13 edge case). Non-bot modes only:
  /// in bot mode the bot always taps, so no timeout is needed. Runs on its
  /// OWN timer so it can never be cancelled by the bot-tap arming.
  void _armArmedTimeout() {
    _armedTimer?.cancel();
    _armedTimer = Timer(Duration(milliseconds: armedTimeoutMs), () {
      _armedTimer = null;
      if (_disposed || paused || phase != DashPhase.armed) return;
      _settleValidTap(armedTimeoutMs, timedOut: true);
    });
  }

  /// Robo-Dash's own tap: it fires after its rolled reaction delay and wins
  /// the round for the bot if the human hasn't tapped first. Runs on its OWN
  /// timer so it can never be cancelled by the armed-timeout arming.
  void _armBotTap([Duration? delay]) {
    _botTimer?.cancel();
    _botTimer = Timer(delay ?? Duration(milliseconds: botReactionMs), () {
      _botTimer = null;
      if (_disposed || paused || phase != DashPhase.armed) return;
      // Bot tapped first — it wins the round.
      lastMs = null;
      lastFalseStart = false;
      lastRoundHumanWon = false;
      botRoundWins++;
      onEvent?.call(DashEvent.tapValid);
      _toResult('Robo-Dash tapped first!');
    });
  }

  void _validTap() {
    if (phase != DashPhase.armed || _armedAt == null) return;
    final ms = DateTime.now().difference(_armedAt!).inMilliseconds;
    _settleValidTap(ms, timedOut: false);
  }

  void _settleValidTap(int ms, {required bool timedOut}) {
    if (phase != DashPhase.armed) return;
    _timer?.cancel();
    _timer = null;
    _cancelArmedTimers();
    lastMs = ms;
    lastFalseStart = false;
    if (mode == DashMode.bot) {
      lastRoundHumanWon = !timedOut && ms <= botReactionMs;
      if (lastRoundHumanWon) {
        humanRoundWins++;
      } else {
        botRoundWins++;
      }
    } else if (mode == DashMode.attack) {
      attackRounds++;
      attackScore += ms >= 1500 ? 0 : 1500 - ms;
    } else {
      times[currentPlayer].add(ms);
    }
    onEvent?.call(DashEvent.tapValid);
    _toResult(timedOut ? 'Too slow!' : _verdict(ms));
  }

  void _falseStart() {
    _timer?.cancel();
    _timer = null;
    _cancelArmedTimers();
    _pending.clear();
    lastMs = null;
    lastFalseStart = true;
    if (mode == DashMode.attack) {
      attackStrikes++;
    } else if (mode == DashMode.bot) {
      lastRoundHumanWon = false;
      botRoundWins++;
    } else {
      times[currentPlayer].add(falseStartPenaltyMs);
    }
    onEvent?.call(DashEvent.falseStart);
    _toResult('FALSE START!');
  }

  void _toResult(String line) {
    phase = DashPhase.result;
    banner = line;
    onEvent?.call(DashEvent.roundResult);
    notifyListeners();
    _arm(const Duration(milliseconds: 1500), _afterResult);
  }

  void _afterResult() {
    if (_disposed || paused || phase != DashPhase.result) return;
    _timer?.cancel();
    _timer = null;
    if (mode == DashMode.attack) {
      if (attackStrikes >= attackMaxStrikes) {
        _finish();
        return;
      }
      _beginRound();
      return;
    }
    if (mode == DashMode.bot) {
      round++;
      if (round >= roundsPerMatch) {
        _finish();
        return;
      }
      _beginRound();
      return;
    }
    // Quick: advance round / player.
    if (times[currentPlayer].length >= roundsPerMatch) {
      if (currentPlayer + 1 < playerCount) {
        currentPlayer++;
        phase = DashPhase.idle;
        banner = 'Pass to ${playerNames[currentPlayer]} — tap to start!';
        onEvent?.call(DashEvent.turnReady);
        notifyListeners();
        return;
      }
      _finish();
      return;
    }
    _beginRound();
  }

  void _finish() {
    phase = DashPhase.over;
    banner = _finalBanner();
    onEvent?.call(DashEvent.matchEnd);
    notifyListeners();
  }

  // -------------------------------------------------------------- results
  /// Quick-mode average for a player (lower is better). Null if no rounds.
  double? averageFor(int pi) {
    final t = times[pi];
    if (t.isEmpty) return null;
    return t.reduce((a, b) => a + b) / t.length;
  }

  int? quickWinner() {
    if (mode != DashMode.quick) return null;
    int? best;
    double? bestAvg;
    for (int i = 0; i < playerCount; i++) {
      final a = averageFor(i);
      if (a == null) continue;
      if (bestAvg == null || a < bestAvg) {
        bestAvg = a;
        best = i;
      }
    }
    return best;
  }

  bool get botHumanWon => humanRoundWins > botRoundWins;

  String _finalBanner() {
    if (mode == DashMode.attack) return 'Game over — $attackScore pts!';
    if (mode == DashMode.bot) {
      return botHumanWon
          ? 'You beat $botName $humanRoundWins–$botRoundWins!'
          : '$botName wins $botRoundWins–$humanRoundWins. Rematch?';
    }
    final w = quickWinner();
    if (w == null) return 'Match over!';
    if (playerCount == 1) {
      return 'Average ${averageFor(0)!.round()} ms — ${_verdict(averageFor(0)!.round())}';
    }
    return '${playerNames[w]} wins with ${averageFor(w)!.round()} ms avg!';
  }

  static String _verdict(int ms) {
    if (ms < 200) return 'Inhuman!!';
    if (ms < 280) return 'Superb!';
    if (ms < 400) return 'Nice!';
    if (ms < 600) return 'Solid!';
    return 'Keep practicing!';
  }

  static String grade(int ms) => _verdict(ms);

  /// Points for one valid tap (RULES §8).
  static int pointsFor(int ms) => ms >= 1500 ? 0 : 1500 - ms;
}
