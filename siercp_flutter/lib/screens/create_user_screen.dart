import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../services/admin_service.dart';
import '../services/firebase_auth_service.dart';

class CreateUserScreen extends ConsumerStatefulWidget {
  const CreateUserScreen({super.key});

  @override
  ConsumerState<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends ConsumerState<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  String _selectedRole = AppConstants.roleStudent;
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  bool _success = false;
  String _createdName = '';

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _success = false;
    });

    try {
      final svc = ref.read(adminServiceProvider);
      final user = await svc.adminCreateUser(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        role: _selectedRole,
        identificacion:
            _idCtrl.text.trim().isEmpty ? null : _idCtrl.text.trim(),
      );

      // Invalidar lista de usuarios para refrescar
      ref.invalidate(allUsersProvider);

      setState(() {
        _success = true;
        _createdName = user.fullName;
      });

      // Limpiar formulario para crear otro
      _firstNameCtrl.clear();
      _lastNameCtrl.clear();
      _emailCtrl.clear();
      _idCtrl.clear();
      _passCtrl.clear();
    } catch (e) {
      setState(() => _error = FirebaseAuthService.parseAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final bg = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text('Crear Usuario'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────
                _HeaderBanner(isDark: isDark, textP: textP, textS: textS),
                const SizedBox(height: 28),

                // ── Selector de Rol ──────────────────────────
                _RoleSelector(
                  selected: _selectedRole,
                  onChanged: (r) => setState(() => _selectedRole = r),
                  isDark: isDark,
                ),
                const SizedBox(height: 24),

                // ── Nombre y Apellido ────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Apellido',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Cédula ───────────────────────────────────
                TextFormField(
                  controller: _idCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Número de identificación / Cédula',
                    hintText: 'Ej: 1234567890',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    if (v.trim().length < 5) return 'Mínimo 5 dígitos';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Email ────────────────────────────────────
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    hintText: 'usuario@siercp.edu.co',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (!v.contains('@')) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Contraseña ───────────────────────────────
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Contraseña temporal',
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
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Mínimo 6 caracteres'
                      : null,
                ),
                const SizedBox(height: 28),

                // ── Feedback: Error ───────────────────────────
                if (_error != null) ...[
                  _FeedbackBanner(
                    isSuccess: false,
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Feedback: Éxito ───────────────────────────
                if (_success) ...[
                  _FeedbackBanner(
                    isSuccess: true,
                    message: '¡$_createdName creado exitosamente!',
                    onDismiss: () => setState(() => _success = false),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Botón Crear ──────────────────────────────
                ElevatedButton.icon(
                  onPressed: _loading ? null : _create,
                  icon: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add_outlined),
                  label: Text(_loading ? 'Creando…' : 'Crear usuario'),
                ),
                const SizedBox(height: 12),

                // ── Botón Volver al directorio ────────────────
                OutlinedButton.icon(
                  onPressed: () => context.go('/admin/users'),
                  icon: const Icon(Icons.group_outlined, size: 18),
                  label: const Text('Ver directorio de usuarios'),
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

class _HeaderBanner extends StatelessWidget {
  final bool isDark;
  final Color textP;
  final Color textS;
  const _HeaderBanner(
      {required this.isDark, required this.textP, required this.textS});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brand.withValues(alpha: isDark ? 0.25 : 0.12),
            AppColors.accent.withValues(alpha: isDark ? 0.15 : 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.admin_panel_settings_outlined,
                color: AppColors.brand, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registro administrativo',
                    style: TextStyle(
                      color: textP,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    )),
                const SizedBox(height: 2),
                Text(
                  'Crea cuentas para instructores y estudiantes.\n'
                  'Tu sesión de admin no se verá afectada.',
                  style: TextStyle(color: textS, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final bool isDark;
  const _RoleSelector({
    required this.selected,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rol del nuevo usuario',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
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
                label: 'Estudiante',
                color: AppColors.cyan,
                isSelected: selected == AppConstants.roleStudent,
                onTap: () => onChanged(AppConstants.roleStudent),
              ),
              _RoleTab(
                icon: Icons.school_outlined,
                label: 'Instructor',
                color: AppColors.accent,
                isSelected: selected == AppConstants.roleInstructor,
                onTap: () => onChanged(AppConstants.roleInstructor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleTab({
    required this.icon,
    required this.label,
    required this.color,
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
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.30),
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
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
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

class _FeedbackBanner extends StatelessWidget {
  final bool isSuccess;
  final String message;
  final VoidCallback onDismiss;
  const _FeedbackBanner({
    required this.isSuccess,
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? AppColors.green : AppColors.red;
    final bgColor = isSuccess ? AppColors.greenBg : AppColors.redBg;
    final icon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Text(message, style: TextStyle(color: color, fontSize: 13))),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close, color: color, size: 16),
          ),
        ],
      ),
    );
  }
}
