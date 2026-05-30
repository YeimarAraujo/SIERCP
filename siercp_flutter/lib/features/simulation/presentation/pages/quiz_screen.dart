import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/simulation/data/models/quiz_question.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/simulation/data/simulation_service.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final String topicId;
  const QuizScreen({super.key, required this.topicId});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  List<QuizQuestion>? _questions;
  String? _loadError;
  bool _loading = true;
  bool _submitting = false;

  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _answered = false;
  final Map<String, int> _answers = {};

  static const _optionLabels = ['A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final qs = await ref.read(simulationServiceProvider)
          .loadQuestions(topicId: widget.topicId);
      if (!mounted) return;
      setState(() { _questions = qs; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadError = e.toString(); _loading = false; });
    }
  }

  void _selectAnswer(int idx) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = idx;
      _answered = true;
      _answers[_questions![_currentIndex].id] = idx;
    });
  }

  Future<void> _next() async {
    final questions = _questions!;
    if (_currentIndex < questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _answered = false;
      });
    } else {
      await _submit();
    }
  }

  Future<void> _submit() async {
    final messenger       = ScaffoldMessenger.of(context);
    final inverseSurface  = Theme.of(context).colorScheme.inverseSurface;
    final router          = GoRouter.of(context);
    setState(() => _submitting = true);
    try {
      final service = ref.read(simulationServiceProvider);
      final answersMap = <String, String>{};
      for (final e in _answers.entries) {
        if (e.value >= 0 && e.value < _optionLabels.length) {
          answersMap[e.key] = _optionLabels[e.value];
        }
      }
      final userId = ref.read(currentUserProvider)?.id ?? '';
      final result = await service.submitAnswers(
        topicId: widget.topicId,
        userId:  userId,
        answers: answersMap,
      );
      if (!mounted) return;
      context.pushReplacement(
        '/simulation/theoretical/result/${result.sessionId}',
        extra: result,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Error al enviar. Intenta de nuevo.'),
          backgroundColor: inverseSurface,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP  = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS  = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Text('Error al cargar la evaluación.',
                    style: TextStyle(color: textS),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadQuestions,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final questions = _questions!;
    final total     = questions.length;
    final q         = questions[_currentIndex];
    final progress  = (_currentIndex + (_answered ? 1 : 0)) / total;
    final isLast    = _currentIndex == total - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final router    = GoRouter.of(context);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('¿Abandonar evaluación?'),
            content: const Text('Se perderá tu progreso.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Continuar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Abandonar',
                    style: TextStyle(color: AppColors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true && mounted) router.pop();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 20, color: textS),
                      onPressed: () async {
                        final router    = GoRouter.of(context);
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('¿Abandonar evaluación?'),
                            content: const Text('Se perderá tu progreso.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Continuar'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Abandonar',
                                    style: TextStyle(color: AppColors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && mounted) router.pop();
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Evaluación Teórica',
                            style: TextStyle(
                                color: textP,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Pregunta ${_currentIndex + 1} de $total',
                            style: TextStyle(color: textS, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    // Score chip
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_answers.length}/$total',
                        style: const TextStyle(
                          color: AppColors.brand,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Progress bar ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.brand.withValues(alpha: 0.12),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.brand),
                    minHeight: 4,
                  ),
                ),
              ),
              // ── Question badge + text ─────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Level badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          q.level.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.brand,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        q.text,
                        style: TextStyle(
                          color: textP,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      if (q.source.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          q.source,
                          style: TextStyle(
                              color: textS.withValues(alpha: 0.5),
                              fontSize: 10),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // ── Options ───────────────────────────────────────────
                      ...List.generate(q.options.length, (i) {
                        final isSelected = _selectedAnswer == i;
                        final isCorrect  = i == q.correctOptionIndex;
                        final letter     = _optionLabels[i];

                        Color? bg;
                        Color border;
                        Color textColor = textP;
                        IconData? trailingIcon;

                        if (_answered) {
                          if (isCorrect) {
                            bg         = const Color(0xFF059669).withValues(alpha: 0.1);
                            border     = const Color(0xFF059669).withValues(alpha: 0.5);
                            textColor  = const Color(0xFF059669);
                            trailingIcon = Icons.check_circle_outline_rounded;
                          } else if (isSelected) {
                            bg         = AppColors.red.withValues(alpha: 0.08);
                            border     = AppColors.red.withValues(alpha: 0.4);
                            textColor  = AppColors.red;
                            trailingIcon = Icons.cancel_outlined;
                          } else {
                            bg        = null;
                            border    = theme.colorScheme.outline.withValues(alpha: 0.15);
                            textColor = textS.withValues(alpha: 0.5);
                          }
                        } else {
                          bg     = null;
                          border = theme.colorScheme.outline.withValues(alpha: 0.3);
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(
                            onTap: () => _selectAnswer(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 13),
                              decoration: BoxDecoration(
                                color: bg ?? theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: border,
                                  width: isSelected && _answered ? 1.5 : 0.8,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: _answered
                                          ? textColor.withValues(alpha: 0.12)
                                          : theme.colorScheme.outline
                                              .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        letter,
                                        style: TextStyle(
                                          color: _answered
                                              ? textColor
                                              : textS.withValues(alpha: 0.6),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      q.options[i],
                                      style: TextStyle(
                                          color: textColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          height: 1.35),
                                    ),
                                  ),
                                  if (trailingIcon != null) ...[
                                    const SizedBox(width: 8),
                                    Icon(trailingIcon,
                                        size: 18, color: textColor),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      // ── Explanation ───────────────────────────────────────
                      if (_answered && q.explanation.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: theme.colorScheme.outline
                                    .withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.lightbulb_outline_rounded,
                                      size: 14, color: AppColors.amber),
                                  SizedBox(width: 7),
                                  Text(
                                    'Explicación',
                                    style: TextStyle(
                                      color: AppColors.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                q.explanation,
                                style: TextStyle(
                                    color: textS, fontSize: 12, height: 1.55),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              // ── Continue button ───────────────────────────────────────────
              if (_answered)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isLast
                                  ? 'Finalizar evaluación'
                                  : 'Siguiente pregunta',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
