import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/services/firestore_service.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/users/data/models/user.dart';

/// Pantalla para que un USUARIO solicite convertirse en instructor independiente.
/// Requiere subir: licencia SST y/o certificado profesional de RCP.
/// El SuperAdmin revisa y aprueba/rechaza desde /super-admin/certificates.
class InstructorApplyScreen extends ConsumerStatefulWidget {
  const InstructorApplyScreen({super.key});

  @override
  ConsumerState<InstructorApplyScreen> createState() =>
      _InstructorApplyScreenState();
}

class _InstructorApplyScreenState extends ConsumerState<InstructorApplyScreen> {
  final _formKey = GlobalKey<FormState>();

  // Formulario principal
  final _issuerCtrl = TextEditingController();
  final _certNumCtrl = TextEditingController();
  final _issueDateCtrl = TextEditingController();
  final _expiryDateCtrl = TextEditingController();

  String _certType = 'SST_LICENCIA';
  bool _loading = false;
  String? _error;
  bool _submitted = false;
  // HIGH-07: must be populated with a real Firebase Storage URL before submit.
  String? _fileUrl;

  static const _certTypes = [
    ('SST_LICENCIA', 'Licencia SST (Res. 0312/2019)', Icons.security_outlined),
    (
      'TITULO_PROFESIONAL',
      'Título Profesional en Salud',
      Icons.workspace_premium_outlined
    ),
    ('BLS_AHA', 'BLS (Basic Life Support) AHA', Icons.favorite_outlined),
    ('ACLS_AHA', 'ACLS AHA', Icons.monitor_heart_outlined),
    ('PALS_AHA', 'PALS AHA', Icons.child_care_outlined),
    ('INSTRUCTOR_BLS', 'Instructor BLS AHA', Icons.school_outlined),
    ('INSTRUCTOR_ACLS', 'Instructor ACLS AHA', Icons.medical_services_outlined),
    ('INSTRUCTOR_PALS', 'Instructor PALS AHA', Icons.school_outlined),
    ('SVBS', 'Soporte Vital Básico (SVBS)', Icons.local_hospital_outlined),
    (
      'PRIMEROS_AUXILIOS',
      'Primeros Auxilios Avanzados',
      Icons.healing_outlined
    ),
    ('OTRO', 'Otro', Icons.description_outlined),
  ];

  @override
  void dispose() {
    _issuerCtrl.dispose();
    _certNumCtrl.dispose();
    _issueDateCtrl.dispose();
    _expiryDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('Sin sesión activa.');

      // HIGH-07 fix: upload the document to Firebase Storage first and get a
      // real URL before creating the Firestore record. The Firestore rule now
      // rejects `fileUrl == 'pending_upload'`. File upload UI is pending
      // (tracked in backlog); for now we block submission without a real URL.
      // Once file upload is implemented, replace this placeholder with the
      // actual Storage download URL obtained after `ref.putFile(file)`.
      if (_fileUrl == null || _fileUrl!.isEmpty) {
        setState(() {
          _error = 'Debes adjuntar el archivo del certificado antes de enviar.';
          _loading = false;
        });
        return;
      }

      await ref.read(firestoreServiceProvider).submitCertificateForVerification(
            userId: user.id,
            type: _certType,
            issuer: _issuerCtrl.text.trim(),
            certificateNumber: _certNumCtrl.text.trim(),
            issueDate: _issueDateCtrl.text.trim(),
            expiryDate: _expiryDateCtrl.text.trim().isEmpty
                ? null
                : _expiryDateCtrl.text.trim(),
            fileUrl: _fileUrl!,
          );
      setState(() {
        _submitted = true;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final user = ref.watch(currentUserProvider);

    if (_submitted) return _SuccessView(isDark: isDark);

    // Si ya tiene verificación pendiente o aprobada, mostrar estado
    if (user?.certVerification == CertVerificationStatus.pending) {
      return _PendingView(isDark: isDark);
    }
    if (user?.certVerification == CertVerificationStatus.approved) {
      return _ApprovedView(isDark: isDark);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: textP),
          onPressed: () => context.pop(),
        ),
        title: Text('Solicitar rol de Instructor',
            style: TextStyle(
                color: textP, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // ── Info banner ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.school_outlined,
                            size: 18, color: Color(0xFF7C3AED)),
                        SizedBox(width: 8),
                        Text('Instructor Independiente',
                            style: TextStyle(
                                color: Color(0xFF7C3AED),
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Para crear cursos y capacitar estudiantes sin pertenecer a una institución, debes tener certificados profesionales o licencia SST vigente. '
                      'El SuperAdmin revisará tus documentos en un plazo de 1-3 días hábiles.',
                      style: TextStyle(
                          color:
                              const Color(0xFF7C3AED).withValues(alpha: 0.85),
                          fontSize: 12,
                          height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Tipo de certificado ──────────────────────────────────────
              Text('Tipo de documento',
                  style: TextStyle(
                      color: textP, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _certTypes.map((t) {
                  final selected = _certType == t.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _certType = t.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.brand.withValues(alpha: 0.12)
                            : (isDark ? AppColors.darkBg2 : AppColors.lightBg2),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: selected
                              ? AppColors.brand
                              : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder),
                          width: selected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(t.$3,
                              size: 16,
                              color: selected ? AppColors.brand : textS),
                          const SizedBox(width: 6),
                          Text(t.$2,
                              style: TextStyle(
                                  color: selected ? AppColors.brand : textS,
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── Entidad emisora ──────────────────────────────────────────
              TextFormField(
                controller: _issuerCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Entidad emisora',
                  hintText: 'Ej: Ministerio de Salud, AHA, Cruz Roja…',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 14),

              // ── Número de certificado ────────────────────────────────────
              TextFormField(
                controller: _certNumCtrl,
                decoration: const InputDecoration(
                  labelText: 'Número de certificado / licencia',
                  hintText: 'Ej: SST-2024-001234',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 14),

              // ── Fecha de emisión ─────────────────────────────────────────
              TextFormField(
                controller: _issueDateCtrl,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Fecha de emisión',
                  hintText: 'DD/MM/AAAA',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 14),

              // ── Fecha de vencimiento (opcional) ──────────────────────────
              TextFormField(
                controller: _expiryDateCtrl,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Fecha de vencimiento (opcional)',
                  hintText: 'DD/MM/AAAA  —  dejar en blanco si no aplica',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // ── Nota sobre archivo ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Próximamente podrás adjuntar el archivo PDF o imagen del certificado. '
                        'Por ahora envía los datos y el SuperAdmin te contactará para verificación.',
                        style: TextStyle(
                            color: AppColors.amber, fontSize: 11, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Error ────────────────────────────────────────────────────
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.redBg,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border:
                        Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.red, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── Submit ───────────────────────────────────────────────────
              ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_outlined, size: 18),
                label: Text(_loading ? 'Enviando…' : 'Enviar solicitud'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Estado: enviado ───────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final bool isDark;
  const _SuccessView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline,
                    size: 52, color: AppColors.green),
              ),
              const SizedBox(height: 24),
              const Text('Solicitud enviada',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.green)),
              const SizedBox(height: 12),
              Text(
                'Tu solicitud ha sido enviada al SuperAdmin. Recibirás una notificación cuando sea revisada (1-3 días hábiles).',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 14,
                    height: 1.6),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50)),
                child: const Text('Volver al inicio'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Estado: pendiente ─────────────────────────────────────────────────────────

class _PendingView extends StatelessWidget {
  final bool isDark;
  const _PendingView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded,
                    size: 52, color: AppColors.amber),
              ),
              const SizedBox(height: 24),
              const Text('Solicitud en revisión',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.amber)),
              const SizedBox(height: 12),
              Text(
                'Tu certificado está siendo revisado por el SuperAdmin. Recibirás una notificación con el resultado.',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 14,
                    height: 1.6),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              OutlinedButton(
                onPressed: () => context.go('/home'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50)),
                child: const Text('Volver al inicio'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Estado: aprobado ──────────────────────────────────────────────────────────

class _ApprovedView extends StatelessWidget {
  final bool isDark;
  const _ApprovedView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified,
                    size: 52, color: AppColors.brand),
              ),
              const SizedBox(height: 24),
              const Text('¡Ya eres Instructor!',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brand)),
              const SizedBox(height: 12),
              Text(
                'Tus certificados han sido aprobados. Ahora puedes crear cursos y capacitar estudiantes de forma independiente.',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 14,
                    height: 1.6),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              ElevatedButton.icon(
                onPressed: () => context.go('/courses'),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Crear mi primer curso'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
