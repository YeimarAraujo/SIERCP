import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/features/simulation/data/models/quiz_topic.dart';
import 'package:siercp/features/simulation/data/models/quiz_question.dart';
import 'package:siercp/features/simulation/data/models/quiz_session.dart';

class SimulationService {
  final FirebaseFirestore _db;
  final FirebaseFunctions _fn;

  SimulationService({FirebaseFirestore? db, FirebaseFunctions? fn})
      : _db = db ?? FirebaseFirestore.instance,
        _fn = fn ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Stream<List<QuizTopic>> watchTopics() {
    return _db
        .collection('quizTopics')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(QuizTopic.fromFirestore).toList());
  }

  Future<List<QuizQuestion>> loadQuestions({
    required String topicId,
    int limit = 10,
  }) async {
    final result = await _fn.httpsCallable('getQuizQuestions').call({
      'topicId': topicId,
      'limit': limit,
    });
    final data = result.data as Map<String, dynamic>;
    final raw = data['questions'] as List? ?? [];
    return raw
        .map((q) => QuizQuestion.fromMap(q as Map<String, dynamic>))
        .toList();
  }

  Future<QuizSessionResult> submitAnswers({
    required String topicId,
    required Map<String, String> answers, // questionId → selectedOption (A/B/C/D)
  }) async {
    final payload = answers.entries
        .map((e) => {'questionId': e.key, 'selectedOption': e.value})
        .toList();

    final result = await _fn.httpsCallable('submitQuizAnswers').call({
      'topicId': topicId,
      'answers': payload,
    });

    return QuizSessionResult.fromMap(
        result.data as Map<String, dynamic>);
  }

  Stream<Map<String, dynamic>> watchUserStats(String userId) {
    return _db
        .collection('userStats')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }
}

final simulationServiceProvider = Provider<SimulationService>(
  (_) => SimulationService(),
);

final quizTopicsProvider = StreamProvider<List<QuizTopic>>((ref) {
  return ref.watch(simulationServiceProvider).watchTopics();
});

final userStatsProvider = StreamProvider.family<Map<String, dynamic>, String>(
  (ref, userId) =>
      ref.watch(simulationServiceProvider).watchUserStats(userId),
);
