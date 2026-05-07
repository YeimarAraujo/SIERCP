import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  studentJoinedCourse,
  studentAddedToCourse,
  systemAlert,
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

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    required this.type,
    this.extraData,
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
      type: NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => NotificationType.systemAlert,
      ),
      extraData: data['extraData'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'type': type.toString().split('.').last,
      'extraData': extraData,
    };
  }
}
