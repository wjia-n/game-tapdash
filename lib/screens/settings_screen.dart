import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/dash_themes.dart';
import 'dash_ui.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.tapdash';

/// Settings: renameable player profile (all 4 pass-and-play slots),
/// music/SFX toggles + volume, share, rate, reset stats.
class SettingsScreen extends StatefulWidget {
  final TapDashAudio audio;
  final TapDashSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final List<TextEditingController> _nameCtrls;

  DashThemeDef get _t => DashThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    _nameCtrls = [
      for (int i = 0; i < 4; i++)
        TextEditingController(text: widget.settings.playerNames[i]),
    ];
  }

  @override
  void dispose() {
    for (final c in _nameCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyAudio() {
    widget.audio.configure(
      musicOn: widget.settings.musicOn,
      sfxOn: widget.settings.sfxOn,
      volume: widget.settings.volume,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) => Scaffold(
        backgroundColor: t.idleBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.onCard),
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Settings', style: DashKit.display(24, t)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashKit.sectionTitle('Player names', t),
              DashKit.card(
                t: t,
                child: Column(
                  children: [
                    for (int i = 0; i < 4; i++)
                      Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: t.accent.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                  child: Text('P${i + 1}',
                                      style: DashKit.label(13, t))),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _nameCtrls[i],
                                maxLength: 14,
                                style: DashKit.label(16, t)
                                    .copyWith(color: t.onCard),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: TapDashSettings.defaultNames[i],
                                  hintStyle: DashKit.label(16, t).copyWith(
                                      color: t.onCard
                                          .withValues(alpha: 0.4)),
                                  filled: true,
                                  fillColor: Colors.black
                                      .withValues(alpha: 0.05),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                ),
                                onChanged: (v) =>
                                    widget.settings.setPlayerName(i, v),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              DashKit.sectionTitle('Audio', t),
              DashKit.card(
                t: t,
                child: Column(
                  children: [
                    _toggleRow(t, 'Music', Icons.music_note,
                        widget.settings.musicOn, (v) {
                      widget.settings.setMusic(v);
                      _applyAudio();
                      widget.audio.click();
                    }),
                    const SizedBox(height: 6),
                    _toggleRow(t, 'Sound effects', Icons.volume_up,
                        widget.settings.sfxOn, (v) {
                      widget.settings.setSfx(v);
                      _applyAudio();
                      widget.audio.click();
                    }),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.volume_down, color: t.onCard),
                        Expanded(
                          child: Slider(
                            value: widget.settings.volume,
                            activeColor: t.accentDark,
                            inactiveColor: t.accent.withValues(alpha: 0.3),
                            onChanged: (v) {
                              widget.settings.setVolume(v);
                              _applyAudio();
                            },
                            onChangeEnd: (_) => widget.audio.click(),
                          ),
                        ),
                        Icon(Icons.volume_up, color: t.onCard),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              DashKit.sectionTitle('Share the fun', t),
              Row(
                children: [
                  Expanded(
                    child: DashKit.button(
                      t: t,
                      text: 'Share Tap Dash',
                      fontSize: 16,
                      onTap: () async {
                        widget.audio.click();
                        try {
                          await Share.share(
                            'Think you\'ve got fast fingers? Try Tap Dash! $_storeUrl',
                            subject: 'Tap Dash',
                          );
                        } catch (_) {}
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DashKit.button(
                      t: t,
                      text: 'Rate us',
                      fontSize: 16,
                      color: t.cardBg,
                      textColor: t.onCard,
                      onTap: () async {
                        widget.audio.click();
                        try {
                          if (await InAppReview.instance.isAvailable()) {
                            await InAppReview.instance.requestReview();
                          }
                        } catch (_) {}
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DashKit.sectionTitle('Stats', t),
              DashKit.card(
                t: t,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Games played: ${widget.settings.gamesPlayed}',
                        style: DashKit.label(15, t)),
                    const SizedBox(height: 4),
                    Text(
                        'Best average: ${widget.settings.bestQuickAvg == 0 ? '—' : '${widget.settings.bestQuickAvg} ms'}',
                        style: DashKit.label(15, t)),
                    const SizedBox(height: 4),
                    Text(
                        'Best attack: ${widget.settings.bestAttack == 0 ? '—' : '${widget.settings.bestAttack} pts'}',
                        style: DashKit.label(15, t)),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          widget.audio.click();
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Reset stats?'),
                              content: const Text(
                                  'This clears your bests and win counts.'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.of(c).pop(false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.of(c).pop(true),
                                    child: const Text('Reset')),
                              ],
                            ),
                          );
                          if (ok == true) {
                            widget.settings.resetStats();
                          }
                        },
                        child: Text('Reset all stats',
                            style: DashKit.label(14, t).copyWith(
                                color: const Color(0xFFB03024))),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text('Made with love by WAJIHA',
                    style: DashKit.label(12, t)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleRow(DashThemeDef t, String label, IconData icon, bool value,
      ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Icon(icon, color: t.accentDark),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: DashKit.label(16, t))),
        Switch(
          value: value,
          activeThumbColor: t.accentDark,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
