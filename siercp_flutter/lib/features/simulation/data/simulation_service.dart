import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/features/simulation/data/models/quiz_topic.dart';
import 'package:siercp/features/simulation/data/models/quiz_question.dart';
import 'package:siercp/features/simulation/data/models/quiz_session.dart';

/// Implementación sin Cloud Functions — usa Firestore directamente.
/// - loadQuestions: lee de `quizQuestions`, baraja y devuelve SIN correctOption/explanation.
/// - submitAnswers: relee con correctOption (solo para validar), calcula score,
///   escribe `quizSessions` y actualiza `userStats` vía transacción Firestore.
class SimulationService {
  final FirebaseFirestore _db;

  SimulationService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── Colecciones ──────────────────────────────────────────────────────────────
  CollectionReference get _topics    => _db.collection(AppConstants.colQuizTopics);
  CollectionReference get _questions => _db.collection(AppConstants.colQuizQuestions);
  CollectionReference get _sessions  => _db.collection(AppConstants.colQuizSessions);
  CollectionReference get _stats     => _db.collection(AppConstants.colUserStats);

  // ── Topics ───────────────────────────────────────────────────────────────────

  Stream<List<QuizTopic>> watchTopics() {
    return _topics
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(QuizTopic.fromFirestore).toList());
  }

  // ── Questions ────────────────────────────────────────────────────────────────

  Future<List<QuizQuestion>> loadQuestions({
    required String topicId,
    int limit = 10,
  }) async {
    final snap = await _questions
        .where('topicId', isEqualTo: topicId)
        .where('isActive', isEqualTo: true)
        .get();

    if (snap.docs.isEmpty) return [];

    // Barajar y limitar, igual que la Cloud Function
    final all = snap.docs.toList()..shuffle(Random());
    final selected = all.take(limit).toList();

    return selected.map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      // Extraer sólo el texto de las opciones — el ID (A/B/C/D) no se expone en UI.
      final rawOpts = d['options'] as List? ?? [];
      final optTexts = rawOpts.map<String>((o) {
        if (o is Map) return (o['text'] ?? '').toString();
        return o.toString();
      }).toList();

      return QuizQuestion(
        id: doc.id,
        text: d['text'] as String? ?? '',
        options: optTexts,
        level: d['level'] as String? ?? 'basico',
        source: d['source'] as String? ?? '',
        imageUrl: d['imageUrl'] as String?,
      );
    }).toList();
  }

  // ── Submit & validate ─────────────────────────────────────────────────────────

  Future<QuizSessionResult> submitAnswers({
    required String topicId,
    required String userId,
    required Map<String, String> answers, // questionId → selectedOption ('A'/'B'/'C'/'D')
  }) async {
    // 1. Leer preguntas CON correctOption para validar (solo en el cliente, no en UI)
    final snap = await _questions
        .where('topicId', isEqualTo: topicId)
        .where('isActive', isEqualTo: true)
        .get();

    final questionMap = {
      for (final doc in snap.docs)
        doc.id: doc.data() as Map<String, dynamic>
    };

    // 2. Calcular resultados
    int correct = 0;
    final results = <QuestionResult>[];

    for (final entry in answers.entries) {
      final qId      = entry.key;
      final selected = entry.value;
      final qData    = questionMap[qId];
      if (qData == null) continue;

      final correctOpt  = qData['correctOption'] as String? ?? '';
      final isCorrect   = selected == correctOpt;
      final explanation = qData['explanation'] as String? ?? '';

      if (isCorrect) correct++;

      results.add(QuestionResult(
        questionId:    qId,
        correct:       isCorrect,
        correctOption: correctOpt,
        explanation:   explanation,
      ));
    }

    final total   = answers.length;
    final score   = total > 0 ? (correct / total * 100).roundToDouble() : 0.0;
    final passed  = score >= 70.0;

    // XP: 20 base si aprueba, +30 si perfecto
    final xpEarned = !passed ? 0 : (score == 100.0 ? 50 : 20);

    // 3. Guardar sesión de quiz en Firestore
    final sessionRef = _sessions.doc();
    final sessionId  = sessionRef.id;

    await sessionRef.set({
      'sessionId':   sessionId,
      'userId':      userId,
      'topicId':     topicId,
      'type':        'theoretical',
      'score':       score,
      'passed':      passed,
      'correct':     correct,
      'total':       total,
      'xpEarned':    xpEarned,
      'completedAt': FieldValue.serverTimestamp(),
    });

    // 4. Actualizar userStats en transacción atómica (XP + nivel)
    if (xpEarned > 0) {
      final statsRef = _stats.doc(userId);
      await _db.runTransaction((tx) async {
        final snap   = await tx.get(statsRef);
        final data   = snap.data() as Map<String, dynamic>? ?? {};
        final newXp  = ((data['xp'] as int?) ?? 0) + xpEarned;
        final newLvl = _calcLevel(newXp);
        tx.set(statsRef, {
          'xp':               newXp,
          'level':            newLvl,
          'quizzesCompleted': FieldValue.increment(1),
          'updatedAt':        FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }).catchError((_) => null);
    }

    return QuizSessionResult(
      sessionId:  sessionId,
      score:      score,
      passed:     passed,
      correct:    correct,
      total:      total,
      xpEarned:   xpEarned,
      newLevel:   null,
      newBadges:  const [],
      results:    results,
    );
  }

  // ── User stats ────────────────────────────────────────────────────────────────

  Stream<Map<String, dynamic>> watchUserStats(String userId) {
    return _stats
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data() as Map<String, dynamic>? ?? {});
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static const _xpThresholds = [0, 100, 300, 600, 1000, 1500, 2200, 3000, 4000, 5500];

  static int _calcLevel(int xp) =>
      _xpThresholds.where((t) => xp >= t).length;
}

// ── Providers ─────────────────────────────────────────────────────────────────

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
