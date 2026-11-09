import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:siercp/core/constants/constants.dart';

import '../../data/models/user_skill.dart';

/// Enlace público donde cualquiera comprueba si la competencia es válida o fue revocada.
String verificationUrl(String skillCode) => '${AppConstants.webBaseUrl}/verify/$skillCode';

/// Certificado con QR de verificación: se muestra, se comparte y se descarga en PDF.
class SkillCertificateSheet extends StatelessWidget {
  const SkillCertificateSheet({super.key, required this.skill, required this.holderName});

  final UserSkill skill;
  final String holderName;

  static Future<void> show(BuildContext context, UserSkill skill, String holderName) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => SkillCertificateSheet(skill: skill, holderName: holderName),
      );

  @override
  Widget build(BuildContext context) {
    final url = verificationUrl(skill.skillCode);
    final revoked = skill.status == 'REVOKED';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(skill.skillName, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            Text('Nivel ${skill.levelLabel} · ${skill.issuedByName}', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (revoked)
              const Text('Esta competencia fue revocada.', style: TextStyle(color: Colors.red))
            else
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(data: url, size: 200),
              ),
            const SizedBox(height: 8),
            SelectableText(skill.skillCode, style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 4),
            const Text('Escanéalo para verificar la competencia.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            if (!revoked)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Compartir'),
                      onPressed: () => Share.share('Verifica mi competencia "${skill.skillName}": $url'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('PDF'),
                      onPressed: () async => Printing.sharePdf(
                        bytes: await buildCertificatePdf(skill, holderName),
                        filename: 'certificado-${skill.skillCode}.pdf',
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// PDF de una página con los datos de la competencia y el QR de verificación.
Future<Uint8List> buildCertificatePdf(UserSkill skill, String holderName) async {
  final doc = pw.Document(title: 'Certificado ${skill.skillCode}', author: 'SICAP');
  final issued = skill.issuedAt != null ? DateFormat('dd/MM/yyyy').format(skill.issuedAt!) : '';
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (_) => pw.Container(
        padding: const pw.EdgeInsets.all(32),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.teal, width: 3)),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('SICAP', style: pw.TextStyle(fontSize: 18, color: PdfColors.teal, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Text('Certificado de competencia', style: const pw.TextStyle(fontSize: 28)),
            pw.SizedBox(height: 20),
            pw.Text('Se certifica que', style: const pw.TextStyle(fontSize: 14)),
            pw.Text(holderName, style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Text('demostró la competencia', style: const pw.TextStyle(fontSize: 14)),
            pw.Text(skill.skillName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Nivel ${skill.levelLabel} · emitido por ${skill.issuedByName}', style: const pw.TextStyle(fontSize: 13)),
            if (issued.isNotEmpty) pw.Text('Fecha de emisión: $issued', style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 20),
            pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: verificationUrl(skill.skillCode), width: 110, height: 110),
            pw.SizedBox(height: 6),
            pw.Text('Código ${skill.skillCode} · Verifícalo en ${verificationUrl(skill.skillCode)}',
                style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
    ),
  );
  return doc.save();
}
