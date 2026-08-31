import 'package:cloud_firestore/cloud_firestore.dart';

/// Skill verificada en la cartera del usuario (Skill Wallet · S2).
/// Documento de solo lectura para el cliente: lo escribe únicamente el
/// Competency Intelligence Engine (Cloud Functions).
class UserSkill {
  final String id;
  final String skillId;
  final String skillName;
  final String skillCode; // SK-2026-000125
  final String level; // BASICO | INTERMEDIO | AVANZADO | PROFESIONAL
  final int levelOrder;
  final String issuedByName;
  final num bestScore;
  final String status; // ACTIVE | REVOKED
  final DateTime? issuedAt;

  const UserSkill({
    required this.id,
    required this.skillId,
    required this.skillName,
    required this.skillCode,
    required this.level,
    required this.levelOrder,
    required this.issuedByName,
    required this.bestScore,
    required this.status,
    this.issuedAt,
  });

  bool get isActive => status == 'ACTIVE';

  String get levelLabel => switch (level) {
        'BASICO' => 'Básico',
        'INTERMEDIO' => 'Intermedio',
        'AVANZADO' => 'Avanzado',
        'PROFESIONAL' => 'Profesional',
        _ => level,
      };

  factory UserSkill.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserSkill(
      id: doc.id,
      skillId: d['skillId'] ?? '',
      skillName: d['skillName'] ?? '',
      skillCode: d['skillCode'] ?? '',
      level: d['level'] ?? 'BASICO',
      levelOrder: (d['levelOrder'] as num?)?.toInt() ?? 1,
      issuedByName: d['issuedByName'] ?? 'SIERCP',
      bestScore: (d['bestScore'] as num?) ?? 0,
      status: d['status'] ?? 'ACTIVE',
      issuedAt: (d['issuedAt'] as Timestamp?)?.toDate(),
    );
  }
}
