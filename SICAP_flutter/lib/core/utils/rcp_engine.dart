import 'dart:math';
import 'package:flutter/foundation.dart';

class RcpTelemetry {
  final double depthMm;
  final double forceKg;
  final int timestamp;

  final int? externalCount;
  final int? externalBpm;
  final bool sensorOk;
  final bool calibrated;

  RcpTelemetry({
    required this.depthMm,
    required this.forceKg,
    required this.timestamp,
    this.externalCount,
    this.externalBpm,
    this.sensorOk = true,
    this.calibrated = true,
  });
}

class RcpEngine extends ChangeNotifier {
  // Patrón Singleton para acceso global
  static final RcpEngine instance = RcpEngine._internal();
  factory RcpEngine() => instance;
  RcpEngine._internal();
  // AHA 2025 Constants
  static const double ahaMinDepthMm = 50.0;
  static const double ahaMaxDepthMm = 60.0;
  static const int ahaMinRateCpm = 100;
  static const int ahaMaxRateCpm = 120;

  /// Profundidad residual máxima para contar la liberación como completa.
  /// Provisional: el filtro del firmware deja ~4–7 mm tras una liberación total
  /// y ~13 mm con 10 mm reales de residual. Calibrar con el maniquí.
  static const double ahaRecoilResidualMm = 10.0;

  /// Sin compresiones durante más de este tiempo se considera una pausa.
  static const Duration pausaMinima = Duration(seconds: 2);

  // Detection Constants (Sincronizados con Firmware v2.5)
  static const double detectStartMm = 15.0;  // Umbral de inicio
  static const double detectPeakMinMm = 20.0;
  static const double detectEndMm = 8.0;    // Umbral de liberación
  static const double detectRearmMm = 8.0;
  static const int detectMinDurMs = 120;
  static const int detectMaxDurMs = 900;
  static const int detectDebounceMs = 60;
  
  static const int maxWindow = 14;
  
  // Picos para Audio Feedback
  double picoProfundidad = 0.0;
  double picoFuerza = 0.0;
  
  // Métricas de la última compresión completada
  double lastPicoProfundidad = 0.0;
  double lastPicoFuerza = 0.0;
  int lastBpm = 0;

  int compresionesTotales = 0;
  int compresionesCorrectas = 0;
  int recoilCorrectos = 0;
  int freqCorrectas = 0;
  
  int pausasCount = 0;
  double maxPausaSeg = 0.0;
  double totalPausaSeg = 0.0;

  /// Reloj inyectable para las pruebas.
  DateTime Function() clock = DateTime.now;
  DateTime? _ultimaCompresion;

  /// Menor profundidad vista desde la última compresión contada.
  double _valleProfundidad = double.infinity;
  
  double sumProfundidad = 0.0;
  double sumFuerza = 0.0;
  double sumBpm = 0.0;
  
  // Filtro EMA (Sincronizado con el firmware)
  static const double emaAlpha = 0.5;

  bool recoilOk = false;
  bool compresionCorrecta = false;
  bool lastCompresionCorrecta = false;
  int currentCpm = 0;

  /// ACTUALIZACIÓN DESDE HARDWARE (Senior Logic)
  /// Evaluamos la CALIDAD de la compresión que el hardware acaba de contar
  void updateFromHardware({
    required int compressions,
    required int bpm,
  }) {
    if (compressions > compresionesTotales) {
      // Guardar métricas de la compresión que acaba de terminar
      lastPicoProfundidad = picoProfundidad;
      lastPicoFuerza = picoFuerza;
      lastBpm = bpm;

      // 1. Validar Profundidad (AHA 50-60mm)
      bool profOk = picoProfundidad >= ahaMinDepthMm && picoProfundidad <= ahaMaxDepthMm;
      if (profOk) compresionesCorrectas++;
      
      // Acumular solo picos para promedios reales de reporte
      sumProfundidad += picoProfundidad;

      // 2. Validar Frecuencia (AHA 100-120 BPM)
      bool freqOk = bpm >= ahaMinRateCpm && bpm <= ahaMaxRateCpm;
      if (freqOk) freqCorrectas++;
      
      // Acumular ritmo para promedio de reporte
      sumBpm += bpm.toDouble(); 

      // 3. Validar Recoil: el tórax debe volver casi a cero antes de esta compresión.
      recoilOk = _valleProfundidad <= ahaRecoilResidualMm;
      if (recoilOk) recoilCorrectos++;
      _valleProfundidad = double.infinity;

      _registrarPausa();

      lastCompresionCorrecta = profOk && freqOk && recoilOk;
      compresionCorrecta = lastCompresionCorrecta;

      // Reset de picos para la siguiente compresión
      // Importante: No resetear a 0 absoluto si ya hay profundidad en el buffer (aunque usualmente es < 8mm aquí)
      picoProfundidad = 0;
      picoFuerza = 0;
    }
    
    compresionesTotales = compressions;
    currentCpm = bpm;
    notifyListeners();
  }

  void _registrarPausa() {
    final ahora = clock();
    final anterior = _ultimaCompresion;
    _ultimaCompresion = ahora;
    if (anterior == null) return;

    final pausa = ahora.difference(anterior);
    if (pausa <= pausaMinima) return;

    final segundos = pausa.inMilliseconds / 1000;
    pausasCount++;
    totalPausaSeg += segundos;
    if (segundos > maxPausaSeg) maxPausaSeg = segundos;
  }

  /// Fracción de compresión: % del tiempo de la sesión con compresiones activas.
  double ccfPct(int duracionSeg) {
    if (duracionSeg <= 0 || compresionesTotales == 0) return 0;
    return ((1 - totalPausaSeg / duracionSeg) * 100).clamp(0, 100).toDouble();
  }

  bool evaluate(RcpTelemetry data) {
    if (data.depthMm < _valleProfundidad) _valleProfundidad = data.depthMm;

    // Rastreamos el pico de esta compresión para evaluarlo cuando el hardware cuente
    if (data.depthMm > picoProfundidad) picoProfundidad = data.depthMm;
    if (data.forceKg > picoFuerza) picoFuerza = data.forceKg;

    return false; 
  }


  void reset() {
    picoProfundidad = 0.0;
    picoFuerza = 0.0;
    lastPicoProfundidad = 0.0;
    lastPicoFuerza = 0.0;
    lastBpm = 0;
    compresionesTotales = 0;
    compresionesCorrectas = 0;
    recoilCorrectos = 0;
    freqCorrectas = 0;
    pausasCount = 0;
    maxPausaSeg = 0.0;
    totalPausaSeg = 0.0;
    _ultimaCompresion = null;
    _valleProfundidad = double.infinity;
    sumProfundidad = 0.0;
    sumFuerza = 0.0;
    sumBpm = 0.0;
    recoilOk = false;
    compresionCorrecta = false;
    lastCompresionCorrecta = false;
    currentCpm = 0;
  }
}

