import 'package:flutter/material.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/courses/data/models/alert_course.dart';

// ─── MetricCard ────────────────────────────────────────────────────────────────
enum MetricStatus { ok, warning, error, neutral }

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final MetricStatus status;
  final String? hint;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.suffix,
    this.status = MetricStatus.neutral,
    this.hint,
  });

  Color get _color {
    switch (status) {
      case MetricStatus.ok:
        return AppColors.green;
      case MetricStatus.warning:
        return AppColors.amber;
      case MetricStatus.error:
        return AppColors.red;
      case MetricStatus.neutral:
        return const Color(0xFF00D4FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg2 : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _color.withValues(alpha: isDark ? 0.2 : 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _color.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getStatusIcon(), size: 12, color: _color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  fontFamily: 'SpaceMono',
                ),
              ),
              Text(
                suffix,
                style: TextStyle(
                  color: _color.withValues(alpha: 0.8),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (status) {
      case MetricStatus.ok:
        return Icons.check_circle_outline;
      case MetricStatus.warning:
        return Icons.warning_amber_rounded;
      case MetricStatus.error:
        return Icons.error_outline_rounded;
      case MetricStatus.neutral:
        return Icons.analytics_outlined;
    }
  }
}

// ─── AlertCard ─────────────────────────────────────────────────────────────────
class AlertCard extends StatelessWidget {
  final AlertModel alert;
  const AlertCard({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: alert.bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(alert.icon, color: alert.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  alert.message,
                  style: TextStyle(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.7),
                      fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _timeAgo(alert.timestamp),
            style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: 0.5),
                fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ─── SectionLabel ──────────────────────────────────────────────────────────────
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context)
              .textTheme
              .bodySmall
              ?.color
              ?.withValues(alpha: 0.6),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.08,
        ),
      );
}
