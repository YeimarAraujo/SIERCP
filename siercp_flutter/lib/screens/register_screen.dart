import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_auth_service.dart';
import 'package:siercp/l10n/app_localizations.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _idCtrl        = TextEditingController();
  final _passCtrl      = TextEditingController();

  String _selectedRole = AppConstants.roleStudent;
  bool _obscure  = true;
  bool _loading  = false;
  bool _acceptedPrivacy = false;
  String? _error;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final loc = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedPrivacy) {
      setState(() => _error = loc.registerPrivacyError);
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      await ref.read(authStateProvider.notifier).register(
        email:          _emailCtrl.text.trim(),
        password:       _passCtrl.text,
        firstName:      _firstNameCtrl.text.trim(),
        lastName:       _lastNameCtrl.text.trim(),
        role:           _selectedRole,
        identificacion: _idCtrl.text.trim(),
      );
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = FirebaseAuthService.parseAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.privacyPolicy, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP  = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS  = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final loc    = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textP, size: 20),
          onPressed: () => context.pop(),
        ),
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
                Text(
                  loc.registerTitle,
                  style: TextStyle(
                    color: textP, fontSize: 28, fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  loc.registerSubtitle,
                  style: TextStyle(color: textS, fontSize: 14),
                ),
                const SizedBox(height: 28),

                // Role selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg2 : AppColors.lightBg2,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      _RoleTab(
                        icon: Icons.person_outline,
                        label: loc.roleStudentLabel,
                        isSelected: _selectedRole == AppConstants.roleStudent,
                        onTap: () => setState(() => _selectedRole = AppConstants.roleStudent),
                      ),
                      _RoleTab(
                        icon: Icons.school_outlined,
                        label: loc.roleInstructorLabel,
                        isSelected: _selectedRole == AppConstants.roleInstructor,
                        onTap: () => setState(() => _selectedRole = AppConstants.roleInstructor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Name row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: loc.firstName,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? loc.requiredField : null,
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
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? loc.requiredField : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Identificación
                TextFormField(
                  controller: _idCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: loc.idLabel,
                    hintText: loc.idHint,
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return loc.requiredField;
                    if (v.trim().length < 5) return loc.min5Digits;
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Email
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
                    if (!v.contains('@')) return loc.invalidEmail;
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Password
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: loc.passwordLabel,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? loc.min6Chars : null,
                ),
                const SizedBox(height: 28),

                // Privacy Policy Checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _acceptedPrivacy,
                      onChanged: (v) => setState(() => _acceptedPrivacy = v ?? false),
                      activeColor: AppColors.brand,
                    ),
                    Text(
                      loc.acceptPrivacy1,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: _showPrivacyPolicy,
                      child: Text(
                        loc.acceptPrivacy2,
                        style: const TextStyle(
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.blue,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Error
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.redBg,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.red, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppColors.red, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white,
                          ),
                        )
                      : Text(loc.registerTitle),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.brand.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

