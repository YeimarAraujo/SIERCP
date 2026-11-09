class QuestionResult {
  final String questionId;
  final bool correct;
  final String correctOption;
  final String explanation;

  const QuestionResult({
    required this.questionId,
    required this.correct,
    required this.correctOption,
    required this.explanation,
  });

  factory QuestionResult.fromMap(Map<String, dynamic> m) => QuestionResult(
        questionId: m['questionId'] as String? ?? '',
        correct: m['correct'] as bool? ?? false,
        correctOption: m['correctOption'] as String? ?? '',
        explanation: m['explanation'] as String? ?? '',
      );
}

class QuizSessionResult {
  final String sessionId;
  final double score;
  final bool passed;
  final int correct;
  final int total;
  final int xpEarned;
  final int? newLevel;
  final List<String> newBadges;
  final List<QuestionResult> results;

  const QuizSessionResult({
    required this.sessionId,
    required this.score,
    required this.passed,
    required this.correct,
    required this.total,
    required this.xpEarned,
    this.newLevel,
    required this.newBadges,
    required this.results,
  });

  factory QuizSessionResult.fromMap(Map<String, dynamic> m) {
    final rawResults = m['results'] as List? ?? [];
    final rawBadges = m['newBadges'] as List? ?? [];
    return QuizSessionResult(
      sessionId: m['sessionId'] as String? ?? '',
      score: (m['score'] as num?)?.toDouble() ?? 0,
      passed: m['passed'] as bool? ?? false,
      correct: (m['correct'] as num?)?.toInt() ?? 0,
      total: (m['total'] as num?)?.toInt() ?? 0,
      xpEarned: (m['xpEarned'] as num?)?.toInt() ?? 0,
      newLevel: (m['newLevel'] as num?)?.toInt(),
      newBadges: List<String>.from(rawBadges.map((b) => b.toString())),
      results: rawResults
          .map((r) => QuestionResult.fromMap(r as Map<String, dynamic>))
          .toList(),
    );
  }
}
