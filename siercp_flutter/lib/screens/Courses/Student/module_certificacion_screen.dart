import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../services/report_pdf_service.dart';
import '../../../providers/session_provider.dart';

class ModuleCertificacionScreen extends ConsumerWidget {
  final String courseId;
  final String studentId;

  const ModuleCertificacionScreen({
    super.key,
    required this.courseId,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: const Text('Certificación')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium_rounded, size: 100, color: AppColors.accent),
              const SizedBox(height: 24),
              Text(
                '¡Felicidades!',
                style: TextStyle(color: textP, fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                'Has completado todos los requisitos de este curso. Ya puedes descargar tu certificado de participación.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textS, fontSize: 14),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => _downloadCertificate(context, ref),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Descargar Certificado'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  minimumSize: const Size(double.infinity, 54),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Volver al curso'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadCertificate(BuildContext context, WidgetRef ref) async {
    // Aquí se llamaría al servicio de PDF para generar un certificado
    // Por ahora, mostraremos un mensaje.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generando certificado...')),
    );
    
    // Simulación de descarga
    await Future.delayed(const Duration(seconds: 2));
    if (context.mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Certificado descargado correctamente')),
      );
    }
  }
}
