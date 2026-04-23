import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/guide.dart';
import '../providers/auth_provider.dart';
import '../providers/guide_provider.dart';
import '../services/guide_service.dart';
import '../core/theme.dart';

class AddGuideScreen extends ConsumerStatefulWidget {
  final String courseId;
  const AddGuideScreen({super.key, required this.courseId});

  @override
  ConsumerState<AddGuideScreen> createState() => _AddGuideScreenState();
}

class _AddGuideScreenState extends ConsumerState<AddGuideScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _orderCtrl = TextEditingController(text: '1');
  final _minsCtrl  = TextEditingController(text: '10');

  GuideCategory _category  = GuideCategory.tecnica;
  bool _isRequired         = false;
  File? _selectedFile;
  String? _selectedFileName;
  bool _uploading          = false;
  double _uploadProgress   = 0.0;
  String? _uploadError;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _orderCtrl.dispose();
    _minsCtrl.dispose();
    super.dispose();
  }

  // ── Seleccionar PDF ───────────────────────────────────────────────────────
  Future<void> _pickPDF() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null) return;

    // Validar tamaño
    final file = File(picked.path!);
    final bytes = await file.length();
    if (bytes > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El PDF supera los 10 MB permitidos.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _selectedFile     = file;
      _selectedFileName = picked.name;
      _uploadError      = null;
    });
  }

  // ── Subir guía ────────────────────────────────────────────────────────────
  Future<void> _uploadGuide() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un archivo PDF.'),
          backgroundColor: AppColors.amber,
        ),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() { _uploading = true; _uploadProgress = 0; _uploadError = null; });

    try {
      final guideId = const Uuid().v4();
      final service = ref.read(guideServiceProvider);

      // Subir PDF
      final pdfUrl = await service.uploadPDF(
        _selectedFile!,
        widget.courseId,
        guideId,
        onProgress: (p) => setState(() => _uploadProgress = p),
      );

      // Crear guía
      final guide = GuideModel(
        id:               guideId,
        title:            _titleCtrl.text.trim(),
        description:      _descCtrl.text.trim(),
        courseId:         widget.courseId,
        pdfUrl:           pdfUrl,
        uploadedBy:       user.id,
        uploaderName:     user.fullName,
        uploadedAt:       DateTime.now(),
        category:         _category,
        required:         _isRequired,
        order:            int.tryParse(_orderCtrl.text) ?? 1,
        estimatedMinutes: int.tryParse(_minsCtrl.text)  ?? 10,
      );

      await service.createGuide(guide);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('¡Guía agregada con éxito!'),
            ]),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() { _uploading = false; _uploadError = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final textS  = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final border = theme.colorScheme.outline;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Agregar guía'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Título ──────────────────────────────────────────────────────
            TextFormField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Título de la guía *',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'El título es requerido' : null,
            ),
            const SizedBox(height: 16),

            // ── Descripción ─────────────────────────────────────────────────
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción *',
                prefixIcon: Icon(Icons.description_outlined),
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'La descripción es requerida' : null,
            ),
            const SizedBox(height: 16),

            // ── Categoría ───────────────────────────────────────────────────
            DropdownButtonFormField<GuideCategory>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: GuideCategory.values
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text('${cat.emoji} ${cat.label}'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 16),

            // ── Orden + Tiempo estimado ─────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _orderCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Orden de lectura',
                      prefixIcon: Icon(Icons.sort_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tiempo estimado (min)',
                      prefixIcon: Icon(Icons.schedule_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // ── Obligatoria ─────────────────────────────────────────────────
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('¿Es obligatoria para aprobar el curso?'),
              subtitle: Text(
                'Los estudiantes deben leerla para obtener la certificación.',
                style: TextStyle(color: textS, fontSize: 11),
              ),
              value: _isRequired,
              activeColor: AppColors.brand,
              onChanged: (v) => setState(() => _isRequired = v),
            ),

            const SizedBox(height: 8),
            Divider(color: border.withValues(alpha: 0.4)),
            const SizedBox(height: 12),

            // ── Selector de PDF ─────────────────────────────────────────────
            GestureDetector(
              onTap: _uploading ? null : _pickPDF,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _selectedFile != null
                      ? AppColors.brand.withValues(alpha: 0.05)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: _selectedFile != null
                        ? AppColors.brand.withValues(alpha: 0.4)
                        : border.withValues(alpha: 0.5),
                    width: _selectedFile != null ? 1.5 : 0.5,
                    style: _selectedFile != null
                        ? BorderStyle.solid
                        : BorderStyle.solid,
                  ),
                ),
                child: _selectedFile == null
                    ? Column(
                        children: [
                          Icon(Icons.upload_file_rounded,
                              size: 40, color: textS.withValues(alpha: 0.5)),
                          const SizedBox(height: 8),
                          Text('Toca para seleccionar PDF',
                              style: TextStyle(color: textS, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('Máximo 10 MB',
                              style: TextStyle(
                                  color: textS.withValues(alpha: 0.6),
                                  fontSize: 11)),
                        ],
                      )
                    : Row(
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded,
                              size: 36, color: AppColors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedFileName ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text('PDF listo para subir',
                                    style: TextStyle(
                                        color: AppColors.green, fontSize: 11)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            iconSize: 18,
                            onPressed: () => setState(() {
                              _selectedFile     = null;
                              _selectedFileName = null;
                            }),
                          ),
                        ],
                      ),
              ),
            ),

            // ── Barra de progreso de carga ──────────────────────────────────
            if (_uploading) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor: border.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation(AppColors.brand),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(_uploadProgress * 100).round()}% subido...',
                style: TextStyle(color: textS, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],

            // ── Error ───────────────────────────────────────────────────────
            if (_uploadError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  _uploadError!,
                  style: const TextStyle(color: AppColors.red, fontSize: 12),
                ),
              ),
            ],

            const SizedBox(height: 28),

            // ── Botón subir ─────────────────────────────────────────────────
            ElevatedButton.icon(
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload_rounded, size: 18),
              label: Text(_uploading ? 'Subiendo...' : 'Subir guía'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              onPressed: _uploading ? null : _uploadGuide,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
