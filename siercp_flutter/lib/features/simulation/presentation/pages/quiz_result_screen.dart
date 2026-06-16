import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/simulation/data/models/quiz_session.dart';
import 'package:siercp/l10n/app_localizations.dart';
import 'package:siercp/features/simulation/presentation/widgets/result_quiz_dialog_screen.dart';

class QuizResultScreen extends StatefulWidget {
  final String sessionId;
  final QuizSessionResult? result;

  const QuizResultScreen({
    super.key,
    required this.sessionId,
    this.result,
  });

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scoreAnim;
  bool _showReview = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    final score = (widget.result?.score ?? 0) / 100;
    _scoreAnim = Tween<double>(begin: 0, end: score).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();

    final result = widget.result;
    if (result != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
           barrierDismissible: false,
           builder: (_) => EvaluacionResultadoDialog(
             score: result.score,
             xpEarned: result.xpEarned,
             newLevel: result.newLevel,
           ),
         );
       });
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final result = widget.result;

    if (result == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text('Resultado no disponible.',
                  style: TextStyle(color: textS)),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => context.go('/simulation/theoretical'),
                child: const Text('Volver a temas'),
              ),
            ],
          ),
        ),
      );
    }

    final passed = result.passed;
    final scoreColor = passed ? AppColors.green : AppColors.red;
    final scoreStr = result.score.toStringAsFixed(0);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: _showReview
            ? _ReviewPanel(
                result: result,
                onBack: () => setState(() => _showReview = false),
              )
            : Column(
                children: [
                  // ── Top bar ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        Text(
                          loc.quizResultTitle,
                          style: TextStyle(
                            color: textP,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () =>
                              context.go('/simulation/theoretical'),
                          child: const Text('Terminar'),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // ── Score ring ─────────────────────────────────
                          AnimatedBuilder(
                            animation: _scoreAnim,
                            builder: (_, __) => _ScoreRing(
                              progress: _scoreAnim.value,
                              score: scoreStr,
                              passed: passed,
                              color: scoreColor,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Verdict ────────────────────────────────────
                          Text(
                            passed ? loc.quizPassed : loc.quizFailed,
                            style: TextStyle(
                              color: scoreColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            loc.quizMinScore,
                            style: TextStyle(
                                color: textS.withValues(alpha: 0.7),
                                fontSize: 12),
                          ),
                          const SizedBox(height: 24),

                          // ── Stats row ──────────────────────────────────
                          _StatsRow(result: result, loc: loc),
                          const SizedBox(height: 20),

                          // ── XP / Badges ────────────────────────────────
                          if (result.xpEarned > 0) ...[
                            _XpCard(result: result, loc: loc, isDark: isDark),
                            const SizedBox(height: 16),
                          ] else ...[
                            _NoXpHint(isDark: isDark),
                            const SizedBox(height: 16),
                          ],

                          // ── Actions ────────────────────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.list_alt_rounded,
                                      size: 16),
                                  label: Text(loc.quizReviewAnswers),
                                  onPressed: () =>
                                      setState(() => _showReview = true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.refresh_rounded,
                                      size: 16),
                                  label: Text(loc.quizRetry),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brand,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => context
                                      .go('/simulation/theoretical'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final double progress;
  final String score;
  final bool passed;
  final Color color;

  const _ScoreRing({
    required this.progress,
    required this.score,
    required this.passed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 10,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score%',
                style: TextStyle(
                  color: color,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Icon(
                passed
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: color,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final QuizSessionResult result;
  final AppLocalizations loc;
  const _StatsRow({required this.result, required this.loc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    final items = [
      _StatItem(
        label: 'Correctas',
        value: '${result.correct}/${result.total}',
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.green,
      ),
      _StatItem(
        label: 'Incorrectas',
        value: '${result.total - result.correct}',
        icon: Icons.cancel_outlined,
        color: AppColors.red,
      ),
    ];

    return Row(
      children: items
          .map((item) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                      right: item == items.first ? 8 : 0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border.all(color: border, width: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: isDark ? null : AppShadows.card(false),
                  ),
                  child: Column(
                    children: [
                      Icon(item.icon, color: item.color, size: 22),
                      const SizedBox(height: 6),
                      Text(
                        item.value,
                        style: TextStyle(
                          color: item.color,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatItem(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
}

class _XpCard extends StatelessWidget {
  final QuizSessionResult result;
  final AppLocalizations loc;
  final bool isDark;
  const _XpCard(
      {required this.result, required this.loc, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: isDark ? 0.12 : 0.06),
        border: Border.all(
            color: AppColors.brand.withValues(alpha: isDark ? 0.3 : 0.15),
            width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded,
                  color: AppColors.brand, size: 18),
              const SizedBox(width: 6),
              Text(
                loc.quizXpEarned(result.xpEarned),
                style: const TextStyle(
                  color: AppColors.brand,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (result.newLevel != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    loc.quizLevelUp(result.newLevel!),
                    style: const TextStyle(
                      color: AppColors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (result.newBadges.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: result.newBadges
                  .map((b) => _BadgeChip(badgeId: b))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoXpHint extends StatelessWidget {
  final bool isDark;
  const _NoXpHint({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: isDark ? 0.12 : 0.06),
        border: Border.all(
          color: AppColors.red.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: AppColors.red.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Text(
            'Necesitas ≥70% para ganar XP',
            style: TextStyle(
              color: AppColors.red.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String badgeId;
  const _BadgeChip({required this.badgeId});

  String _label() {
    switch (badgeId) {
      case 'first_quiz':
        return '🎯 Primera evaluación';
      case 'quiz_perfect':
        return '⭐ Puntaje perfecto';
      case 'quiz_master':
        return '🏆 Quiz Master';
      case 'all_topics':
        return '📚 Todos los temas';
      default:
        return '🏅 $badgeId';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.amber.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        _label(),
        style:
            const TextStyle(color: AppColors.amber, fontSize: 10),
      ),
    );
  }
}

// ── Review panel ─────────────────────────────────────────────────────────────

class _ReviewPanel extends StatelessWidget {
  final QuizSessionResult result;
  final VoidCallback onBack;
  const _ReviewPanel({required this.result, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: textP),
              ),
              const SizedBox(width: 12),
              Text(
                'Revisión de respuestas',
                style: TextStyle(
                    color: textP,
                    fontSize: 17,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            itemCount: result.results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) =>
                _ReviewCard(item: result.results[i], index: i),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final QuestionResult item;
  final int index;
  const _ReviewCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final cardBg = theme.colorScheme.surface;
    final correct = item.correct;
    final color = correct ? AppColors.green : AppColors.red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(
            color: color.withValues(alpha: isDark ? 0.4 : 0.25),
            width: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: isDark ? null : AppShadows.card(false),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Pregunta ${index + 1}',
                style: TextStyle(
                    color: textP,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  correct ? 'Correcta' : 'Incorrecta',
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (item.correctOption.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 13, color: AppColors.green),
                const SizedBox(width: 6),
                Text(
                  'Respuesta correcta: ${item.correctOption}',
                  style: const TextStyle(
                      color: AppColors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          if (item.explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.explanation,
              style: TextStyle(color: textS, fontSize: 11, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}
