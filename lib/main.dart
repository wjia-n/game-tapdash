import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const TapDashApp());

class TapDashApp extends StatelessWidget {
  const TapDashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Tap Dash',
      tagline: 'One-tap rhythm dashing through tricky levels',
      emoji: '⚡',
      slug: 'tapdash',
      howToPlay:
          '• 5 rounds. The screen turns red — wait for GREEN, then tap!\n• Tap too early = false start penalty.\n• Your reaction time is measured in milliseconds.\n• Lowest average wins. Lightning fingers ready?',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => TapDashScreen(players: players, callbacks: cb),
    );
  }
}
