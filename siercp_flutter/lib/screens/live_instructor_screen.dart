import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/alert_course.dart';
import '../models/session.dart';
import '../services/device_service.dart';
import '../providers/session_provider.dart';
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

    final activeSessionsAsync = ref.watch(courseActiveSessionsProvider(widget.courseId));

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
      ),
      body: SafeArea(
        child: activeSessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (sessions) {
            if (sessions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_off_outlined, size: 64, color: textS.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    Text('No hay sesiones activas en este momento', 
                      style: TextStyle(color: textS, fontSize: 14)),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final session = sessions[i];
                return _RealtimeSessionCard(session: session, isDark: isDark);
              },
            );
          },
        ),
      ),
    );
  }
}

class _RealtimeSessionCard extends ConsumerWidget {
  final SessionModel session;
  final bool isDark;

  const _RealtimeSessionCard({required this.session, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchar telemetría del maniquí asociado a esta sesión
    final manikinId = session.manikinId;
    if (manikinId == null || manikinId.isEmpty) {
      return _DeviceMonitorCard(
        studentName: session.studentName,
        deviceId: 'Sin dispositivo',
        depthMm: 0,
        ratePerMin: 0,
        connected: false,
        isDark: isDark,
      );
    }

    final deviceStream = ref.watch(deviceServiceProvider).streamDevice(manikinId);

    return StreamBuilder<DeviceInfo?>(
      stream: deviceStream,
      builder: (context, snapshot) {
        final device = snapshot.data;
        final isConnected = device != null && device.isActive;

        return _DeviceMonitorCard(
          studentName: session.studentName,
          deviceId: manikinId,
          depthMm: device?.profundidadMm ?? 0,
          ratePerMin: device?.frecuenciaCpm ?? 0,
          connected: isConnected,
          isDark: isDark,
        );
      },
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
