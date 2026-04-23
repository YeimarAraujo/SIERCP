import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/alert_course.dart';

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
      case MetricStatus.ok: return AppColors.green;
      case MetricStatus.warning: return AppColors.amber;
      case MetricStatus.error: return AppColors.red;
      case MetricStatus.neutral: return AppColors.textPrimary;
    }
  }

  Color get _borderColor {
    switch (status) {
      case MetricStatus.ok: return AppColors.green.withValues(alpha: 0.3);
      case MetricStatus.warning: return AppColors.amber.withValues(alpha: 0.3);
      case MetricStatus.error: return AppColors.red.withValues(alpha: 0.3);
      case MetricStatus.neutral: return AppColors.cardBorder;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: _borderColor, width: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.07,
            ),
          ),
          const Spacer(),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: _color,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'SpaceMono',
                  ),
                ),
                if (suffix.isNotEmpty)
                  TextSpan(
                    text: suffix,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontFamily: 'SpaceMono',
                    ),
                  ),
              ],
            ),
          ),
          if (hint != null)
            Text(
              hint!,
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 9),
            ),
        ],
      ),
    );
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
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  alert.message,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _timeAgo(alert.timestamp),
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
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
    style: const TextStyle(
      color: AppColors.textTertiary,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.08,
    ),
  );
}

