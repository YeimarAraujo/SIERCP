import 'dart:math';
import 'package:flutter/foundation.dart';

class RcpTelemetry {
  final double depthMm;
  final double forceKg;
  final int timestamp;

  final int? externalCount;
  final int? externalBpm;

  RcpTelemetry({
    required this.depthMm,
    required this.forceKg,
    required this.timestamp,
    this.externalCount,
    this.externalBpm,
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
  static const double ahaRecoilThresholdKg = 2.5;

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
  
  double sumProfundidad = 0.0;
  double sumFuerza = 0.0;
  double sumBpm = 0.0;
  
  // Filtro EMA (Sincronizado con Hardware 0.35)
  static const double emaAlpha = 0.35;

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

      // 3. Validar Recoil (Liberación)
      if (recoilOk) recoilCorrectos++;

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

  bool evaluate(RcpTelemetry data) {
    recoilOk = data.forceKg < ahaRecoilThresholdKg;
    
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
    sumProfundidad = 0.0;
    sumFuerza = 0.0;
    sumBpm = 0.0;
    recoilOk = false;
    compresionCorrecta = false;
    lastCompresionCorrecta = false;
    currentCpm = 0;
  }
}

