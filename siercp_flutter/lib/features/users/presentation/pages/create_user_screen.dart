import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/core/providers/org_context_provider.dart';
import 'package:siercp/core/services/firestore_service.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart'
    show currentUserProvider;
import 'package:siercp/core/services/tenant_service.dart';
import 'package:siercp/features/auth/data/firebase_auth_service.dart';
import 'package:siercp/features/users/data/admin_service.dart';
import 'package:siercp/features/users/data/user_org_repository.dart';

class CreateUserScreen extends ConsumerStatefulWidget {
  const CreateUserScreen({super.key});

  @override
  ConsumerState<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends ConsumerState<CreateUserScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _firstCtrl = TextEditingController();
  final _lastCtrl  = TextEditingController();
  final _idCtrl    = TextEditingController();
  final _passCtrl  = TextEditingController();

  String  _selectedRole = AppConstants.roleUsuario;
  bool    _obscure      = true;
  bool    _loading      = false;
  bool    _showPass     = false;
  String? _error;
  InviteResult? _result;

  bool _emailChecked = false;
  bool _userExists   = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Paso 1: verificar si el email ya existe en el sistema ─────────────────

  Future<void> _checkEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Ingresa un correo válido.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final existing =
          await ref.read(firestoreServiceProvider).getUserByEmail(email);
      setState(() {
        _userExists   = existing != null;
        _emailChecked = true;
        _showPass     = existing == null;
        if (existing != null) {
          _firstCtrl.text = existing.firstName;
          _lastCtrl.text  = existing.lastName;
          _idCtrl.text    = existing.identificacion ?? '';
        }
      });
    } catch (e) {
      setState(() => _error = 'Error verificando el correo: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Paso 2: ejecutar la acción (invitar o crear) ──────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Leer el orgId directamente desde el contexto sin pasar por
    // userOrgRepositoryProvider (que puede tener un error cacheado).
    final orgId = ref.read(orgContextProvider).activeOrgId;
    if (orgId == null || orgId.isEmpty) {
      setState(() => _error =
          'Sin organización activa. Verifica tu sesión e intenta de nuevo.');
      return;
    }

    setState(() { _loading = true; _error = null; _result = null; });

    try {
      final adminId = ref.read(currentUserProvider)?.id ?? '';

      // Construir el repositorio en línea para evitar el estado cacheado del provider.
      final db   = ref.read(firestoreServiceProvider);
      final repo = UserOrgRepository(
        db:      db,
        authSvc: FirebaseAuthService(db),
        tenant:  TenantService(institutionId: orgId),
      );

      final result = await repo.inviteOrCreate(
            email:         _emailCtrl.text.trim(),
            role:          _selectedRole,
            approvedBy:    adminId,
            firstName:     _firstCtrl.text.trim().isEmpty
                ? null : _firstCtrl.text.trim(),
            lastName:      _lastCtrl.text.trim().isEmpty
                ? null : _lastCtrl.text.trim(),
            identificacion: _idCtrl.text.trim().isEmpty
                ? null : _idCtrl.text.trim(),
            password:      _showPass ? _passCtrl.text : null,
          );

      ref.invalidate(orgUsersProvider);
      setState(() => _result = result);
      if (result.type != InviteResultType.alreadyMember) _clearForm();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearForm() {
    _emailCtrl.clear();
    _firstCtrl.clear();
    _lastCtrl.clear();
    _idCtrl.clear();
    _passCtrl.clear();
    setState(() {
      _emailChecked = false;
      _userExists   = false;
      _showPass     = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg     = theme.scaffoldBackgroundColor;
    final orgCtx = ref.watch(orgContextProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text('Invitar / Crear Usuario'),
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
                _OrgBanner(
                  orgName: orgCtx.activeOrgName ?? 'Mi Organización',
                  isDark:  isDark,
                ),
                const SizedBox(height: 20),
                _RoleSelectorGrid(
                  selected:  _selectedRole,
                  onChanged: (r) => setState(() => _selectedRole = r),
                ),
                const SizedBox(height: 20),
                _EmailField(
                  ctrl:        _emailCtrl,
                  checked:     _emailChecked,
                  userExists:  _userExists,
                  onCheck:     _checkEmail,
                  loading:     _loading && !_emailChecked,
                  onEditEmail: () => setState(() {
                    _emailChecked = false;
                    _userExists   = false;
                    _error        = null;
                    _result       = null;
                  }),
                ),
                if (_emailChecked) ...[
                  const SizedBox(height: 16),
                  _UserExistsBanner(exists: _userExists),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller:         _firstCtrl,
                          readOnly:           _userExists,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText:  'Nombre',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) =>
                              (!_userExists && (v == null || v.trim().isEmpty))
                                  ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller:         _lastCtrl,
                          readOnly:           _userExists,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText:  'Apellido',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) =>
                              (!_userExists && (v == null || v.trim().isEmpty))
                                  ? 'Requerido' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller:   _idCtrl,
                    readOnly:     _userExists,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText:  'Cédula / ID',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  if (_showPass) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller:  _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText:  'Contraseña temporal',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                              size: 20),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 10)
                          ? 'Mínimo 10 caracteres' : null,
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                if (_error != null) ...[
                  _FeedbackBanner(
                    isSuccess: false,
                    message:   _error!,
                    onDismiss: () => setState(() => _error = null),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_result != null) ...[
                  _FeedbackBanner(
                    isSuccess: _result!.isSuccess,
                    message:   _result!.message,
                    onDismiss: () => setState(() => _result = null),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!_emailChecked)
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _checkEmail,
                    icon:  _loading
                        ? const _LoadingIndicator()
                        : const Icon(Icons.search_outlined),
                    label: Text(_loading ? 'Buscando…' : 'Verificar correo'),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon:  _loading
                        ? const _LoadingIndicator()
                        : Icon(_userExists
                            ? Icons.link_outlined
                            : Icons.person_add_outlined),
                    label: Text(_loading
                        ? 'Procesando…'
                        : _userExists
                            ? 'Añadir a la organización'
                            : 'Crear y añadir'),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.go('/admin/users'),
                  icon:  const Icon(Icons.group_outlined, size: 18),
                  label: const Text('Ver directorio'),
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

// ── Widgets de apoyo ──────────────────────────────────────────────────────────

class _OrgBanner extends StatelessWidget {
  final String orgName;
  final bool isDark;
  const _OrgBanner({required this.orgName, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textP = Theme.of(context).textTheme.bodyLarge?.color ??
        AppColors.textPrimary;
    final textS = Theme.of(context).textTheme.bodyMedium?.color ??
        AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brand.withValues(alpha: isDark ? 0.22 : 0.10),
            AppColors.accent.withValues(alpha: isDark ? 0.12 : 0.05),
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:  AppColors.brand.withValues(alpha: 0.15),
              shape:  BoxShape.circle,
            ),
            child: const Icon(Icons.domain_outlined,
                color: AppColors.brand, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registro en organización',
                    style: TextStyle(
                        color:      textP,
                        fontWeight: FontWeight.w700,
                        fontSize:   14)),
                const SizedBox(height: 2),
                Text(orgName,
                    style: const TextStyle(
                        color:      AppColors.brand,
                        fontWeight: FontWeight.w600,
                        fontSize:   12)),
                const SizedBox(height: 1),
                Text(
                  'Si el usuario ya existe, solo se añade a esta org.',
                  style: TextStyle(color: textS, fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserExistsBanner extends StatelessWidget {
  final bool exists;
  const _UserExistsBanner({required this.exists});

  @override
  Widget build(BuildContext context) {
    final color = exists ? AppColors.amber : AppColors.green;
    final bg    = exists ? AppColors.amberBg : AppColors.greenBg;
    final icon  = exists
        ? Icons.person_search_outlined
        : Icons.person_add_outlined;
    final msg = exists
        ? 'Usuario encontrado. Se añadirá a esta organización sin crear cuenta nueva.'
        : 'Usuario nuevo. Se creará una cuenta y se añadirá a esta organización.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: TextStyle(color: color, fontSize: 12, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  final TextEditingController ctrl;
  final bool checked;
  final bool userExists;
  final VoidCallback onCheck;
  final VoidCallback onEditEmail;
  final bool loading;

  const _EmailField({
    required this.ctrl,
    required this.checked,
    required this.userExists,
    required this.onCheck,
    required this.onEditEmail,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:   ctrl,
      readOnly:     checked,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText:  'Correo electrónico',
        prefixIcon: const Icon(Icons.email_outlined),
        suffixIcon: checked
            ? IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onEditEmail,
                tooltip: 'Cambiar correo',
              )
            : (loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.brand),
                    ),
                  )
                : null),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Requerido';
        if (!RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(v.trim())) {
          return 'Correo inválido';
        }
        return null;
      },
      onFieldSubmitted: (_) { if (!checked) onCheck(); },
    );
  }
}

class _RoleSelectorGrid extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _RoleSelectorGrid({required this.selected, required this.onChanged});

  // SECURITY (MED-05): ADMIN is intentionally excluded from this list.
  // An admin inviting another admin creates cascading privilege escalation.
  // Promote to ADMIN only via a dedicated, separately-audited flow.
  // Matches AppConstants.assignableRoles.
  static const _roles = [
    (AppConstants.roleUsuario,            'Usuario',     Icons.person_outline,             AppColors.brand2),
    (AppConstants.roleInstructor,         'Instructor',  Icons.school_outlined,            AppColors.accent),
    (AppConstants.roleUsuarioSST,         'SST',         Icons.health_and_safety_outlined, AppColors.green),
    (AppConstants.roleUsuarioProfesional, 'Profesional', Icons.badge_outlined,             AppColors.cyan),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ROL EN LA ORGANIZACIÓN',
          style: TextStyle(
              color: textS, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 0.8),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _roles.map((r) {
            final (role, label, icon, color) = r;
            final isSelected = selected == role;
            return GestureDetector(
              onTap: () => onChanged(role),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isSelected ? color : theme.colorScheme.outline,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16,
                        color: isSelected ? color : textS),
                    const SizedBox(width: 6),
                    Text(label,
                        style: TextStyle(
                            color: isSelected ? color : textS,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700 : FontWeight.w500)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 18, width: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
    final bg    = isSuccess ? AppColors.greenBg : AppColors.redBg;
    final icon  = isSuccess ? Icons.check_circle_outline : Icons.error_outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: color, fontSize: 13))),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close, color: color, size: 16),
          ),
        ],
      ),
    );
  }
}
