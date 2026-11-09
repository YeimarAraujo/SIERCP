import 'package:flutter_test/flutter_test.dart';
import 'package:siercp/core/utils/rcp_engine.dart';

RcpTelemetry _sample(double depth) => RcpTelemetry(
      depthMm: depth,
      forceKg: 0,
      timestamp: 0,
      sensorOk: true,
      calibrated: true,
    );

void main() {
  late RcpEngine engine;
  late DateTime now;
  var count = 0;

  /// Simula una compresión: valle, pico y conteo del hardware.
  void compress({double valley = 3, double peak = 55, int gapMs = 545}) {
    now = now.add(Duration(milliseconds: gapMs));
    engine.evaluate(_sample(valley));
    engine.evaluate(_sample(peak));
    count++;
    engine.updateFromHardware(compressions: count, bpm: 110);
  }

  setUp(() {
    engine = RcpEngine.instance..reset();
    now = DateTime(2026);
    count = 0;
    engine.clock = () => now;
  });

  test('una liberación completa cuenta como retroceso correcto', () {
    compress();
    expect(engine.recoilCorrectos, 1);
  });

  test('la profundidad residual ya no aprueba el retroceso', () {
    compress(valley: 18);
    expect(engine.recoilCorrectos, 0);
    expect(engine.lastCompresionCorrecta, isFalse);
  });

  test('sin fuerza medida no hay retroceso automático', () {
    for (var i = 0; i < 10; i++) {
      compress(valley: 20);
    }
    expect(engine.recoilCorrectos, 0);
  });

  test('un intervalo mayor a 2 s cuenta como pausa', () {
    compress();
    compress(gapMs: 545);
    expect(engine.pausasCount, 0);

    compress(gapMs: 6000);
    expect(engine.pausasCount, 1);
    expect(engine.maxPausaSeg, 6);
  });

  test('la fracción de compresión descuenta las pausas', () {
    compress();
    compress(gapMs: 12000);
    expect(engine.ccfPct(60), closeTo(80, 0.01));
  });

  test('sin compresiones la fracción es 0', () {
    expect(engine.ccfPct(60), 0);
  });

  test('reset limpia pausas y valle', () {
    compress();
    compress(gapMs: 5000);
    engine.reset();
    expect(engine.pausasCount, 0);
    expect(engine.totalPausaSeg, 0);
  });
}
