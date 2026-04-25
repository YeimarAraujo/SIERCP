import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/alert_course.dart';
import '../providers/session_provider.dart';
import '../widgets/section_label.dart';
import '../widgets/depth_gauge.dart';
import '../widgets/rate_gauge.dart';

class LiveInstructorScreen extends ConsumerStatefulWidget {
  final String courseId;
  const LiveInstructorScreen({super.key, required this.courseId});

  @override
  ConsumerState<LiveInstructorScreen> createState() =>
      _LiveInstructorScreenState();
}

class _LiveInstructorScreenState extends ConsumerState<LiveInstructorScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    final coursesAsync = ref.watch(coursesProvider);
    final courses = coursesAsync.value ?? [];
    final course = courses
        .cast<CourseModel?>()
        .firstWhere((c) => c?.id == widget.courseId, orElse: () => null);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monitorización en Vivo'),
            Text(
              course?.title ?? 'Curso',
              style: TextStyle(
                  color: textS, fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.greenBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: AppColors.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text('CONECTADO',
                    style: TextStyle(
                        color: AppColors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Dispositivos Activos (Simulación)'),
              const SizedBox(height: 12),
              _DeviceMonitorCard(
                studentName: 'Juan Pérez',
                deviceId: 'ESP32-A1',
                depthMm: 55,
                ratePerMin: 110,
                connected: true,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _DeviceMonitorCard(
                studentName: 'María García',
                deviceId: 'ESP32-B2',
                depthMm: 35,
                ratePerMin: 140,
                connected: true,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _DeviceMonitorCard(
                studentName: 'Carlos López',
                deviceId: 'ESP32-C3',
                depthMm: 0,
                ratePerMin: 0,
                connected: false,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceMonitorCard extends StatelessWidget {
  final String studentName;
  final String deviceId;
  final double depthMm;
  final int ratePerMin;
  final bool connected;
  final bool isDark;

  const _DeviceMonitorCard({
    required this.studentName,
    required this.deviceId,
    required this.depthMm,
    required this.ratePerMin,
    required this.connected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final textT = theme.textTheme.bodySmall?.color ?? AppColors.textTertiary;
    final bg = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: isDark ? null : AppShadows.card(false),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: connected
                  ? AppColors.brand.withValues(alpha: 0.05)
                  : AppColors.cardBorder.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg)),
              border: Border(bottom: BorderSide(color: border, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          connected ? AppColors.brand : AppColors.textTertiary,
                      child: const Icon(Icons.person,
                          size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(studentName,
                            style: TextStyle(
                                color: textP,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                        Text('Maniquí: $deviceId',
                            style: TextStyle(color: textS, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                Icon(
                  connected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: connected ? AppColors.brand : textT,
                  size: 16,
                )
              ],
            ),
          ),

          // Body (Gauges)
          Padding(
            padding: const EdgeInsets.all(16),
            child: connected
                ? Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('PROFUNDIDAD',
                                style: TextStyle(
                                    color: textS,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(
                              height: 90,
                              child: DepthGauge(depthMm: depthMm),
                            )
                          ],
                        ),
                      ),
                      Container(width: 0.5, height: 70, color: border),
                      Expanded(
                        child: Column(
                          children: [
                            Text('FRECUENCIA',
                                style: TextStyle(
                                    color: textS,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(
                              height: 90,
                              child: RateGauge(ratePerMin: ratePerMin),
                            )
                          ],
                        ),
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('Esperando conexión del maniquí...',
                          style: TextStyle(color: textT, fontSize: 12)),
                    ),
                  ),
          )
        ],
      ),
    );
  }
}
