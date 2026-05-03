import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/report_data.dart';
import '../models/session.dart';

class ReportPreviewScreen extends StatelessWidget {
  final dynamic reportData; // Can be StudentReportData or CourseReportData

  const ReportPreviewScreen({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final bg = theme.scaffoldBackgroundColor;

    bool isStudent = reportData is StudentReportData;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(isStudent ? 'Reporte de Estudiante' : 'Reporte de Curso',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isStudent, textP, textS),
            const SizedBox(height: 24),
            if (isStudent)
              _buildStudentContent(reportData as StudentReportData, textP, textS, isDark)
            else
              _buildCourseContent(reportData as CourseReportData, textP, textS, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isStudent, Color textP, Color textS) {
    final title = isStudent ? (reportData as StudentReportData).studentName : (reportData as CourseReportData).courseTitle;
    final subtitle = isStudent ? (reportData as StudentReportData).courseName : 'Consolidado Grupal';

    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(isStudent ? Icons.person_rounded : Icons.groups_rounded, color: AppColors.brand, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: textP, fontSize: 18, fontWeight: FontWeight.w700)),
              Text(subtitle, style: TextStyle(color: textS, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentContent(StudentReportData data, Color textP, Color textS, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatGrid([
          _StatItem(label: 'Promedio', value: '${data.avgScore.toStringAsFixed(0)}%', color: AppColors.green),
          _StatItem(label: 'Sesiones', value: '${data.totalCount}', color: AppColors.brand),
          _StatItem(label: 'Aprobadas', value: '${data.approvedCount}', color: AppColors.cyan),
          _StatItem(label: 'Mejor Score', value: '${data.bestScore.toStringAsFixed(0)}%', color: AppColors.amber),
        ], isDark),
        const SizedBox(height: 24),
        _SectionTitle('Métricas Promedio'),
        const SizedBox(height: 12),
        _MetricTile(label: 'Profundidad', value: '${data.avgDepthMm.toStringAsFixed(1)} mm', icon: Icons.straighten),
        _MetricTile(label: 'Frecuencia', value: '${data.avgRatePerMin.toStringAsFixed(0)} /min', icon: Icons.speed),
        const SizedBox(height: 24),
        _SectionTitle('Historial de Sesiones'),
        const SizedBox(height: 12),
        ...data.sessions.where((s) => s.metrics != null).map((s) => _SessionTile(session: s, textP: textP, textS: textS)),
      ],
    );
  }

  Widget _buildCourseContent(CourseReportData data, Color textP, Color textS, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatGrid([
          _StatItem(label: 'Promedio Global', value: '${data.globalAvgScore.toStringAsFixed(1)}%', color: AppColors.green),
          _StatItem(label: 'Estudiantes', value: '${data.totalStudents}', color: AppColors.brand),
          _StatItem(label: 'Total Sesiones', value: '${data.totalSessions}', color: AppColors.cyan),
          _StatItem(label: 'Aprobaciones', value: '${data.totalApproved}', color: AppColors.amber),
        ], isDark),
        const SizedBox(height: 24),
        _SectionTitle('Rendimiento por Estudiante'),
        const SizedBox(height: 12),
        ...data.students.map((st) {
          final sid = st['studentId'] as String? ?? '';
          final sessions = data.studentSessions[sid] ?? [];
          final withM = sessions.where((s) => s.metrics != null).toList();
          final avg = withM.isEmpty ? 0.0 : withM.map((s) => s.metrics!.score).reduce((a, b) => a + b) / withM.length;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                  child: Text(st['studentName']?[0]?.toUpperCase() ?? 'U', style: const TextStyle(color: AppColors.brand, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(st['studentName'] ?? 'Estudiante', style: TextStyle(color: textP, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${sessions.length} sesiones', style: TextStyle(color: textS, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (avg >= 70 ? AppColors.green : AppColors.red).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${avg.toStringAsFixed(0)}%', style: TextStyle(color: avg >= 70 ? AppColors.green : AppColors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatGrid(List<_StatItem> items, bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: items.map((item) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(item.label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(item.value, style: TextStyle(color: item.color, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'SpaceMono')),
          ],
        ),
      )).toList(),
    );
  }
}

class _StatItem {
  final String label, value;
  final Color color;
  _StatItem({required this.label, required this.value, required this.color});
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.brand));
}

class _MetricTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _MetricTile({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.brand.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(children: [
      Icon(icon, size: 18, color: AppColors.brand),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.brand)),
    ]),
  );
}

class _SessionTile extends StatelessWidget {
  final SessionModel session;
  final Color textP, textS;
  const _SessionTile({required this.session, required this.textP, required this.textS});
  @override
  Widget build(BuildContext context) {
    final m = session.metrics!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(session.scenarioTitle ?? 'RCP', style: TextStyle(color: textP, fontSize: 12, fontWeight: FontWeight.w600)),
          Text(DateFormat('dd MMM, yyyy').format(session.startedAt), style: TextStyle(color: textS, fontSize: 10)),
        ]),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${m.score.toStringAsFixed(0)}%', style: TextStyle(color: m.approved ? AppColors.green : AppColors.red, fontSize: 14, fontWeight: FontWeight.bold)),
          Text('${m.averageDepthMm.toStringAsFixed(1)}mm | ${m.averageRatePerMin.toStringAsFixed(0)}/min', style: TextStyle(color: textS, fontSize: 10)),
        ]),
      ]),
    );
  }
}
