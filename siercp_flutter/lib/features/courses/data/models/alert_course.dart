import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum AlertType { ok, warning, error, info }

class AlertModel {
  final String id;
  final String? sessionId;
  final String? courseId;
  final AlertType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool read;

  const AlertModel({
    required this.id,
    this.sessionId,
    this.courseId,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.read = false,
  });

  Color get color {
    switch (type) {
      case AlertType.ok:
        return const Color(0xFF00E676);
      case AlertType.warning:
        return const Color(0xFFFFAB00);
      case AlertType.error:
        return const Color(0xFFFF3B5C);
      case AlertType.info:
        return const Color(0xFF00D4FF);
    }
  }

  Color get bgColor {
    switch (type) {
      case AlertType.ok:
        return const Color(0x1F00E676);
      case AlertType.warning:
        return const Color(0x1FFFAB00);
      case AlertType.error:
        return const Color(0x1FFF3B5C);
      case AlertType.info:
        return const Color(0x1F00D4FF);
    }
  }

  IconData get icon {
    switch (type) {
      case AlertType.ok:
        return Icons.check_circle_outline;
      case AlertType.warning:
        return Icons.warning_amber_outlined;
      case AlertType.error:
        return Icons.cancel_outlined;
      case AlertType.info:
        return Icons.info_outline;
    }
  }

  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    debugPrint('🔔 Parseando alerta: ${doc.id} - ${d['title']}');
    return AlertModel(
      id: doc.id,
      sessionId: d['sessionId'],
      courseId: d['courseId'],
      type: _parseType(d['type']),
      title: d['title'] ?? '',
      message: d['message'] ?? '',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: d['read'] ?? false,
    );
  }

  static AlertType _parseType(String? t) {
    switch (t) {
      case 'ok':
        return AlertType.ok;
      case 'warning':
        return AlertType.warning;
      case 'error':
        return AlertType.error;
      default:
        return AlertType.info;
    }
  }

  Map<String, dynamic> toFirestore() => {
        if (sessionId != null) 'sessionId': sessionId,
        if (courseId != null) 'courseId': courseId,
        'type': type.toString().split('.').last,
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': read,
      };
}

// Categorías canónicas de escenario (sin duplicados).
// Cada valor mapea a un string fijo para Firestore.
enum ScenarioCategory {
  paroCardiaco,      // paro_cardiaco — adulto genérico
  infarto,           // infarto       — STEMI / isquemia
  pediatrico,        // pediatrico    — RCP pediátrico/lactante
  ahogamiento,       // ahogamiento   — submersión / near-drowning
  accidenteTransito, // accidente_transito
  colapsoEjercicio,  // colapso_ejercicio
  atragantamiento,   // atragantamiento — OVACE
  descargaElectrica, // descarga_electrica
  sobredosis,        // sobredosis    — opioides u otras sustancias
  quemadura,         // quemadura
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
  final String? relatedGuideId;
  final String? situation;
  final String? action;

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
    this.isNew = false,
    this.relatedGuideId,
    this.situation,
    this.action,
  });

  /// Icono representativo de la categoría (sin emojis).
  IconData get icon {
    switch (category) {
      case ScenarioCategory.paroCardiaco:
        return Icons.monitor_heart_outlined;
      case ScenarioCategory.infarto:
        return Icons.favorite_border_rounded;
      case ScenarioCategory.pediatrico:
        return Icons.child_care_outlined;
      case ScenarioCategory.ahogamiento:
        return Icons.water_outlined;
      case ScenarioCategory.accidenteTransito:
        return Icons.directions_car_outlined;
      case ScenarioCategory.colapsoEjercicio:
        return Icons.fitness_center_outlined;
      case ScenarioCategory.atragantamiento:
        return Icons.medical_services_outlined;
      case ScenarioCategory.descargaElectrica:
        return Icons.bolt_outlined;
      case ScenarioCategory.sobredosis:
        return Icons.medication_outlined;
      case ScenarioCategory.quemadura:
        return Icons.local_fire_department_outlined;
    }
  }

  Color get categoryColor {
    switch (category) {
      case ScenarioCategory.paroCardiaco:
      case ScenarioCategory.infarto:
        return const Color(0xFFFF3B5C);
      case ScenarioCategory.ahogamiento:
        return const Color(0xFF00D4FF);
      case ScenarioCategory.accidenteTransito:
        return const Color(0xFFFFAB00);
      case ScenarioCategory.descargaElectrica:
        return const Color(0xFFFFD700);
      case ScenarioCategory.pediatrico:
        return const Color(0xFF00E676);
      case ScenarioCategory.colapsoEjercicio:
        return const Color(0xFF8B5CF6);
      case ScenarioCategory.atragantamiento:
        return const Color(0xFFFF6B35);
      case ScenarioCategory.sobredosis:
        return const Color(0xFFFF8C00);
      case ScenarioCategory.quemadura:
        return const Color(0xFFFF5722);
    }
  }

  /// String canónico persistido en Firestore.
  String get categoryString => switch (category) {
        ScenarioCategory.paroCardiaco      => 'paroCardiaco',
        ScenarioCategory.infarto           => 'infarto',
        ScenarioCategory.pediatrico        => 'pediatrico',
        ScenarioCategory.ahogamiento       => 'ahogamiento',
        ScenarioCategory.accidenteTransito => 'accidenteTransito',
        ScenarioCategory.colapsoEjercicio  => 'colapsoEjercicio',
        ScenarioCategory.atragantamiento   => 'atragantamiento',
        ScenarioCategory.descargaElectrica => 'descargaElectrica',
        ScenarioCategory.sobredosis        => 'sobredosis',
        ScenarioCategory.quemadura         => 'quemadura',
      };

  factory ScenarioModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ScenarioModel(
      id: doc.id,
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      audioIntroText: d['audioIntroText'] ?? '',
      patientAge: d['patientAge'] ?? '',
      patientType: d['patientType'] ?? 'adult',
      category: _parseCategory(d['category']),
      difficulty: d['difficulty'] ?? 'medium',
      locked: d['locked'] ?? false,
      isNew: d['isNew'] ?? false,
      relatedGuideId: d['relatedGuideId'],
      situation: d['situation'],
      action: d['action'],
    );
  }

  /// Parsea strings legacy y nuevos al enum canónico.
  static ScenarioCategory _parseCategory(String? c) => switch (c) {
        // Valores canónicos
        'paroCardiaco'      => ScenarioCategory.paroCardiaco,
        'infarto'           => ScenarioCategory.infarto,
        'pediatrico'        => ScenarioCategory.pediatrico,
        'ahogamiento'       => ScenarioCategory.ahogamiento,
        'accidenteTransito' => ScenarioCategory.accidenteTransito,
        'colapsoEjercicio'  => ScenarioCategory.colapsoEjercicio,
        'atragantamiento'   => ScenarioCategory.atragantamiento,
        'descargaElectrica' => ScenarioCategory.descargaElectrica,
        'sobredosis'        => ScenarioCategory.sobredosis,
        'quemadura'         => ScenarioCategory.quemadura,
        // Valores legacy (migración backward-compat)
        'cardiac'           => ScenarioCategory.paroCardiaco,
        'drowning'          => ScenarioCategory.ahogamiento,
        'accident'          => ScenarioCategory.accidenteTransito,
        'pediatric'         => ScenarioCategory.pediatrico,
        'electrocution'     => ScenarioCategory.descargaElectrica,
        _                   => ScenarioCategory.paroCardiaco,
      };
}

class CourseModel {
  final String id;
  final String title;
  final String instructorName;
  final String? instructorId;
  /// Lista de UIDs de instructores asignados por el admin.
  /// Complementa instructorId (instructor primario).
  final List<String> instructorIds;
  final String? instructorEmail;
  final String? inviteCode;
  final int totalModules;
  final int completedModules;
  final String certification;
  final DateTime? nextDeadline;
  final String? nextDeadlineTitle;
  final double requiredScore;
  final int? studentCount;
  final List<String> guideIds; // IDs de guías del curso
  final int requiredGuideCount; // Cuántas guías son obligatorias
  final String scenarioMode; // 'completo' | 'aleatorio'
  final DateTime? createdAt;
  final String? description;

  const CourseModel({
    required this.id,
    required this.title,
    required this.instructorName,
    this.instructorId,
    this.instructorIds = const [],
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

  double get progress =>
      totalModules == 0 ? 0 : completedModules / totalModules;
  int get progressPct => (progress * 100).round();

  /// Retorna true si el usuario es instructor de este curso
  /// (ya sea como instructor primario o como instructor asignado).
  bool isInstructorOf(String userId) =>
      instructorId == userId || instructorIds.contains(userId);

  factory CourseModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawGuides = d['guideIds'];
    final guideList = rawGuides is List ? rawGuides.cast<String>() : <String>[];
    final rawIds = d['instructorIds'];
    final idList = rawIds is List ? rawIds.cast<String>() : <String>[];
    return CourseModel(
      id: doc.id,
      title: d['title'] ?? '',
      instructorName: d['instructorName'] ?? '',
      instructorId: d['instructorId'],
      instructorIds: idList,
      instructorEmail: d['instructorEmail'],
      inviteCode: d['inviteCode'],
      totalModules: d['totalModules'] ?? 0,
      completedModules: d['completedModules'] ?? 0,
      certification: d['certification'] ?? '',
      nextDeadline: (d['nextDeadline'] as Timestamp?)?.toDate(),
      nextDeadlineTitle: d['nextDeadlineTitle'],
      requiredScore: (d['requiredScore'] ?? 85).toDouble(),
      studentCount: d['studentCount'] as int?,
      guideIds: guideList,
      requiredGuideCount: d['requiredGuideCount'] ?? 0,
      scenarioMode: d['scenarioMode'] ?? 'completo',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      description: d['description'],
    );
  }
}
