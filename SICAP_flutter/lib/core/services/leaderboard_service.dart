import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LeaderboardService {
  final FirebaseFirestore _db;

  LeaderboardService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Future<void> updateEntry({
    required String uid,
    required String institutionId,
    required String displayName,
    required double averageScore,
    required int totalSessions,
  }) async {
    final trend = averageScore >= 85
        ? 'up'
        : averageScore >= 70
            ? 'minus'
            : 'down';

    await _db
        .doc('leaderboards/$institutionId/students/$uid')
        .set({
      'uid': uid,
      'displayName': displayName,
      'averageScore': averageScore.round(),
      'totalSessions': totalSessions,
      'trend': trend,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

final leaderboardServiceProvider = Provider<LeaderboardService>((ref) {
  return LeaderboardService();
});
