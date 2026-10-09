import 'package:flutter/material.dart';

/// Theme catalog for Tap Dash.
///
/// Every theme is a full-screen "arena" palette: the whole screen is the
/// game board, so idle/waiting/armed/result each get their own physical,
/// material-feeling background color. No neon, no cyberpunk — warm arcades,
/// wood, felt, stone, candy-shop paint.
class DashThemeDef {
  final String id;
  final String name;
  final bool isPro;
  final Color idleBg; // menu / pre-round backdrop
  final Color waitingBg; // the "wait for it…" red-ish backdrop
  final Color armedBg; // GREEN — tap now
  final Color resultBg; // round-result backdrop
  final Color falseStartBg; // false-start backdrop
  final Color accent; // rings, chips, highlights
  final Color accentDark;
  final Color cardBg; // panels / HUD cards
  final Color onDark; // text on colored backdrops
  final Color onCard; // text on cards

  const DashThemeDef({
    required this.id,
    required this.name,
    this.isPro = false,
    required this.idleBg,
    required this.waitingBg,
    required this.armedBg,
    required this.resultBg,
    required this.falseStartBg,
    required this.accent,
    required this.accentDark,
    required this.cardBg,
    required this.onDark,
    required this.onCard,
  });
}

class DashThemes {
  /// First 4 are the FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'classic',
    'desert',
    'ocean',
    'forest',
  ];

  static bool isProTheme(String id) =>
      !freeThemeIds.contains(id) && id != 'custom';

  static const List<DashThemeDef> all = [
    DashThemeDef(
      id: 'classic',
      name: 'Classic Arcade',
      idleBg: Color(0xFFF3E3C2),
      waitingBg: Color(0xFFD23B3B),
      armedBg: Color(0xFF2FA35C),
      resultBg: Color(0xFF2B5D8A),
      falseStartBg: Color(0xFF6E2430),
      accent: Color(0xFFE8A93D),
      accentDark: Color(0xFFB97B1E),
      cardBg: Color(0xFFFFF8EA),
      onDark: Color(0xFFFFFFFF),
      onCard: Color(0xFF4A2E1B),
    ),
    DashThemeDef(
      id: 'desert',
      name: 'Desert Dunes',
      idleBg: Color(0xFFF0DCB4),
      waitingBg: Color(0xFFC65B2E),
      armedBg: Color(0xFF5C8A3C),
      resultBg: Color(0xFF7A5C36),
      falseStartBg: Color(0xFF5E2F22),
      accent: Color(0xFFD99A3D),
      accentDark: Color(0xFFA86F24),
      cardBg: Color(0xFFFFF4DE),
      onDark: Color(0xFFFFFFFF),
      onCard: Color(0xFF5E3B1E),
    ),
    DashThemeDef(
      id: 'ocean',
      name: 'Ocean Reef',
      idleBg: Color(0xFFD8EAEF),
      waitingBg: Color(0xFFC04545),
      armedBg: Color(0xFF2E9E6B),
      resultBg: Color(0xFF1F5F7A),
      falseStartBg: Color(0xFF4A2A3A),
      accent: Color(0xFF3FA7C9),
      accentDark: Color(0xFF2A7C99),
      cardBg: Color(0xFFF2FAFC),
      onDark: Color(0xFFFFFFFF),
      onCard: Color(0xFF1E4A5C),
    ),
    DashThemeDef(
      id: 'forest',
      name: 'Forest Glade',
      idleBg: Color(0xFFDEE8CF),
      waitingBg: Color(0xFFB84A3A),
      armedBg: Color(0xFF3F8F4F),
      resultBg: Color(0xFF3A5F46),
      falseStartBg: Color(0xFF4A2E2A),
      accent: Color(0xFF8FAD4E),
      accentDark: Color(0xFF6A8334),
      cardBg: Color(0xFFF4F8EA),
      onDark: Color(0xFFFFFFFF),
      onCard: Color(0xFF33482A),
    ),
    DashThemeDef(
      id: 'volcano',
      name: 'Volcano Rock',
      isPro: true,
      idleBg: Color(0xFFE8D5C4),
      waitingBg: Color(0xFFB03024),
      armedBg: Color(0xFF3E9E58),
      resultBg: Color(0xFF4A3A34),
      falseStartBg: Color(0xFF2E1A18),
      accent: Color(0xFFE07B39),
      accentDark: Color(0xFFB25A22),
      cardBg: Color(0xFFFBF1E6),
      onDark: Color(0xFFFFFFFF),
      onCard: Color(0xFF4A2E22),
    ),
    DashThemeDef(
      id: 'snowfield',
      name: 'Snowfield',
      isPro: true,
      idleBg: Color(0xFFEAF2F7),
      waitingBg: Color(0xFFC05656),
      armedBg: Color(0xFF35A06A),
      resultBg: Color(0xFF3E6E8E),
      falseStartBg: Color(0xFF3A3A4E),
      accent: Color(0xFF7FB6D9),
      accentDark: Color(0xFF5A8FB5),
      cardBg: Color(0xFFFFFFFF),
      onDark: Color(0xFFFFFFFF),
      onCard: Color(0xFF2E4A5E),
    ),
    DashThemeDef(
      id: 'candy',
      name: 'Candy Shop',
      isPro: true,
      idleBg: Color(0xFFF9E4EC),
      waitingBg: Color(0xFFD14A6E),
      armedBg: Color(0xFF4CAF6D),
      resultBg: Color(0xFF7A5FA0),
      falseStartBg: Color(0xFF5E2E48),
      accent: Color(0xFFE88BB0),
      accentDark: Color(0xFFC05F88),
      cardBg: Color(0xFFFFF6FA),
      onDark: Color(0xFFFFFFFF),
      onCard: Color(0xFF6E2E4A),
    ),
    DashThemeDef(
      id: 'sunset',
      name: 'Sunset Strip',
      isPro: true,
      idleBg: Color(0xFFF6DFC0),
      waitingBg: Color(0xFFC2503A),
      armedBg: Color(0xFF4E9E5C),
      resultBg: Color(0xFF8A4E5E),
      falseStartBg: Color(0xFF4E2430),
      accent: Color(0xFFE09A4A),
      accentDark: Color(0xFFB87630),
      cardBg: Color(0xFFFFF3E2),
      onDark: Color(0xFFFFFFFF),
      onCard: Color(0xFF6E3E24),
    ),
    DashThemeDef(
      id: 'jungle',
      name: 'Jungle Rush',
      isPro: true,
      idleBg: Color(0xFFDDE6C4),
      waitingBg: Color(0xFFB8472E),
      armedBg: Color(0xFF3D9E57),
      resultBg: Color(0xFF2E5E4A),
      falseStartBg: Color(0xFF3A2E24),
      accent: Color(0xFFB8A93D),
      accentDark: Color(0xFF8E8328),
      cardBg: Color(0xFFF6F8E8),
      onDark: Color(0xFFFFFFFF),
      onCard: Color(0xFF3E4A24),
    ),
    DashThemeDef(
      id: 'marble',
      name: 'Marble Hall',
      isPro: true,
      idleBg: Color(0xFFEDEAE2),
      waitingBg: Color(0xFFB54A4A),
      armedBg: Color(0xFF3E9463),
      resultBg: Color(0xFF4E5E6E),
      falseStartBg: Color(0xFF3A343E),
      accent: Color(0xFFB0A58E),
      accentDark: Color(0xFF8A8069),
      cardBg: Color(0xFFFFFFFF),
      onDark: Color(0xFFFFFFFF),
      onCard: Color(0xFF4A4438),
    ),
    DashThemeDef(
      id: 'berry',
      name: 'Berry Blast',
      isPro: true,
      idleBg: Color(0xFFEFDFF0),
      waitingBg: Color(0xFFC14A5E),
      armedBg: Color(0xFF46A06A),
      resultBg: Color(0xFF6E3E7A),
      falseStartBg: Color(0xFF4A2440),
      accent: Color(0xFFB06EC9),
      accentDark: Color(0xFF8E4EA8),
      cardBg: Color(0xFFFBF4FC),
      onDark: Color(0xFFFFFFFF),
      onCard: Color(0xFF5E2E6E),
    ),
    DashThemeDef(
      id: 'storm',
      name: 'Storm Grey',
      isPro: true,
      idleBg: Color(0xFFDDE2E6),
      waitingBg: Color(0xFFAE4A42),
      armedBg: Color(0xFF3E9E60),
      resultBg: Color(0xFF3E4E5E),
      falseStartBg: Color(0xFF2A2E36),
      accent: Color(0xFF8E9AA8),
      accentDark: Color(0xFF6E7888),
      cardBg: Color(0xFFF4F6F8),
      onDark: Color(0xFFFFFFFF),
      onCard: Color(0xFF3E444E),
    ),
  ];

  static DashThemeDef byId(String id, {DashThemeDef? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static List<DashThemeDef> visible({required bool isPro, DashThemeDef? custom}) {
    final list = [
      for (final t in all)
        if (!t.isPro || isPro) t,
    ];
    if (isPro && custom != null) list.add(custom);
    return list;
  }
}

// ---------------------------------------------------------------------------
// Dasher styles: the little runner character drawn on screen.
// 8 styles, first 4 free, rest PRO. Each is a physical toy material.
// ---------------------------------------------------------------------------
class DasherStyleDef {
  final int id;
  final String name;
  final bool isPro;
  final Color body; // main body color
  final Color bodyDark; // shading
  final Color belly; // belly / highlight patch
  final Color hat; // hat or accessory color
  final double roundness; // 0 = boxy .. 1 = round
  final bool stripes; // painted racing stripes

  const DasherStyleDef({
    required this.id,
    required this.name,
    this.isPro = false,
    required this.body,
    required this.bodyDark,
    required this.belly,
    required this.hat,
    required this.roundness,
    this.stripes = false,
  });
}

class DasherStyles {
  static const List<DasherStyleDef> all = [
    DasherStyleDef(
      id: 0,
      name: 'Woody',
      body: Color(0xFFD9A066),
      bodyDark: Color(0xFFA86F3C),
      belly: Color(0xFFF0D3A8),
      hat: Color(0xFF5E8FC9),
      roundness: 0.9,
    ),
    DasherStyleDef(
      id: 1,
      name: 'Marble',
      body: Color(0xFFF2F0EA),
      bodyDark: Color(0xFFB9B4A6),
      belly: Color(0xFFFFFFFF),
      hat: Color(0xFFC9563C),
      roundness: 1.0,
      stripes: true,
    ),
    DasherStyleDef(
      id: 2,
      name: 'Rubber Duck',
      body: Color(0xFFF2C14E),
      bodyDark: Color(0xFFC9932E),
      belly: Color(0xFFFBE3A0),
      hat: Color(0xFFD96C4A),
      roundness: 0.85,
    ),
    DasherStyleDef(
      id: 3,
      name: 'Clay Boulder',
      body: Color(0xFFC97B5A),
      bodyDark: Color(0xFF9A5638),
      belly: Color(0xFFE8B08E),
      hat: Color(0xFF6E8E5A),
      roundness: 0.75,
    ),
    DasherStyleDef(
      id: 4,
      name: 'Brass Bolt',
      isPro: true,
      body: Color(0xFFD9A93D),
      bodyDark: Color(0xFF9A7524),
      belly: Color(0xFFF2D88E),
      hat: Color(0xFF4E5E6E),
      roundness: 0.6,
      stripes: true,
    ),
    DasherStyleDef(
      id: 5,
      name: 'Felt Fox',
      isPro: true,
      body: Color(0xFF7BAE6E),
      bodyDark: Color(0xFF57824C),
      belly: Color(0xFFC4DDAE),
      hat: Color(0xFFD96C4A),
      roundness: 0.7,
    ),
    DasherStyleDef(
      id: 6,
      name: 'Glass Gem',
      isPro: true,
      body: Color(0xFF7FC4D9),
      bodyDark: Color(0xFF4E8EA8),
      belly: Color(0xFFD4EEF7),
      hat: Color(0xFFF2C14E),
      roundness: 0.5,
    ),
    DasherStyleDef(
      id: 7,
      name: 'Slate Shadow',
      isPro: true,
      body: Color(0xFF5E6672),
      bodyDark: Color(0xFF3E444E),
      belly: Color(0xFF9AA2AE),
      hat: Color(0xFFD9A93D),
      roundness: 0.65,
      stripes: true,
    ),
  ];

  static DasherStyleDef byId(int id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return all.first;
  }

  static bool isPro(int id) => byId(id).isPro;
  static List<DasherStyleDef> visible({required bool isPro}) =>
      [for (final s in all) if (!s.isPro || isPro) s];
}
