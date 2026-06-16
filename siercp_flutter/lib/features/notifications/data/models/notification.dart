import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de notificación. Cubre el catálogo completo enviable (ver
/// NOTIFICACIONES_SETUP.md). El mapeo desde string es tolerante a las dos
/// convenciones que conviven en el sistema (snake_case del panel/Worker y
/// camelCase de la app), de modo que cualquier `type` recibido obtiene su ícono.
enum NotificationType {
  studentJoinedCourse,
  studentAddedToCourse,
  enrollment,
  certificate,
  payment,
  courseUpdate,
  liveSession,
  quiz,
  achievement,
  reminder,
  systemAlert,
}

/// Convierte el string almacenado en Firestore (`type`) al enum, aceptando
/// alias snake_case y camelCase. Desconocido → [NotificationType.systemAlert].
NotificationType notificationTypeFromString(String? raw) {
  switch (raw) {
    case 'studentJoinedCourse':
      return NotificationType.studentJoinedCourse;
    case 'studentAddedToCourse':
      return NotificationType.studentAddedToCourse;
    case 'enrollment':
      return NotificationType.enrollment;
    case 'certificate':
      return NotificationType.certificate;
    case 'payment':
      return NotificationType.payment;
    case 'course_update':
    case 'courseUpdate':
      return NotificationType.courseUpdate;
    case 'live_session':
    case 'liveSession':
      return NotificationType.liveSession;
    case 'quiz':
      return NotificationType.quiz;
    case 'achievement':
      return NotificationType.achievement;
    case 'reminder':
      return NotificationType.reminder;
    case 'system':
    case 'systemAlert':
    default:
      return NotificationType.systemAlert;
  }
}

class NotificationModel {
  final String id;
  final String userId; // Recipient
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final NotificationType type;
  final Map<String, dynamic>? extraData;

  /// True si proviene de la colección `broadcasts` (anuncio masivo) en vez de
  /// `notifications` (dirigida a un usuario). Los broadcasts no tienen estado
  /// de lectura por-usuario en el documento; `isRead` se calcula en el cliente.
  final bool isBroadcast;

  /// Ruta de deep-link al tocar (campo `link` de los broadcasts).
  final String? link;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    required this.type,
    this.extraData,
    this.isBroadcast = false,
    this.link,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final timestamp = data['createdAt'] as Timestamp?;

    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      createdAt: timestamp?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      type: notificationTypeFromString(data['type'] as String?),
      extraData: data['extraData'],
      link: data['link'] as String?,
    );
  }

  /// Mapea un documento de `broadcasts` a [NotificationModel].
  /// [lastSeen] determina el estado de lectura: el broadcast se considera leído
  /// si se creó antes o en el momento de la última visita a Notificaciones.
  factory NotificationModel.fromBroadcast(
    DocumentSnapshot doc, {
    DateTime? lastSeen,
  }) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final timestamp = data['createdAt'] as Timestamp?;
    final created = timestamp?.toDate() ?? DateTime.now();

    return NotificationModel(
      id: 'bc_${doc.id}',
      userId: '',
      title: data['title'] ?? '',
      message: data['message'] ?? data['body'] ?? '',
      createdAt: created,
      isRead: lastSeen != null && !created.isAfter(lastSeen),
      type: notificationTypeFromString(data['type'] as String?),
      extraData: data['data'] as Map<String, dynamic>?,
      isBroadcast: true,
      link: data['link'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'type': type.name,
      'extraData': extraData,
    };
  }
}
