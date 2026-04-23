import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/guide_provider.dart';
import '../services/device_service.dart';
import '../core/theme.dart';

class DeviceSelectionScreen extends ConsumerWidget {
  const DeviceSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(availableDevicesProvider);
    final theme        = Theme.of(context);
    final textP        = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS        = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Seleccionar maniquí'),
        centerTitle: true,
      ),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
        error:   (e, _) => _ErrorBody(error: e.toString()),
        data: (devices) {
          final active   = devices.where((d) => d.isActive).toList();
          final inactive = devices.where((d) => !d.isActive).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(availableDevicesProvider),
            color: AppColors.brand,
            child: CustomScrollView(
              slivers: [
                // Info header
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.brand),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Selecciona el maniquí que vas a usar. Solo aparecen dispositivos con datos recientes (< 5 segundos).',
                            style: TextStyle(color: textP, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Activos
                if (active.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text('🟢 Disponibles (${active.length})',
                          style: TextStyle(color: textP, fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _DeviceTile(
                        device: active[i],
                        onSelect: () {
                          ref.read(selectedDeviceMacProvider.notifier).state = active[i].macAddress;
                          context.pop();
                        },
                      ),
                      childCount: active.length,
                    ),
                  ),
                ],

                // Inactivos
                if (inactive.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('🔴 Sin señal reciente (${inactive.length})',
                          style: TextStyle(color: textS, fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _DeviceTile(device: inactive[i], onSelect: null),
                      childCount: inactive.length,
                    ),
                  ),
                ],

                // Sin dispositivos
                if (devices.isEmpty)
                  SliverFillRemaining(child: _EmptyDevices()),

                // Modo simulación
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.science_outlined, size: 16),
                      label: const Text('Continuar sin maniquí (modo simulación)'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 46),
                        foregroundColor: textS,
                        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                      ),
                      onPressed: () {
                        ref.read(selectedDeviceMacProvider.notifier).state = null;
                        context.pop();
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Device Tile ──────────────────────────────────────────────────────────────
class _DeviceTile extends StatelessWidget {
  final DeviceInfo device;
  final VoidCallback? onSelect;
  const _DeviceTile({required this.device, this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final border  = theme.colorScheme.outline;
    final textP   = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS   = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final active  = device.isActive;
    final color   = active ? AppColors.green : AppColors.red;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(
          color: active ? AppColors.green.withValues(alpha: 0.3) : border.withValues(alpha: 0.3),
          width: active ? 1.5 : 0.5,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            active ? Icons.sensors_rounded : Icons.sensors_off_rounded,
            color: color,
            size: 22,
          ),
        ),
        title: Text(
          device.macAddress,
          style: TextStyle(
            color: textP,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFamily: 'SpaceMono',
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(device.lastUpdateLabel, style: TextStyle(color: textS, fontSize: 10)),
            if (active) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  _TelemetryChip(label: '${device.ritmoCpm.toStringAsFixed(0)} CPM'),
                  const SizedBox(width: 4),
                  _TelemetryChip(label: '${device.presion.toStringAsFixed(1)} mmHg'),
                  const SizedBox(width: 4),
                  _TelemetryChip(label: '${device.temperatura.toStringAsFixed(1)}°C'),
                ],
              ),
            ],
          ],
        ),
        trailing: active
            ? ElevatedButton(
                onPressed: onSelect,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  textStyle: const TextStyle(fontSize: 11),
                ),
                child: const Text('Usar este'),
              )
            : null,
      ),
    );
  }
}

class _TelemetryChip extends StatelessWidget {
  final String label;
  const _TelemetryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: const TextStyle(color: AppColors.brand, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Estado vacío ─────────────────────────────────────────────────────────────
class _EmptyDevices extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textS = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sensors_off_rounded, size: 64,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No hay maniquíes detectados',
              style: TextStyle(color: textS, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Verifica que el ESP32 esté encendido y conectado a WiFi.',
              style: TextStyle(color: textS.withValues(alpha: 0.7), fontSize: 12),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String error;
  const _ErrorBody({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.red),
            const SizedBox(height: 12),
            Text(error, style: const TextStyle(color: AppColors.red), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
