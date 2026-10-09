import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/tapdash_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/dash_themes.dart';
import 'dash_ui.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.tapdash';

/// The tap arena: the whole screen is the game. Engine-owned phases;
/// this widget only renders + forwards taps.
class GameScreen extends StatefulWidget {
  final TapDashAudio audio;
  final TapDashSettings settings;
  final StoreService store;
  const GameScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TapDashEngine _engine;
  late final AnimationController _pulse;
  bool _showResults = false;
  bool _reviewAsked = false;

  DashThemeDef get _t => DashThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final s = widget.settings;
    _engine = TapDashEngine(
      mode: switch (s.mode) {
        'attack' => DashMode.attack,
        'bot' => DashMode.bot,
        _ => DashMode.quick,
      },
      playerNames: [for (int i = 0; i < s.playerCount; i++) s.playerNames[i]],
      playerCount: s.mode == 'quick' ? s.playerCount : 1,
      difficulty: DashDifficulty.values[s.difficulty],
      botDifficulty: s.botDifficulty,
    );
    _engine.onEvent = _onEvent;
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _engine.startMatch();
  }

  void _onEvent(DashEvent e) {
    final a = widget.audio;
    switch (e) {
      case DashEvent.countdownTick:
        a.countdown();
        break;
      case DashEvent.go:
        a.go();
        HapticFeedback.heavyImpact();
        break;
      case DashEvent.decoy:
        a.decoy();
        HapticFeedback.lightImpact();
        break;
      case DashEvent.tapValid:
        a.tap();
        HapticFeedback.mediumImpact();
        break;
      case DashEvent.falseStart:
        a.falseStart();
        HapticFeedback.heavyImpact();
        break;
      case DashEvent.roundResult:
        if (_engine.lastFalseStart) {
          // buzzer already played
        } else if (_engine.mode == DashMode.bot && !_engine.lastRoundHumanWon) {
          a.lose();
        } else if (_engine.lastMs != null && _engine.lastMs! < 280) {
          a.roundWin();
        }
        break;
      case DashEvent.matchEnd:
        _onMatchEnd();
        break;
      case DashEvent.turnReady:
        a.click();
        break;
    }
  }

  Future<void> _onMatchEnd() async {
    final s = widget.settings;
    final e = _engine;
    if (e.mode == DashMode.quick) {
      final w = e.quickWinner();
      if (w != null) {
        final avg = e.averageFor(w)!.round();
        await s.recordQuick(avg);
        if (e.playerCount == 1) {
          widget.audio.win();
        } else {
          widget.audio.roundWin();
        }
      }
    } else if (e.mode == DashMode.attack) {
      await s.recordAttack(e.attackScore);
      widget.audio.win();
    } else {
      await s.recordBot(e.botHumanWon);
      if (e.botHumanWon) {
        widget.audio.win();
      } else {
        widget.audio.lose();
      }
    }
    if (!mounted) return;
    setState(() => _showResults = true);
    // Sensible review moment: every 5th finished game, only when launched
    // from Play (guarded — never crashes).
    if (!_reviewAsked &&
        s.gamesPlayed > 0 &&
        s.gamesPlayed % 5 == 0) {
      _reviewAsked = true;
      try {
        if (await InAppReview.instance.isAvailable()) {
          await InAppReview.instance.requestReview();
        }
      } catch (_) {}
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Freeze the engine while backgrounded so timers can't fire unseen.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _engine.setPaused(true);
    } else if (state == AppLifecycleState.resumed) {
      if (!_showResults) _engine.setPaused(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _engine.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Color _bg() {
    final t = _t;
    switch (_engine.phase) {
      case DashPhase.idle:
      case DashPhase.countdown:
        return t.idleBg;
      case DashPhase.waiting:
        return t.waitingBg;
      case DashPhase.decoy:
        return const Color(0xFFE8A93D); // trick flash — amber, not green
      case DashPhase.armed:
        return t.armedBg;
      case DashPhase.result:
        return _engine.lastFalseStart ? t.falseStartBg : t.resultBg;
      case DashPhase.over:
        return t.idleBg;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _engine,
      builder: (_, _) => Scaffold(
        backgroundColor: _bg(),
        body: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_showResults || _engine.paused) return;
                _engine.tap();
              },
              child: SafeArea(
                child: Column(
                  children: [
                    _hud(),
                    Expanded(child: _arena()),
                    _footer(),
                  ],
                ),
              ),
            ),
            if (_engine.paused && !_showResults) _pauseOverlay(),
            if (_showResults) _resultsOverlay(),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- HUD
  Widget _hud() {
    final e = _engine;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              widget.audio.click();
              e.setPaused(true);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.pause, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _roundChips()),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(_modeLabel(),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _modeLabel() {
    final e = _engine;
    return switch (e.mode) {
      DashMode.quick =>
        e.playerCount > 1 ? 'Pass & Play' : 'Quick Match',
      DashMode.attack => 'Attack · ${e.attackScore} pts',
      DashMode.bot => 'You ${e.humanRoundWins}–${e.botRoundWins} Bot',
    };
  }

  Widget _roundChips() {
    final e = _engine;
    if (e.mode == DashMode.attack) {
      // Strikes as chips.
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          TapDashEngine.attackMaxStrikes,
          (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 30,
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: i < e.attackStrikes
                  ? const Color(0xFF2B2118)
                  : Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ),
      );
    }
    final total = TapDashEngine.roundsPerMatch;
    final done = e.mode == DashMode.bot
        ? e.round
        : (e.mode == DashMode.quick
            ? e.times[e.currentPlayer].length
            : 0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        total,
        (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 26,
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: i < done
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- arena
  Widget _arena() {
    final t = _t;
    final e = _engine;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing ring behind the dasher when armed.
          Stack(
            alignment: Alignment.center,
            children: [
              if (e.phase == DashPhase.armed)
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, _) => Container(
                    width: 190 + _pulse.value * 40,
                    height: 190 + _pulse.value * 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: 0.85 - _pulse.value * 0.4),
                        width: 6,
                      ),
                    ),
                  ),
                ),
              Dasher(
                  style: DasherStyles.byId(widget.settings.styleId),
                  size: 130),
            ],
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: child,
            ),
            child: Text(
              _mainText(),
              key: ValueKey('${e.phase}_${e.countdownValue}_${e.lastMs}'),
              textAlign: TextAlign.center,
              style: DashKit.display(44, t, color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _subText(),
            textAlign: TextAlign.center,
            style: DashKit.label(16, t,
                color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }

  String _mainText() {
    final e = _engine;
    switch (e.phase) {
      case DashPhase.idle:
        return 'Tap to start';
      case DashPhase.countdown:
        return '${e.countdownValue}';
      case DashPhase.waiting:
        return 'Wait for it…';
      case DashPhase.decoy:
        return 'TRICK!';
      case DashPhase.armed:
        return 'TAP NOW!';
      case DashPhase.result:
        if (e.lastFalseStart) return 'FALSE START!';
        if (e.mode == DashMode.bot) {
          return e.lastRoundHumanWon ? 'You got it!' : 'Bot got it!';
        }
        return '${e.lastMs} ms';
      case DashPhase.over:
        return 'Done!';
    }
  }

  String _subText() {
    final e = _engine;
    switch (e.phase) {
      case DashPhase.idle:
        return e.banner;
      case DashPhase.countdown:
        return 'Get ready…';
      case DashPhase.waiting:
        return e.difficulty == DashDifficulty.lightning
            ? 'Careful — amber tricks don\'t count!'
            : 'Don\'t tap yet!';
      case DashPhase.decoy:
        return 'That amber flash was a trick — hold!';
      case DashPhase.armed:
        return 'As fast as you can!';
      case DashPhase.result:
        if (e.lastFalseStart) {
          return e.mode == DashMode.attack
              ? 'Strike ${e.attackStrikes}/${TapDashEngine.attackMaxStrikes}!'
              : 'Too eager! +${TapDashEngine.falseStartPenaltyMs} ms penalty.';
        }
        if (e.mode == DashMode.bot && e.lastMs != null) {
          return 'You: ${e.lastMs} ms · Bot: ${e.botReactionMs} ms';
        }
        return e.lastMs != null ? TapDashEngine.grade(e.lastMs!) : '';
      case DashPhase.over:
        return e.banner;
    }
  }

  // ---------------------------------------------------------------- footer
  Widget _footer() {
    final e = _engine;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (e.mode == DashMode.quick && e.playerCount > 1)
            _scoreStrip(),
          const SizedBox(height: 8),
          Text(
            e.phase == DashPhase.idle ? e.banner : _turnLine(),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _turnLine() {
    final e = _engine;
    if (e.mode == DashMode.quick && e.playerCount > 1) {
      return '${e.currentName}\'s turn';
    }
    if (e.mode == DashMode.attack) {
      return 'Round ${e.attackRounds + 1} · Strikes ${e.attackStrikes}/${TapDashEngine.attackMaxStrikes}';
    }
    if (e.mode == DashMode.bot) {
      return 'Round ${e.round + 1}/${TapDashEngine.roundsPerMatch}';
    }
    final done = e.times[e.currentPlayer].length;
    return 'Round $done/${TapDashEngine.roundsPerMatch}';
  }

  Widget _scoreStrip() {
    final e = _engine;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(e.playerCount, (i) {
        final avg = e.averageFor(i);
        final active = i == e.currentPlayer && e.phase != DashPhase.over;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? Colors.white
                : Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.6), width: 2),
          ),
          child: Text(
            '${e.playerNames[i]}: ${avg == null ? '—' : '${avg.round()}ms'}',
            style: TextStyle(
              color: active ? const Color(0xFF2B2118) : Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------- pause overlay
  Widget _pauseOverlay() {
    final t = _t;
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: DashKit.card(
          t: t,
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused', style: DashKit.display(32, t)),
              const SizedBox(height: 18),
              DashKit.button(
                t: t,
                text: '▶  Resume',
                onTap: () {
                  widget.audio.click();
                  _engine.setPaused(false);
                },
              ),
              const SizedBox(height: 12),
              DashKit.button(
                t: t,
                text: '↻  Restart',
                color: t.cardBg,
                textColor: t.onCard,
                onTap: () {
                  widget.audio.click();
                  _engine.setPaused(false);
                  _engine.startMatch();
                },
              ),
              const SizedBox(height: 12),
              DashKit.button(
                t: t,
                text: '✕  Quit',
                color: t.cardBg,
                textColor: t.onCard,
                onTap: () {
                  widget.audio.click();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------- results overlay
  Widget _resultsOverlay() {
    final t = _t;
    final e = _engine;
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: DashKit.card(
            t: t,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Dasher(
                    style: DasherStyles.byId(widget.settings.styleId),
                    size: 90),
                const SizedBox(height: 10),
                Text('Match Over!', style: DashKit.display(32, t)),
                const SizedBox(height: 6),
                Text(e.banner,
                    textAlign: TextAlign.center,
                    style: DashKit.label(16, t)),
                const SizedBox(height: 14),
                _resultsBody(),
                const SizedBox(height: 18),
                DashKit.button(
                  t: t,
                  text: '↻  Play Again',
                  onTap: () {
                    widget.audio.click();
                    setState(() => _showResults = false);
                    _engine.startMatch();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _smallBtn(t, Icons.share, 'Share', _share),
                    const SizedBox(width: 12),
                    _smallBtn(t, Icons.home, 'Menu', () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultsBody() {
    final t = _t;
    final e = _engine;
    if (e.mode == DashMode.attack) {
      final isBest = e.attackScore >= widget.settings.bestAttack &&
          e.attackScore > 0;
      return DashKit.card(
        t: t,
        color: t.idleBg,
        child: Column(
          children: [
            Text('${e.attackScore}',
                style: DashKit.display(46, t, color: t.accentDark)),
            Text('points · ${e.attackRounds} rounds',
                style: DashKit.label(14, t)),
            if (isBest)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('NEW BEST!',
                    style: DashKit.label(16, t).copyWith(
                        color: t.accentDark, fontWeight: FontWeight.w900)),
              ),
          ],
        ),
      );
    }
    if (e.mode == DashMode.bot) {
      return DashKit.card(
        t: t,
        color: t.idleBg,
        child: Column(
          children: [
            Text('${e.humanRoundWins} – ${e.botRoundWins}',
                style: DashKit.display(46, t, color: t.accentDark)),
            Text(e.botHumanWon ? 'You beat Robo-Dash!' : 'Robo-Dash wins this one.',
                style: DashKit.label(14, t)),
          ],
        ),
      );
    }
    // Quick: per-player averages.
    return Column(
      children: List.generate(e.playerCount, (i) {
        final avg = e.averageFor(i);
        final winner = e.quickWinner() == i;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: winner ? t.accent.withValues(alpha: 0.3) : t.idleBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: winner
                    ? t.accentDark
                    : Colors.black.withValues(alpha: 0.12),
                width: winner ? 3 : 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${winner ? '🏆 ' : ''}${e.playerNames[i]}',
                  style: DashKit.display(18, t)),
              Text(avg == null ? '—' : '${avg.round()} ms',
                  style: DashKit.display(18, t)),
            ],
          ),
        );
      }),
    );
  }

  Widget _smallBtn(
      DashThemeDef t, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.14), width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                offset: const Offset(0, 3),
                blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: t.accentDark, size: 20),
            const SizedBox(width: 8),
            Text(label, style: DashKit.label(15, t)),
          ],
        ),
      ),
    );
  }

  Future<void> _share() async {
    widget.audio.click();
    final e = _engine;
    String line;
    if (e.mode == DashMode.attack) {
      line = 'I scored ${e.attackScore} pts in Tap Dash Score Attack!';
    } else if (e.mode == DashMode.bot) {
      line = e.botHumanWon
          ? 'I beat Robo-Dash ${e.humanRoundWins}–${e.botRoundWins} in Tap Dash!'
          : 'Robo-Dash beat me ${e.botRoundWins}–${e.humanRoundWins} in Tap Dash. Rematch time!';
    } else {
      final w = e.quickWinner();
      final avg = w == null ? null : e.averageFor(w);
      line = avg == null
          ? 'I just played Tap Dash!'
          : 'My Tap Dash average: ${avg.round()} ms. Beat that!';
    }
    try {
      await Share.share('$line $_storeUrl', subject: 'Tap Dash');
    } catch (_) {}
  }
}
