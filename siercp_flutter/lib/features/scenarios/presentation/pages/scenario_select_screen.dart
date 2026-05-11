import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/courses/data/models/alert_course.dart';
import 'package:siercp/features/session/presentation/providers/session_provider.dart';
import 'package:siercp/core/widgets/device_status_widget.dart';
import 'package:siercp/l10n/app_localizations.dart';

// Icono por categoría de escenario
IconData _scenarioIcon(String category) {
  switch (category.toLowerCase()) {
    case 'accident':
    case 'accidente':
      return Icons.directions_car_outlined;
    case 'drowning':
    case 'ahogamiento':
      return Icons.water_outlined;
    case 'cardiac':
    case 'paro':
      return Icons.monitor_heart_outlined;
    case 'electrocution':
    case 'electrocucion':
      return Icons.bolt_outlined;
    case 'pediatric':
    case 'pediatrico':
      return Icons.child_care_outlined;
    case 'infant':
    case 'lactante':
      return Icons.baby_changing_station_outlined;
    default:
      return Icons.medical_services_outlined;
  }
}

Color _scenarioColor(String category) {
  switch (category.toLowerCase()) {
    case 'accident':
    case 'accidente':
      return AppColors.amber;
    case 'drowning':
    case 'ahogamiento':
      return AppColors.cyan;
    case 'cardiac':
    case 'paro':
      return AppColors.red;
    case 'electrocution':
    case 'electrocucion':
      return const Color(0xFFFFC107);
    case 'pediatric':
    case 'pediatrico':
      return AppColors.accent;
    case 'infant':
    case 'lactante':
      return const Color(0xFFFF6B9D);
    default:
      return AppColors.brand;
  }
}

class ScenarioSelectScreen extends ConsumerWidget {
  const ScenarioSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenariosAsync = ref.watch(scenariosProvider);
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.selectScenarioTitle,
                          style: TextStyle(color: textP, fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(loc.selectScenarioSubtitle,
                          style: TextStyle(color: textS, fontSize: 12)),
                    ],
                  ),
                  // Botón seleccionar maniquí
                  OutlinedButton.icon(
                    icon: const Icon(Icons.sensors_rounded, size: 14),
                    label: Text(loc.manikinBtn, style: const TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () => context.push('/session/device-select'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Estado del maniquí
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: DeviceConnectionWidget(),
            ),
            const SizedBox(height: 10),

            // AHA info banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Builder(
                builder: (context) {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.brand
                          .withValues(alpha: isDark ? 0.12 : 0.06),
                      border: Border.all(
                        color: AppColors.brand
                            .withValues(alpha: isDark ? 0.3 : 0.2),
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.brand, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            loc.scenarioInfoBanner,
                            style: TextStyle(
                              color:
                                  isDark ? AppColors.accent : AppColors.brand,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final isLandscape = MediaQuery.of(context).orientation ==
                      Orientation.landscape;
                  return scenariosAsync.when(
                    loading: () => const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.brand)),
                    error: (_, __) => _OfflineScenarios(loc: loc),
                    data: (scenarios) => scenarios.isEmpty
                        ? _OfflineScenarios(loc: loc)
                        : isLandscape
                            ? GridView.builder(
                                padding: const EdgeInsets.all(20),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 400,
                                  mainAxisExtent: 115,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 0,
                                ),
                                itemCount: scenarios.length,
                                itemBuilder: (ctx, i) =>
                                    _ScenarioCard(scenario: scenarios[i]),
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: scenarios.length,
                                itemBuilder: (ctx, i) =>
                                    _ScenarioCard(scenario: scenarios[i]),
                              ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineScenarios extends StatelessWidget {
  final AppLocalizations loc;
  const _OfflineScenarios({required this.loc});

  List<_DemoScenario> _getDemos() => [
    _DemoScenario('paroCardiaco',      'cardiac',           loc.demoTitle1,
        loc.demoSub1,
        loc.demoDesc1,
        false, false),
    _DemoScenario('accidenteTransito', 'accident',          loc.demoTitle2,
        loc.demoSub2,
        loc.demoDesc2,
        false, false),
    _DemoScenario('ahogamiento',       'drowning',          loc.demoTitle3,
        loc.demoSub3,
        loc.demoDesc3,
        false, true),
    _DemoScenario('colapsoEjercicio',  'colapsoEjercicio',  loc.demoTitle4,
        loc.demoSub4,
        loc.demoDesc4,
        false, true),
    _DemoScenario('atragantamiento',   'atragantamiento',   loc.demoTitle5,
        loc.demoSub5,
        loc.demoDesc5,
        false, false),
    _DemoScenario('descargaElectrica', 'electrocucion',     loc.demoTitle6,
        loc.demoSub6,
        loc.demoDesc6,
        false, false),
    _DemoScenario('sobredosis',        'sobredosis',        loc.demoTitle7,
        loc.demoSub7,
        loc.demoDesc7,
        false, false),
    _DemoScenario('infarto',           'cardiac',           loc.demoTitle8,
        loc.demoSub8,
        loc.demoDesc8,
        false, false),
  ];

  @override
  Widget build(BuildContext context) {
    final demos = _getDemos();
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          mainAxisExtent: 115,
          crossAxisSpacing: 12,
          mainAxisSpacing: 0,
        ),
        itemCount: demos.length,
        itemBuilder: (ctx, i) {
          final d = demos[i];
          return _ScenarioCardRaw(
            id: d.id,
            category: d.category,
            title: d.title,
            subtitle: d.subtitle,
            description: d.description,
            locked: d.locked,
            isNew: d.isNew,
          );
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: demos
          .map((d) => _ScenarioCardRaw(
                id: d.id,
                category: d.category,
                title: d.title,
                subtitle: d.subtitle,
                description: d.description,
                locked: d.locked,
                isNew: d.isNew,
              ))
          .toList(),
    );
  }
}

class _DemoScenario {
  final String id, category, title, subtitle, description;
  final bool locked, isNew;
  const _DemoScenario(this.id, this.category, this.title, this.subtitle,
      this.description, this.locked, this.isNew);
}

// Card from API model
class _ScenarioCard extends StatelessWidget {
  final ScenarioModel scenario;
  const _ScenarioCard({required this.scenario});

  @override
  Widget build(BuildContext context) => _ScenarioCardRaw(
        id: scenario.id,
        category: scenario.categoryString,
        title: scenario.title,
        subtitle: scenario.description,
        description: scenario.audioIntroText,
        locked: scenario.locked,
        isNew: scenario.isNew,
      );
}

// ─── Card raw (universal) ─────────────────────────────────────────────────────
class _ScenarioCardRaw extends StatelessWidget {
  final String id, category, title, subtitle, description;
  final bool locked, isNew;

  const _ScenarioCardRaw({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.locked,
    required this.isNew,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final textT = theme.textTheme.bodySmall?.color ?? AppColors.textTertiary;
    final cardBg = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    final iconColor = _scenarioColor(category);
    final icon = _scenarioIcon(category);

    return GestureDetector(
      onTap: locked
          ? () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    loc.lockedScenarioMsg,
                    style: TextStyle(color: theme.colorScheme.onInverseSurface),
                  ),
                  backgroundColor: theme.colorScheme.inverseSurface,
                ),
              )
          : () => context.go('/scenario-detail/$id'),
      child: Opacity(
        opacity: locked ? 0.45 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border.all(color: border, width: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: isDark ? null : AppShadows.card(false),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: textP,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isNew)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.cyanBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              loc.newBadge,
                              style: const TextStyle(
                                color: AppColors.cyan,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (locked)
                          Icon(Icons.lock_outline_rounded,
                              color: textT, size: 14),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textS, fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textT, fontSize: 9),
                    ),
                  ],
                ),
              ),
              if (!locked)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child:
                      Icon(Icons.chevron_right_rounded, size: 20, color: textT),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
