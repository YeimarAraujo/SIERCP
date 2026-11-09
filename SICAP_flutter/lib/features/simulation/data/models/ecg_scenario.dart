import 'package:flutter/material.dart';
import 'package:siercp/core/theme/theme.dart';

/// Tipo de ritmo electrocardiográfico. Cada valor controla la morfología de la
/// curva generada por el sintetizador [EcgGenerator]. Para agregar un nuevo
/// escenario clínico basta con añadir un valor aquí (si requiere una morfología
/// nueva) y registrar el [EcgScenario] correspondiente en el catálogo.
enum EcgRhythm {
  sinusNormal,
  sinusBradycardia,
  sinusTachycardia,
  sinusArrhythmia,
  atrialFibrillation,
  atrialFlutter,
  svt,
  vtach,
  vfib,
  asystole,
  pea,
  avBlock1,
  avBlock2TypeI,
  avBlock2TypeII,
  avBlock3,
  rbbb,
  lbbb,
  pac,
  pvc,
  bigeminy,
  trigeminy,
  torsades,
  hyperkalemia,
  hypokalemia,
  ischemia,
  stemi,
  nstemi,
  pericarditis,
  paced,
}

/// Nivel de alarma del monitor. Controla el color e intermitencia del marco y
/// de los indicadores de constantes vitales.
enum AlarmLevel { none, advisory, warning, critical }

extension AlarmLevelX on AlarmLevel {
  Color get color {
    switch (this) {
      case AlarmLevel.none:
        return AppColors.green;
      case AlarmLevel.advisory:
        return AppColors.cyan;
      case AlarmLevel.warning:
        return AppColors.amber;
      case AlarmLevel.critical:
        return AppColors.red;
    }
  }

  String get label {
    switch (this) {
      case AlarmLevel.none:
        return 'ESTABLE';
      case AlarmLevel.advisory:
        return 'VIGILAR';
      case AlarmLevel.warning:
        return 'ALERTA';
      case AlarmLevel.critical:
        return 'CRÍTICO';
    }
  }
}

/// Modelo desacoplado de un escenario de ECG simulado. Toda la información
/// necesaria para renderizar el monitor proviene de este objeto inmutable, de
/// modo que la capa de presentación no conoce los detalles de generación de la
/// señal ni del catálogo.
@immutable
class EcgScenario {
  final String id;
  final String name;

  /// Categoría para agrupar la lista (p. ej. "Ritmos sinusales").
  final String category;

  /// Descripción breve mostrada en la tarjeta de la lista.
  final String summary;

  /// Nota clínica más extensa mostrada en el monitor / detalle.
  final String clinicalNote;

  final EcgRhythm rhythm;

  /// Frecuencia cardíaca a mostrar. 0 ⇒ se muestra "--" (asistolia / FV).
  final int heartRate;

  /// Etiqueta opcional de FC cuando no es un número fijo (p. ej. "Variable").
  final String? heartRateLabel;

  final int spo2; // 0 ⇒ "--"
  final int respRate; // 0 ⇒ "--"
  final int sysBp; // 0 ⇒ sin PA (no aplica al escenario)
  final int diaBp;

  /// Si el escenario tiene pulso (perfusión). Falso en FV, asistolia, AESP y
  /// TV sin pulso: el monitor muestra SpO₂/PA sin onda de pulso.
  final bool pulsePresent;

  final AlarmLevel alarm;
  final Color accent;

  const EcgScenario({
    required this.id,
    required this.name,
    required this.category,
    required this.summary,
    required this.clinicalNote,
    required this.rhythm,
    required this.heartRate,
    this.heartRateLabel,
    this.spo2 = 0,
    this.respRate = 0,
    this.sysBp = 0,
    this.diaBp = 0,
    this.pulsePresent = true,
    this.alarm = AlarmLevel.none,
    this.accent = AppColors.green,
  });

  bool get hasBloodPressure => sysBp > 0;
  String get hrText => heartRateLabel ?? (heartRate > 0 ? '$heartRate' : '--');
  String get spo2Text => spo2 > 0 ? '$spo2' : '--';
  String get respText => respRate > 0 ? '$respRate' : '--';
  String get bpText => hasBloodPressure ? '$sysBp/$diaBp' : '--/--';
}
