import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/core/services/privacy_service.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Autorización de tratamiento de datos (Ley 1581 de 2012).
///
/// Aparece a quien no ha aceptado la política vigente: cuentas nuevas, cuentas
/// creadas por una institución o importadas, y todos cuando la política cambia.
/// Si es menor de edad, autoriza su representante legal.
class ConsentGateScreen extends ConsumerStatefulWidget {
  const ConsentGateScreen({super.key});

  @override
  ConsumerState<ConsentGateScreen> createState() => _ConsentGateScreenState();
}

class _ConsentGateScreenState extends ConsumerState<ConsentGateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _guardianName = TextEditingController();
  final _guardianDocument = TextEditingController();
  final _guardianEmail = TextEditingController();
  String _guardianDocumentType = 'CC';
  String _relationship = 'Madre';
  DateTime? _birthDate;
  bool _authorizes = false;
  bool _marketing = false;
  bool _saving = false;
  String? _error;

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    final saved = ref.read(currentUserProvider)?.birthDate;
    if (saved != null) _birthDate = DateTime.tryParse(saved);
  }

  @override
  void dispose() {
    _guardianName.dispose();
    _guardianDocument.dispose();
    _guardianEmail.dispose();
    super.dispose();
  }

  bool get _isMinor {
    final birth = _birthDate;
    if (birth == null) return false;
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) age--;
    return age < 18;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _accept() async {
    if (_birthDate == null) {
      setState(() => _error = 'Indica tu fecha de nacimiento.');
      return;
    }
    if (!_authorizes) {
      setState(() => _error = 'Debes autorizar el tratamiento de datos para usar SICAP.');
      return;
    }
    if (_isMinor && !_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await PrivacyService().recordConsent(
        birthDate: _dateFormat.format(_birthDate!),
        marketing: _marketing,
        guardian: _isMinor
            ? Guardian(
                name: _guardianName.text.trim(),
                documentType: _guardianDocumentType,
                document: _guardianDocument.text.trim(),
                relationship: _relationship,
                email: _guardianEmail.text.trim(),
              )
            : null,
      );
      // El documento del usuario se actualiza en el servidor; la ruta se
      // libera cuando llega ese cambio (ver el listener en build).
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProvider, (_, user) {
      if (user?.privacyPolicyVersion == AppConstants.privacyPolicyVersion) context.go('/home');
    });

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tratamiento de datos personales'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Salir'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Antes de continuar necesitamos tu autorización, como exige la '
                'Ley 1581 de 2012.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Usamos tus datos de identificación, contacto y práctica de RCP para '
                'tu formación, tus certificados, el seguimiento de tu instructor y '
                'las obligaciones legales. Puedes conocer, actualizar y rectificar '
                'tus datos, pedir su supresión y revocar esta autorización desde '
                '"Privacidad y datos" en el menú.',
              ),
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(AppConstants.privacyPolicyUrl),
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Leer la política completa'),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cake_outlined),
                title: const Text('Fecha de nacimiento'),
                subtitle: Text(_birthDate == null ? 'Toca para elegir' : _dateFormat.format(_birthDate!)),
                onTap: _pickBirthDate,
              ),
              if (_isMinor) ..._guardianFields(theme),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _authorizes,
                onChanged: (v) => setState(() => _authorizes = v ?? false),
                title: Text(_isMinor
                    ? 'Como representante legal, autorizo el tratamiento de los datos del menor según la política.'
                    : 'Autorizo el tratamiento de mis datos personales según la política.'),
                subtitle: const Text('Obligatorio para usar SICAP.'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _marketing,
                onChanged: (v) => setState(() => _marketing = v ?? false),
                title: const Text('Acepto recibir novedades y ofertas de cursos.'),
                subtitle: const Text('Opcional. Puedes cambiarlo cuando quieras.'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.red)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _accept,
                child: Text(_saving ? 'Guardando…' : 'Aceptar y continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _guardianFields(ThemeData theme) => [
        const SizedBox(height: 8),
        Text('Eres menor de edad', style: theme.textTheme.titleSmall),
        const Text('Tu madre, padre o representante legal debe autorizar. Completa sus datos.'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _guardianName,
          decoration: const InputDecoration(labelText: 'Nombre completo del representante'),
          validator: (v) => (v ?? '').trim().length < 3 ? 'Escribe el nombre' : null,
        ),
        Row(children: [
          SizedBox(
            width: 96,
            child: DropdownButtonFormField<String>(
              initialValue: _guardianDocumentType,
              items: const ['CC', 'CE', 'PA']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _guardianDocumentType = v ?? 'CC'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _guardianDocument,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Documento'),
              validator: (v) => (v ?? '').trim().length < 4 ? 'Escribe el documento' : null,
            ),
          ),
        ]),
        DropdownButtonFormField<String>(
          initialValue: _relationship,
          decoration: const InputDecoration(labelText: 'Parentesco'),
          items: const ['Madre', 'Padre', 'Tutor legal']
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => setState(() => _relationship = v ?? 'Madre'),
        ),
        TextFormField(
          controller: _guardianEmail,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Correo del representante'),
          validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((v ?? '').trim())
              ? null
              : 'Escribe un correo válido',
        ),
        const SizedBox(height: 8),
      ];
}
