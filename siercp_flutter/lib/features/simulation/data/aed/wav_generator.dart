import 'dart:math' as math;
import 'dart:typed_data';

class WavGenerator {
  static const int sampleRate = 44100;
  static const int bitsPerSample = 16;
  static const int numChannels = 1;

  static Uint8List generateWav({required List<double> samples}) {
    final data = Int16List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      data[i] = (clamped * 32767).round();
    }

    final dataSize = data.lengthInBytes;
    final header = ByteData(44);
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * numChannels * bitsPerSample ~/ 8, Endian.little);
    header.setUint16(32, numChannels * bitsPerSample ~/ 8, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    final result = Uint8List(44 + dataSize);
    result.setRange(0, 44, header.buffer.asUint8List());
    result.setRange(44, 44 + dataSize, data.buffer.asUint8List());

    return result;
  }

  static List<double> sineWave(double frequency, double duration,
      {double amplitude = 0.8}) {
    final count = (sampleRate * duration).round();
    return List<double>.generate(count, (i) {
      final t = i / sampleRate;
      return amplitude * math.sin(2 * math.pi * frequency * t);
    });
  }

  static List<double> sweep(double startFreq, double endFreq, double duration,
      {double amplitude = 0.8}) {
    final count = (sampleRate * duration).round();
    return List<double>.generate(count, (i) {
      final t = i / sampleRate;
      final progress = t / duration;
      final freq = startFreq + (endFreq - startFreq) * progress;
      return amplitude * math.sin(2 * math.pi * freq * t);
    });
  }

  static List<double> silence(double duration) {
    final count = (sampleRate * duration).round();
    return List<double>.filled(count, 0.0);
  }

  static List<double> noise(double duration, {double amplitude = 0.5}) {
    final random = math.Random();
    final count = (sampleRate * duration).round();
    return List<double>.generate(
        count, (_) => (random.nextDouble() * 2 - 1) * amplitude);
  }

  static List<double> squareWave(double frequency, double duration,
      {double amplitude = 0.6}) {
    final count = (sampleRate * duration).round();
    return List<double>.generate(count, (i) {
      final t = i / sampleRate;
      final val = math.sin(2 * math.pi * frequency * t);
      return val >= 0 ? amplitude : -amplitude;
    });
  }

  static List<double> applyEnvelope(
      List<double> samples, double attackMs, double releaseMs) {
    final result = List<double>.from(samples);
    final attackSamples = (sampleRate * attackMs / 1000).round();
    final releaseSamples = (sampleRate * releaseMs / 1000).round();

    for (int i = 0; i < attackSamples && i < result.length; i++) {
      result[i] *= i / attackSamples;
    }
    for (int i = 0; i < releaseSamples && i < result.length; i++) {
      final idx = result.length - 1 - i;
      result[idx] *= i / releaseSamples;
    }

    return result;
  }

  static List<double> concat(List<List<double>> segments) {
    final totalLength =
        segments.fold<int>(0, (sum, s) => sum + s.length);
    final result = List<double>.filled(totalLength, 0.0);
    int offset = 0;
    for (final segment in segments) {
      result.setRange(offset, offset + segment.length, segment);
      offset += segment.length;
    }
    return result;
  }
}
