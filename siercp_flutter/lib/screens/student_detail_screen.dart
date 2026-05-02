import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../models/session.dart';
import '../../providers/session_provider.dart';
import '../../widgets/metric_card.dart';

class StudentDetailScreen extends ConsumerWidget {
  final String userId;
  const StudentDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(usersStatusProvider([userId]));
    final sessionsAsync = ref.watch(studentSessionsProvider(userId));
    
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Perfil del Estudiante'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (users) {
          final user = users.firstOrNull;
          if (user == null) return const Center(child: Text('Usuario no encontrado'));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(user, theme),
                const SizedBox(height: 24),
                
                const SectionLabel('Estadísticas Generales'),
                const SizedBox(height: 12),
                sessionsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error al cargar stats: $e'),
                  data: (sessions) => _buildStatsGrid(sessions),
                ),

                const SizedBox(height: 24),
                const SectionLabel('Actividad Reciente'),
                const SizedBox(height: 12),
                sessionsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (sessions) => _buildSessionList(sessions, theme),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(UserModel user, ThemeData theme) {
    final isOnline = user.isOnline;
    final lastActive = user.lastActive;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
        boxShadow: AppShadows.card(theme.brightness == Brightness.dark),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: AppColors.brand.withValues(alpha: 0.1),
            child: Text(user.initials, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.brand)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: TextStyle(color: textP, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(user.email, style: TextStyle(color: textS, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isOnline ? AppColors.green : AppColors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'En línea ahora' : (lastActive != null ? 'Visto por última vez: ${_formatDate(lastActive)}' : 'Desconectado'),
                      style: TextStyle(color: textS, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(List<SessionModel> sessions) {
    if (sessions.isEmpty) {
      return const Center(child: Text('Sin sesiones registradas', style: TextStyle(color: AppColors.textSecondary)));
    }

    final total = sessions.length;
    final avgScore = sessions.map((s) => s.metrics?.score ?? 0).reduce((a, b) => a + b) / total;
    final approved = sessions.where((s) => s.metrics?.approved ?? false).length;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        MetricCard(label: 'Total Sesiones', value: total.toString(), suffix: 'sesiones'),
        MetricCard(label: 'Puntaje Prom.', value: '${avgScore.toStringAsFixed(1)}%', suffix: 'promedio', status: avgScore >= 80 ? MetricStatus.ok : MetricStatus.warning),
        MetricCard(label: 'Aprobadas', value: approved.toString(), suffix: 'sesiones'),
        MetricCard(label: 'Tasa Aprob.', value: '${((approved / total) * 100).toStringAsFixed(0)}%', suffix: 'éxito', status: (approved/total) >= 0.7 ? MetricStatus.ok : MetricStatus.warning),
      ],
    );
  }

  Widget _buildSessionList(List<SessionModel> sessions, ThemeData theme) {
    if (sessions.isEmpty) return const SizedBox.shrink();
    
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sessions.length > 5 ? 5 : sessions.length,
      itemBuilder: (context, i) {
        final s = sessions[i];
        final score = s.metrics?.score ?? 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
          ),
          child: ListTile(
            title: Text(s.scenarioTitle ?? 'Sesión RCP', style: TextStyle(color: textP, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text(_formatDate(s.startedAt ?? DateTime.now()), style: TextStyle(color: textS, fontSize: 11)),
            trailing: Text(
              '${score.toStringAsFixed(0)}%',
              style: TextStyle(
                color: score >= 80 ? AppColors.green : AppColors.red,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd MMM yyyy, HH:mm').format(dt);
  }
}
