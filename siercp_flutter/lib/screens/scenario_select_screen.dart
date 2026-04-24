import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/alert_course.dart';
import '../providers/session_provider.dart';
import '../widgets/device_status_widget.dart';

// ─── Icono por categoría de escenario ─────────────────────────────────────────
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

// ─── Main screen ──────────────────────────────────────────────────────────────
class ScenarioSelectScreen extends ConsumerWidget {
  const ScenarioSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenariosAsync = ref.watch(scenariosProvider);
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
                      Text('Seleccionar escenario',
                          style: TextStyle(color: textP, fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Elige el caso clínico a simular',
                          style: TextStyle(color: textS, fontSize: 12)),
                    ],
                  ),
                  // Botón seleccionar maniquí
                  OutlinedButton.icon(
                    icon: const Icon(Icons.sensors_rounded, size: 14),
                    label: const Text('Maniquí', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: isDark ? 0.12 : 0.06),
                      border: Border.all(
                        color: AppColors.brand.withValues(alpha: isDark ? 0.3 : 0.2),
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.brand, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Selecciona un escenario y conecta el maniquí ESP32 para comenzar.',
                            style: TextStyle(
                              color: isDark ? AppColors.accent : AppColors.brand,
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
                      error: (_, __) => const _OfflineScenarios(),
                      data: (scenarios) => scenarios.isEmpty
                          ? const _OfflineScenarios()
                          : isLandscape
                              ? GridView.builder(
                                  padding: const EdgeInsets.all(20),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 400,
                                    mainAxisExtent: 95,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 0,
                                  ),
                                  itemCount: scenarios.length,
                                  itemBuilder: (ctx, i) =>
                                      _ScenarioCard(scenario: scenarios[i]),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
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

// ─── 8 escenarios locales completos ──────────────────────────────────────────
class _OfflineScenarios extends StatelessWidget {
  const _OfflineScenarios();

  static const _demos = [
    _DemoScenario('paroCardiaco',      'cardiac',           '🏠 Paro cardíaco en casa',
        'Adulto · 52 años · Colapso repentino',
        'Familiar encuentra a la víctima inconsciente en el suelo. Sin pulso ni respiración.',
        false, false),
    _DemoScenario('accidenteTransito', 'accident',          '🚗 Accidente de tránsito',
        'Adulto · 35 años · Múltiples traumas',
        'Víctima encontrada en la vía, sin respuesta. Evalúa la escena antes de actuar.',
        false, false),
    _DemoScenario('ahogamiento',       'drowning',          '🌊 Ahogamiento en piscina',
        'Adulto · Sin respiración ni pulso',
        'Rescatado de la piscina. Protocolo de ahogamiento: ventilaciones primero.',
        false, true),
    _DemoScenario('colapsoEjercicio',  'colapsoEjercicio',  '🏋️ Colapso durante ejercicio',
        'Adulto · 28 años · Atleta',
        'Colapso súbito en el gimnasio. Posible fibrilación ventricular. Usa el DEA.',
        false, true),
    _DemoScenario('atragantamiento',   'atragantamiento',   '🍽️ Atragantamiento severo',
        'Adulto · Obstrucción de vía aérea',
        'Cena familiar. Maniobra de Heimlich + RCP si pierde el conocimiento.',
        false, false),
    _DemoScenario('descargaElectrica', 'electrocucion',     '⚡ Descarga eléctrica',
        'Adulto · Accidente laboral',
        'Trabajador electrocutado. Asegurar la escena antes de tocar a la víctima.',
        false, false),
    _DemoScenario('sobredosis',        'sobredosis',        '🛏️ Sobredosis por opioides',
        'Adulto · Intoxicación · Respiración lenta',
        'Víctima con sobredosis: Naloxona si disponible + RCP si paro cardíaco.',
        false, false),
    _DemoScenario('infarto',           'cardiac',           '🚨 Infarto que evoluciona a paro',
        'Adulto · 60 años · Dolor torácico',
        'Paciente con dolor torácico que evoluciona a paro cardíaco. Actúa rápido.',
        false, false),
  ];

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 0,
          childAspectRatio: 2.8,
        ),
        itemCount: _demos.length,
        itemBuilder: (ctx, i) {
          final d = _demos[i];
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
      children: _demos
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

// ─── Card from API model ───────────────────────────────────────────────────────
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
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP  = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS  = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final textT  = theme.textTheme.bodySmall?.color  ?? AppColors.textTertiary;
    final cardBg = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    final iconColor = _scenarioColor(category);
    final icon      = _scenarioIcon(category);

    return GestureDetector(
      onTap: locked
          ? () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Completa los módulos anteriores para desbloquear.',
                    style: TextStyle(color: theme.colorScheme.onInverseSurface),
                  ),
                  backgroundColor: theme.colorScheme.inverseSurface,
                ),
              )
          : () => context.go('/session?scenario=$id'),
      child: Opacity(
        opacity: locked ? 0.45 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
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
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isNew)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.cyanBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Nuevo',
                              style: TextStyle(
                                color: AppColors.cyan,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (locked)
                          Icon(Icons.lock_outline_rounded, color: textT, size: 16),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(color: textS, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textT, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (!locked)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.chevron_right_rounded, size: 20, color: textT),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

