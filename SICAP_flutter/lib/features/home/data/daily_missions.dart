import 'package:flutter/material.dart';
import 'package:siercp/features/session/data/models/session.dart';

enum MissionCategory { quality, consistency, technique, streak }

class Mission {
  final String id;
  final String title;
  final String description;
  final IconData iconData;
  final MissionCategory category;
  final int xpReward;
  final bool Function(SessionMetrics metrics) condition;
  final String progressLabel;

  const Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.iconData,
    required this.category,
    required this.xpReward,
    required this.condition,
    required this.progressLabel,
  });
}

final List<Mission> missionCatalogue = [
  Mission(
    id: 'perfect_depth',
    title: 'Profundidad perfecta',
    description: 'Completa una sesión con profundidad promedio entre 50–60 mm.',
    iconData: Icons.straighten,
    category: MissionCategory.quality,
    xpReward: 50,
    condition: (m) =>
        m.averageDepthMm >= 50 && m.averageDepthMm <= 60 && m.totalCompressions >= 30,
    progressLabel: '50–60 mm',
  ),
  Mission(
    id: 'perfect_rate',
    title: 'Ritmo ideal',
    description: 'Mantén una frecuencia de 100–120 compresiones por minuto.',
    iconData: Icons.speed,
    category: MissionCategory.quality,
    xpReward: 50,
    condition: (m) =>
        m.averageRatePerMin >= 100 && m.averageRatePerMin <= 120 && m.totalCompressions >= 30,
    progressLabel: '100–120/min',
  ),
  Mission(
    id: 'high_score',
    title: 'Puntuación de experto',
    description: 'Alcanza una puntuación ≥ 85 % en una sesión.',
    iconData: Icons.emoji_events_rounded,
    category: MissionCategory.quality,
    xpReward: 75,
    condition: (m) => m.score >= 85,
    progressLabel: '≥ 85 %',
  ),
  Mission(
    id: 'perfect_recoil',
    title: 'Descompresión completa',
    description: 'Logra ≥ 90 % de compresiones con descompresión completa.',
    iconData: Icons.replay,
    category: MissionCategory.technique,
    xpReward: 50,
    condition: (m) =>
        m.correctCompressionsPct >= 90 && m.totalCompressions >= 30,
    progressLabel: '≥ 90 % correctas',
  ),
  Mission(
    id: 'no_violations',
    title: 'Sin errores críticos',
    description: 'Completa una sesión sin ninguna violación AHA.',
    iconData: Icons.check_circle_outline,
    category: MissionCategory.technique,
    xpReward: 100,
    condition: (m) => m.violations.isEmpty && m.totalCompressions >= 30,
    progressLabel: '0 violaciones',
  ),
  Mission(
    id: 'marathon',
    title: 'Fondo y forma',
    description: 'Completa más de 200 compresiones en una sesión.',
    iconData: Icons.fitness_center,
    category: MissionCategory.consistency,
    xpReward: 60,
    condition: (m) => m.totalCompressions >= 200,
    progressLabel: '200 compresiones',
  ),
  Mission(
    id: 'ccf_master',
    title: 'Ritmo constante',
    description: 'Mantén CCF ≥ 80 % con máximo 3 interrupciones.',
    iconData: Icons.timer,
    category: MissionCategory.consistency,
    xpReward: 70,
    condition: (m) => m.interruptionCount <= 3 && m.totalCompressions >= 60,
    progressLabel: '≤ 3 interrupciones',
  ),
];
