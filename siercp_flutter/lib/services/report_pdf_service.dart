import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';
import '../models/session.dart';
import '../models/alert_course.dart';
import '../core/constants.dart';
import 'local_storage_service.dart';

final reportPdfServiceProvider = Provider<ReportPdfService>((ref) {
  return ReportPdfService(ref.read(localStorageServiceProvider));
});

class ReportPdfService {
  final LocalStorageService _local;
  ReportPdfService(this._local);

  static final _brand = PdfColor.fromHex('1800AD');
  static final _green = PdfColor.fromHex('00C853');
  static final _red = PdfColor.fromHex('FF3B5C');
  static final _amber = PdfColor.fromHex('FFAB00');
  static final _grey = PdfColor.fromHex('F2F4F8');
  static final _greyBorder = PdfColor.fromHex('E5E7F0');
  static final _textDark = PdfColor.fromHex('1A1A2E');
  static final _textMid = PdfColor.fromHex('5A5C7A');

  /// Reporte individual para un estudiante dentro de un curso.
  /// Incluye todas sus sesiones, métricas promedio y detalle por sesión.
  Future<ReportRecord> generateStudentCourseReport({
    required String studentId,
    required String studentName,
    required String courseId,
    required String courseName,
    required List<SessionModel> sessions,
    Map<String, dynamic>? enrollmentData,
  }) async {
    final pdf = pw.Document();
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final completed = sessions.where((s) => s.metrics != null).toList();

    // Calcular estadísticas
    double avgScore = 0, bestScore = 0, avgDepth = 0, avgRate = 0;
    int approved = 0;
    if (completed.isNotEmpty) {
      final scores = completed.map((s) => s.metrics!.score).toList();
      avgScore = scores.reduce((a, b) => a + b) / scores.length;
      bestScore = scores.reduce((a, b) => a > b ? a : b);
      avgDepth = completed
              .map((s) => s.metrics!.averageDepthMm)
              .reduce((a, b) => a + b) /
          completed.length;
      avgRate = completed
              .map((s) => s.metrics!.averageRatePerMin)
              .reduce((a, b) => a + b) /
          completed.length;
      approved = completed.where((s) => s.metrics!.approved).length;
    }

    final scoreColor = avgScore >= AppConstants.ahaExcellentScore
        ? _green
        : avgScore >= AppConstants.ahaPassScore
            ? _amber
            : _red;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (ctx) => [
        // Header
        _buildHeader('Reporte de Estudiante', courseName, now),
        pw.SizedBox(height: 16),

        // Info estudiante
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
              color: _grey, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(children: [
            pw.Expanded(
                child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Estudiante',
                    style: pw.TextStyle(color: _textMid, fontSize: 9)),
                pw.SizedBox(height: 2),
                pw.Text(studentName,
                    style: pw.TextStyle(
                        color: _textDark,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold)),
              ],
            )),
            pw.Expanded(
                child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('Sesiones',
                    style: pw.TextStyle(color: _textMid, fontSize: 9)),
                pw.SizedBox(height: 2),
                pw.Text('${sessions.length}',
                    style: pw.TextStyle(
                        color: _textDark,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold)),
              ],
            )),
            pw.Expanded(
                child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Aprobadas',
                    style: pw.TextStyle(color: _textMid, fontSize: 9)),
                pw.SizedBox(height: 2),
                pw.Text('$approved / ${completed.length}',
                    style: pw.TextStyle(
                        color: approved > 0 ? _green : _red,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold)),
              ],
            )),
          ]),
        ),
        pw.SizedBox(height: 16),

        // Score promedio
        pw.Center(
            child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: scoreColor, width: 2),
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Column(children: [
            pw.Text('${avgScore.toStringAsFixed(0)}%',
                style: pw.TextStyle(
                    color: scoreColor,
                    fontSize: 42,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text('Promedio General',
                style: pw.TextStyle(color: _textMid, fontSize: 11)),
          ]),
        )),
        pw.SizedBox(height: 16),

        // Resumen métricas
        pw.Text('RESUMEN DE MÉTRICAS',
            style: pw.TextStyle(
                color: _textMid,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.2)),
        pw.SizedBox(height: 8),
        _buildMetricRow(
            'Mejor calificación',
            '${bestScore.toStringAsFixed(1)}%',
            bestScore >= AppConstants.ahaPassScore),
        _buildMetricRow(
            'Profundidad promedio',
            '${avgDepth.toStringAsFixed(1)} mm',
            avgDepth >= AppConstants.ahaMinDepthMm &&
                avgDepth <= AppConstants.ahaMaxDepthMm),
        _buildMetricRow(
            'Frecuencia promedio',
            '${avgRate.toStringAsFixed(0)} /min',
            avgRate >= AppConstants.ahaMinRatePerMin &&
                avgRate <= AppConstants.ahaMaxRatePerMin),
        _buildMetricRow(
            'Tasa de aprobación',
            completed.isEmpty
                ? '0%'
                : '${((approved / completed.length) * 100).toStringAsFixed(0)}%',
            completed.isNotEmpty && approved / completed.length >= 0.7),
        pw.SizedBox(height: 20),

        // Detalle por sesión
        if (completed.isNotEmpty) ...[
          pw.Text('DETALLE POR SESIÓN',
              style: pw.TextStyle(
                  color: _textMid,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold),
            headerDecoration: pw.BoxDecoration(color: _brand),
            cellStyle: pw.TextStyle(color: _textDark, fontSize: 9),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center
            },
            headers: [
              'Escenario',
              'Fecha',
              'Score',
              'Prof. (mm)',
              'Frec. (/min)',
              'Estado'
            ],
            data: completed.map((s) {
              final m = s.metrics!;
              return [
                s.scenarioTitle ?? 'RCP',
                DateFormat('dd/MM/yy').format(s.startedAt),
                '${m.score.toStringAsFixed(0)}%',
                m.averageDepthMm.toStringAsFixed(1),
                m.averageRatePerMin.toStringAsFixed(0),
                m.approved ? '✓' : '✗',
              ];
            }).toList(),
          ),
        ],
        pw.SizedBox(height: 20),

        // Footer
        pw.Divider(color: _greyBorder),
        pw.SizedBox(height: 6),
        pw.Text(
          'Reporte generado por SIERCP — Sistema Inteligente de Entrenamiento RCP.\nGuías AHA 2025. Uso educativo.',
          style: pw.TextStyle(color: _textMid, fontSize: 8),
          textAlign: pw.TextAlign.center,
        ),
      ],
    ));

    // Guardar archivo
    final dir = await _getReportsDir();
    final safeName = studentName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filePath = '${dir.path}/Reporte_${safeName}_$timestamp.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    // Registrar en SQLite
    final record = ReportRecord(
      id: const Uuid().v4(),
      type: 'student',
      title: 'Reporte: $studentName',
      studentId: studentId,
      studentName: studentName,
      courseId: courseId,
      courseName: courseName,
      filePath: filePath,
      generatedAt: DateTime.now(),
      sessionCount: sessions.length,
      averageScore: avgScore,
    );
    await _local.saveReportRecord(record);
    return record;
  }

  /// Genera un PDF consolidado de TODOS los estudiantes de un curso.
  Future<ReportRecord> generateCourseReport({
    required CourseModel course,
    required List<Map<String, dynamic>> students,
    required Map<String, List<SessionModel>> studentSessions,
  }) async {
    final pdf = pw.Document();
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // Stats globales del curso
    int totalSessions = 0, totalApproved = 0;
    double sumScores = 0;
    int withScores = 0;
    for (final entry in studentSessions.entries) {
      for (final s in entry.value) {
        totalSessions++;
        if (s.metrics != null) {
          withScores++;
          sumScores += s.metrics!.score;
          if (s.metrics!.approved) totalApproved++;
        }
      }
    }
    final globalAvg = withScores > 0 ? sumScores / withScores : 0.0;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (ctx) => [
        _buildHeader('Reporte Consolidado de Curso', course.title, now),
        pw.SizedBox(height: 16),

        // Stats del curso
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
              color: _grey, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(children: [
            _buildStatCol('Estudiantes', '${students.length}'),
            _buildStatCol('Sesiones', '$totalSessions'),
            _buildStatCol('Promedio', '${globalAvg.toStringAsFixed(1)}%'),
            _buildStatCol('Aprobadas', '$totalApproved'),
          ]),
        ),
        pw.SizedBox(height: 16),

        // Tabla de estudiantes
        pw.Text('RENDIMIENTO POR ESTUDIANTE',
            style: pw.TextStyle(
                color: _textMid,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.2)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold),
          headerDecoration: pw.BoxDecoration(color: _brand),
          cellStyle: pw.TextStyle(color: _textDark, fontSize: 9),
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          headers: [
            'Estudiante',
            'Sesiones',
            'Promedio',
            'Mejor',
            'Aprobadas',
            'Estado'
          ],
          data: students.map((st) {
            final name = st['studentName'] as String? ?? 'Sin nombre';
            final sid = st['studentId'] as String? ?? '';
            final ss = studentSessions[sid] ?? [];
            final withM = ss.where((s) => s.metrics != null).toList();
            final avg = withM.isEmpty
                ? 0.0
                : withM.map((s) => s.metrics!.score).reduce((a, b) => a + b) /
                    withM.length;
            final best = withM.isEmpty
                ? 0.0
                : withM
                    .map((s) => s.metrics!.score)
                    .reduce((a, b) => a > b ? a : b);
            final ap = withM.where((s) => s.metrics!.approved).length;
            return [
              name,
              '${ss.length}',
              '${avg.toStringAsFixed(1)}%',
              '${best.toStringAsFixed(1)}%',
              '$ap/${withM.length}',
              avg >= course.requiredScore ? '✓ Aprobado' : '✗ Pendiente',
            ];
          }).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Divider(color: _greyBorder),
        pw.SizedBox(height: 6),
        pw.Text(
          'Reporte generado por SIERCP — Sistema Inteligente de Entrenamiento RCP.\nGuías AHA 2025. Uso educativo.',
          style: pw.TextStyle(color: _textMid, fontSize: 8),
          textAlign: pw.TextAlign.center,
        ),
      ],
    ));

    final dir = await _getReportsDir();
    final safeName = course.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filePath = '${dir.path}/Curso_${safeName}_$timestamp.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    final record = ReportRecord(
      id: const Uuid().v4(),
      type: 'course',
      title: 'Curso: ${course.title}',
      courseId: course.id,
      courseName: course.title,
      filePath: filePath,
      generatedAt: DateTime.now(),
      sessionCount: totalSessions,
      averageScore: globalAvg,
    );
    await _local.saveReportRecord(record);
    return record;
  }

  pw.Widget _buildHeader(String subtitle, String detail, String date) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
          color: _brand, borderRadius: pw.BorderRadius.circular(12)),
      child: pw
          .Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('SIERCP',
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(subtitle,
              style: pw.TextStyle(
                  color: PdfColor.fromHex('CCCCFF'), fontSize: 12)),
          pw.SizedBox(height: 2),
          pw.Text(detail,
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('Generado: $date',
              style:
                  pw.TextStyle(color: PdfColor.fromHex('CCCCFF'), fontSize: 9)),
          pw.SizedBox(height: 4),
          pw.Text('AHA Guidelines 2025',
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold)),
        ]),
      ]),
    );
  }

  pw.Widget _buildMetricRow(String label, String value, bool ok) {
    final color = ok ? _green : _red;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _greyBorder),
          borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Row(children: [
        pw.Text(ok ? '✓' : '✗',
            style: pw.TextStyle(color: color, fontSize: 14)),
        pw.SizedBox(width: 10),
        pw.Expanded(
            child: pw.Text(label,
                style: pw.TextStyle(
                    color: _textDark,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold))),
        pw.Text(value,
            style: pw.TextStyle(
                color: color, fontSize: 13, fontWeight: pw.FontWeight.bold)),
      ]),
    );
  }

  pw.Widget _buildStatCol(String label, String value) {
    return pw.Expanded(
        child: pw.Column(children: [
      pw.Text(value,
          style: pw.TextStyle(
              color: _textDark, fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      pw.Text(label, style: pw.TextStyle(color: _textMid, fontSize: 9)),
    ]));
  }

  Future<Directory> _getReportsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${appDir.path}/SIERCP/reportes');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    return reportsDir;
  }
}
