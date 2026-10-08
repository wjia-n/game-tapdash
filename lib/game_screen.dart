import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Tap Dash — reaction-time tester: 5 rounds, tap the instant it turns green.
class TapDashScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;

  const TapDashScreen({super.key, required this.players, required this.callbacks});

  @override
  State<TapDashScreen> createState() => _TapDashScreenState();
}

enum _Phase { idle, waiting, armed, result }

class _TapDashScreenState extends State<TapDashScreen> {
  static const int _rounds = 5;
  static const int _penalty = 1000;

  _Phase phase = _Phase.idle;
  int round = 0;
  final List<int> times = [];
  int _token = 0;
  int? _lastMs;
  bool _falseStart = false;
  DateTime? _armedAt;
  int best = 0;
  final rng = Random();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() => best = p.getInt('tapdash_best') ?? 0);
      }
    });
  }

  void _startMatch() {
    setState(() {
      round = 0;
      times.clear();
      _lastMs = null;
      _falseStart = false;
    });
    _startRound();
  }

  void _startRound() {
    final my = ++_token;
    setState(() {
      phase = _Phase.waiting;
      _lastMs = null;
      _falseStart = false;
    });
    final delay = 1500 + rng.nextInt(2500);
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted || my != _token || phase != _Phase.waiting) return;
      setState(() {
        phase = _Phase.armed;
        _armedAt = DateTime.now();
      });
      Sfx.click();
    });
  }

  void _tap() {
    if (phase == _Phase.idle || phase == _Phase.result) {
      _startMatch();
      return;
    }
    if (phase == _Phase.waiting) {
      // false start!
      _token++;
      setState(() {
        _falseStart = true;
        _lastMs = _penalty;
        phase = _Phase.result;
      });
      Sfx.lose();
      _next();
      return;
    }
    if (phase == _Phase.armed && _armedAt != null) {
      final ms = DateTime.now().difference(_armedAt!).inMilliseconds;
      _token++;
      setState(() {
        _lastMs = ms;
        phase = _Phase.result;
      });
      if (ms < 250) {
        Sfx.win();
      } else {
        Sfx.tap();
      }
      _next();
    }
  }

  void _next() {
    final my = _token;
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted || my != _token) return;
      times.add(_lastMs ?? _penalty);
      if (times.length >= _rounds) {
        _finishMatch();
      } else {
        setState(() => round = times.length);
        _startRound();
      }
    });
  }

  Future<void> _finishMatch() async {
    final avg = (times.reduce((a, b) => a + b) / times.length).round();
    widget.players[0].score = max(0, 2000 - avg);
    widget.callbacks.refreshHud();
    final prefs = await SharedPreferences.getInstance();
    final isBest = best == 0 || avg < best;
    if (isBest) {
      await prefs.setInt('tapdash_best', avg);
      if (mounted) {
        setState(() => best = avg);
      }
    }
    if (!mounted) return;
    final grade = avg < 220
        ? '⚡ LIGHTNING!'
        : avg < 320
            ? '🔥 Blazing fast!'
            : avg < 450
                ? '👍 Solid reflexes!'
                : '🐢 Warm those fingers up!';
    widget.callbacks.finish(
      headline: 'Average: $avg ms $grade',
      subline: isBest ? 'NEW BEST average! 🥇' : 'Best average: $best ms.',
    );
  }

  Color _bg(GameTheme t) {
    switch (phase) {
      case _Phase.idle:
        return t.surface;
      case _Phase.waiting:
        return const Color(0xFFE63946);
      case _Phase.armed:
        return const Color(0xFF2FBF71);
      case _Phase.result:
        return _falseStart ? const Color(0xFF6C1F2A) : const Color(0xFF1E5F8A);
    }
  }

  String _mainText() {
    switch (phase) {
      case _Phase.idle:
        return 'Tap to start ⚡';
      case _Phase.waiting:
        return 'Wait for green… 🟢';
      case _Phase.armed:
        return 'TAP NOW!';
      case _Phase.result:
        return _falseStart ? 'FALSE START! 😅' : '$_lastMs ms';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _bg(t),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Round ${min(round + 1, _rounds)}/$_rounds',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('🏆 ${best == 0 ? '—' : '$best ms'}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      _rounds,
                      (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 26,
                            height: 10,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: i < times.length
                                  ? Colors.white
                                  : (i == times.length && phase != _Phase.idle
                                      ? Colors.white70
                                      : Colors.white24),
                            ),
                          )),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_mainText(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 14),
                        if (phase == _Phase.idle)
                          const Text('5 rounds · tap only when it turns green',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, fontSize: 15)),
                        if (phase == _Phase.result && !_falseStart && _lastMs != null)
                          Text(_verdict(_lastMs!),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    for (int i = 0; i < times.length; i++)
                      Chip(
                        label: Text(times[i] >= _penalty ? '❌ FS' : '${times[i]}ms',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700)),
                        backgroundColor: Colors.black26,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _verdict(int ms) {
    if (ms < 200) {
      return 'Inhuman!! ⚡';
    }
    if (ms < 280) {
      return 'Superb! 🔥';
    }
    if (ms < 400) {
      return 'Nice! 👍';
    }
    return 'Keep practicing 💪';
  }
}
