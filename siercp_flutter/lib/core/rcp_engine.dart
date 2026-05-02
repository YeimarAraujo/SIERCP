import 'dart:math';

class RcpTelemetry {
  final double depthMm;
  final double forceKg;
  final int timestamp;

  RcpTelemetry({
    required this.depthMm,
    required this.forceKg,
    required this.timestamp,
  });
}

class RcpEngine {
  // AHA 2025 Constants
  static const double ahaMinDepthMm = 50.0;
  static const double ahaMaxDepthMm = 60.0;
  static const int ahaMinRateCpm = 100;
  static const int ahaMaxRateCpm = 120;
  static const double ahaRecoilThresholdKg = 2.5;

  // Detection Constants
  static const double detectStartMm = 10.0;
  static const double detectPeakMinMm = 20.0;
  static const double detectEndMm = 6.0;
  static const double detectRearmMm = 6.0;
  static const int detectMinDurMs = 120;
  static const int detectMaxDurMs = 900;
  static const int detectDebounceMs = 60;
  
  static const int maxWindow = 14;

  // State
  String _estadoMecanico = 'reposo';
  bool enCompresion = false;
  int _inicioCompresionTs = 0;
  int _finCompresionTs = 0;
  double picoFuerza = 0.0;
  double picoProfundidad = 0.0;
  
  int compresionesTotales = 0;
  int compresionesCorrectas = 0;
  int recoilCorrectos = 0;
  int freqCorrectas = 0;
  
  List<int> _tsCompresiones = [];
  int ultimaCompresionTs = 0;
  
  int pausasCount = 0;
  double maxPausaSeg = 0.0;
  
  double sumProfundidad = 0.0;
  double sumFuerza = 0.0;

  bool recoilOk = false;
  bool compresionCorrecta = false;
  int currentCpm = 0;

  bool evaluate(RcpTelemetry data) {
    bool nuevaCompresion = false;
    int ahora = data.timestamp;
    
    recoilOk = data.forceKg < ahaRecoilThresholdKg;

    if (_estadoMecanico == 'reposo') {
      // Si el timestamp retrocede significativamente, el dispositivo se reinició
      if (ahora < ultimaCompresionTs - 1000) {
        reset();
      }
      
      if (ultimaCompresionTs > 0 && (ahora - ultimaCompresionTs) > 30000) {
        reset();
      }
      if (data.depthMm >= detectStartMm) {
        _estadoMecanico = 'comprimiendo';
        enCompresion = true;
        _inicioCompresionTs = ahora;
        picoFuerza = data.forceKg;
        picoProfundidad = data.depthMm;
      }
    } else if (_estadoMecanico == 'comprimiendo') {
      if (data.forceKg > picoFuerza) picoFuerza = data.forceKg;
      if (data.depthMm > picoProfundidad) picoProfundidad = data.depthMm;

      if (data.depthMm <= detectEndMm) {
        int duracionMs = ahora - _inicioCompresionTs;
        _estadoMecanico = 'rearmando';
        enCompresion = false;
        _finCompresionTs = ahora;

        bool valida = duracionMs >= detectMinDurMs &&
                      duracionMs <= detectMaxDurMs &&
                      picoProfundidad >= detectPeakMinMm;

        if (valida) {
          compresionesTotales++;
          _tsCompresiones.add(ahora);
          if (_tsCompresiones.length > maxWindow * 2) {
            _tsCompresiones.removeAt(0);
          }

          bool profOk = picoProfundidad >= ahaMinDepthMm && picoProfundidad <= ahaMaxDepthMm;
          bool recoilFue = data.forceKg < ahaRecoilThresholdKg;
          currentCpm = _calcularCpm(ahora);
          bool freqOk = currentCpm >= ahaMinRateCpm && currentCpm <= ahaMaxRateCpm;

          if (profOk) compresionesCorrectas++;
          if (recoilFue) recoilCorrectos++;
          if (freqOk) freqCorrectas++;

          compresionCorrecta = profOk && recoilFue && freqOk;

          sumProfundidad += picoProfundidad;
          sumFuerza += picoFuerza;

          if (ultimaCompresionTs > 0) {
            double pausa = (ahora - ultimaCompresionTs) / 1000.0;
            if (pausa > maxPausaSeg) maxPausaSeg = pausa;
            if (pausa >= 10.0) pausasCount++;
          }
          ultimaCompresionTs = ahora;
          nuevaCompresion = true;
        }
      }
    } else if (_estadoMecanico == 'rearmando') {
      if ((ahora - _finCompresionTs) > detectDebounceMs) {
        if (data.depthMm < detectRearmMm) {
          _estadoMecanico = 'reposo';
          picoFuerza = 0.0;
          picoProfundidad = 0.0;
        }
      }
    }

    return nuevaCompresion;
  }

  int _calcularCpm(int ahora) {
    if (_tsCompresiones.length < 2) return 0;
    
    // Limpiar muestras viejas (> 5 seg) para que la frecuencia sea "instantánea" pero suave
    while (_tsCompresiones.length > 2 && (ahora - _tsCompresiones.first) > 5000) {
      _tsCompresiones.removeAt(0);
    }

    if ((ahora - _tsCompresiones.last) > 3000) return 0;
    
    int spanMs = _tsCompresiones.last - _tsCompresiones.first;
    if (spanMs <= 0) return 0;
    
    int count = _tsCompresiones.length;
    double minutes = spanMs / 60000.0;
    int cpm = ((count - 1) / minutes).round();
    
    return cpm.clamp(0, 200);
  }

  void reset() {
    _estadoMecanico = 'reposo';
    enCompresion = false;
    _inicioCompresionTs = 0;
    _finCompresionTs = 0;
    picoFuerza = 0.0;
    picoProfundidad = 0.0;
    compresionesTotales = 0;
    compresionesCorrectas = 0;
    recoilCorrectos = 0;
    freqCorrectas = 0;
    _tsCompresiones = [];
    ultimaCompresionTs = 0;
    pausasCount = 0;
    maxPausaSeg = 0.0;
    sumProfundidad = 0.0;
    sumFuerza = 0.0;
    recoilOk = false;
    compresionCorrecta = false;
    currentCpm = 0;
  }
}

