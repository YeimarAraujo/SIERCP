import 'package:cloud_firestore/cloud_firestore.dart';

/// Insignia del catálogo (S4). Agrupa skills; se otorga vía Cloud Functions.
class BadgeModel {
  final String id;
  final String name;
  final String description;
  final String tier; // BRONZE | SILVER | GOLD
  final String? imageUrl;
  final String requirementType; // SKILL_SET | COUNT | PATH
  final List<String> requiredSkillIds;
  final int requiredCount;
  final bool active;

  const BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.tier,
    this.imageUrl,
    required this.requirementType,
    this.requiredSkillIds = const [],
    this.requiredCount = 0,
    this.active = true,
  });

  factory BadgeModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final req = (d['requirement'] as Map<String, dynamic>?) ?? const {};
    return BadgeModel(
      id: doc.id,
      name: d['name'] ?? '',
      description: d['description'] ?? '',
      tier: d['tier'] ?? 'BRONZE',
      imageUrl: d['imageUrl'],
      requirementType: req['type'] ?? 'COUNT',
      requiredSkillIds: (req['skillIds'] as List?)?.cast<String>() ?? const [],
      requiredCount: (req['count'] as num?)?.toInt() ?? 0,
      active: d['active'] as bool? ?? true,
    );
  }

  /// Progreso 0..1 dado el conjunto de skillIds ACTIVE del usuario.
  double progress(Set<String> ownedSkillIds) {
    switch (requirementType) {
      case 'SKILL_SET':
        if (requiredSkillIds.isEmpty) return 0;
        final have = requiredSkillIds.where(ownedSkillIds.contains).length;
        return have / requiredSkillIds.length;
      case 'COUNT':
        if (requiredCount <= 0) return 0;
        return (ownedSkillIds.length / requiredCount).clamp(0, 1).toDouble();
      default:
        return 0;
    }
  }

  bool isEarned(Set<String> ownedSkillIds) => progress(ownedSkillIds) >= 1.0;
}
