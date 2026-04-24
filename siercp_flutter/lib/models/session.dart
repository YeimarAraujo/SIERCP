import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/constants.dart';

enum SessionStatus { pending, active, completed, aborted }
enum PatientType   { adult, pediatric, infant }

class SessionModel {
  final String id;
  final String studentId;
  final String? scenarioId;
  final String? scenarioTitle;
  final PatientType patientType;
  final SessionStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final SessionMetrics? metrics;
  final String? courseId;

  const SessionModel({
    required this.id,
    required this.studentId,
    this.scenarioId,
    this.scenarioTitle,
    required this.patientType,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.metrics,
    this.courseId,
  });

  Duration get duration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  String get durationFormatted {
    final d = duration;
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  factory SessionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SessionModel(
      id:             doc.id,
      studentId:      d['studentId']     ?? '',
      scenarioId:     d['scenarioId'],
      scenarioTitle:  d['scenarioTitle'],
      patientType:    _parsePatientType(d['patientType']),
      status:         _parseStatus(d['status']),
      startedAt:      (d['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt:        (d['endedAt'] as Timestamp?)?.toDate(),
      metrics:        d['metrics'] != null ? SessionMetrics.fromMap(d['metrics']) : null,
      courseId:        d['courseId'],
    );
  }

  static PatientType _parsePatientType(String? t) {
    switch (t) {
      case 'pediatric': return PatientType.pediatric;
      case 'infant': return PatientType.infant;
      default: return PatientType.adult;
    }
  }

  static SessionStatus _parseStatus(String? s) {
    switch (s) {
      case 'active':    return SessionStatus.active;
      case 'completed': return SessionStatus.completed;
      case 'aborted':   return SessionStatus.aborted;
      default:          return SessionStatus.pending;
    }
  }
}

class SessionMetrics {
  final int totalCompressions;
  final int correctCompressions;
  final double averageDepthMm;
  final double averageRatePerMin;
  final double correctCompressionsPct;
  final double averageForcKg;
  final double recoilPct;
  final int interruptionCount;
  final double maxPauseSeconds;
  final double ccfPct; // Chest Compression Fraction (AHA: >= 60%)
  // Score desglosado por componente AHA
  final double depthScore;
  final double rateScore;
  final double recoilScore;
  final double interruptionScore;
  final double score;
  final bool approved;
  final List<AhaViolation> violations;

  const SessionMetrics({
    required this.totalCompressions,
    this.correctCompressions = 0,
    required this.averageDepthMm,
    required this.averageRatePerMin,
    required this.correctCompressionsPct,
    required this.averageForcKg,
    this.recoilPct = 100.0,
    required this.interruptionCount,
    required this.maxPauseSeconds,
    this.ccfPct = 100.0,
    this.depthScore = 0.0,
    this.rateScore = 0.0,
    this.recoilScore = 0.0,
    this.interruptionScore = 0.0,
    required this.score,
    required this.approved,
    required this.violations,
  });

  Color get scoreColor {
    if (score >= AppConstants.ahaExcellentScore) return const Color(0xFF00E676);
    if (score >= AppConstants.ahaPassScore) return const Color(0xFFFFAB00);
    return const Color(0xFFFF3B5C);
  }

  bool get depthOk =>
      averageDepthMm >= AppConstants.ahaMinDepthMm &&
      averageDepthMm <= AppConstants.ahaMaxDepthMm;

  bool get rateOk =>
      averageRatePerMin >= AppConstants.ahaMinRatePerMin &&
      averageRatePerMin <= AppConstants.ahaMaxRatePerMin;

  bool get recoilGood => recoilPct >= 80.0;

  String get gradeLabel {
    if (score >= AppConstants.ahaExcellentScore) return 'Excelente';
    if (score >= AppConstants.ahaPassScore) return 'Aprobado';
    if (score >= 50) return 'Necesita mejora';
    return 'Reprobado';
  }

  factory SessionMetrics.fromMap(Map<String, dynamic> m) => SessionMetrics(
    totalCompressions:    m['totalCompressions']    ?? 0,
    correctCompressions:  m['correctCompressions']  ?? 0,
    averageDepthMm:       (m['averageDepthMm']       ?? 0).toDouble(),
    averageRatePerMin:    (m['averageRatePerMin']    ?? 0).toDouble(),
    correctCompressionsPct: (m['correctCompressionsPct'] ?? 0).toDouble(),
    averageForcKg:        (m['averageForceKg']       ?? 0).toDouble(),
    recoilPct:            (m['recoilPct']            ?? 100).toDouble(),
    interruptionCount:    m['interruptionCount']    ?? 0,
    maxPauseSeconds:      (m['maxPauseSeconds']      ?? 0).toDouble(),
    ccfPct:               (m['ccfPct']               ?? 100).toDouble(),
    depthScore:           (m['depthScore']           ?? 0).toDouble(),
    rateScore:            (m['rateScore']            ?? 0).toDouble(),
    recoilScore:          (m['recoilScore']          ?? 0).toDouble(),
    interruptionScore:    (m['interruptionScore']    ?? 0).toDouble(),
    score:                (m['score']                ?? 0).toDouble(),
    approved:             m['approved']              ?? false,
    violations: (m['violations'] as List? ?? [])
        .map((v) => AhaViolation.fromMap(v as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toMap() => {
    'totalCompressions':    totalCompressions,
    'correctCompressions':  correctCompressions,
    'averageDepthMm':       averageDepthMm,
    'averageRatePerMin':    averageRatePerMin,
    'correctCompressionsPct': correctCompressionsPct,
    'averageForceKg':       averageForcKg,
    'recoilPct':            recoilPct,
    'interruptionCount':    interruptionCount,
    'maxPauseSeconds':      maxPauseSeconds,
    'depthScore':           depthScore,
    'rateScore':            rateScore,
    'recoilScore':          recoilScore,
    'interruptionScore':    interruptionScore,
    'score':                score,
    'approved':             approved,
    'violations': violations.map((v) => v.toMap()).toList(),
  };
}

class AhaViolation {
  final String type;
  final String message;
  final int count;

  const AhaViolation({required this.type, required this.message, required this.count});

  factory AhaViolation.fromMap(Map<String, dynamic> m) => AhaViolation(
    type:    m['type']    ?? '',
    message: m['message'] ?? '',
    count:   m['count']   ?? 0,
  );

  Map<String, dynamic> toMap() => {'type': type, 'message': message, 'count': count};
}

class LiveSessionData {
  final double depthMm;
  final int ratePerMin;
  final double forceKg;
  final int compressionCount;
  final int correctCompressionCount;
  final double correctPct;
  final bool decompressedFully;
  final double recoilPct;
  final double oxygen;
  final int pauseCount;
  final double maxPauseSec;
  final bool sensorOk;
  final bool calibrated;
  final String? alertMessage;
  final String? alertType;

  const LiveSessionData({
    required this.depthMm,
    required this.ratePerMin,
    required this.forceKg,
    required this.compressionCount,
    this.correctCompressionCount = 0,
    required this.correctPct,
    required this.decompressedFully,
    this.recoilPct = 100.0,
    this.oxygen = 98.0,
    this.pauseCount = 0,
    this.maxPauseSec = 0.0,
    this.sensorOk = true,
    this.calibrated = false,
    this.alertMessage,
    this.alertType,
  });

  factory LiveSessionData.fromMap(Map<String, dynamic> m) => LiveSessionData(
    depthMm:                (m['depthMm']          ?? 0).toDouble(),
    ratePerMin:              m['ratePerMin']        ?? 0,
    forceKg:                (m['forceKg']           ?? 0).toDouble(),
    compressionCount:        m['compressionCount']  ?? 0,
    correctCompressionCount: m['correctCompressionCount'] ?? 0,
    correctPct:             (m['correctPct']        ?? 0).toDouble(),
    decompressedFully:       m['decompressedFully'] ?? false,
    recoilPct:              (m['recoilPct']         ?? 100).toDouble(),
    oxygen:                 (m['oxygen']            ?? 98.0).toDouble(),
    pauseCount:              m['pauseCount']        ?? 0,
    maxPauseSec:            (m['maxPauseSec']       ?? 0).toDouble(),
    sensorOk:                m['sensorOk']          ?? true,
    calibrated:              m['calibrated']        ?? false,
    alertMessage:            m['alertMessage'],
    alertType:               m['alertType'],
  );

  LiveSessionData copyWith({
    double? depthMm, int? ratePerMin, double? forceKg,
    int? compressionCount, int? correctCompressionCount,
    double? correctPct, bool? decompressedFully,
    double? recoilPct, double? oxygen,
    int? pauseCount, double? maxPauseSec,
    bool? sensorOk, bool? calibrated,
    String? alertMessage, String? alertType,
  }) => LiveSessionData(
    depthMm:                depthMm               ?? this.depthMm,
    ratePerMin:             ratePerMin             ?? this.ratePerMin,
    forceKg:                forceKg                ?? this.forceKg,
    compressionCount:       compressionCount       ?? this.compressionCount,
    correctCompressionCount: correctCompressionCount ?? this.correctCompressionCount,
    correctPct:             correctPct             ?? this.correctPct,
    decompressedFully:      decompressedFully      ?? this.decompressedFully,
    recoilPct:              recoilPct              ?? this.recoilPct,
    oxygen:                 oxygen                 ?? this.oxygen,
    pauseCount:             pauseCount             ?? this.pauseCount,
    maxPauseSec:            maxPauseSec            ?? this.maxPauseSec,
    sensorOk:               sensorOk               ?? this.sensorOk,
    calibrated:             calibrated             ?? this.calibrated,
    alertMessage:           alertMessage           ?? this.alertMessage,
    alertType:              alertType              ?? this.alertType,
  );
}
