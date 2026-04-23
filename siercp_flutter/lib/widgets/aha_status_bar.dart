import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/constants.dart';

class AhaStatusBar extends StatelessWidget {
  final double depthMm;
  final int ratePerMin;
  final bool decompressedFully;

  const AhaStatusBar({
    super.key,
    required this.depthMm,
    required this.ratePerMin,
    required this.decompressedFully,
  });

  @override
  Widget build(BuildContext context) {
    final depthOk = depthMm >= AppConstants.ahaMinDepthMm &&
        depthMm <= AppConstants.ahaMaxDepthMm;
    final rateOk = ratePerMin >= AppConstants.ahaMinRatePerMin &&
        ratePerMin <= AppConstants.ahaMaxRatePerMin;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ESTADO AHA EN TIEMPO REAL',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.08,
            ),
          ),
          const SizedBox(height: 12),
          _AhaRow(
            label: 'Profundidad',
            value: '${depthMm.toStringAsFixed(0)}mm',
            range: '${AppConstants.ahaMinDepthMm.toInt()}–${AppConstants.ahaMaxDepthMm.toInt()}mm',
            progress: depthMm.clamp(0, 80) / 80,
            ok: depthOk,
          ),
          const SizedBox(height: 10),
          _AhaRow(
            label: 'Frecuencia',
            value: '$ratePerMin/min',
            range: '${AppConstants.ahaMinRatePerMin}–${AppConstants.ahaMaxRatePerMin}/min',
            progress: (ratePerMin.clamp(0, 150)) / 150,
            ok: rateOk,
          ),
          const SizedBox(height: 10),
          _AhaRow(
            label: 'Descompresión',
            value: decompressedFully ? 'Completa' : 'Incompleta',
            range: 'Retorno total requerido',
            progress: decompressedFully ? 1.0 : 0.3,
            ok: decompressedFully,
          ),
        ],
      ),
    );
  }
}

class _AhaRow extends StatelessWidget {
  final String label;
  final String value;
  final String range;
  final double progress;
  final bool ok;

  const _AhaRow({
    required this.label,
    required this.value,
    required this.range,
    required this.progress,
    required this.ok,
  });

  Color get _color => ok ? AppColors.green : AppColors.red;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: _color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'SpaceMono',
                ),
              ),
              const SizedBox(width: 4),
              Text(
                range,
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: AppColors.cardBorder,
          valueColor: AlwaysStoppedAnimation(_color),
          minHeight: 4,
        ),
      ),
    ],
  );
}
