import 'dart:math' as math;
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import 'wav_generator.dart';

enum EcgRhythmTypeForAudio { fv, tv, asistolia, aesp, normal, fa, bav, tsv }

class EcgAudioService {
  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;
  bool _muted = false;
  Directory? _tempDir;

  bool get muted => _muted;

  set muted(bool v) {
    _muted = v;
    if (v) {
      _player.stop();
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _tempDir = await getTemporaryDirectory();
    _initialized = true;
  }

  Future<void> playTick() async {
    if (_muted) return;
    final tick = WavGenerator.applyEnvelope(
      WavGenerator.sineWave(1000, 0.015, amplitude: 0.3),
      1,
      10,
    );
    await _playWav(tick);
  }

  Future<void> playRhythmBeep(EcgRhythmTypeForAudio type) async {
    if (_muted) return;
    final samples = _buildRhythmSamples(type);
    await _playWav(samples);
  }

  Future<void> playCorrect() async {
    if (_muted) return;
    final note1 = WavGenerator.applyEnvelope(
      WavGenerator.sineWave(523, 0.12, amplitude: 0.6),
      3,
      30,
    );
    final gap = WavGenerator.silence(0.04);
    final note2 = WavGenerator.applyEnvelope(
      WavGenerator.sineWave(659, 0.15, amplitude: 0.6),
      3,
      40,
    );
    await _playWav(WavGenerator.concat([note1, gap, note2]));
  }

  Future<void> playWrong() async {
    if (_muted) return;
    final note1 = WavGenerator.applyEnvelope(
      WavGenerator.sineWave(440, 0.12, amplitude: 0.3),
      8, 40,
    );
    final gap = WavGenerator.silence(0.03);
    final note2 = WavGenerator.applyEnvelope(
      WavGenerator.sineWave(350, 0.15, amplitude: 0.3),
      8, 50,
    );
    await _playWav(WavGenerator.concat([note1, gap, note2]));
  }

  Future<void> playCompletionChime() async {
    if (_muted) return;
    final c = WavGenerator.applyEnvelope(
      WavGenerator.sineWave(523, 0.15, amplitude: 0.6),
      3,
      30,
    );
    final e = WavGenerator.applyEnvelope(
      WavGenerator.sineWave(659, 0.15, amplitude: 0.6),
      3,
      30,
    );
    final g = WavGenerator.applyEnvelope(
      WavGenerator.sineWave(784, 0.3, amplitude: 0.6),
      3,
      60,
    );
    final gap = WavGenerator.silence(0.05);
    await _playWav(WavGenerator.concat([c, gap, e, gap, g]));
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    await stop();
    _player.dispose();
  }

  Future<void> _playWav(List<double> samples) async {
    try {
      final wavData = WavGenerator.generateWav(samples: samples);
      final file = File(
        '${_tempDir?.path ?? "."}/ecg_tone_${DateTime.now().microsecondsSinceEpoch}.wav',
      );
      await file.writeAsBytes(wavData);
      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
      file.delete();
    } catch (_) {}
  }

  List<double> _buildRhythmSamples(EcgRhythmTypeForAudio type) {
    switch (type) {
      case EcgRhythmTypeForAudio.fv:
        return _fvSound();
      case EcgRhythmTypeForAudio.tv:
        return _rhythmicBeeps(180, 0.08);
      case EcgRhythmTypeForAudio.asistolia:
        return WavGenerator.silence(1.5);
      case EcgRhythmTypeForAudio.aesp:
        return _rhythmicBeeps(30, 0.1);
      case EcgRhythmTypeForAudio.normal:
        return _rhythmicBeeps(72, 0.06);
      case EcgRhythmTypeForAudio.fa:
        return _faSound();
      case EcgRhythmTypeForAudio.bav:
        return _rhythmicBeeps(35, 0.08);
      case EcgRhythmTypeForAudio.tsv:
        return _rhythmicBeeps(210, 0.04);
    }
  }

  List<double> _rhythmicBeeps(int bpm, double beepDuration) {
    final interval = 60.0 / bpm;
    final beep = WavGenerator.applyEnvelope(
      WavGenerator.sineWave(880, beepDuration, amplitude: 0.5),
      2,
      10,
    );
    final pause = WavGenerator.silence(interval - beepDuration);
    return WavGenerator.concat([
      beep, pause,
      beep, pause,
      beep, pause,
      beep, pause,
      beep, pause,
      beep, pause,
      beep, pause,
      beep, pause,
    ]);
  }

  List<double> _fvSound() {
    final chaos1 = WavGenerator.applyEnvelope(
      WavGenerator.noise(0.5, amplitude: 0.4),
      5,
      30,
    );
    final chaos2 = WavGenerator.applyEnvelope(
      WavGenerator.sineWave(200, 0.15, amplitude: 0.3),
      3,
      20,
    );
    final gap = WavGenerator.silence(0.05);
    final chaos3 = WavGenerator.applyEnvelope(
      WavGenerator.noise(0.3, amplitude: 0.5),
      5,
      30,
    );
    return WavGenerator.concat([chaos1, gap, chaos2, gap, chaos3]);
  }

  List<double> _faSound() {
    final rng = math.Random();
    final segments = <List<double>>[];
    for (int i = 0; i < 10; i++) {
      final gap = 0.3 + rng.nextDouble() * 0.5;
      segments.add(WavGenerator.silence(gap));
      final beep = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(800, 0.05, amplitude: 0.4),
        2,
        10,
      );
      segments.add(beep);
    }
    return WavGenerator.concat(segments);
  }

  Future<void> playRhythmLoop(EcgRhythmTypeForAudio type) async {
    if (_muted) return;
    final samples = _buildRhythmSamples(type);
    final looped = WavGenerator.concat([samples, samples, samples]);
    await _playWav(looped);
  }
}
