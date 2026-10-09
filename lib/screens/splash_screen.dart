import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/dash_themes.dart';
import 'dash_ui.dart';
import 'menu_screen.dart';

/// Launch splash: WAJIHA company moment → game splash (logo + name +
/// animated loading line + "Credits: WAJIHA"). Single splash flow.
class SplashScreen extends StatefulWidget {
  final TapDashAudio audio;
  final TapDashSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  bool _companyDone = false;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the splash shows, then start menu music.
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    // Company moment: the official WAJIHA logo, untouched.
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _companyDone = true);
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_companyDone) return const _CompanySplash();
    final theme = DashThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return _GameSplash(theme: theme, loader: _loader);
  }
}

/// Company splash moment: the official WAJIHA logo, never redrawn.
class _CompanySplash extends StatelessWidget {
  const _CompanySplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/wajiha_logo.png', fit: BoxFit.cover),
            ),
            const SizedBox(height: 20),
            const Text(
              'WAJIHA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Game splash: logo + name + animated loading line + credits.
class _GameSplash extends StatelessWidget {
  final DashThemeDef theme;
  final AnimationController loader;
  const _GameSplash({required this.theme, required this.loader});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.idleBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: theme.accentDark, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    offset: const Offset(0, 12),
                    blurRadius: 26,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/tapdash_logo.png', fit: BoxFit.cover),
            ),
            const SizedBox(height: 22),
            Text('Tap Dash', style: DashKit.display(52, theme)),
            const SizedBox(height: 6),
            Text('ONE-TAP REACTION ARCADE',
                style: DashKit.label(13, theme)),
            const SizedBox(height: 30),
            // Animated loading line.
            SizedBox(
              width: 220,
              child: AnimatedBuilder(
                animation: loader,
                builder: (_, _) => Column(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.black.withValues(alpha: 0.18),
                        border: Border.all(
                          color: theme.accentDark.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: loader.value.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: theme.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Warming up those fingers…',
                        style: DashKit.label(13, theme)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 34),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/wajiha_logo.png',
                      width: 26, height: 26, fit: BoxFit.cover),
                ),
                const SizedBox(width: 8),
                Text('Credits: WAJIHA', style: DashKit.label(14, theme)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
