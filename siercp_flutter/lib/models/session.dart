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
  final double averageDepthMm;
  final double averageRatePerMin;
  final double correctCompressionsPct;
  final double averageForcKg;
  final int interruptionCount;
  final double maxPauseSeconds;
  final double score;
  final bool approved;
  final List<AhaViolation> violations;

  const SessionMetrics({
    required this.totalCompressions,
    required this.averageDepthMm,
    required this.averageRatePerMin,
    required this.correctCompressionsPct,
    required this.averageForcKg,
    required this.interruptionCount,
    required this.maxPauseSeconds,
    required this.score,
    required this.approved,
    required this.violations,
  });

  Color get scoreColor {
    if (score >= 85) return const Color(0xFF00E676);
    if (score >= 70) return const Color(0xFFFFAB00);
    return const Color(0xFFFF3B5C);
  }

  bool get depthOk =>
      averageDepthMm >= AppConstants.ahaMinDepthMm &&
      averageDepthMm <= AppConstants.ahaMaxDepthMm;

  bool get rateOk =>
      averageRatePerMin >= AppConstants.ahaMinRatePerMin &&
      averageRatePerMin <= AppConstants.ahaMaxRatePerMin;

  factory SessionMetrics.fromMap(Map<String, dynamic> m) => SessionMetrics(
    totalCompressions:    m['totalCompressions']    ?? 0,
    averageDepthMm:       (m['averageDepthMm']       ?? 0).toDouble(),
    averageRatePerMin:    (m['averageRatePerMin']    ?? 0).toDouble(),
    correctCompressionsPct: (m['correctCompressionsPct'] ?? 0).toDouble(),
    averageForcKg:        (m['averageForceKg']       ?? 0).toDouble(),
    interruptionCount:    m['interruptionCount']    ?? 0,
    maxPauseSeconds:      (m['maxPauseSeconds']      ?? 0).toDouble(),
    score:                (m['score']                ?? 0).toDouble(),
    approved:             m['approved']              ?? false,
    violations: (m['violations'] as List? ?? [])
        .map((v) => AhaViolation.fromMap(v as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toMap() => {
    'totalCompressions':    totalCompressions,
    'averageDepthMm':       averageDepthMm,
    'averageRatePerMin':    averageRatePerMin,
    'correctCompressionsPct': correctCompressionsPct,
    'averageForceKg':       averageForcKg,
    'interruptionCount':    interruptionCount,
    'maxPauseSeconds':      maxPauseSeconds,
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
  final double correctPct;
  final bool decompressedFully;
  final double oxygen;
  final String? alertMessage;
  final String? alertType;

  const LiveSessionData({
    required this.depthMm,
    required this.ratePerMin,
    required this.forceKg,
    required this.compressionCount,
    required this.correctPct,
    required this.decompressedFully,
    this.oxygen      = 98.0,
    this.alertMessage,
    this.alertType,
  });

  factory LiveSessionData.fromMap(Map<String, dynamic> m) => LiveSessionData(
    depthMm:          (m['depthMm']          ?? 0).toDouble(),
    ratePerMin:        m['ratePerMin']        ?? 0,
    forceKg:          (m['forceKg']           ?? 0).toDouble(),
    compressionCount:  m['compressionCount']  ?? 0,
    correctPct:       (m['correctPct']        ?? 0).toDouble(),
    decompressedFully: m['decompressedFully'] ?? false,
    oxygen:           (m['oxygen']            ?? 98.0).toDouble(),
    alertMessage:      m['alertMessage'],
    alertType:         m['alertType'],
  );

  LiveSessionData copyWith({
    double? depthMm, int? ratePerMin, double? forceKg,
    int? compressionCount, double? correctPct, bool? decompressedFully,
    double? oxygen, String? alertMessage, String? alertType,
  }) => LiveSessionData(
    depthMm:          depthMm          ?? this.depthMm,
    ratePerMin:       ratePerMin       ?? this.ratePerMin,
    forceKg:          forceKg          ?? this.forceKg,
    compressionCount: compressionCount ?? this.compressionCount,
    correctPct:       correctPct       ?? this.correctPct,
    decompressedFully: decompressedFully ?? this.decompressedFully,
    oxygen:           oxygen           ?? this.oxygen,
    alertMessage:     alertMessage     ?? this.alertMessage,
    alertType:        alertType        ?? this.alertType,
  );
}
