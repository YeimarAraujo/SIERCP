import 'package:cloud_firestore/cloud_firestore.dart';

class QuizTopic {
  final String id;
  final String title;
  final String description;
  final String category;
  final int questionCount;
  final int durationSeconds;
  final bool isActive;
  final String? requiresPlan;
  final String? iconName;
  final String? colorHex;

  const QuizTopic({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.questionCount,
    required this.durationSeconds,
    required this.isActive,
    this.requiresPlan,
    this.iconName,
    this.colorHex,
  });

  factory QuizTopic.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return QuizTopic(
      id: doc.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      category: d['category'] as String? ?? 'general',
      questionCount: (d['questionCount'] as num?)?.toInt() ?? 10,
      durationSeconds: (d['durationSeconds'] as num?)?.toInt() ?? 600,
      isActive: d['isActive'] as bool? ?? true,
      requiresPlan: d['requiresPlan'] as String?,
      iconName: d['iconName'] as String?,
      colorHex: d['colorHex'] as String?,
    );
  }
}
