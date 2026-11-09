import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/features/session/data/models/session.dart';
import 'package:siercp/features/session/presentation/providers/session_provider.dart';
import 'package:siercp/features/home/data/daily_missions.dart';
import 'package:siercp/core/services/firestore_service.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';

final todayMissionProvider = Provider<Mission>((ref) {
  final now = DateTime.now();
  final seed = now.year * 10000 + now.month * 100 + now.day;
  final index = Random(seed).nextInt(missionCatalogue.length);
  return missionCatalogue[index];
});

final missionCompletedProvider = FutureProvider<bool>((ref) async {
  final mission = ref.watch(todayMissionProvider);
  final sessionsAsync = ref.watch(sessionsHistoryProvider);
  final sessions = sessionsAsync.valueOrNull ?? [];
  if (sessions.isEmpty) return false;

  final today = DateTime.now();
  final todaySessions = sessions.where((s) =>
      s.status == SessionStatus.completed &&
      s.metrics != null &&
      s.startedAt.year == today.year &&
      s.startedAt.month == today.month &&
      s.startedAt.day == today.day);

  return todaySessions.any((s) => mission.condition(s.metrics!));
});

final missionXpClaimedProvider = StateProvider<bool>((ref) => false);

Future<void> claimMissionXp(WidgetRef ref) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return;

  final mission = ref.read(todayMissionProvider);
  final completed = await ref.read(missionCompletedProvider.future);
  if (!completed) return;

  final claimed = ref.read(missionXpClaimedProvider);
  if (claimed) return;

  final db = ref.read(firestoreServiceProvider);
  await db.addXpTransaction(user.id, mission.xpReward, 'Misión: ${mission.title}');
  ref.read(missionXpClaimedProvider.notifier).state = true;
}
