import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';
import 'theme/dash_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final settings = TapDashSettings();
  await settings.load();
  final audio = TapDashAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  runApp(TapDashApp(settings: settings, audio: audio));
}

class TapDashApp extends StatefulWidget {
  final TapDashSettings settings;
  final TapDashAudio audio;
  const TapDashApp({super.key, required this.settings, required this.audio});

  @override
  State<TapDashApp> createState() => _TapDashAppState();
}

class _TapDashAppState extends State<TapDashApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; game screens additionally freeze their engines.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) {
        final theme = DashThemes.byId(
          widget.settings.themeId,
          custom: widget.settings.customTheme,
        );
        return MaterialApp(
          title: 'Tap Dash',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: theme.idleBg,
            colorScheme: ColorScheme.fromSeed(seedColor: theme.accent),
          ),
          home: SplashScreen(audio: widget.audio, settings: widget.settings),
        );
      },
    );
  }
}
