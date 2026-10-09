import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/dash_themes.dart';
import 'dash_ui.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';
import 'themes_screen.dart';

/// Main menu: mode picker, player count, difficulty tiers, best stats,
/// and navigation to Themes / Settings / Pro.
class MenuScreen extends StatelessWidget {
  final TapDashAudio audio;
  final TapDashSettings settings;
  const MenuScreen({super.key, required this.audio, required this.settings});

  DashThemeDef get _t => DashThemes.byId(
        settings.themeId,
        custom: settings.customTheme,
      );

  void _play(BuildContext context) {
    audio.click();
    audio.startGameMusic();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: audio,
          settings: settings,
          store: StoreService()..init(),
        ),
      ),
    ).then((_) => audio.startMenuMusic());
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return ListenableBuilder(
      listenable: settings,
      builder: (_, _) => Scaffold(
        backgroundColor: t.idleBg,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: logo + name + pro badge.
                Row(
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: t.accentDark, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            offset: const Offset(0, 6),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset('assets/tapdash_logo.png',
                          fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tap Dash', style: DashKit.display(34, t)),
                          Text('How fast are those fingers?',
                              style: DashKit.label(13, t)),
                        ],
                      ),
                    ),
                    if (settings.isPro)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: t.accent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.black.withValues(alpha: 0.2)),
                        ),
                        child: const Text('PRO',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13)),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                // Dasher mascot + best stats.
                DashKit.card(
                  t: t,
                  child: Row(
                    children: [
                      Dasher(
                          style: DasherStyles.byId(settings.styleId), size: 84),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hey, ${settings.playerNames[0]}!',
                                style: DashKit.display(20, t)),
                            const SizedBox(height: 6),
                            _stat(t, 'Best average',
                                settings.bestQuickAvg == 0 ? '—' : '${settings.bestQuickAvg} ms'),
                            _stat(t, 'Best attack',
                                settings.bestAttack == 0 ? '—' : '${settings.bestAttack} pts'),
                            _stat(t, 'Vs Robo-Dash',
                                '${settings.botWins}W – ${settings.botLosses}L'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                DashKit.sectionTitle('Game mode', t),
                _modeCard(
                  context, t,
                  id: 'quick',
                  title: 'Quick Match',
                  desc: '5 rounds. Lowest average wins.',
                ),
                const SizedBox(height: 10),
                _modeCard(
                  context, t,
                  id: 'attack',
                  title: 'Score Attack',
                  desc: 'Endless rounds. 3 false starts end it.',
                ),
                const SizedBox(height: 10),
                _modeCard(
                  context, t,
                  id: 'bot',
                  title: 'Vs Robo-Dash',
                  desc: 'Race the bot. Tap before it does!',
                ),
                const SizedBox(height: 14),
                if (settings.mode == 'quick') ...[
                  DashKit.sectionTitle('Players (pass & play)', t),
                  _stepper(t, settings.playerCount, 1, 4,
                      (v) => settings.setPlayerCount(v)),
                  const SizedBox(height: 14),
                ],
                if (settings.mode == 'bot') ...[
                  DashKit.sectionTitle('Bot skill', t),
                  _botDiffRow(t),
                  const SizedBox(height: 14),
                ],
                DashKit.sectionTitle('Speed tier', t),
                _difficultyRow(t),
                const SizedBox(height: 22),
                Center(
                  child: DashKit.button(
                    t: t,
                    text: '▶  PLAY',
                    fontSize: 26,
                    onTap: () => _play(context),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 60, vertical: 18),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _navBtn(context, t, 'Themes', Icons.palette, () {
                      audio.click();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ThemesScreen(
                              audio: audio, settings: settings)));
                    }),
                    _navBtn(context, t, 'Settings', Icons.settings, () {
                      audio.click();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => SettingsScreen(
                              audio: audio, settings: settings)));
                    }),
                    _navBtn(context, t, settings.isPro ? 'Pro ✓' : 'Go Pro',
                        Icons.star, () {
                      audio.click();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ProScreen(
                              audio: audio,
                              settings: settings,
                              store: StoreService()..init())));
                    }),
                  ],
                ),
                const SizedBox(height: 26),
                Center(
                  child: Text('Tap only when it turns GREEN!',
                      style: DashKit.label(12, t)),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(DashThemeDef t, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Text('$k: ', style: DashKit.label(13, t)),
          Text(v,
              style: DashKit.label(13, t).copyWith(
                  color: t.onCard, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _modeCard(BuildContext context, DashThemeDef t,
      {required String id, required String title, required String desc}) {
    final selected = settings.mode == id;
    return GestureDetector(
      onTap: () {
        audio.click();
        settings.setMode(id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? t.accent.withValues(alpha: 0.28) : t.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? t.accentDark : Colors.black.withValues(alpha: 0.14),
            width: selected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.22 : 0.12),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? t.accentDark : Colors.transparent,
                border: Border.all(color: t.accentDark, width: 2),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DashKit.display(18, t)),
                  Text(desc, style: DashKit.label(13, t)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepper(
      DashThemeDef t, int value, int min, int max, ValueChanged<int> onChange) {
    return DashKit.card(
      t: t,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stepBtn(t, Icons.remove, () {
            audio.click();
            onChange((value - 1).clamp(min, max));
          }),
          Text('$value player${value > 1 ? 's' : ''}',
              style: DashKit.display(22, t)),
          _stepBtn(t, Icons.add, () {
            audio.click();
            onChange((value + 1).clamp(min, max));
          }),
        ],
      ),
    );
  }

  Widget _stepBtn(DashThemeDef t, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: t.accent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                offset: const Offset(0, 3),
                blurRadius: 0),
          ],
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _botDiffRow(DashThemeDef t) {
    const names = ['Chill Bot', 'Swift Bot', 'Beast Bot'];
    return Row(
      children: List.generate(3, (i) {
        final selected = settings.botDifficulty == i;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              audio.click();
              settings.setBotDifficulty(i);
            },
            child: Container(
              margin: EdgeInsets.only(left: i == 0 ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? t.accent : t.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: selected
                        ? t.accentDark
                        : Colors.black.withValues(alpha: 0.14),
                    width: selected ? 3 : 2),
              ),
              child: Center(
                child: Text(names[i],
                    textAlign: TextAlign.center,
                    style: DashKit.label(13, t).copyWith(
                        color: selected ? Colors.white : t.onCard,
                        fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _difficultyRow(DashThemeDef t) {
    const defs = [
      ('Chill', 'Relaxed waits', 0, false),
      ('Swift', 'Snappier waits', 1, false),
      ('Lightning', 'Trick flashes!', 2, true),
    ];
    return Row(
      children: [
        for (final (name, desc, idx, pro) in defs)
          Expanded(
            child: GestureDetector(
              onTap: () {
                audio.click();
                settings.setDifficulty(idx);
              },
              child: Container(
                margin: EdgeInsets.only(left: idx == 0 ? 0 : 8),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                decoration: BoxDecoration(
                  color: settings.difficulty == idx ? t.accent : t.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: settings.difficulty == idx
                          ? t.accentDark
                          : Colors.black.withValues(alpha: 0.14),
                      width: settings.difficulty == idx ? 3 : 2),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(name,
                            style: DashKit.label(14, t).copyWith(
                                color: settings.difficulty == idx
                                    ? Colors.white
                                    : t.onCard,
                                fontWeight: FontWeight.w900)),
                        if (pro && !settings.isPro)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.lock,
                                size: 14, color: Colors.white),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(desc,
                        textAlign: TextAlign.center,
                        style: DashKit.label(11, t).copyWith(
                            color: settings.difficulty == idx
                                ? Colors.white.withValues(alpha: 0.9)
                                : t.onCard.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _navBtn(BuildContext context, DashThemeDef t, String label,
      IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: Colors.black.withValues(alpha: 0.14), width: 2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    offset: const Offset(0, 4),
                    blurRadius: 8),
              ],
            ),
            child: Icon(icon, color: t.accentDark, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: DashKit.label(12, t)),
        ],
      ),
    );
  }
}
