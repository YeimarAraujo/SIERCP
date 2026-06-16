import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Traza de monitor con barrido en tiempo real (estilo monitor de cabecera).
///
/// Reproduce una señal continua `sampler(t)` desplazando un cursor de escritura
/// de izquierda a derecha; tras el cursor deja un pequeño hueco de borrado, tal
/// como hacen los monitores clínicos reales. Es reutilizable para ECG, pletismo
/// de SpO₂ o curva respiratoria: sólo cambia el `sampler`, el `color` y la
/// `amplitude`.
class MonitorTrace extends StatefulWidget {
  /// Señal en función del tiempo (segundos). Rango útil aprox. [-1.5, 1.5].
  final double Function(double t) sampler;
  final Color color;

  /// Segundos visibles a lo ancho de la traza (velocidad de barrido).
  final double windowSeconds;

  /// Factor de escala vertical (1.0 = ocupa media altura por unidad).
  final double amplitude;

  /// Desplazamiento vertical del cero (0 = centro).
  final double baseline;
  final double strokeWidth;

  /// Si la animación está en marcha (al pausar congela la traza).
  final bool running;

  const MonitorTrace({
    super.key,
    required this.sampler,
    required this.color,
    this.windowSeconds = 5.0,
    this.amplitude = 0.42,
    this.baseline = 0.0,
    this.strokeWidth = 1.6,
    this.running = true,
  });

  @override
  State<MonitorTrace> createState() => _MonitorTraceState();
}

class _MonitorTraceState extends State<MonitorTrace>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  List<double> _buffer = const [];
  int _head = 0;
  double _t = 0; // tiempo de señal acumulado
  double _carrySamples = 0; // fracción de muestra pendiente
  Duration _last = Duration.zero;
  double _width = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_buffer.isEmpty) {
      _last = elapsed;
      return;
    }
    final realDt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (!widget.running) {
      setState(() {}); // mantener pintado pero sin avanzar
      return;
    }
    // Muestras por segundo = ancho / ventana de tiempo.
    final samplesPerSec = _buffer.length / widget.windowSeconds;
    final exact = realDt * samplesPerSec + _carrySamples;
    var n = exact.floor();
    _carrySamples = exact - n;
    if (n > _buffer.length) n = _buffer.length; // evitar saltos tras pausas
    final dtSample = 1.0 / samplesPerSec;
    for (var i = 0; i < n; i++) {
      _t += dtSample;
      _buffer[_head] = widget.sampler(_t);
      _head = (_head + 1) % _buffer.length;
    }
    setState(() {});
  }

  void _resize(double width) {
    final n = width.round().clamp(2, 2000);
    if (n == _buffer.length) return;
    _width = width;
    _buffer = List<double>.filled(n, widget.baseline);
    _head = 0;
    // Pre-cargar una pantalla para que no arranque en blanco.
    final samplesPerSec = n / widget.windowSeconds;
    final dtSample = 1.0 / samplesPerSec;
    for (var i = 0; i < n; i++) {
      _t += dtSample;
      _buffer[i] = widget.sampler(_t);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w != _width || _buffer.isEmpty) {
          _resize(w);
        }
        return CustomPaint(
          size: Size(w, constraints.maxHeight),
          painter: _TracePainter(
            buffer: _buffer,
            head: _head,
            color: widget.color,
            amplitude: widget.amplitude,
            baseline: widget.baseline,
            strokeWidth: widget.strokeWidth,
          ),
        );
      },
    );
  }
}

class _TracePainter extends CustomPainter {
  final List<double> buffer;
  final int head;
  final Color color;
  final double amplitude;
  final double baseline;
  final double strokeWidth;

  _TracePainter({
    required this.buffer,
    required this.head,
    required this.color,
    required this.amplitude,
    required this.baseline,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (buffer.isEmpty) return;
    final n = buffer.length;
    final midY = size.height / 2;
    final scaleY = size.height * amplitude;

    double yOf(int i) => midY - (buffer[i] - baseline) * scaleY;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Brillo suave detrás de la línea.
    final glow = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    // El hueco de borrado son las columnas justo después del cursor.
    const gap = 6;
    final path = Path();
    bool started = false;
    for (var x = 0; x < n; x++) {
      // Distancia "por delante" del cursor: se omite el hueco de barrido.
      final ahead = (x - head + n) % n;
      if (ahead < gap) {
        started = false;
        continue;
      }
      final y = yOf(x).clamp(0.0, size.height);
      if (!started) {
        path.moveTo(x.toDouble(), y);
        started = true;
      } else {
        path.lineTo(x.toDouble(), y);
      }
    }
    canvas.drawPath(path, glow);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TracePainter old) =>
      old.head != head || old.buffer != buffer || old.color != color;
}
