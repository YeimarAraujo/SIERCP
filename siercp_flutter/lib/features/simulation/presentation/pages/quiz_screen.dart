import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/simulation/data/models/quiz_question.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/simulation/data/simulation_service.dart';
import 'package:siercp/l10n/app_localizations.dart';

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
  // questionId → selected option index (0-3)
  final Map<String, int> _selected = {};

  late int _secondsLeft;
  Timer? _timer;

  static const _optionLabels = ['A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final service = ref.read(simulationServiceProvider);
      final questions = await service.loadQuestions(topicId: widget.topicId);
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
        // durationSeconds is stored in the topic; default 10 min
        _secondsLeft = 10 * 60;
      });
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        _forceSubmit();
      }
    });
  }

  void _forceSubmit() {
    final questions = _questions;
    if (questions == null) return;
    // Auto-fill unanswered with -1 (server will mark wrong)
    _submit(forced: true);
  }

  Future<void> _submit({bool forced = false}) async {
    final questions = _questions;
    if (questions == null) return;
    final loc = AppLocalizations.of(context)!;

    // Validate all answered unless forced
    if (!forced && _selected.length < questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(loc.quizAnswerAll,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onInverseSurface)),
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
      ));
      return;
    }

    _timer?.cancel();
    setState(() => _submitting = true);

    try {
      final service = ref.read(simulationServiceProvider);
      // Build answers map: questionId → option letter
      final answers = <String, String>{};
      for (final q in questions) {
        final idx = _selected[q.id];
        if (idx != null && idx >= 0 && idx < _optionLabels.length) {
          answers[q.id] = _optionLabels[idx];
        }
      }

      final userId = ref.read(currentUserProvider)?.id ?? '';
      final result = await service.submitAnswers(
        topicId: widget.topicId,
        userId:  userId,
        answers: answers,
      );

      if (!mounted) return;
      context.pushReplacement(
        '/simulation/theoretical/result/${result.sessionId}',
        extra: result,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.quizErrorSubmit,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onInverseSurface)),
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
      ));
    }
  }

  String get _timerDisplay {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color _timerColor(BuildContext context) {
    if (_secondsLeft <= 60) return AppColors.red;
    if (_secondsLeft <= 180) return AppColors.amber;
    return AppColors.brand;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.brand),
              const SizedBox(height: 16),
              Text(loc.quizLoading, style: TextStyle(color: textS)),
            ],
          ),
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
                Text(loc.quizErrorLoad,
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
    final total = questions.length;
    final current = _currentIndex;
    final q = questions[current];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('¿Abandonar evaluación?'),
            content:
                const Text('Se perderá tu progreso en esta evaluación.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Continuar')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Abandonar',
                      style: TextStyle(color: AppColors.red))),
            ],
          ),
        );
        if (confirmed == true && mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              _QuizHeader(
                current: current + 1,
                total: total,
                timerDisplay: _timerDisplay,
                timerColor: _timerColor(context),
                onClose: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('¿Abandonar evaluación?'),
                      content: const Text(
                          'Se perderá tu progreso en esta evaluación.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Continuar')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Abandonar',
                                style: TextStyle(color: AppColors.red))),
                      ],
                    ),
                  );
                  if (confirmed == true && mounted) context.pop();
                },
              ),

              // ── Progress bar ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (current + 1) / total,
                    minHeight: 4,
                    backgroundColor:
                        AppColors.brand.withValues(alpha: 0.1),
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.brand),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Question ─────────────────────────────────────────────────
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

                      // Question text
                      Text(
                        q.text,
                        style: TextStyle(
                          color: textP,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Source
                      Text(
                        q.source,
                        style: TextStyle(
                            color: textS.withValues(alpha: 0.6),
                            fontSize: 10),
                      ),
                      const SizedBox(height: 20),

                      // Options
                      ...List.generate(q.options.length, (i) {
                        final selected = _selected[q.id] == i;
                        return _OptionTile(
                          label: _optionLabels[i],
                          text: q.options[i],
                          selected: selected,
                          onTap: () =>
                              setState(() => _selected[q.id] = i),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ── Navigation ───────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    if (current > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              setState(() => _currentIndex--),
                          child: const Text('Anterior'),
                        ),
                      ),
                    if (current > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: current < total - 1
                          ? ElevatedButton(
                              onPressed: () =>
                                  setState(() => _currentIndex++),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Siguiente'),
                            )
                          : ElevatedButton(
                              onPressed: _submitting ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor: Colors.white,
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : Text(loc.quizSubmit),
                            ),
                    ),
                  ],
                ),
              ),

              // Answered counter
              Padding(
                padding:
                    const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${_selected.length} de $total respondidas',
                  style: TextStyle(
                      color: textS.withValues(alpha: 0.6),
                      fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizHeader extends StatelessWidget {
  final int current;
  final int total;
  final String timerDisplay;
  final Color timerColor;
  final VoidCallback onClose;

  const _QuizHeader({
    required this.current,
    required this.total,
    required this.timerDisplay,
    required this.timerColor,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final textP = Theme.of(context).textTheme.bodyLarge?.color ??
        AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onClose,
            child: Icon(Icons.close_rounded,
                size: 22,
                color: Theme.of(context).textTheme.bodySmall?.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loc.quizQuestionLabel(current, total),
              style: TextStyle(
                  color: textP,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
          ),
          // Timer
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: timerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 13, color: timerColor),
                const SizedBox(width: 4),
                Text(
                  timerDisplay,
                  style: TextStyle(
                    color: timerColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final border = theme.colorScheme.outline;
    final cardBg = theme.colorScheme.surface;

    final borderColor =
        selected ? AppColors.brand : border.withValues(alpha: 0.5);
    final bgColor = selected
        ? AppColors.brand.withValues(alpha: isDark ? 0.15 : 0.06)
        : cardBg;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
              color: borderColor, width: selected ? 1.5 : 0.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.brand
                    : AppColors.brand.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.brand,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: textP,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.brand, size: 18),
          ],
        ),
      ),
    );
  }
}
