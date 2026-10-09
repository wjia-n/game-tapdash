import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/dash_themes.dart';
import 'dash_ui.dart';

/// PRO custom arena creator: paint every arena color yourself.
/// All colors persist inside the single JSON profile.
class CustomThemeScreen extends StatelessWidget {
  final TapDashAudio audio;
  final TapDashSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  DashThemeDef get _t => settings.customTheme;

  static const _fields = [
    ('idle', 'Menu backdrop'),
    ('waiting', 'Wait (red) backdrop'),
    ('armed', 'GO (green) backdrop'),
    ('result', 'Result backdrop'),
    ('falseStart', 'False-start backdrop'),
    ('accent', 'Accent / rings'),
    ('accentDark', 'Accent dark'),
    ('card', 'Cards'),
    ('onCard', 'Card text'),
  ];

  // A physical, toy-box palette — no neon.
  static const _palette = [
    0xFFD23B3B, 0xFFB8472E, 0xFFC2503A, 0xFFD96C4A, 0xFFE09A4A, 0xFFF2C14E,
    0xFFE8A93D, 0xFFD9A93D, 0xFFB8A93D, 0xFF8FAD4E, 0xFF5C8A3C, 0xFF3F8F4F,
    0xFF2FA35C, 0xFF3E9E58, 0xFF46A06A, 0xFF2E9E6B, 0xFF3FA7C9, 0xFF7FC4D9,
    0xFF5E8FC9, 0xFF3E6E8E, 0xFF2B5D8A, 0xFF1F5F7A, 0xFF6E3E7A, 0xFF7A5FA0,
    0xFFB06EC9, 0xFFE88BB0, 0xFFD14A6E, 0xFF8A4E5E, 0xFF6E2430, 0xFF4A2E22,
    0xFFF3E3C2, 0xFFF0DCB4, 0xFFFFF8EA, 0xFFF4F6F8, 0xFFEDEAE2, 0xFFDDE2E6,
    0xFF8E9AA8, 0xFF5E6672, 0xFF3E444E, 0xFF2B2118,
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (_, _) {
        final t = _t;
        return Scaffold(
          backgroundColor: t.idleBg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: t.onCard),
              onPressed: () {
                audio.click();
                Navigator.of(context).pop();
              },
            ),
            title: Text('My Creation', style: DashKit.display(24, t)),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Live preview: the four arena states.
                Row(
                  children: [
                    _preview(t.waitingBg, 'WAIT'),
                    _preview(t.armedBg, 'GO!'),
                    _preview(t.resultBg, 'DONE'),
                    _preview(t.falseStartBg, 'OOPS'),
                  ],
                ),
                const SizedBox(height: 16),
                for (final (key, label) in _fields) ...[
                  DashKit.sectionTitle(label, t),
                  _colorRow(t, key),
                  const SizedBox(height: 6),
                ],
                const SizedBox(height: 16),
                Center(
                  child: DashKit.button(
                    t: t,
                    text: 'Use this arena',
                    onTap: () {
                      audio.click();
                      settings.setTheme('custom');
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () {
                      audio.click();
                      settings.resetCustomColors();
                    },
                    child: Text('Reset to defaults',
                        style: DashKit.label(14, t)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _preview(Color c, String label) {
    return Expanded(
      child: Container(
        height: 74,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.2), width: 2),
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13)),
        ),
      ),
    );
  }

  Widget _colorRow(DashThemeDef t, String key) {
    final current = Color(settings.customColors[key] ?? 0xFF000000);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final argb in _palette)
          GestureDetector(
            onTap: () {
              audio.click();
              settings.setCustomColor(key, argb);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(argb),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: current.value == argb
                      ? t.accentDark
                      : Colors.black.withValues(alpha: 0.18),
                  width: current.value == argb ? 4 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
