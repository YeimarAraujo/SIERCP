import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/devices/data/ble_service.dart';
import 'package:siercp/l10n/app_localizations.dart';

class PracticalHubScreen extends ConsumerWidget {
  const PracticalHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final ble = ref.watch(bleServiceProvider);
    final isConnected = ble.isConnected;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: textP,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.practicalTitle,
                        style: TextStyle(
                          color: textP,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        loc.practicalSubtitle,
                        style: TextStyle(color: textS, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── BLE status banner ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _BleBanner(
                isConnected: isConnected,
                onConnect: () => context.push('/session/device-select'),
              ),
            ),
            const SizedBox(height: 20),

            // ── Options ───────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _PracticeCard(
                      icon: Icons.favorite_outlined,
                      title: loc.practicalRcp,
                      description: loc.practicalRcpDesc,
                      color: AppColors.red,
                      enabled: isConnected,
                      onTap:
                          isConnected ? () => context.push('/scenarios') : null,
                      disabledLabel: loc.practicalDeviceRequired,
                    ),
                    // const SizedBox(height: 16),
                    // _PracticeCard(
                    //   icon: Icons.emergency_outlined,
                    //   title: loc.practicalScenarios,
                    //   description: loc.practicalScenariosDesc,
                    //   color: AppColors.amber,
                    //   enabled: true,
                    //   onTap: () => context.push('/scenarios'),
                    // ),
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

class _BleBanner extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onConnect;

  const _BleBanner({required this.isConnected, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isConnected ? AppColors.green : AppColors.amber;
    final label = isConnected ? 'Maniquí conectado' : 'Maniquí no conectado';
    final sub = isConnected
        ? 'Listo para iniciar práctica de RCP'
        : 'Conecta el maniquí para iniciar ';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.06),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.sensors_rounded : Icons.sensors_off_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.75),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (!isConnected)
            TextButton(
              onPressed: onConnect,
              style: TextButton.styleFrom(
                foregroundColor: color,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
              ),
              child: const Text('Conectar', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;
  final String? disabledLabel;

  const _PracticeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.enabled,
    this.onTap,
    this.disabledLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final textT = theme.textTheme.bodySmall?.color ?? AppColors.textTertiary;
    final cardBg = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    return GestureDetector(
      onTap: onTap ??
          (!enabled && disabledLabel != null
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        disabledLabel!,
                        style: TextStyle(
                            color: theme.colorScheme.onInverseSurface),
                      ),
                      backgroundColor: theme.colorScheme.inverseSurface,
                    ),
                  )
              : null),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.55,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border.all(color: border, width: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: isDark ? null : AppShadows.card(false),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textP,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(color: textS, fontSize: 11),
                    ),
                    if (!enabled && disabledLabel != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 11, color: textT),
                          const SizedBox(width: 4),
                          Text(
                            disabledLabel!,
                            style: TextStyle(color: textT, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (enabled)
                Icon(Icons.chevron_right_rounded,
                    color: theme.colorScheme.outline, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
