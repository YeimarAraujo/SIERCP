import 'package:cloud_firestore/cloud_firestore.dart';

/// Ruta de aprendizaje (S4): secuencia de cursos que otorgan un set de skills.
class LearningPath {
  final String id;
  final String name;
  final String description;
  final String level;
  final int estimatedHours;
  final List<String> courseIds;
  final List<String> skillIds; // skills que la ruta otorga
  final String? institutionId;
  final bool active;

  const LearningPath({
    required this.id,
    required this.name,
    required this.description,
    required this.level,
    required this.estimatedHours,
    required this.courseIds,
    required this.skillIds,
    this.institutionId,
    this.active = true,
  });

  factory LearningPath.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LearningPath(
      id: doc.id,
      name: d['name'] ?? '',
      description: d['description'] ?? '',
      level: d['level'] ?? '',
      estimatedHours: (d['estimatedHours'] as num?)?.toInt() ?? 0,
      courseIds: (d['courseIds'] as List?)?.cast<String>() ?? const [],
      skillIds: (d['skillIds'] as List?)?.cast<String>() ?? const [],
      institutionId: d['institutionId'],
      active: d['active'] as bool? ?? true,
    );
  }

  /// Progreso 0..1 según skills ACTIVE obtenidas de las requeridas.
  double progress(Set<String> ownedSkillIds) {
    if (skillIds.isEmpty) return 0;
    final have = skillIds.where(ownedSkillIds.contains).length;
    return have / skillIds.length;
  }

  bool isComplete(Set<String> ownedSkillIds) => progress(ownedSkillIds) >= 1.0;
}
