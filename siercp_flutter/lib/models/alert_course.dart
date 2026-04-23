import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ─── ALERT ────────────────────────────────────────────────────────────────────
enum AlertType { ok, warning, error, info }

class AlertModel {
  final String id;
  final String sessionId;
  final AlertType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool read;

  const AlertModel({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.read = false,
  });

  Color get color {
    switch (type) {
      case AlertType.ok:      return const Color(0xFF00E676);
      case AlertType.warning: return const Color(0xFFFFAB00);
      case AlertType.error:   return const Color(0xFFFF3B5C);
      case AlertType.info:    return const Color(0xFF00D4FF);
    }
  }

  Color get bgColor {
    switch (type) {
      case AlertType.ok:      return const Color(0x1F00E676);
      case AlertType.warning: return const Color(0x1FFFAB00);
      case AlertType.error:   return const Color(0x1FFF3B5C);
      case AlertType.info:    return const Color(0x1F00D4FF);
    }
  }

  IconData get icon {
    switch (type) {
      case AlertType.ok:      return Icons.check_circle_outline;
      case AlertType.warning: return Icons.warning_amber_outlined;
      case AlertType.error:   return Icons.cancel_outlined;
      case AlertType.info:    return Icons.info_outline;
    }
  }

  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AlertModel(
      id:        doc.id,
      sessionId: d['sessionId'] ?? '',
      type:      _parseType(d['type']),
      title:     d['title']     ?? '',
      message:   d['message']   ?? '',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read:      d['read']      ?? false,
    );
  }

  static AlertType _parseType(String? t) {
    switch (t) {
      case 'ok':      return AlertType.ok;
      case 'warning': return AlertType.warning;
      case 'error':   return AlertType.error;
      default:        return AlertType.info;
    }
  }

  Map<String, dynamic> toFirestore() => {
    'sessionId': sessionId,
    'type':      type.name,
    'title':     title,
    'message':   message,
    'timestamp': FieldValue.serverTimestamp(),
    'read':      read,
  };
}

// ─── SCENARIO ─────────────────────────────────────────────────────────────────
enum ScenarioCategory {
  accident,
  drowning,
  cardiac,
  pediatric,
  electrocution,
  // Nuevas categorías
  ahogamiento,
  accidenteTransito,
  paroCardiaco,
  colapsoEjercicio,
  atragantamiento,
  descargaElectrica,
  sobredosis,
  infarto,
}

class ScenarioModel {
  final String id;
  final String title;
  final String description;
  final String audioIntroText;
  final String patientAge;
  final String patientType;
  final ScenarioCategory category;
  final String difficulty;
  final bool locked;
  final bool isNew;
  final String? relatedGuideId;  // Guía recomendada antes del escenario
  final String? situation;       // Descripción de la situación
  final String? action;          // Qué debe hacer el rescatador

  const ScenarioModel({
    required this.id,
    required this.title,
    required this.description,
    required this.audioIntroText,
    required this.patientAge,
    required this.patientType,
    required this.category,
    required this.difficulty,
    this.locked = false,
    this.isNew  = false,
    this.relatedGuideId,
    this.situation,
    this.action,
  });

  String get emoji {
    switch (category) {
      case ScenarioCategory.accident:          return '🚗';
      case ScenarioCategory.drowning:          return '🏊';
      case ScenarioCategory.cardiac:           return '❤️';
      case ScenarioCategory.pediatric:         return '🧒';
      case ScenarioCategory.electrocution:     return '⚡';
      case ScenarioCategory.ahogamiento:       return '🌊';
      case ScenarioCategory.accidenteTransito: return '🚗';
      case ScenarioCategory.paroCardiaco:      return '🏠';
      case ScenarioCategory.colapsoEjercicio:  return '🏋️';
      case ScenarioCategory.atragantamiento:   return '🍽️';
      case ScenarioCategory.descargaElectrica: return '⚡';
      case ScenarioCategory.sobredosis:        return '🛏️';
      case ScenarioCategory.infarto:           return '🚨';
    }
  }

  Color get categoryColor {
    switch (category) {
      case ScenarioCategory.cardiac:
      case ScenarioCategory.paroCardiaco:
      case ScenarioCategory.infarto:
        return const Color(0xFFFF3B5C);
      case ScenarioCategory.drowning:
      case ScenarioCategory.ahogamiento:
        return const Color(0xFF00D4FF);
      case ScenarioCategory.accident:
      case ScenarioCategory.accidenteTransito:
        return const Color(0xFFFFAB00);
      case ScenarioCategory.electrocution:
      case ScenarioCategory.descargaElectrica:
        return const Color(0xFFFFD700);
      case ScenarioCategory.pediatric:
        return const Color(0xFF00E676);
      case ScenarioCategory.colapsoEjercicio:
        return const Color(0xFF8B5CF6);
      case ScenarioCategory.atragantamiento:
        return const Color(0xFFFF6B35);
      case ScenarioCategory.sobredosis:
        return const Color(0xFFFF8C00);
    }
  }

  String get categoryString => {
    ScenarioCategory.accident:          'accident',
    ScenarioCategory.drowning:          'drowning',
    ScenarioCategory.cardiac:           'cardiac',
    ScenarioCategory.pediatric:         'pediatric',
    ScenarioCategory.electrocution:     'electrocution',
    ScenarioCategory.ahogamiento:       'ahogamiento',
    ScenarioCategory.accidenteTransito: 'accidenteTransito',
    ScenarioCategory.paroCardiaco:      'paroCardiaco',
    ScenarioCategory.colapsoEjercicio:  'colapsoEjercicio',
    ScenarioCategory.atragantamiento:   'atragantamiento',
    ScenarioCategory.descargaElectrica: 'descargaElectrica',
    ScenarioCategory.sobredosis:        'sobredosis',
    ScenarioCategory.infarto:           'infarto',
  }[category] ?? 'cardiac';

  factory ScenarioModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ScenarioModel(
      id:             doc.id,
      title:          d['title']          ?? '',
      description:    d['description']    ?? '',
      audioIntroText: d['audioIntroText'] ?? '',
      patientAge:     d['patientAge']     ?? '',
      patientType:    d['patientType']    ?? 'adult',
      category:       _parseCategory(d['category']),
      difficulty:     d['difficulty']     ?? 'medium',
      locked:         d['locked']         ?? false,
      isNew:          d['isNew']          ?? false,
      relatedGuideId: d['relatedGuideId'],
      situation:      d['situation'],
      action:         d['action'],
    );
  }

  static ScenarioCategory _parseCategory(String? c) {
    switch (c) {
      case 'accident':          return ScenarioCategory.accident;
      case 'drowning':          return ScenarioCategory.drowning;
      case 'pediatric':         return ScenarioCategory.pediatric;
      case 'electrocution':     return ScenarioCategory.electrocution;
      case 'ahogamiento':       return ScenarioCategory.ahogamiento;
      case 'accidenteTransito': return ScenarioCategory.accidenteTransito;
      case 'paroCardiaco':      return ScenarioCategory.paroCardiaco;
      case 'colapsoEjercicio':  return ScenarioCategory.colapsoEjercicio;
      case 'atragantamiento':   return ScenarioCategory.atragantamiento;
      case 'descargaElectrica': return ScenarioCategory.descargaElectrica;
      case 'sobredosis':        return ScenarioCategory.sobredosis;
      case 'infarto':           return ScenarioCategory.infarto;
      default:                  return ScenarioCategory.cardiac;
    }
  }
}

// ─── COURSE ───────────────────────────────────────────────────────────────────
class CourseModel {
  final String id;
  final String title;
  final String instructorName;
  final String? instructorId;
  final String? instructorEmail;
  final String? inviteCode;
  final int totalModules;
  final int completedModules;
  final String certification;
  final DateTime? nextDeadline;
  final String? nextDeadlineTitle;
  final double requiredScore;
  final int? studentCount;
  final List<String> guideIds;        // IDs de guías del curso
  final int requiredGuideCount;       // Cuántas guías son obligatorias
  final String scenarioMode;          // 'completo' | 'aleatorio'
  final DateTime? createdAt;
  final String? description;

  const CourseModel({
    required this.id,
    required this.title,
    required this.instructorName,
    this.instructorId,
    this.instructorEmail,
    this.inviteCode,
    required this.totalModules,
    required this.completedModules,
    required this.certification,
    this.nextDeadline,
    this.nextDeadlineTitle,
    this.requiredScore = 85.0,
    this.studentCount,
    this.guideIds = const [],
    this.requiredGuideCount = 0,
    this.scenarioMode = 'completo',
    this.createdAt,
    this.description,
  });

  double get progress => totalModules == 0 ? 0 : completedModules / totalModules;
  int    get progressPct => (progress * 100).round();

  factory CourseModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawGuides = d['guideIds'];
    final guideList = rawGuides is List ? rawGuides.cast<String>() : <String>[];
    return CourseModel(
      id:                  doc.id,
      title:               d['title']              ?? '',
      instructorName:      d['instructorName']     ?? '',
      instructorId:        d['instructorId'],
      instructorEmail:     d['instructorEmail'],
      inviteCode:          d['inviteCode'],
      totalModules:        d['totalModules']       ?? 0,
      completedModules:    d['completedModules']   ?? 0,
      certification:       d['certification']      ?? '',
      nextDeadline:        (d['nextDeadline'] as Timestamp?)?.toDate(),
      nextDeadlineTitle:   d['nextDeadlineTitle'],
      requiredScore:       (d['requiredScore']     ?? 85).toDouble(),
      studentCount:        d['studentCount']       as int?,
      guideIds:            guideList,
      requiredGuideCount:  d['requiredGuideCount'] ?? 0,
      scenarioMode:        d['scenarioMode']       ?? 'completo',
      createdAt:           (d['createdAt'] as Timestamp?)?.toDate(),
      description:         d['description'],
    );
  }
}
