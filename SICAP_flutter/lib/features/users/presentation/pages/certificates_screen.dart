import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:uuid/uuid.dart';

// ── Certificate type metadata ─────────────────────────────────────────────────

class CertMeta {
  final String value;
  final String label;
  final String issuer;
  final String description;
  final IconData icon;
  const CertMeta({
    required this.value,
    required this.label,
    required this.issuer,
    required this.description,
    required this.icon,
  });

  /// Construye desde un documento Firestore de la colección certificate_types.
  factory CertMeta.fromFirestore(Map<String, dynamic> data, IconData fallbackIcon) {
    return CertMeta(
      value:       data['value']       as String? ?? '',
      label:       data['label']       as String? ?? '',
      issuer:      data['issuer']      as String? ?? '',
      description: data['description'] as String? ?? '',
      icon:        fallbackIcon,
    );
  }
}

/// Tipos canónicos colombianos de certificado.
/// Fuentes: Resolución 0312/2019 (SST), Ley 1562/2012, normativas AHA/MinSalud.
/// Esta lista es el FALLBACK cuando la colección Firestore está vacía.
/// El SA puede añadir o desactivar tipos desde la consola Firestore
/// o desde el panel SuperAdmin → certificate_types.
const _kCertTypesFallback = [
  // ── Certificaciones AHA ──────────────────────────────────────────────────
  CertMeta(
    value:       'BLS_AHA',
    label:       'BLS Provider AHA',
    issuer:      'American Heart Association',
    description: 'Soporte Vital Básico (BLS) vigente — AHA. '
        'Certificación más solicitada en empresas y hospitales Colombia.',
    icon: Icons.favorite_rounded,
  ),
  CertMeta(
    value:       'ACLS_AHA',
    label:       'ACLS Provider AHA',
    issuer:      'American Heart Association',
    description: 'Soporte Cardiovascular Avanzado (ACLS). '
        'Requerido en unidades de cuidado intensivo y urgencias.',
    icon: Icons.monitor_heart_rounded,
  ),
  CertMeta(
    value:       'PALS_AHA',
    label:       'PALS AHA',
    issuer:      'American Heart Association',
    description: 'Soporte Vital Pediátrico Avanzado (PALS). '
        'Requerido en pediatría y urgencias pediátricas.',
    icon: Icons.child_care_rounded,
  ),
  CertMeta(
    value:       'INSTRUCTOR_BLS',
    label:       'Instructor BLS / SVBS',
    issuer:      'American Heart Association / MinSalud',
    description: 'Certificación como instructor de BLS o SVBS. '
        'Habilita para dictar cursos avalados por AHA o MinSalud.',
    icon: Icons.school_rounded,
  ),
  CertMeta(
    value:       'INSTRUCTOR_ACLS',
    label:       'Instructor ACLS',
    issuer:      'American Heart Association',
    description: 'Certificación como instructor de ACLS. '
        'Requerido para centros de entrenamiento AHA.',
    icon: Icons.workspace_premium_rounded,
  ),
  CertMeta(
    value:       'INSTRUCTOR_PALS',
    label:       'Instructor PALS',
    issuer:      'American Heart Association',
    description: 'Certificación como instructor de PALS.',
    icon: Icons.workspace_premium_rounded,
  ),
  // ── Certificaciones nacionales Colombia ──────────────────────────────────
  CertMeta(
    value:       'SVBS',
    label:       'SVBS — Soporte Vital Básico',
    issuer:      'Ministerio de Salud y Protección Social',
    description: 'Soporte Vital Básico según lineamientos MinSalud Colombia. '
        'Decreto 1072/2015 y Resolución 8430/1993.',
    icon: Icons.local_hospital_rounded,
  ),
  CertMeta(
    value:       'PRIMEROS_AUXILIOS',
    label:       'Primeros Auxilios',
    issuer:      'Ministerio de Salud / Cruz Roja / Defensa Civil',
    description: 'Certificado de Primeros Auxilios básicos. '
        'Obligatorio según Decreto 1072/2015 para brigadas SST.',
    icon: Icons.medical_services_rounded,
  ),
  CertMeta(
    value:       'SST_LICENCIA',
    label:       'Licencia SST',
    issuer:      'Ministerio de Salud y Protección Social',
    description: 'Licencia en Seguridad y Salud en el Trabajo. '
        'Resolución 0312/2019, Ley 1562/2012. '
        'Activa plan SST Expert y rol USUARIO_SST.',
    icon: Icons.health_and_safety_rounded,
  ),
  CertMeta(
    value:       'TITULO_PROFESIONAL',
    label:       'Título Profesional',
    issuer:      'Ministerio de Educación Nacional',
    description: 'Diploma o acta de grado universitario en área de salud. '
        'Habilita instructor sin licencia SST. Activa USUARIO_PROFESIONAL.',
    icon: Icons.school_outlined,
  ),
  // ── Otros ────────────────────────────────────────────────────────────────
  CertMeta(
    value:       'OTRO',
    label:       'Otro certificado',
    issuer:      'Otra entidad reconocida',
    description: 'Cualquier otro certificado de entidad reconocida '
        'que respalde el perfil profesional del solicitante.',
    icon: Icons.badge_rounded,
  ),
];

// ── Provider: carga tipos desde Firestore; usa fallback si la colección está vacía ──

final certificateTypesProvider = FutureProvider<List<CertMeta>>((ref) async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection('certificate_types')
        .orderBy('order', descending: false)
        .get()
        .timeout(const Duration(seconds: 5));

    if (snap.docs.isEmpty) return _kCertTypesFallback;

    return snap.docs.map((doc) {
      final data = doc.data();
      // Mapear el iconCode guardado en Firestore a IconData
      final iconCode = data['iconCode'] as int?;
      final icon     = iconCode != null
          ? IconData(iconCode, fontFamily: 'MaterialIcons')
          : Icons.badge_rounded;
      return CertMeta.fromFirestore(data, icon);
    }).toList();
  } catch (_) {
    return _kCertTypesFallback;
  }
});

// ── Status helpers ────────────────────────────────────────────────────────────

Color _statusColor(String status) => switch (status) {
      'APPROVED' => const Color(0xFF22c55e),
      'REJECTED' => const Color(0xFFef4444),
      'PENDING' => const Color(0xFFf59e0b),
      _ => const Color(0xFF94a3b8),
    };

String _statusLabel(String status) => switch (status) {
      'APPROVED' => 'Aprobado',
      'REJECTED' => 'Rechazado',
      'PENDING' => 'En revisión',
      _ => 'Sin verificar',
    };

IconData _statusIcon(String status) => switch (status) {
      'APPROVED' => Icons.check_circle_rounded,
      'REJECTED' => Icons.cancel_rounded,
      'PENDING' => Icons.schedule_rounded,
      _ => Icons.help_outline_rounded,
    };

// ── Screen ────────────────────────────────────────────────────────────────────

class CertificatesScreen extends ConsumerStatefulWidget {
  const CertificatesScreen({super.key});

  @override
  ConsumerState<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends ConsumerState<CertificatesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _certNumberCtrl = TextEditingController();
  final _issuerCtrl = TextEditingController();
  final _issueDateCtrl = TextEditingController();
  final _expiryDateCtrl = TextEditingController();

  String _selectedType = 'BLS_AHA';
  PlatformFile? _selectedFile;
  bool _uploading = false;
  double _uploadProgress = 0;

  List<Map<String, dynamic>> _certs = [];
  bool _loadingCerts = true;

  @override
  void initState() {
    super.initState();
    _loadCertificates();
    // Pre-fill issuer from selected type (orElse evita "Bad state: No element"
    // si el tipo por defecto no existe en la lista).
    _issuerCtrl.text = _kCertTypesFallback
        .firstWhere((t) => t.value == _selectedType, orElse: () => _kCertTypesFallback.first)
        .issuer;
  }

  @override
  void dispose() {
    _certNumberCtrl.dispose();
    _issuerCtrl.dispose();
    _issueDateCtrl.dispose();
    _expiryDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCertificates() async {
    final authState = ref.read(authStateProvider).value;
    if (authState?.user == null) return;

    setState(() => _loadingCerts = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection(AppConstants.colUserCertificates)
          .where('userId', isEqualTo: authState!.user!.id)
          .orderBy('createdAt', descending: true)
          .get();
      setState(() {
        _certs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _loadingCerts = false;
      });
    } catch (_) {
      setState(() => _loadingCerts = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: false,
      withReadStream: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final f = result.files.first;
      if ((f.size) > 10 * 1024 * 1024) {
        _showSnack('El archivo no debe superar 10 MB', isError: true);
        return;
      }
      setState(() => _selectedFile = f);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      _showSnack('Selecciona un archivo PDF, JPG o PNG', isError: true);
      return;
    }

    final authState = ref.read(authStateProvider).value;
    if (authState?.user == null) return;
    final uid = authState!.user!.id;

    final idempotencyKey = const Uuid().v4();

    setState(() { _uploading = true; _uploadProgress = 0; });

    try {
      // 1) Upload to Firebase Storage
      final ext = _selectedFile!.extension ?? 'pdf';
      final storagePath = '${AppConstants.colUserCertificates}/$uid/$idempotencyKey.$ext';
      final storageRef = FirebaseStorage.instance.ref(storagePath);
      final task = storageRef.putFile(
        File(_selectedFile!.path!),
        SettableMetadata(customMetadata: {'userId': uid, 'idempotencyKey': idempotencyKey}),
      );

      task.snapshotEvents.listen((snap) {
        if (mounted) {
          setState(() => _uploadProgress = snap.bytesTransferred / snap.totalBytes);
        }
      });

      await task;
      final fileUrl = await storageRef.getDownloadURL();

      // 2) Save metadata to Firestore
      await FirebaseFirestore.instance
          .collection(AppConstants.colUserCertificates)
          .add({
        'idempotencyKey': idempotencyKey,
        'userId': uid,
        'type': _selectedType,
        'issuer': _issuerCtrl.text.trim(),
        'certificateNumber': _certNumberCtrl.text.trim(),
        'issueDate': _issueDateCtrl.text.trim(),
        'expiryDate': _expiryDateCtrl.text.isNotEmpty ? _expiryDateCtrl.text.trim() : null,
        'fileUrl': fileUrl,
        'verificationStatus': 'PENDING',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnack('Certificado enviado. Revisión en 24–48 h hábiles.');
      _certNumberCtrl.clear();
      _issueDateCtrl.clear();
      _expiryDateCtrl.clear();
      setState(() { _selectedFile = null; _uploading = false; _uploadProgress = 0; });
      await _loadCertificates();
    } catch (e) {
      _showSnack('Error al subir el certificado. Intenta de nuevo.', isError: true);
      setState(() { _uploading = false; _uploadProgress = 0; });
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.red : AppColors.green,
    ));
  }

  /// Abre/descarga el archivo del certificado del propio usuario.
  Future<void> _openCertificate(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || url.isEmpty) {
      _showSnack('Enlace del certificado no válido', isError: true);
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _showSnack('No se pudo abrir el certificado', isError: true);
  }

  Future<void> _pickDate(TextEditingController ctrl, {DateTime? firstDate, DateTime? lastDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      ctrl.text = '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF8FAFC);
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFEAECF0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Certificados Profesionales',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 17),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: borderColor, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Certificados de cursos (Tipo A) retirados — reemplazados por el
            // Skill Passport. Esta pantalla queda solo para CREDENCIALES
            // profesionales (user_certificates) que el usuario sube para verificación.

            // ── Info banner ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.brand, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sube tus certificados profesionales para obtener más beneficios. '
                      'Revisión manual en 24–48 h hábiles. Formatos: PDF, JPG, PNG (máx. 10 MB).\n'
                      'Validados conforme al Ministerio de Educación y Ministerio de Salud de Colombia.',
                      style: TextStyle(color: AppColors.brand, fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Upload form ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Subir nuevo certificado',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 16),

                    // Type selector
                    Text('Tipo de certificado', style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...(_kCertTypesFallback.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedType = t.value;
                          _issuerCtrl.text = t.issuer;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _selectedType == t.value
                                ? AppColors.brand.withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _selectedType == t.value ? AppColors.brand : borderColor,
                              width: _selectedType == t.value ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(t.icon,
                                color: _selectedType == t.value ? AppColors.brand : subColor,
                                size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.label,
                                        style: TextStyle(
                                          color: _selectedType == t.value ? AppColors.brand : textColor,
                                          fontWeight: FontWeight.w700, fontSize: 13)),
                                    Text(t.description,
                                        style: TextStyle(color: subColor, fontSize: 11, height: 1.4)),
                                  ],
                                ),
                              ),
                              if (_selectedType == t.value)
                                Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ))),

                    const SizedBox(height: 12),

                    // Issuer
                    _FieldLabel('Entidad expedidora *', subColor),
                    const SizedBox(height: 6),
                    _buildInput(_issuerCtrl, 'Ej. Ministerio de Salud...', textColor, borderColor, isDark),

                    const SizedBox(height: 12),

                    // Certificate number
                    _FieldLabel('Número de certificado / matrícula *', subColor),
                    const SizedBox(height: 6),
                    _buildInput(_certNumberCtrl, 'Ej. SP-2023-001234', textColor, borderColor, isDark,
                        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Campo obligatorio' : null),

                    const SizedBox(height: 12),

                    // Dates
                    Row(
                      children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel('Fecha expedición *', subColor),
                            const SizedBox(height: 6),
                            _buildInput(_issueDateCtrl, 'AAAA-MM-DD', textColor, borderColor, isDark,
                              readOnly: true,
                              onTap: () => _pickDate(_issueDateCtrl, lastDate: DateTime.now()),
                              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Requerido' : null,
                            ),
                          ],
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel('Vencimiento', subColor),
                            const SizedBox(height: 6),
                            _buildInput(_expiryDateCtrl, 'AAAA-MM-DD', textColor, borderColor, isDark,
                              readOnly: true,
                              onTap: () => _pickDate(_expiryDateCtrl, firstDate: DateTime.now()),
                            ),
                          ],
                        )),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // File picker
                    _FieldLabel('Archivo del certificado *', subColor),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _uploading ? null : _pickFile,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _selectedFile != null
                              ? AppColors.brand.withValues(alpha: 0.06)
                              : (isDark ? AppColors.darkBg : const Color(0xFFFAFAFA)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedFile != null ? AppColors.brand : borderColor,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _selectedFile != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                              color: _selectedFile != null ? AppColors.brand : subColor,
                              size: 28,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _selectedFile != null
                                  ? _selectedFile!.name
                                  : 'Toca para seleccionar PDF, JPG o PNG',
                              style: TextStyle(
                                color: _selectedFile != null ? AppColors.brand : subColor,
                                fontSize: 12, fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_selectedFile != null)
                              Text(
                                '${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB · Toca para cambiar',
                                style: TextStyle(color: subColor, fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Progress bar
                    if (_uploading) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: _uploadProgress,
                              backgroundColor: borderColor,
                              valueColor: AlwaysStoppedAnimation(AppColors.brand),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${(_uploadProgress * 100).toInt()}%',
                              style: TextStyle(color: AppColors.brand, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _uploading ? null : _submit,
                        icon: _uploading
                            ? SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.8)),
                                ),
                              )
                            : const Icon(Icons.cloud_upload_rounded, size: 18),
                        label: Text(_uploading ? 'Subiendo...' : 'Enviar para validación',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Existing certificates ──────────────────────────────────
            Text('Mis certificados enviados',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),

            if (_loadingCerts)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            else if (_certs.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cardBg, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 40, color: borderColor),
                    const SizedBox(height: 8),
                    Text('Aún no has enviado certificados',
                        style: TextStyle(color: subColor, fontSize: 13)),
                  ],
                ),
              )
            else
              ...(_certs.map((cert) {
                final status = cert['verificationStatus'] as String? ?? 'NONE';
                final typeMeta = _kCertTypesFallback.firstWhere(
                  (t) => t.value == cert['type'],
                  orElse: () => _kCertTypesFallback.last,
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: _statusColor(status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(typeMeta.icon, color: _statusColor(status), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(typeMeta.label,
                                style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13)),
                            Text('N.° ${cert['certificateNumber'] ?? '—'}',
                                style: TextStyle(color: subColor, fontSize: 11)),
                            if (cert['rejectionReason'] != null)
                              Text(cert['rejectionReason'] as String,
                                  style: const TextStyle(color: Color(0xFFef4444), fontSize: 11, height: 1.4)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_statusIcon(status), size: 12, color: _statusColor(status)),
                                const SizedBox(width: 4),
                                Text(_statusLabel(status),
                                    style: TextStyle(
                                      color: _statusColor(status),
                                      fontSize: 10, fontWeight: FontWeight.w800,
                                    )),
                              ],
                            ),
                          ),
                          if ((cert['fileUrl'] as String?)?.isNotEmpty ?? false) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _openCertificate(cert['fileUrl'] as String),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.download_rounded, size: 15, color: AppColors.brand),
                                  const SizedBox(width: 3),
                                  Text('Ver / descargar',
                                      style: TextStyle(
                                        color: AppColors.brand,
                                        fontSize: 11, fontWeight: FontWeight.w700,
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              })),

            const SizedBox(height: 24),

            // Legal note
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBg : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Los documentos son tratados conforme a la Ley 1581 de 2012 (habeas data). '
                'SIERCP valida contra los registros del Ministerio de Educación Nacional '
                'y la Resolución 4502 de 2012 del Ministerio de Salud. '
                'No compartimos ni vendemos tu información.',
                style: TextStyle(color: subColor, fontSize: 11, height: 1.55),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController ctrl,
    String hint,
    Color textColor,
    Color borderColor,
    bool isDark, {
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: ctrl,
      readOnly: readOnly,
      onTap: onTap,
      validator: validator,
      style: TextStyle(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFef4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFef4444), width: 1.5),
        ),
        filled: true,
        fillColor: isDark ? AppColors.darkBg : Colors.white,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _FieldLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      );
}
