class QuizQuestion {
  final String id;
  final String text;
  final List<String> options;
  final String level;
  final String source;
  final String? imageUrl;
  final int? correctOptionIndex;
  final String explanation;

  const QuizQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.level,
    required this.source,
    this.imageUrl,
    this.correctOptionIndex,
    this.explanation = '',
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> m) {
    final rawOptions = m['options'];
    final options = rawOptions is List
        ? List<String>.from(rawOptions.map((o) => o.toString()))
        : <String>[];
    final correctLetter = m['correctOption'] as String? ?? '';
    final correctIdx = ['A', 'B', 'C', 'D'].indexOf(correctLetter);
    return QuizQuestion(
      id: m['id'] as String? ?? '',
      text: m['text'] as String? ?? '',
      options: options,
      level: m['level'] as String? ?? 'basic',
      source: m['source'] as String? ?? '',
      imageUrl: m['imageUrl'] as String?,
      correctOptionIndex: correctIdx >= 0 ? correctIdx : null,
      explanation: m['explanation'] as String? ?? '',
    );
  }
}
