import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Tap Dash — all sounds synthesized in code as WAV
/// bytes. No asset files. Punchy, arcade-physical: button thocks, go-bells,
/// buzzer false-starts.
///
/// Reliability design (every call is safe to repeat and safe to overlap):
/// - Music clips are synthesized ONCE and cached; starting music never blocks
///   the UI thread after the first build.
/// - A [_musicGen] generation counter serializes track changes: every
///   start/stop bumps the generation, in-flight work from an older request
///   aborts, and the LATEST request always wins. Overlapping calls (menu in/out,
///   pause/resume, toggles) can never swallow a start or leave the player
///   half-started — music is app-scoped and never silently dies.
/// - Lifecycle uses pause()/resume() so an interruption (call, backgrounding)
///   resumes exactly where it left off instead of restarting or dying.
/// - Every public method catches player errors; audio can never crash the app.
class TapDashAudio {
  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  // Cache synthesized clips so we only build them once.
  final Map<String, Uint8List> _cache = {};

  // Music state machine. [_musicGen] is bumped by every start/stop request;
  // async work checks it still owns the latest generation before touching
  // the player, so overlapping requests can never desync the music.
  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  TapDashAudio() {
    // Fire-and-forget is fine here: configure() runs before any play.
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    volume = volume.clamp(0.0, 1.0);
    this.volume = volume;
    _music.setVolume(musicOn ? volume * 0.55 : 0.0);
    _sfx.setVolume(sfxOn ? volume : 0.0);
    if (!musicOn) {
      stopMusic();
    }
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, 2.2).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  /// Arcade button thock: low plastic thunk + click.
  List<double> _thock() {
    final n = (_rate * 0.12).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.004) *
          (0.9 * sin(2 * pi * 220 * t) * exp(-t * 40) +
              0.5 * sin(2 * pi * 660 * t) * exp(-t * 70) +
              0.3 * (_rand.nextDouble() * 2 - 1) * exp(-t * 150));
    }
    return out;
  }

  /// False-start buzzer: harsh double buzz.
  List<double> _buzzer() {
    final n = (_rate * 0.45).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final gate = (t < 0.18 || (t > 0.24 && t < 0.42)) ? 1.0 : 0.0;
      out[i] = gate *
          _env(i, n, attack: 0.01) *
          (0.7 * sin(2 * pi * 140 * t) + 0.4 * sin(2 * pi * 186 * t));
    }
    return out;
  }

  /// Go bell: bright ding-ding.
  List<double> _goBell() {
    final out = <double>[];
    for (final f in [1318.5, 1760.0]) {
      out.addAll(_tone(f, 0.35, harmonics: 0.4));
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: 0.2));
      final gap = List<double>.filled((_rate * gapSecs).round(), 0);
      out.addAll(gap);
    }
    return out;
  }

  /// Bouncy bassline + claps: menu groove, 12s loop.
  Uint8List _menuBytes() => _clip('music_menu', () {
        final n = (_rate * 12).round();
        final out = List<double>.filled(n, 0);
        final bass = [130.81, 130.81, 146.83, 130.81, 98.0, 98.0, 110.0, 123.47];
        final beat = n ~/ 8;
        for (int k = 0; k < 8; k++) {
          final start = k * beat;
          final tone = _tone(bass[k], 0.42, harmonics: 0.3);
          for (int i = 0; i < tone.length && start + i < n; i++) {
            out[start + i] += tone[i] * 0.5;
          }
          // clap on beats 2 and 4 of each bar pair
          if (k % 4 == 1 || k % 4 == 3) {
            final clapLen = (_rate * 0.09).round();
            for (int i = 0; i < clapLen && start + i < n; i++) {
              final t = i / _rate;
              out[start + i] +=
                  (_rand.nextDouble() * 2 - 1) * exp(-t * 90) * 0.4;
            }
          }
        }
        // sparkle arpeggio on top
        final plucks = [523.25, 587.33, 659.25, 783.99, 659.25, 587.33];
        for (int k = 0; k < plucks.length; k++) {
          final start = (n * k / plucks.length).round();
          final tone = _tone(plucks[k], 0.3, harmonics: 0.35);
          for (int i = 0; i < tone.length && start + i < n; i++) {
            out[start + i] += tone[i] * 0.22;
          }
        }
        return out;
      });

  /// Driving game groove: punchy bass + faster sparkle, 10s loop.
  Uint8List _gameBytes() => _clip('music_game', () {
        final n = (_rate * 10).round();
        final out = List<double>.filled(n, 0);
        final bass = [
          146.83, 146.83, 164.81, 146.83, //
          130.81, 130.81, 146.83, 164.81, //
          146.83, 146.83, 164.81, 196.0, //
          174.61, 164.81, 146.83, 130.81, //
        ];
        final beat = n ~/ 16;
        for (int k = 0; k < 16; k++) {
          final start = k * beat;
          final tone = _tone(bass[k], 0.28, harmonics: 0.35);
          for (int i = 0; i < tone.length && start + i < n; i++) {
            out[start + i] += tone[i] * 0.45;
          }
        }
        final plucks = [659.25, 783.99, 880.0, 783.99, 659.25, 587.33, 523.25, 587.33];
        for (int k = 0; k < plucks.length; k++) {
          final start = (n * k / plucks.length).round();
          final tone = _tone(plucks[k], 0.25, harmonics: 0.3);
          for (int i = 0; i < tone.length && start + i < n; i++) {
            out[start + i] += tone[i] * 0.2;
          }
        }
        return out;
      });

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() => _play(_clip('click', () => _tone(1150, 0.06)));
  Future<void> tap() => _play(_clip('tap', _thock));
  Future<void> falseStart() => _play(_clip('falsestart', _buzzer));
  Future<void> go() => _play(_clip('go', _goBell));
  Future<void> decoy() =>
      _play(_clip('decoy', () => _tone(880, 0.12, harmonics: 0.4)));
  Future<void> countdown() =>
      _play(_clip('count', () => _tone(660, 0.12, harmonics: 0.3)));
  Future<void> roundWin() => _play(
      _clip('roundwin', () => _arp([659.25, 783.99, 1046.5], 0.12, 0.03)));
  Future<void> gameStart() =>
      _play(_clip('start', () => _tone(420, 0.32, freqEnd: 840)));
  Future<void> win() => _play(_clip(
      'win', () => _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.16, 0.03)));
  Future<void> lose() => _play(
      _clip('lose', () => _arp([392.0, 329.63, 261.63, 196.0], 0.22, 0.04)));

  // ----------------------------------------------------------------- music
  /// Start (or keep) a music track. Generation-serialized: the latest request
  /// always wins; a start issued while an older one is in flight is never
  /// dropped. Re-requesting the current track just ensures it is audible.
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      // Already on this track — make sure it is actually audible.
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    // Wait for any in-flight op, then bail if superseded meanwhile.
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  /// App-scoped stop: cancels any pending start, then stops. Used only when
  /// the user turns music OFF — never on screen navigation.
  Future<void> stopMusic() async {
    ++_musicGen; // cancel any in-flight start
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  /// App went to background / interruption: pause (not stop) so we resume
  /// exactly where we left off.
  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  /// App came back: resume only if we paused it and music is still wanted.
  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      // Resume failed (e.g. player was released) — restart the track.
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
