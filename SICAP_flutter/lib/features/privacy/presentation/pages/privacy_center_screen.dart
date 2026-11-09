import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/core/services/privacy_service.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Derechos del titular (Ley 1581, art. 8): conocer, actualizar, rectificar,
/// pedir prueba de la autorización, revocarla y pedir la supresión.
class PrivacyCenterScreen extends ConsumerStatefulWidget {
  const PrivacyCenterScreen({super.key});

  @override
  ConsumerState<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends ConsumerState<PrivacyCenterScreen> {
  final _service = PrivacyService();
  bool _busy = false;

  static const _requestTypes = {
    'access': 'Consultar qué datos tienen sobre mí',
    'rectification': 'Corregir o actualizar mis datos',
    'revocation': 'Revocar mi autorización',
    'deletion': 'Eliminar mi cuenta y mis datos',
    'complaint': 'Presentar un reclamo',
  };

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _snack(e.toString());
    }
    if (mounted) setState(() => _busy = false);
  }

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _download() => _run(() async {
        final file = await _service.exportData();
        await Share.shareXFiles([XFile(file.path)], text: 'Mis datos en SICAP');
      });

  Future<void> _openRequest(String type) async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_requestTypes[type]!),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 2000,
          decoration: const InputDecoration(hintText: 'Cuéntanos qué necesitas'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Enviar')),
        ],
      ),
    );
    controller.dispose();
    if (message == null || message.isEmpty) return;
    await _run(() async {
      final due = await _service.request(type, message);
      _snack('Solicitud enviada. Te responderemos por correo a más tardar el ${DateFormat('d/MM/yyyy').format(due)}.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad y datos')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Autorización vigente'),
              subtitle: Text(user?.privacyPolicyVersion == null
                  ? 'Sin autorización registrada'
                  : 'Política del ${user!.privacyPolicyVersion}'),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.campaign_outlined),
              title: const Text('Recibir novedades y ofertas'),
              subtitle: const Text('Opcional. No afecta tus cursos.'),
              value: user?.marketingConsent ?? false,
              onChanged: (v) => _run(() => _service.setMarketing(v)),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Descargar mis datos'),
              subtitle: const Text('Perfil, sesiones, autorizaciones y certificados en un archivo.'),
              onTap: _download,
            ),
            ListTile(
              leading: const Icon(Icons.policy_outlined),
              title: const Text('Leer la política de tratamiento'),
              onTap: () => launchUrl(Uri.parse(AppConstants.privacyPolicyUrl),
                  mode: LaunchMode.externalApplication),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Solicitudes. Consultas: respuesta en 10 días hábiles. '
                  'Reclamos, correcciones y eliminación: 15 días hábiles.'),
            ),
            for (final entry in _requestTypes.entries)
              ListTile(
                leading: Icon(entry.key == 'deletion' ? Icons.delete_outline : Icons.mail_outline),
                title: Text(entry.value),
                onTap: () => _openRequest(entry.key),
              ),
          ],
        ),
      ),
    );
  }
}
