import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/core/models/institution.dart';
import 'package:siercp/features/auth/data/firebase_auth_service.dart';
import 'package:siercp/core/services/firestore_service.dart';

class InstitutionRegisterScreen extends ConsumerStatefulWidget {
  const InstitutionRegisterScreen({super.key});

  @override
  ConsumerState<InstitutionRegisterScreen> createState() =>
      _InstitutionRegisterScreenState();
}

class _InstitutionRegisterScreenState
    extends ConsumerState<InstitutionRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Institution fields
  final _orgNameCtrl    = TextEditingController();
  final _nitCtrl        = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _addressCtrl    = TextEditingController();
  final _cityCtrl       = TextEditingController();
  InstitutionType _orgType = InstitutionType.company;

  // Admin account fields
  final _firstNameCtrl  = TextEditingController();
  final _lastNameCtrl   = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _passCtrl       = TextEditingController();

  bool _obscure  = true;
  bool _loading  = false;
  String? _error;

  @override
  void dispose() {
    _orgNameCtrl.dispose();
    _nitCtrl.dispose();
    _contactEmailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _adminEmailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final db   = ref.read(firestoreServiceProvider);
      final auth = ref.read(firebaseAuthServiceProvider);

      // 1. Create institution document first to get the org ID
      final instRef = FirebaseFirestore.instance.collection('institutions').doc();
      final orgId   = instRef.id;

      // 2. Create Firebase Auth account for admin using a secondary app so the
      //    current session is not affected (admin may already be logged in).
      final adminUser = await auth.adminCreateUser(
        email:     _adminEmailCtrl.text.trim(),
        password:  _passCtrl.text,
        firstName: _firstNameCtrl.text.trim(),
        lastName:  _lastNameCtrl.text.trim(),
        role:      AppConstants.roleAdmin,
      );

      // 3. Mark account as inactive + pending until super admin approves
      await FirebaseFirestore.instance
          .collection('users')
          .doc(adminUser.id)
          .update({'institutionId': orgId, 'isActive': false, 'status': 'PENDING'});

      // 4. Write institution document
      final institution = InstitutionModel(
        id:           orgId,
        name:         _orgNameCtrl.text.trim(),
        nit:          _nitCtrl.text.trim().isEmpty ? null : _nitCtrl.text.trim(),
        type:         _orgType,
        status:       InstitutionStatus.pending,
        contactEmail: _contactEmailCtrl.text.trim(),
        phoneNumber:  _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        address:      _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        city:         _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        country:      'Colombia',
        primaryAdminId: adminUser.id,
        createdAt:    DateTime.now(),
      );
      await instRef.set(institution.toFirestore());

      // 5. Create membership for admin in this org
      await db.createMembership(
        userId:        adminUser.id,
        institutionId: orgId,
        role:          AppConstants.roleAdmin,
        status:        'pending',
      );

      if (mounted) _showSuccess();
    } catch (e) {
      setState(() => _error = FirebaseAuthService.parseAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 24),
            SizedBox(width: 10),
            Text('Solicitud enviada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Tu institución ha sido registrada en estado pendiente. '
          'Un super administrador revisará y activará tu cuenta. '
          'Recibirás confirmación por email cuando se apruebe el plan institucional.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/login');
            },
            child: const Text('Ir al inicio de sesión'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textP, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
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
                  'Registro Institucional',
                  style: TextStyle(color: textP, fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Registra tu institución o empresa. Tu cuenta de administrador quedará pendiente hasta que actives un plan institucional.',
                  style: TextStyle(color: textS, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 28),

                // ── Datos de la institución ──────────────────────────────────
                _SectionHeader(label: 'Datos de la organización', color: textP),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _orgNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la institución / empresa',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nitCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'NIT / RUT',
                          hintText: 'Opcional',
                          prefixIcon: Icon(Icons.numbers_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<InstitutionType>(
                        initialValue: _orgType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: InstitutionType.values.map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.label, style: const TextStyle(fontSize: 13)),
                        )).toList(),
                        onChanged: (v) => setState(() => _orgType = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _contactEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email de contacto institucional',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Campo obligatorio';
                    if (!v.contains('@')) return 'Email inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          hintText: 'Opcional',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cityCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Ciudad',
                          hintText: 'Opcional',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    hintText: 'Opcional',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Cuenta del administrador ─────────────────────────────────
                _SectionHeader(label: 'Cuenta del administrador', color: textP),
                const SizedBox(height: 14),

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
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
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
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _adminEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email del administrador',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Campo obligatorio';
                    if (!v.contains('@')) return 'Email inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 28),

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
                        const Icon(Icons.error_outline, color: AppColors.red, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Registrar institución'),
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

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 18, color: AppColors.brand,
            margin: const EdgeInsets.only(right: 10)),
        Text(label, style: TextStyle(
          color: color, fontSize: 15, fontWeight: FontWeight.w700,
        )),
      ],
    );
  }
}
