import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/session.dart';
import '../models/alert_course.dart';

final exportServiceProvider = Provider<ExportService>((ref) => ExportService());

class ExportService {
  // ─── Exportar sesión individual como PDF ───────────────────────────────────
  Future<void> exportSessionPDF(SessionModel session, SessionMetrics metrics) async {
    final pdf = pw.Document();
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final sessionDate = DateFormat('dd/MM/yyyy HH:mm').format(session.startedAt);

    // Colores de marca
    final brandColor = PdfColor.fromHex('1800AD');
    final greenColor = PdfColor.fromHex('00C853');
    final redColor   = PdfColor.fromHex('FF3B5C');
    final amberColor = PdfColor.fromHex('FFAB00');
    final greyLight  = PdfColor.fromHex('F2F4F8');
    final greyBorder = PdfColor.fromHex('E5E7F0');
    final textDark   = PdfColor.fromHex('1A1A2E');
    final textMid    = PdfColor.fromHex('5A5C7A');

    final scoreColor = metrics.approved
        ? greenColor
        : metrics.score >= 70
            ? amberColor
            : redColor;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          // ── Header ──────────────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: brandColor,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SIERCP',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Reporte de Sesión RCP',
                      style: pw.TextStyle(
                        color: PdfColor.fromHex('CCCCFF'),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Generado: $now',
                      style: pw.TextStyle(
                        color: PdfColor.fromHex('CCCCFF'),
                        fontSize: 9,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'AHA Guidelines 2020',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Información de sesión ─────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: greyLight,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Escenario', style: pw.TextStyle(color: textMid, fontSize: 9)),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        session.scenarioTitle ?? 'Sesión RCP',
                        style: pw.TextStyle(color: textDark, fontSize: 13, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Fecha de sesión', style: pw.TextStyle(color: textMid, fontSize: 9)),
                      pw.SizedBox(height: 2),
                      pw.Text(sessionDate, style: pw.TextStyle(color: textDark, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Duración', style: pw.TextStyle(color: textMid, fontSize: 9)),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        session.durationFormatted,
                        style: pw.TextStyle(color: textDark, fontSize: 13, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Score ──────────────────────────────────────────────────────────
          pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: scoreColor, width: 2),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    '${metrics.score.toStringAsFixed(0)}%',
                    style: pw.TextStyle(
                      color: scoreColor,
                      fontSize: 48,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    metrics.approved ? '✓ APROBADO' : '✗ REPROBADO',
                    style: pw.TextStyle(
                      color: scoreColor,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Parámetros AHA ─────────────────────────────────────────────────
          pw.Text(
            'PARÁMETROS EVALUADOS — AHA 2020',
            style: pw.TextStyle(
              color: textMid,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 8),

          ..._buildParamRows(metrics, textDark, textMid, greenColor, redColor, greyBorder),
          pw.SizedBox(height: 20),

          // ── Correcciones ───────────────────────────────────────────────────
          if (metrics.violations.isNotEmpty) ...[
            pw.Text(
              'CORRECCIONES NECESARIAS',
              style: pw.TextStyle(
                color: textMid,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            pw.SizedBox(height: 8),
            ...metrics.violations.map(
              (v) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('FFF0F0'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  children: [
                    pw.Text('⚠', style: pw.TextStyle(color: redColor, fontSize: 14)),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(v.message, style: pw.TextStyle(color: textDark, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          pw.Text('${v.count} ocurrencia(s)', style: pw.TextStyle(color: textMid, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Footer ──────────────────────────────────────────────────────────
          pw.SizedBox(height: 20),
          pw.Divider(color: greyBorder),
          pw.SizedBox(height: 8),
          pw.Text(
            'Este reporte fue generado por SIERCP — Sistema Inteligente de Entrenamiento RCP.\nCertificación basada en Guías AHA 2020. Para uso educativo y de entrenamiento únicamente.',
            style: pw.TextStyle(color: textMid, fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );

    // Save and share
    final dir = await getTemporaryDirectory();
    final safeDate = DateFormat('yyyyMMdd_HHmm').format(session.startedAt);
    final file = File('${dir.path}/SIERCP_Sesion_$safeDate.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Reporte de Sesión RCP — ${session.scenarioTitle ?? 'SIERCP'}',
    );
  }

  // ─── Exportar historial como CSV ───────────────────────────────────────────
  Future<void> exportHistoryCSV(List<SessionModel> sessions) async {
    final buffer = StringBuffer();

    // CSV header
    buffer.writeln(
      'ID,Escenario,Fecha,Duración (s),Score (%),Aprobado,Compresiones,Profundidad Prom (mm),Frecuencia Prom (/min),Compresiones correctas (%),Pausas,Max Pausa (s)',
    );

    for (final s in sessions) {
      final m = s.metrics;
      buffer.writeln([
        s.id,
        '"${s.scenarioTitle ?? 'RCP'}"',
        DateFormat('yyyy-MM-dd HH:mm').format(s.startedAt),
        s.duration.inSeconds,
        m?.score.toStringAsFixed(1) ?? '',
        m?.approved == true ? 'Sí' : 'No',
        m?.totalCompressions ?? '',
        m?.averageDepthMm.toStringAsFixed(1) ?? '',
        m?.averageRatePerMin.toStringAsFixed(1) ?? '',
        m?.correctCompressionsPct.toStringAsFixed(1) ?? '',
        m?.interruptionCount ?? '',
        m?.maxPauseSeconds.toStringAsFixed(1) ?? '',
      ].join(','));
    }

    final dir = await getTemporaryDirectory();
    final now = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/SIERCP_Historial_$now.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Historial de Sesiones RCP — SIERCP',
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  List<pw.Widget> _buildParamRows(
    SessionMetrics metrics,
    PdfColor textDark,
    PdfColor textMid,
    PdfColor greenColor,
    PdfColor redColor,
    PdfColor greyBorder,
  ) {
    final params = [
      (
        'Profundidad promedio',
        '${metrics.averageDepthMm.toStringAsFixed(1)} mm',
        '50 – 60 mm',
        metrics.depthOk,
      ),
      (
        'Frecuencia promedio',
        '${metrics.averageRatePerMin.toStringAsFixed(0)} /min',
        '100 – 120 /min',
        metrics.rateOk,
      ),
      (
        'Compresiones correctas',
        '${metrics.correctCompressionsPct.toStringAsFixed(1)}%',
        'Meta: ≥ 85%',
        metrics.correctCompressionsPct >= 85,
      ),
      (
        'Pausa máxima',
        '${metrics.maxPauseSeconds.toStringAsFixed(1)} s',
        'Máx: 10 s',
        metrics.maxPauseSeconds <= 10,
      ),
      (
        'Total compresiones',
        '${metrics.totalCompressions}',
        '',
        true,
      ),
      (
        'Interrupciones detectadas',
        '${metrics.interruptionCount}',
        'Meta: 0',
        metrics.interruptionCount == 0,
      ),
    ];

    return params.map((p) {
      final (label, value, range, ok) = p;
      final color = ok ? greenColor : redColor;
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: greyBorder),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          children: [
            pw.Text(ok ? '✓' : '✗', style: pw.TextStyle(color: color, fontSize: 14)),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(label, style: pw.TextStyle(color: textDark, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  if (range.isNotEmpty)
                    pw.Text(range, style: pw.TextStyle(color: textMid, fontSize: 9)),
                ],
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(color: color, fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );
    }).toList();
  }
  // ─── Exportar notas de estudiantes de un curso como CSV ───────────────────
  Future<void> exportCourseGradesCSV(
    CourseModel course,
    List<Map<String, dynamic>> students,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln('SIERCP — Notas del Curso: ${course.title}');
    buffer.writeln(
        'Exportado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
    buffer.writeln();
    buffer.writeln(
        'Estudiante,Identificación,Email,Sesiones,Promedio (%),Aprobado');

    for (final s in students) {
      final name = '"${s['studentName'] ?? 'Estudiante'}"';
      final cedula = s['identificacion'] ?? '';
      final email = s['studentEmail'] ?? '';
      final sessions = s['sessionCount'] ?? 0;
      final avg = (s['avgScore'] as num?)?.toDouble() ?? 0.0;
      final approved = avg >= 85 ? 'Sí' : 'No';

      buffer.writeln('$name,$cedula,$email,$sessions,${avg.toStringAsFixed(1)},$approved');
    }

    final dir = await getTemporaryDirectory();
    final safe = course.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final now = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/SIERCP_Notas_${safe}_$now.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Notas del Curso — ${course.title}',
    );
  }
}
