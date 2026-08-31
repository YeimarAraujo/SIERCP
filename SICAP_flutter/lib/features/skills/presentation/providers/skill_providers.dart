import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/user_skill.dart';
import '../../data/models/badge.dart';
import '../../data/models/learning_path.dart';
import '../../data/skill_service.dart';

final skillServiceProvider = Provider<SkillService>((_) => SkillService());

/// Rutas de aprendizaje visibles para el usuario (plataforma + su institución).
final learningPathsProvider = StreamProvider<List<LearningPath>>((ref) {
  return FirebaseFirestore.instance
      .collection('learningPaths')
      .where('active', isEqualTo: true)
      .snapshots()
      .map((snap) => snap.docs.map(LearningPath.fromFirestore).toList());
});

/// Entrada de ranking (proyección leaderboards/{institutionId}/students).
class RankingEntry {
  final String uid;
  final String displayName;
  final num averageScore;
  final int skillsCount;
  const RankingEntry(this.uid, this.displayName, this.averageScore, this.skillsCount);
}

/// Ranking de la institución del usuario, ordenado por score promedio.
final institutionRankingProvider = StreamProvider<List<RankingEntry>>((ref) {
  final user = ref.watch(currentUserProvider);
  final institutionId = user?.institutionId ?? '';
  if (institutionId.isEmpty) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection('leaderboards')
      .doc(institutionId)
      .collection('students')
      .orderBy('averageScore', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs.map((d) {
            final m = d.data();
            return RankingEntry(
              d.id,
              (m['displayName'] as String?) ?? 'Usuario',
              (m['averageScore'] as num?) ?? 0,
              (m['skillsCount'] as num?)?.toInt() ?? 0,
            );
          }).toList());
});

/// Estado del perfil público del usuario: { publicProfile, publicSlug }.
final publicProfileProvider = StreamProvider<({bool enabled, String slug})>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value((enabled: false, slug: ''));
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.id)
      .snapshots()
      .map((d) => (
            enabled: (d.data()?['publicProfile'] as bool?) ?? false,
            slug: (d.data()?['publicSlug'] as String?) ?? '',
          ));
});

/// Skills ACTIVE del usuario actual (Skill Wallet · S2).
/// Solo lectura — las skills las otorga el Competency Engine (Cloud Functions).
final userSkillsStreamProvider = StreamProvider<List<UserSkill>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);

  return FirebaseFirestore.instance
      .collection('userSkills')
      .where('userId', isEqualTo: user.id)
      .where('status', isEqualTo: 'ACTIVE')
      .orderBy('issuedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(UserSkill.fromFirestore).toList());
});

/// IDs de skills ACTIVE del usuario (para calcular progreso de badges).
final ownedSkillIdsProvider = Provider<Set<String>>((ref) {
  final skills = ref.watch(userSkillsStreamProvider).valueOrNull ?? const [];
  return skills.map((s) => s.skillId).toSet();
});

/// Catálogo de badges activos.
final badgesCatalogProvider = StreamProvider<List<BadgeModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('badges')
      .where('active', isEqualTo: true)
      .snapshots()
      .map((snap) => snap.docs.map(BadgeModel.fromFirestore).toList());
});

/// Badges separados en obtenidos / bloqueados, con progreso calculado.
typedef BadgesView = ({List<BadgeModel> earned, List<BadgeModel> locked});

final badgesViewProvider = Provider<AsyncValue<BadgesView>>((ref) {
  final catalog = ref.watch(badgesCatalogProvider);
  final owned = ref.watch(ownedSkillIdsProvider);
  return catalog.whenData((badges) {
    final earned = badges.where((b) => b.isEarned(owned)).toList();
    final locked = badges.where((b) => !b.isEarned(owned)).toList()
      ..sort((a, b) => b.progress(owned).compareTo(a.progress(owned)));
    return (earned: earned, locked: locked);
  });
});
