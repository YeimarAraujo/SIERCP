import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/core/data/colombia_geo.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/auth/data/firebase_auth_service.dart';
import 'package:siercp/l10n/app_localizations.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  String _docType = 'CC';
  String _department = '';
  String _city = '';
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _acceptedPrivacy = false;
  String? _error;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _idCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final loc = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedPrivacy) {
      setState(() => _error = loc.registerPrivacyError);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authStateProvider.notifier).register(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
            firstName: _firstNameCtrl.text.trim(),
            lastName: _lastNameCtrl.text.trim(),
            role: AppConstants.roleUsuario,
            identificacion: _idCtrl.text.trim(),
            documentType: _docType,
            department: _department.isEmpty ? null : _department,
            city: _city.isEmpty ? null : _city,
            phoneNumber:
                _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          );
      if (mounted) {
        context.go('/home');
        return;
      }
    } catch (e) {
      setState(() => _error = FirebaseAuthService.parseAuthError(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.privacyPolicy,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Text(
            '1. Introducción\n\nEl Sistema de Entrenamiento en RCP se compromete a proteger la privacidad y seguridad de la información personal de sus usuarios. Esta política explica cómo recopilamos, usamos, almacenamos y protegemos los datos personales conforme a la normativa vigente en Colombia (Ley 1581 de 2012 y normas complementarias).\n\n2. Información que Recopilamos\n\nPodemos recopilar la siguiente información:\n\nDatos personales: nombre completo, número de identificación, correo electrónico, número de teléfono.\nDatos académicos o profesionales: institución, cargo, certificaciones previas.\nDatos de uso del sistema: progreso en módulos, resultados de evaluaciones, fechas de acceso.\nInformación técnica: dirección IP, tipo de dispositivo y navegador.\n\n3. Finalidad del Tratamiento de Datos\n\nLa información recopilada será utilizada para:\n\nGestionar el registro y acceso al sistema.\nRealizar seguimiento del progreso del usuario en los módulos de RCP.\nEmitir certificados de participación o aprobación.\nEnviar información relevante sobre capacitaciones o actualizaciones.\nMejorar la calidad del servicio y la experiencia del usuario.\n\n4. Almacenamiento y Seguridad\n\nLa información será almacenada en bases de datos seguras y se implementarán medidas técnicas, administrativas y organizativas para evitar acceso no autorizado, pérdida o alteración de la información.\n\n5. Compartición de Información\n\nLos datos personales no serán vendidos ni compartidos con terceros, salvo:\n\nCuando sea requerido por autoridad competente.\nCuando sea necesario para emitir certificaciones oficiales.\nCuando el usuario otorgue autorización expresa.\n\n6. Derechos del Usuario\n\nDe acuerdo con la legislación colombiana, el usuario tiene derecho a:\n\nConocer, actualizar y rectificar sus datos personales.\nSolicitar prueba de la autorización otorgada.\nRevocar la autorización o solicitar la eliminación de sus datos.\nPresentar quejas ante la Superintendencia de Industria y Comercio.\n\n7. Uso de Cookies\n\nEl sistema puede utilizar cookies para mejorar la experiencia de navegación y analizar el uso de la plataforma.\n\n8. Modificaciones a la Política\n\nNos reservamos el derecho de actualizar esta política en cualquier momento. Los cambios serán publicados en la plataforma.\n\n9. Contacto\n\nPara consultas relacionadas con la privacidad y tratamiento de datos, puede comunicarse a través del correo electrónico oficial del sistema.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(context)!.closeButton),
          ),
        ],
      ),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  List<DropdownMenuItem<String>> _docTypeItems() => documentTypes.entries
      .map((e) => DropdownMenuItem(
          value: e.key,
          child:
              Text('${e.key} — ${e.value}', overflow: TextOverflow.ellipsis)))
      .toList();

  List<DropdownMenuItem<String>> _departmentItems() => [
        const DropdownMenuItem(
            value: '', child: Text('Selecciona un departamento')),
        ...colombiaDepartments
            .map((d) => DropdownMenuItem(value: d, child: Text(d))),
      ];

  List<DropdownMenuItem<String>> _cityItems() {
    if (_department.isEmpty) {
      return [
        const DropdownMenuItem(
            value: '', child: Text('Selecciona un departamento'))
      ];
    }
    return [
      const DropdownMenuItem(value: '', child: Text('Selecciona un municipio')),
      ...getMunicipalities(_department)
          .map((c) => DropdownMenuItem(value: c, child: Text(c))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final loc = AppLocalizations.of(context)!;

    final dropDecor = InputDecoration(
      border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textP, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(loc.registerTitle,
            style: TextStyle(
                color: textP, fontSize: 24, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(loc.registerSubtitle,
                    style: TextStyle(color: textS, fontSize: 14)),
                const SizedBox(height: 18),

                // ── Info banner ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: AppColors.brand.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: AppColors.brand),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Para obtener certificaciones necesitas subir tu licencia SST o certificados profesionales. Las instituciones pueden certificarte directamente al estar afiliado.',
                          style: TextStyle(
                              color: AppColors.brand,
                              fontSize: 12,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Nombre y apellido ────────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: loc.firstName,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? loc.requiredField
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: loc.lastName,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? loc.requiredField
                          : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 14),

                // ── Tipo de documento ────────────────────────────────────────
                DropdownButtonFormField<String>(
                  value: _docType,
                  isExpanded: true,
                  decoration: dropDecor.copyWith(
                    labelText: 'Tipo de documento',
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  items: _docTypeItems(),
                  selectedItemBuilder: (context) => documentTypes.entries
                      .map((e) => Text('${e.key} — ${e.value}',
                          overflow: TextOverflow.ellipsis))
                      .toList(growable: false),
                  onChanged: (v) => setState(() => _docType = v ?? 'CC'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? loc.requiredField : null,
                ),
                const SizedBox(height: 14),

                // ── Número de documento ──────────────────────────────────────
                TextFormField(
                  controller: _idCtrl,
                  keyboardType: (_docType == 'CC' || _docType == 'TI')
                      ? TextInputType.number
                      : TextInputType.text,
                  inputFormatters: (_docType == 'CC' || _docType == 'TI')
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : [],
                  decoration: InputDecoration(
                    labelText: documentTypes[_docType] ?? 'Número de documento',
                    hintText: _docType == 'NIT' ? '900000000-1' : 'Número',
                    prefixIcon: const Icon(Icons.credit_card_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return loc.requiredField;
                    if (v.trim().length < 4) return 'Mínimo 4 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Departamento ────────────────────────────────────────────
                DropdownButtonFormField<String>(
                  value: _department.isEmpty ? '' : _department,
                  decoration: dropDecor.copyWith(
                    labelText: 'Departamento',
                    prefixIcon: const Icon(Icons.map_outlined),
                  ),
                  items: _departmentItems(),
                  onChanged: (v) => setState(() {
                    _department = v ?? '';
                    _city = '';
                  }),
                ),
                const SizedBox(height: 14),

                // ── Ciudad / Municipio ───────────────────────────────────────
                DropdownButtonFormField<String>(
                  value: _city.isEmpty ? '' : _city,
                  decoration: dropDecor.copyWith(
                    labelText: 'Ciudad / Municipio',
                    prefixIcon: const Icon(Icons.location_city_outlined),
                  ),
                  items: _cityItems(),
                  onChanged: _department.isEmpty
                      ? null
                      : (v) => setState(() => _city = v ?? ''),
                ),
                const SizedBox(height: 14),

                // ── Teléfono (opcional) ──────────────────────────────────────
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]'))
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    hintText: '+57 300 000 0000',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final digits = v.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 7) return 'Mínimo 7 dígitos';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Email ────────────────────────────────────────────────────
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: loc.emailLabel,
                    hintText: loc.emailHint,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return loc.requiredField;
                    if (!RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$')
                        .hasMatch(v.trim())) {
                      return loc.invalidEmail;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Contraseña ───────────────────────────────────────────────
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: loc.passwordLabel,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                      icon: Icon(
                          _obscurePass
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 10) return loc.min6Chars;
                    if (!v.contains(RegExp(r'[A-Z]')) ||
                        !v.contains(RegExp(r'[0-9]'))) {
                      return 'Debe incluir mayúsculas y números';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Confirmar contraseña ─────────────────────────────────────
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return loc.requiredField;
                    if (v != _passCtrl.text)
                      return 'Las contraseñas no coinciden';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ── Indicador de fortaleza ───────────────────────────────────
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _passCtrl,
                  builder: (_, val, __) {
                    if (val.text.isEmpty) return const SizedBox.shrink();
                    return _PasswordStrengthBar(password: val.text);
                  },
                ),
                const SizedBox(height: 16),

                // ── Política de privacidad ───────────────────────────────────
                Row(children: [
                  Checkbox(
                    value: _acceptedPrivacy,
                    onChanged: (v) =>
                        setState(() => _acceptedPrivacy = v ?? false),
                    activeColor: AppColors.brand,
                  ),
                  Text(loc.acceptPrivacy1,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _showPrivacyPolicy,
                    child: Text(loc.acceptPrivacy2,
                        style: const TextStyle(
                            color: AppColors.brand,
                            decoration: TextDecoration.underline,
                            fontSize: 13)),
                  ),
                ]),
                const SizedBox(height: 14),

                // ── Error ────────────────────────────────────────────────────
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.redBg,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: AppColors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.red, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppColors.red, fontSize: 13))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Botón registrar ──────────────────────────────────────────
                ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(loc.registerTitle),
                ),
                const SizedBox(height: 20),

                // ── Link institución ─────────────────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: () => context.push('/register-institution'),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13, color: textS),
                        children: const [
                          TextSpan(
                              text: '¿Representas una institución o empresa? '),
                          TextSpan(
                            text: 'Regístrate aquí',
                            style: TextStyle(
                                color: AppColors.brand,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Password strength indicator ───────────────────────────────────────────────

class _PasswordStrengthBar extends StatelessWidget {
  final String password;
  const _PasswordStrengthBar({required this.password});

  static int _score(String p) {
    int s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final score = _score(password);
    final color = [
      AppColors.red,
      AppColors.amber,
      AppColors.cyan,
      AppColors.green
    ][score.clamp(0, 3)];
    final labels = ['Muy débil', 'Débil', 'Buena', 'Fuerte'];
    final label = password.length < 6 ? 'Muy débil' : labels[score.clamp(0, 3)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
            children: List.generate(
                4,
                (i) => Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                        decoration: BoxDecoration(
                          color:
                              i < score ? color : color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ))),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
