import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> init() async {
    try {
      // Configurar el contexto global para asegurar salida por altavoz y modo ruidoso
      await AudioPlayer.global.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
        android: const AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ));
    } catch (e) {
      debugPrint('Error initializing AudioContext: $e');
    }
  }

  /// Plays a specific audio asset from `assets/audio/`
  Future<void> playAsset(String assetName) async {
    try {
      if (_player.state == PlayerState.playing) {
        await _player.stop();
      }
      await _player.play(AssetSource('audio/$assetName'));
    } catch (e) {
      debugPrint('Error playing audio $assetName: $e');
    }
  }

  Future<void> playStart() async {
    await playAsset('InicioRCP.mp3');
  }

  Future<void> playFeedback(String type) async {
    switch (type) {
      case 'mas_profundo':
        await playAsset('MasProfundo.mp3');
        break;
      case 'menos_profundo':
        await playAsset('MenosProfundo.mp3');
        break;
      case 'mas_rapido':
        await playAsset('MasRapido.mp3');
        break;
      case 'mas_lento':
        await playAsset('MasLento.mp3');
        break;
      case 'excelente':
        await playAsset('Excelente.mp3');
        break;
      default:
        break;
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }
}
