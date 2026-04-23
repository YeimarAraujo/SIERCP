import 'package:cloud_firestore/cloud_firestore.dart';

// ─── GuideCategory ────────────────────────────────────────────────────────────
enum GuideCategory {
  tecnica,       // Técnicas de RCP
  teoria,        // Fundamentos teóricos
  seguridad,     // Bioseguridad y prevención
  emergencias,   // Situaciones especiales
  equipamiento,  // Uso de dispositivos
}

extension GuideCategoryExtension on GuideCategory {
  String get label {
    switch (this) {
      case GuideCategory.tecnica:      return 'Técnica';
      case GuideCategory.teoria:       return 'Teoría';
      case GuideCategory.seguridad:    return 'Seguridad';
      case GuideCategory.emergencias:  return 'Emergencias';
      case GuideCategory.equipamiento: return 'Equipamiento';
    }
  }

  String get emoji {
    switch (this) {
      case GuideCategory.tecnica:      return '🤲';
      case GuideCategory.teoria:       return '📖';
      case GuideCategory.seguridad:    return '🛡️';
      case GuideCategory.emergencias:  return '🚨';
      case GuideCategory.equipamiento: return '🔧';
    }
  }

  String get value {
    switch (this) {
      case GuideCategory.tecnica:      return 'tecnica';
      case GuideCategory.teoria:       return 'teoria';
      case GuideCategory.seguridad:    return 'seguridad';
      case GuideCategory.emergencias:  return 'emergencias';
      case GuideCategory.equipamiento: return 'equipamiento';
    }
  }

  static GuideCategory fromValue(String? val) {
    switch (val) {
      case 'tecnica':      return GuideCategory.tecnica;
      case 'teoria':       return GuideCategory.teoria;
      case 'seguridad':    return GuideCategory.seguridad;
      case 'emergencias':  return GuideCategory.emergencias;
      case 'equipamiento': return GuideCategory.equipamiento;
      default:             return GuideCategory.tecnica;
    }
  }
}

// ─── GuideModel ───────────────────────────────────────────────────────────────
class GuideModel {
  final String id;
  final String title;
  final String description;
  final String courseId;
  final String pdfUrl;           // Firebase Storage download URL
  final String uploadedBy;       // User ID (instructor/admin)
  final String uploaderName;     // Nombre del instructor
  final DateTime uploadedAt;
  final GuideCategory category;
  final bool required;           // ¿Es obligatoria?
  final int order;               // Orden de lectura sugerido
  final int estimatedMinutes;    // Tiempo estimado de lectura

  const GuideModel({
    required this.id,
    required this.title,
    required this.description,
    required this.courseId,
    required this.pdfUrl,
    required this.uploadedBy,
    required this.uploaderName,
    required this.uploadedAt,
    required this.category,
    this.required = false,
    this.order = 0,
    this.estimatedMinutes = 10,
  });

  factory GuideModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GuideModel(
      id:               doc.id,
      title:            d['title']            ?? '',
      description:      d['description']      ?? '',
      courseId:         d['courseId']         ?? '',
      pdfUrl:           d['pdfUrl']           ?? '',
      uploadedBy:       d['uploadedBy']       ?? '',
      uploaderName:     d['uploaderName']     ?? '',
      uploadedAt:       (d['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category:         GuideCategoryExtension.fromValue(d['category']),
      required:         d['required']         ?? false,
      order:            d['order']            ?? 0,
      estimatedMinutes: d['estimatedMinutes'] ?? 10,
    );
  }

  factory GuideModel.fromMap(Map<String, dynamic> d, String id) {
    return GuideModel(
      id:               id,
      title:            d['title']            ?? '',
      description:      d['description']      ?? '',
      courseId:         d['courseId']         ?? '',
      pdfUrl:           d['pdfUrl']           ?? '',
      uploadedBy:       d['uploadedBy']       ?? '',
      uploaderName:     d['uploaderName']     ?? '',
      uploadedAt:       (d['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category:         GuideCategoryExtension.fromValue(d['category']),
      required:         d['required']         ?? false,
      order:            d['order']            ?? 0,
      estimatedMinutes: d['estimatedMinutes'] ?? 10,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title':            title,
    'description':      description,
    'courseId':         courseId,
    'pdfUrl':           pdfUrl,
    'uploadedBy':       uploadedBy,
    'uploaderName':     uploaderName,
    'uploadedAt':       FieldValue.serverTimestamp(),
    'category':         category.value,
    'required':         required,
    'order':            order,
    'estimatedMinutes': estimatedMinutes,
    'createdAt':        FieldValue.serverTimestamp(),
    'updatedAt':        FieldValue.serverTimestamp(),
  };

  GuideModel copyWith({
    String? id,
    String? title,
    String? description,
    String? courseId,
    String? pdfUrl,
    String? uploadedBy,
    String? uploaderName,
    DateTime? uploadedAt,
    GuideCategory? category,
    bool? required,
    int? order,
    int? estimatedMinutes,
  }) =>
      GuideModel(
        id:               id               ?? this.id,
        title:            title            ?? this.title,
        description:      description      ?? this.description,
        courseId:         courseId         ?? this.courseId,
        pdfUrl:           pdfUrl           ?? this.pdfUrl,
        uploadedBy:       uploadedBy       ?? this.uploadedBy,
        uploaderName:     uploaderName     ?? this.uploaderName,
        uploadedAt:       uploadedAt       ?? this.uploadedAt,
        category:         category         ?? this.category,
        required:         required         ?? this.required,
        order:            order            ?? this.order,
        estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      );
}

// ─── GuideProgress ────────────────────────────────────────────────────────────
class GuideProgress {
  final String guideId;
  final String userId;
  final bool completed;
  final DateTime? completedAt;
  final int timeSpentSeconds;    // Tiempo real de lectura
  final int viewCount;           // Veces que abrió el PDF
  final int lastPageReached;     // Última página visitada

  const GuideProgress({
    required this.guideId,
    required this.userId,
    this.completed = false,
    this.completedAt,
    this.timeSpentSeconds = 0,
    this.viewCount = 0,
    this.lastPageReached = 0,
  });

  factory GuideProgress.fromMap(Map<String, dynamic> d, String guideId, String userId) {
    return GuideProgress(
      guideId:          guideId,
      userId:           userId,
      completed:        d['completed']        ?? false,
      completedAt:      (d['completedAt'] as Timestamp?)?.toDate(),
      timeSpentSeconds: d['timeSpentSeconds'] ?? 0,
      viewCount:        d['viewCount']        ?? 0,
      lastPageReached:  d['lastPageReached']  ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'guideId':          guideId,
    'userId':           userId,
    'completed':        completed,
    'completedAt':      completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    'timeSpentSeconds': timeSpentSeconds,
    'viewCount':        viewCount,
    'lastPageReached':  lastPageReached,
    'updatedAt':        FieldValue.serverTimestamp(),
  };

  GuideProgress copyWith({
    String? guideId,
    String? userId,
    bool? completed,
    DateTime? completedAt,
    int? timeSpentSeconds,
    int? viewCount,
    int? lastPageReached,
  }) =>
      GuideProgress(
        guideId:          guideId          ?? this.guideId,
        userId:           userId           ?? this.userId,
        completed:        completed        ?? this.completed,
        completedAt:      completedAt      ?? this.completedAt,
        timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
        viewCount:        viewCount        ?? this.viewCount,
        lastPageReached:  lastPageReached  ?? this.lastPageReached,
      );
}

// ─── GuideProgressSummary ─────────────────────────────────────────────────────
class GuideProgressSummary {
  final int totalGuides;
  final int completedGuides;
  final int requiredGuides;
  final int requiredCompleted;

  const GuideProgressSummary({
    this.totalGuides = 0,
    this.completedGuides = 0,
    this.requiredGuides = 0,
    this.requiredCompleted = 0,
  });

  double get completionPct => totalGuides == 0 ? 0 : completedGuides / totalGuides;
  double get requiredPct   => requiredGuides == 0 ? 0 : requiredCompleted / requiredGuides;
  bool   get allRequiredDone => requiredGuides > 0 && requiredCompleted >= requiredGuides;
}

// ─── Guías pre-cargadas de ejemplo ───────────────────────────────────────────
List<Map<String, dynamic>> preloadedGuides(String courseId, String instructorId, String instructorName) => [
  {
    'id': 'guide_001',
    'title': 'Técnica de Compresiones Torácicas',
    'description': 'Aprende la posición correcta, profundidad y frecuencia según AHA 2020',
    'courseId': courseId,
    'pdfUrl': '',
    'uploadedBy': instructorId,
    'uploaderName': instructorName,
    'category': 'tecnica',
    'required': true,
    'order': 1,
    'estimatedMinutes': 8,
  },
  {
    'id': 'guide_002',
    'title': 'Cadena de Supervivencia',
    'description': 'Los 5 eslabones críticos para salvar vidas en una emergencia cardíaca',
    'courseId': courseId,
    'pdfUrl': '',
    'uploadedBy': instructorId,
    'uploaderName': instructorName,
    'category': 'teoria',
    'required': true,
    'order': 2,
    'estimatedMinutes': 10,
  },
  {
    'id': 'guide_003',
    'title': 'Uso del DEA',
    'description': 'Paso a paso para usar un desfibrilador externo automático correctamente',
    'courseId': courseId,
    'pdfUrl': '',
    'uploadedBy': instructorId,
    'uploaderName': instructorName,
    'category': 'equipamiento',
    'required': false,
    'order': 5,
    'estimatedMinutes': 12,
  },
  {
    'id': 'guide_004',
    'title': 'Bioseguridad en RCP',
    'description': 'Protégete mientras salvas vidas: guantes, barreras y precauciones',
    'courseId': courseId,
    'pdfUrl': '',
    'uploadedBy': instructorId,
    'uploaderName': instructorName,
    'category': 'seguridad',
    'required': true,
    'order': 3,
    'estimatedMinutes': 6,
  },
  {
    'id': 'guide_005',
    'title': 'RCP en Ahogamiento',
    'description': 'Diferencias críticas al reanimar víctimas de ahogamiento en agua',
    'courseId': courseId,
    'pdfUrl': '',
    'uploadedBy': instructorId,
    'uploaderName': instructorName,
    'category': 'emergencias',
    'required': false,
    'order': 7,
    'estimatedMinutes': 9,
  },
];
