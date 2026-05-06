import 'package:cloud_firestore/cloud_firestore.dart';

enum ModuleType {
  teoria,
  evaluacion_teorica,
  practica_guiada,
  certificacion;

  String get label {
    switch (this) {
      case ModuleType.teoria:
        return 'Teoría';
      case ModuleType.evaluacion_teorica:
        return 'Evaluación teórica';
      case ModuleType.practica_guiada:
        return 'Práctica guiada';
      case ModuleType.certificacion:
        return 'Certificación';
    }
  }

  String get icon {
    switch (this) {
      case ModuleType.teoria:
        return '📖';
      case ModuleType.evaluacion_teorica:
        return '📝';
      case ModuleType.practica_guiada:
        return '🫀';
      case ModuleType.certificacion:
        return '🏆';
    }
  }

  String get description {
    switch (this) {
      case ModuleType.teoria:
        return 'PDF, video y texto explicativo';
      case ModuleType.evaluacion_teorica:
        return 'Quiz de opción múltiple con nota mínima';
      case ModuleType.practica_guiada:
        return 'Sesiones de RCP en el simulador';
      case ModuleType.certificacion:
        return 'Genera certificado automático al completar';
    }
  }
}

class QuizQuestion {
  final String text;
  final List<String> options;
  final int correctIndex;

  const QuizQuestion({
    required this.text,
    required this.options,
    required this.correctIndex,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> m) => QuizQuestion(
        text: m['text'] ?? '',
        options: List<String>.from(m['options'] ?? []),
        correctIndex: m['correctIndex'] ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'text': text,
        'options': options,
        'correctIndex': correctIndex,
      };
}

class RequiredSession {
  final String scenarioId;
  final int count;
  final int minScore;

  const RequiredSession({
    required this.scenarioId,
    required this.count,
    required this.minScore,
  });

  factory RequiredSession.fromMap(Map<String, dynamic> m) => RequiredSession(
        scenarioId: m['scenarioId'] ?? 'adulto',
        count: m['count'] ?? 1,
        minScore: m['minScore'] ?? 70,
      );

  Map<String, dynamic> toMap() => {
        'scenarioId': scenarioId,
        'count': count,
        'minScore': minScore,
      };
}

class CourseModule {
  final String id;
  final String courseId;
  final int order;
  final String title;
  final ModuleType type;

  // Teoría
  final String? pdfUrl;
  final String? videoUrl;
  final String? textContent;

  // Evaluación teórica
  final int passingScore;
  final List<QuizQuestion> questions;

  // Práctica guiada
  final List<RequiredSession> requiredSessions;

  const CourseModule({
    required this.id,
    required this.courseId,
    required this.order,
    required this.title,
    required this.type,
    this.pdfUrl,
    this.videoUrl,
    this.textContent,
    this.passingScore = 80,
    this.questions = const [],
    this.requiredSessions = const [],
  });

  factory CourseModule.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final cfg = Map<String, dynamic>.from(d['config'] ?? {});

    return CourseModule(
      id: doc.id,
      courseId: d['courseId'] ?? '',
      order: d['order'] ?? 0,
      title: d['title'] ?? '',
      type: _parseType(d['type']),

      // Teoría
      pdfUrl: cfg['pdfUrl'],
      videoUrl: cfg['videoUrl'],
      textContent: cfg['textContent'],

      // Quiz
      passingScore: cfg['passingScore'] ?? 80,
      questions: (cfg['questions'] as List<dynamic>? ?? [])
          .map((q) => QuizQuestion.fromMap(Map<String, dynamic>.from(q)))
          .toList(),

      // Práctica
      requiredSessions: (cfg['requiredSessions'] as List<dynamic>? ?? [])
          .map((s) => RequiredSession.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
    );
  }

  static ModuleType _parseType(String? t) {
    switch (t) {
      case 'teoria':
        return ModuleType.teoria;
      case 'evaluacion_teorica':
        return ModuleType.evaluacion_teorica;
      case 'practica_guiada':
        return ModuleType.practica_guiada;
      case 'certificacion':
        return ModuleType.certificacion;
      default:
        return ModuleType.teoria;
    }
  }
}
