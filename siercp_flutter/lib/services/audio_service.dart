import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> init() async {
    // Initialization if necessary
  }

  /// Plays a specific audio asset from `assets/audio/`
  Future<void> playAsset(String assetName) async {
    try {
      // Starting from audioplayers ^3.0.0, AssetSource is used for local assets
      await _player.play(AssetSource('audio/$assetName'));
    } catch (e) {
      // ignore: avoid_print
      print('Error playing audio $assetName: $e');
    }
  }

  Future<void> playStart() async {
    await playAsset('0001.mp3');
  }

  Future<void> playFeedback(String type) async {
    switch (type) {
      case 'mas_profundo':
        await playAsset('mas_profundo.mp3');
        break;
      case 'mas_rapido':
        await playAsset('mas_rapido.mp3');
        break;
      case 'bien':
        await playAsset('bien.mp3');
        break;
      default:
        break;
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }
}
