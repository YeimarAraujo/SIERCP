import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

import 'wav_generator.dart';

enum AedVoicePrompt {
  connectElectrodes,
  analyzing,
  doNotTouch,
  shockRecommended,
  pressOrangeButton,
  shockDelivered,
  startCpr,
  noShockRecommended,
  shockBlocked,
  placeElectrodesFirst,
  charging,
  analysisComplete,
}

class AedAudioService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _tonePlayer = AudioPlayer();
  bool _initialized = false;
  bool _ttsAvailable = false;
  Directory? _tempDir;

  Future<void> init() async {
    if (_initialized) return;
    _tempDir = await getTemporaryDirectory();
    try {
      await _tts.setLanguage('es-ES');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _ttsAvailable = true;
    } catch (_) {
      _ttsAvailable = false;
    }
    _initialized = true;
  }

  Future<void> speakPrompt(AedVoicePrompt prompt) async {
    if (!_ttsAvailable) return;
    final text = _promptText(prompt);
    try {
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> speakText(String text) async {
    if (!_ttsAvailable) return;
    try {
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop({bool stopTts = true}) async {
    await _tonePlayer.stop();
    if (stopTts && _ttsAvailable) {
      try {
        await _tts.stop();
      } catch (_) {}
    }
  }

  Future<void> playPowerOnBeep() async {
    final samples = WavGenerator.applyEnvelope(
      WavGenerator.sineWave(880, 0.15, amplitude: 0.7),
      5,
      20,
    );
    await _playWav(samples);
  }

  Future<void> playAnalysisBeep() async {
    final samples = WavGenerator.applyEnvelope(
      WavGenerator.sineWave(660, 0.08, amplitude: 0.6),
      2,
      40,
    );
    await _playWav(samples);
  }

  Future<void> playChargingTone() async {
    final samples = WavGenerator.applyEnvelope(
      WavGenerator.sweep(300, 1200, 1.5, amplitude: 0.5),
      10,
      50,
    );
    await _playWav(samples);
  }

  Future<void> playShockSound() async {
    final thump = WavGenerator.applyEnvelope(
      WavGenerator.sineWave(60, 0.3, amplitude: 0.9),
      2,
      100,
    );
    final burst = WavGenerator.noise(0.05, amplitude: 0.4);
    final tail = WavGenerator.applyEnvelope(
      WavGenerator.sineWave(180, 0.4, amplitude: 0.6),
      10,
      100,
    );
    final samples = WavGenerator.concat([thump, burst, tail]);
    await _playWav(samples);
  }

  Future<void> playCprMetronome({int bpm = 110}) async {
    final interval = 60.0 / bpm;
    final beep = WavGenerator.applyEnvelope(
      WavGenerator.sineWave(800, 0.04, amplitude: 0.7),
      1,
      20,
    );
    final pause = WavGenerator.silence(interval - 0.04);
    final samples = WavGenerator.concat([
      beep,
      pause,
      beep,
      pause,
      beep,
      pause,
      beep,
      pause,
      beep,
      pause,
      beep,
      pause,
      beep,
      pause,
      beep,
      pause,
    ]);
    await _playWav(samples);
  }

  Future<void> playErrorBuzz() async {
    final samples = WavGenerator.applyEnvelope(
      WavGenerator.squareWave(150, 0.5, amplitude: 0.5),
      10,
      100,
    );
    await _playWav(samples);
  }

  Future<void> playCompletionChime() async {
    final note1 = WavGenerator.applyEnvelope(
      WavGenerator.sineWave(523, 0.2, amplitude: 0.7),
      5,
      50,
    );
    final gap = WavGenerator.silence(0.05);
    final note2 = WavGenerator.applyEnvelope(
      WavGenerator.sineWave(659, 0.3, amplitude: 0.7),
      5,
      80,
    );
    final samples = WavGenerator.concat([note1, gap, note2]);
    await _playWav(samples);
  }

  Future<void> dispose() async {
    await stop();
    _tonePlayer.dispose();
  }

  Future<void> _playWav(List<double> samples) async {
    try {
      final wavData = WavGenerator.generateWav(samples: samples);
      final file = File(
        '${_tempDir?.path ?? "."}/aed_tone_${DateTime.now().microsecondsSinceEpoch}.wav',
      );
      await file.writeAsBytes(wavData);
      await _tonePlayer.play(DeviceFileSource(file.path));
      file.delete();
    } catch (e) {
      // Silently fail if audio can't play
    }
  }

  String _promptText(AedVoicePrompt prompt) {
    switch (prompt) {
      case AedVoicePrompt.connectElectrodes:
        return 'Conecte los electrodos al tórax del paciente';
      case AedVoicePrompt.analyzing:
        return 'Analizando ritmo';
      case AedVoicePrompt.doNotTouch:
        return 'No toque al paciente';
      case AedVoicePrompt.shockRecommended:
        return 'Descarga recomendada';
      case AedVoicePrompt.pressOrangeButton:
        return 'Presione el botón naranja para descargar';
      case AedVoicePrompt.shockDelivered:
        return 'Descarga aplicada';
      case AedVoicePrompt.startCpr:
        return 'Inicie RCP, treinta compresiones, dos ventilaciones';
      case AedVoicePrompt.noShockRecommended:
        return 'No se recomienda descarga';
      case AedVoicePrompt.shockBlocked:
        return 'Descarga bloqueada, este ritmo no es desfibrilable';
      case AedVoicePrompt.placeElectrodesFirst:
        return 'Coloque los electrodos primero';
      case AedVoicePrompt.charging:
        return 'Cargando';
      case AedVoicePrompt.analysisComplete:
        return 'Análisis completado';
    }
  }
}
