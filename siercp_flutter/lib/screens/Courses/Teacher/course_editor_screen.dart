// ─── course_editor_screen.dart ────────────────────────────────────────────────
// CAMBIOS:
//   • _TeoriaConfig: el PDF ya NO se escribe a mano — hay un botón que abre
//     el file picker, sube el archivo a Firebase Storage y guarda la URL.
//   • El link de YouTube se valida (acepta watch?v=, youtu.be, shorts/).
//   • Se exporta _TeoriaConfig para reutilizarlo si hace falta.

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/course_module.dart';
import '../../../services/course_service.dart';
import '../../../core/theme.dart';

import '../../../core/theme.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────
class CourseEditorScreen extends ConsumerStatefulWidget {
  final String courseId;
  const CourseEditorScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseEditorScreen> createState() => _CourseEditorScreenState();
}

class _CourseEditorScreenState extends ConsumerState<CourseEditorScreen> {
  @override
  Widget build(BuildContext context) {
    final modulesAsync = ref.watch(courseModulesProvider(widget.courseId));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        title: const Text('Editor de módulos',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _showAddModuleSheet(),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Módulo'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
      body: modulesAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.brand)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (modules) => modules.isEmpty
            ? _EmptyModulesState(onAdd: _showAddModuleSheet)
            : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: modules.length,
                onReorder: (o, n) => _reorderModules(modules, o, n),
                itemBuilder: (_, i) => _ModuleEditorCard(
                  key: ValueKey(modules[i].id),
                  module: modules[i],
                  index: i,
                  onEdit: () => _editModule(modules[i]),
                  onDelete: () => _deleteModule(modules[i].id),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/course-detail/${widget.courseId}'),
        backgroundColor: AppColors.brand.withValues(alpha: 0.15),
        foregroundColor: AppColors.brand,
        elevation: 0,
        icon: const Icon(Icons.preview_rounded, size: 18),
        label: const Text('Vista alumno',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showAddModuleSheet({CourseModule? editing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddModuleSheet(
        courseId: widget.courseId,
        editing: editing,
        onSaved: () => ref.invalidate(courseModulesProvider(widget.courseId)),
      ),
    );
  }

  void _editModule(CourseModule module) => _showAddModuleSheet(editing: module);

  Future<void> _deleteModule(String moduleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar módulo'),
        content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref
          .read(courseServiceProvider)
          .deleteModule(widget.courseId, moduleId);
      if (mounted) {
        ref.invalidate(courseModulesProvider(widget.courseId));
      }
    }
  }

  Future<void> _reorderModules(
      List<CourseModule> modules, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final reordered = [...modules];
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    await ref
        .read(courseServiceProvider)
        .reorderModules(widget.courseId, reordered.map((m) => m.id).toList());
    ref.invalidate(courseModulesProvider(widget.courseId));
  }
}

// ─── Card de módulo en el editor ──────────────────────────────────────────────
class _ModuleEditorCard extends StatelessWidget {
  final CourseModule module;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ModuleEditorCard({
    super.key,
    required this.module,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;
    final typeColor = _colorForType(module.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Center(
              child:
                  Text(module.type.icon, style: const TextStyle(fontSize: 20))),
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('M${index + 1}',
                style: TextStyle(
                    color: typeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(module.title,
                style: TextStyle(
                    color: textP, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Text(module.type.label,
                style: TextStyle(
                    color: typeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 6),
            Text('·', style: TextStyle(color: textS)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(_moduleSubtitle(module),
                  style: TextStyle(color: textS, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.brand,
              onPressed: onEdit,
              tooltip: 'Editar'),
          IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: AppColors.red,
              onPressed: onDelete,
              tooltip: 'Eliminar'),
          const Icon(Icons.drag_handle_rounded, size: 20, color: Colors.grey),
        ]),
      ),
    );
  }

  String _moduleSubtitle(CourseModule m) {
    switch (m.type) {
      case ModuleType.teoria:
        final parts = <String>[
          if (m.pdfUrl != null) '📄 PDF',
          if (m.videoUrl != null) '🎬 Video',
        ];
        return parts.isEmpty ? 'Sin contenido aún' : parts.join('  ');
      case ModuleType.evaluacion_teorica:
        return '${m.questions.length} preguntas · mín. ${m.passingScore}%';
      case ModuleType.practica_guiada:
        return m.requiredSessions
            .map((s) => '${s.count}× ${s.scenarioId}')
            .join(', ');
      case ModuleType.certificacion:
        return 'Genera certificado PDF automático';
    }
  }

  Color _colorForType(ModuleType t) {
    switch (t) {
      case ModuleType.teoria:
        return AppColors.brand;
      case ModuleType.evaluacion_teorica:
        return AppColors.amber;
      case ModuleType.practica_guiada:
        return AppColors.red;
      case ModuleType.certificacion:
        return AppColors.green;
    }
  }
}

// ─── Bottom sheet agregar/editar módulo ───────────────────────────────────────
class _AddModuleSheet extends ConsumerStatefulWidget {
  final String courseId;
  final CourseModule? editing;
  final VoidCallback onSaved;

  const _AddModuleSheet(
      {required this.courseId, required this.onSaved, this.editing});

  @override
  ConsumerState<_AddModuleSheet> createState() => _AddModuleSheetState();
}

class _AddModuleSheetState extends ConsumerState<_AddModuleSheet> {
  ModuleType _selectedType = ModuleType.teoria;
  final _titleCtrl = TextEditingController();
  final _pdfUrlCtrl = TextEditingController();
  final _videoUrlCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  int _passingScore = 80;
  final List<QuizQuestion> _questions = [];
  final List<RequiredSession> _requiredSessions = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _selectedType = e.type;
      _titleCtrl.text = e.title;
      _pdfUrlCtrl.text = e.pdfUrl ?? '';
      _videoUrlCtrl.text = e.videoUrl ?? '';
      _textCtrl.text = e.textContent ?? '';
      _passingScore = e.passingScore;
      _questions.addAll(e.questions);
      _requiredSessions.addAll(e.requiredSessions);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final bg = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(children: [
              Text(
                widget.editing != null ? 'Editar módulo' : 'Nuevo módulo',
                style: TextStyle(
                    color: textP, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (_saving)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.brand))
              else
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 16)),
                  child:
                      Text(widget.editing != null ? 'Actualizar' : 'Guardar'),
                ),
            ]),
          ),
          Divider(color: border, height: 0.5),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                TextField(
                  controller: _titleCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Título del módulo',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Tipo de módulo',
                    style: TextStyle(
                        color: textP,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                ...ModuleType.values.map((t) => _TypeSelector(
                      type: t,
                      selected: _selectedType == t,
                      onTap: () => setState(() => _selectedType = t),
                    )),
                const SizedBox(height: 24),
                _buildConfigSection(),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildConfigSection() {
    switch (_selectedType) {
      case ModuleType.teoria:
        return TeoriaConfig(
          pdfUrlCtrl: _pdfUrlCtrl,
          videoUrlCtrl: _videoUrlCtrl,
          textCtrl: _textCtrl,
          courseId: widget.courseId,
        );
      case ModuleType.evaluacion_teorica:
        return _QuizConfig(
          passingScore: _passingScore,
          questions: _questions,
          onScoreChanged: (v) => setState(() => _passingScore = v),
          onQuestionsChanged: (q) => setState(() {
            _questions.clear();
            _questions.addAll(q);
          }),
        );
      case ModuleType.practica_guiada:
        return _PracticaConfig(
          sessions: _requiredSessions,
          onChanged: (s) => setState(() {
            _requiredSessions.clear();
            _requiredSessions.addAll(s);
          }),
        );
      case ModuleType.certificacion:
        return _CertificacionInfo();
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El título no puede estar vacío')));
      }
      return;
    }
    setState(() => _saving = true);
    Map<String, dynamic> config = {};
    switch (_selectedType) {
      case ModuleType.teoria:
        config = {
          if (_pdfUrlCtrl.text.trim().isNotEmpty)
            'pdfUrl': _pdfUrlCtrl.text.trim(),
          if (_videoUrlCtrl.text.trim().isNotEmpty)
            'videoUrl': _videoUrlCtrl.text.trim(),
          if (_textCtrl.text.trim().isNotEmpty)
            'textContent': _textCtrl.text.trim(),
        };
        break;
      case ModuleType.evaluacion_teorica:
        config = {
          'passingScore': _passingScore,
          'questions': _questions.map((q) => q.toMap()).toList(),
        };
        break;
      case ModuleType.practica_guiada:
        config = {
          'requiredSessions': _requiredSessions.map((s) => s.toMap()).toList()
        };
        break;
      case ModuleType.certificacion:
        config = {};
        break;
    }
    try {
      final svc = ref.read(courseServiceProvider);
      if (widget.editing != null) {
        await svc.updateModule(widget.courseId, widget.editing!.id,
            title: _titleCtrl.text.trim(), type: _selectedType, config: config);
      } else {
        await svc.createModule(
          courseId: widget.courseId,
          title: _titleCtrl.text.trim(),
          type: _selectedType,
          config: config,
        );
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.red.withValues(alpha: 0.9)));
      }
    }
  }
}

// ─── Type Selector ─────────────────────────────────────────────────────────────
class _TypeSelector extends StatelessWidget {
  final ModuleType type;
  final bool selected;
  final VoidCallback onTap;
  const _TypeSelector(
      {required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color();
    final border = theme.colorScheme.outline;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.08)
              : theme.colorScheme.surface,
          border: Border.all(
              color: selected ? color : border, width: selected ? 1.5 : 0.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(children: [
          Text(type.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(type.label,
                  style: TextStyle(
                    color: selected ? color : theme.textTheme.bodyLarge?.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
              Text(type.description,
                  style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color, fontSize: 11)),
            ]),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, color: color, size: 20),
        ]),
      ),
    );
  }

  Color _color() {
    switch (type) {
      case ModuleType.teoria:
        return AppColors.brand;
      case ModuleType.evaluacion_teorica:
        return AppColors.amber;
      case ModuleType.practica_guiada:
        return AppColors.red;
      case ModuleType.certificacion:
        return AppColors.green;
    }
  }
}

// ─── Config: Teoría (REDISEÑADO) ──────────────────────────────────────────────
/// Permite al profesor:
///   1. Cargar un PDF desde el celular → sube a Firebase Storage → guarda URL.
///   2. Pegar/escribir un link de YouTube (validado).
///   3. Escribir texto de descripción.
class TeoriaConfig extends StatefulWidget {
  final TextEditingController pdfUrlCtrl;
  final TextEditingController videoUrlCtrl;
  final TextEditingController textCtrl;
  final String courseId;

  const TeoriaConfig({
    super.key,
    required this.pdfUrlCtrl,
    required this.videoUrlCtrl,
    required this.textCtrl,
    required this.courseId,
  });

  @override
  State<TeoriaConfig> createState() => _TeoriaConfigState();
}

class _TeoriaConfigState extends State<TeoriaConfig> {
  bool _uploadingPdf = false;
  String? _pdfFileName;
  double _uploadProgress = 0;

  // ── Selector + upload PDF ──────────────────────────────────────────────────
  Future<void> _pickAndUploadPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final path = file.path;
    if (path == null) return;

    setState(() {
      _uploadingPdf = true;
      _pdfFileName = file.name;
      _uploadProgress = 0;
    });

    try {
      final storageRef = FirebaseStorage.instance.ref().child(
          'courses/${widget.courseId}/pdfs/${DateTime.now().millisecondsSinceEpoch}_${file.name}');

      final uploadTask = storageRef.putFile(File(path));

      uploadTask.snapshotEvents.listen((snapshot) {
        if (mounted) {
          setState(() => _uploadProgress =
              snapshot.bytesTransferred / snapshot.totalBytes);
        }
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      widget.pdfUrlCtrl.text = downloadUrl;
      if (mounted) {
        setState(() => _uploadingPdf = false);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('PDF subido correctamente'),
          ]),
          backgroundColor: AppColors.green,
        ));
      }
    } catch (e) {
      setState(() => _uploadingPdf = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al subir PDF: $e'),
          backgroundColor: AppColors.red.withValues(alpha: 0.9),
        ));
      }
    }
  }

  // ── Validar YouTube URL ────────────────────────────────────────────────────
  bool _isValidYouTubeUrl(String url) {
    if (url.isEmpty) return true; // vacío = opcional, no es error
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return (uri.host.contains('youtube.com') &&
            uri.queryParameters.containsKey('v')) ||
        uri.host.contains('youtu.be') ||
        (uri.host.contains('youtube.com') &&
            uri.pathSegments.contains('shorts'));
  }

  /// Extrae el video ID de cualquier formato de URL de YouTube
  String? _extractYouTubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.queryParameters.containsKey('v')) return uri.queryParameters['v'];
    if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty)
      return uri.pathSegments.first;
    if (uri.pathSegments.contains('shorts') && uri.pathSegments.length > 1) {
      final idx = uri.pathSegments.indexOf('shorts');
      return uri.pathSegments[idx + 1];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final border = theme.colorScheme.outline;
    final hasPdf = widget.pdfUrlCtrl.text.isNotEmpty;
    final youtubeId = _extractYouTubeId(widget.videoUrlCtrl.text);
    final isYouTubeValid = _isValidYouTubeUrl(widget.videoUrlCtrl.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
            'Contenido del módulo', Icons.book_outlined, AppColors.brand),
        const SizedBox(height: 16),

        // ── Sección PDF ───────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.04),
            border: Border.all(
              color: hasPdf
                  ? AppColors.brand.withValues(alpha: 0.3)
                  : border.withValues(alpha: 0.5),
              width: 0.8,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.picture_as_pdf_outlined,
                    size: 16, color: AppColors.brand),
                const SizedBox(width: 8),
                Text('Archivo PDF',
                    style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                if (hasPdf && !_uploadingPdf)
                  GestureDetector(
                    onTap: () {
                      widget.pdfUrlCtrl.clear();
                      setState(() => _pdfFileName = null);
                    },
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.red),
                  ),
              ]),
              const SizedBox(height: 10),
              if (_uploadingPdf) ...[
                Text('Subiendo: $_pdfFileName',
                    style: TextStyle(color: textS, fontSize: 12)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: border.withValues(alpha: 0.2),
                    color: AppColors.brand,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${(_uploadProgress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: textS, fontSize: 11)),
              ] else if (hasPdf) ...[
                Row(children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 14, color: AppColors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _pdfFileName ?? 'PDF cargado',
                      style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickAndUploadPdf,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Cambiar PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brand,
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ] else ...[
                Text('Selecciona un archivo PDF desde tu dispositivo',
                    style: TextStyle(color: textS, fontSize: 12)),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _pickAndUploadPdf,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Cargar PDF desde el celular'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Sección Video YouTube ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.03),
            border: Border.all(
              color: widget.videoUrlCtrl.text.isNotEmpty && !isYouTubeValid
                  ? AppColors.red.withValues(alpha: 0.5)
                  : border.withValues(alpha: 0.5),
              width: 0.8,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.play_circle_outline_rounded,
                    size: 16, color: Colors.red),
                const SizedBox(width: 8),
                const Text('Video de YouTube',
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('opcional', style: TextStyle(color: textS, fontSize: 10)),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: widget.videoUrlCtrl,
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Enlace de YouTube',
                  hintText: 'https://youtu.be/xxx  o  youtube.com/watch?v=xxx',
                  prefixIcon: const Icon(Icons.link_rounded),
                  errorText:
                      widget.videoUrlCtrl.text.isNotEmpty && !isYouTubeValid
                          ? 'URL de YouTube no válida'
                          : null,
                  suffixIcon: widget.videoUrlCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            widget.videoUrlCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
              // Preview thumbnail si la URL es válida
              if (youtubeId != null) ...[
                const SizedBox(height: 10),
                Container(
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    image: DecorationImage(
                      image: NetworkImage(
                          'https://img.youtube.com/vi/$youtubeId/mqdefault.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                    child: const Center(
                      child: Icon(Icons.play_circle_filled_rounded,
                          color: Colors.white, size: 36),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Vista previa del video · ID: $youtubeId',
                    style: TextStyle(color: textS, fontSize: 10)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Texto / descripción ───────────────────────────────────────────────
        TextField(
          controller: widget.textCtrl,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Texto / descripción del módulo',
            prefixIcon: Icon(Icons.text_snippet_outlined),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

// ─── Quiz config (sin cambios estructurales) ──────────────────────────────────
class _QuizConfig extends StatefulWidget {
  final int passingScore;
  final List<QuizQuestion> questions;
  final ValueChanged<int> onScoreChanged;
  final ValueChanged<List<QuizQuestion>> onQuestionsChanged;

  const _QuizConfig({
    required this.passingScore,
    required this.questions,
    required this.onScoreChanged,
    required this.onQuestionsChanged,
  });

  @override
  State<_QuizConfig> createState() => _QuizConfigState();
}

class _QuizConfigState extends State<_QuizConfig> {
  late List<QuizQuestion> _questions;

  @override
  void initState() {
    super.initState();
    _questions = [...widget.questions];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle(
          'Configuración del quiz', Icons.quiz_outlined, AppColors.amber),
      const SizedBox(height: 12),
      Text('Nota mínima para aprobar: ${widget.passingScore}%',
          style: TextStyle(color: textP, fontSize: 13)),
      Slider(
        value: widget.passingScore.toDouble(),
        min: 50,
        max: 100,
        divisions: 10,
        activeColor: AppColors.amber,
        label: '${widget.passingScore}%',
        onChanged: (v) => widget.onScoreChanged(v.toInt()),
      ),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Preguntas (${_questions.length})',
            style: TextStyle(
                color: textP, fontSize: 13, fontWeight: FontWeight.w600)),
        TextButton.icon(
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Agregar'),
          onPressed: _addQuestion,
        ),
      ]),
      ..._questions.asMap().entries.map((e) => _QuestionCard(
            index: e.key,
            question: e.value,
            onDelete: () {
              setState(() => _questions.removeAt(e.key));
              widget.onQuestionsChanged(_questions);
            },
            onEdit: () => _editQuestion(e.key, e.value),
          )),
    ]);
  }

  void _addQuestion() => _showQuestionDialog();
  void _editQuestion(int index, QuizQuestion q) =>
      _showQuestionDialog(index: index, existing: q);

  void _showQuestionDialog({int? index, QuizQuestion? existing}) {
    final textCtrl = TextEditingController(text: existing?.text ?? '');
    final optionCtrls = List.generate(
        4,
        (i) => TextEditingController(
            text: existing != null && i < existing.options.length
                ? existing.options[i]
                : ''));
    int correct = existing?.correctIndex ?? 0;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing != null ? 'Editar pregunta' : 'Nueva pregunta'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: textCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Texto de la pregunta',
                    prefixIcon: Icon(Icons.help_outline_rounded),
                    alignLabelWithHint: true),
              ),
              const SizedBox(height: 16),
              const Text('Opciones (selecciona la correcta):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...List.generate(
                  4,
                  (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Radio<int>(
                              value: i,
                              groupValue: correct,
                              activeColor: AppColors.green,
                              onChanged: (v) => setSt(() => correct = v!)),
                          Expanded(
                            child: TextField(
                              controller: optionCtrls[i],
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                  labelText: 'Opción ${i + 1}', isDense: true),
                            ),
                          ),
                        ]),
                      )),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final opts = optionCtrls.map((c) => c.text.trim()).toList();
                if (textCtrl.text.trim().isEmpty || opts.any((o) => o.isEmpty))
                  return;
                final q = QuizQuestion(
                    text: textCtrl.text.trim(),
                    options: opts,
                    correctIndex: correct);
                setState(() {
                  if (index != null)
                    _questions[index] = q;
                  else
                    _questions.add(q);
                  widget.onQuestionsChanged(_questions);
                });
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final QuizQuestion question;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _QuestionCard(
      {required this.index,
      required this.question,
      required this.onDelete,
      required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.05),
        border: Border.all(
            color: AppColors.amber.withValues(alpha: 0.2), width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20)),
            child: Text('P${index + 1}',
                style: const TextStyle(
                    color: AppColors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(question.text,
                  style: TextStyle(
                      color: textP, fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis)),
          IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              color: AppColors.brand,
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
          IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              color: AppColors.red,
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
        ]),
        const SizedBox(height: 6),
        ...question.options.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(children: [
                Icon(
                  e.key == question.correctIndex
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 12,
                  color:
                      e.key == question.correctIndex ? AppColors.green : textS,
                ),
                const SizedBox(width: 6),
                Text(e.value,
                    style: TextStyle(
                        color: e.key == question.correctIndex
                            ? AppColors.green
                            : textS,
                        fontSize: 11)),
              ]),
            )),
      ]),
    );
  }
}

// ─── Practica Config (sin cambios) ────────────────────────────────────────────
class _PracticaConfig extends StatefulWidget {
  final List<RequiredSession> sessions;
  final ValueChanged<List<RequiredSession>> onChanged;
  const _PracticaConfig({required this.sessions, required this.onChanged});
  @override
  State<_PracticaConfig> createState() => _PracticaConfigState();
}

class _PracticaConfigState extends State<_PracticaConfig> {
  late List<RequiredSession> _sessions;
  @override
  void initState() {
    super.initState();
    _sessions = [...widget.sessions];
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle(
          'Sesiones requeridas', Icons.favorite_outline, AppColors.red),
      const SizedBox(height: 12),
      ..._sessions.asMap().entries.map((e) => _SessionRow(
            session: e.value,
            onDelete: () {
              setState(() => _sessions.removeAt(e.key));
              widget.onChanged(_sessions);
            },
            onChanged: (s) {
              setState(() => _sessions[e.key] = s);
              widget.onChanged(_sessions);
            },
          )),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () {
          setState(() => _sessions.add(const RequiredSession(
              scenarioId: 'adulto', count: 1, minScore: 70)));
          widget.onChanged(_sessions);
        },
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Agregar sesión requerida'),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
      ),
    ]);
  }
}

class _SessionRow extends StatefulWidget {
  final RequiredSession session;
  final VoidCallback onDelete;
  final ValueChanged<RequiredSession> onChanged;
  const _SessionRow(
      {required this.session, required this.onDelete, required this.onChanged});
  @override
  State<_SessionRow> createState() => _SessionRowState();
}

class _SessionRowState extends State<_SessionRow> {
  late String _scenario;
  late int _count;
  late int _minScore;

  @override
  void initState() {
    super.initState();
    _scenario = widget.session.scenarioId;
    // Migración de datos viejos
    const valid = [
      'paroCardiaco',
      'accidenteTransito',
      'ahogamiento',
      'descargaElectrica'
    ];
    if (!valid.contains(_scenario)) {
      _scenario = 'paroCardiaco';
    }

    _count = widget.session.count;
    _minScore = widget.session.minScore;
  }

  void _notify() => widget.onChanged(RequiredSession(
      scenarioId: _scenario, count: _count, minScore: _minScore));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const scenarios = <String>[
      'paroCardiaco',
      'accidenteTransito',
      'ahogamiento',
      'descargaElectrica'
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.05),
        border: Border.all(
          color: AppColors.red.withValues(alpha: 0.2),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _scenario,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Escenario',
                    isDense: true,
                  ),
                  items: scenarios.map((scenario) {
                    final color = _scenarioColor(scenario);
                    final icon = _scenarioIcon(scenario);

                    return DropdownMenuItem<String>(
                      value: scenario,
                      child: Row(
                        children: [
                          Icon(icon, size: 18, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _scenarioLabel(scenario),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _scenario = v);
                    _notify();
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 70,
                child: TextFormField(
                  initialValue: _count.toString(),
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Cant.', isDense: true),
                  onChanged: (v) {
                    setState(() => _count = int.tryParse(v) ?? 1);
                    _notify();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: AppColors.red,
                onPressed: widget.onDelete,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Puntaje mínimo: $_minScore%',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _minScore.toDouble(),
            min: 50,
            max: 100,
            divisions: 10,
            activeColor: AppColors.red,
            label: '$_minScore%',
            onChanged: (v) {
              setState(() => _minScore = v.toInt());
              _notify();
            },
          ),
        ],
      ),
    );
  }

// ─── Helpers ───────────────────────────────────────────────────────────────

  /// Color según escenario
  Color _scenarioColor(String scenario) {
    switch (scenario) {
      case 'paroCardiaco':
        return AppColors.red;
      case 'accidenteTransito':
        return AppColors.amber;
      case 'ahogamiento':
        return AppColors.cyan;
      case 'descargaElectrica':
        return const Color(0xFFFFC107);
      default:
        return AppColors.textSecondary;
    }
  }

  /// Icono según escenario
  IconData _scenarioIcon(String scenario) {
    switch (scenario) {
      case 'paroCardiaco':
        return Icons.heart_broken_rounded;
      case 'accidenteTransito':
        return Icons.local_hospital_rounded;
      case 'ahogamiento':
        return Icons.water_damage_rounded;
      case 'descargaElectrica':
        return Icons.bolt_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  /// Etiqueta legible del escenario
  String _scenarioLabel(String scenario) {
    switch (scenario) {
      case 'paroCardiaco':
        return 'Paro cardíaco';
      case 'accidenteTransito':
        return 'Accidente de tránsito';
      case 'ahogamiento':
        return 'Ahogamiento';
      case 'descargaElectrica':
        return 'Descarga eléctrica';
      default:
        return scenario[0].toUpperCase() + scenario.substring(1);
    }
  }
}

// ─── Certificación info ────────────────────────────────────────────────────────
class _CertificacionInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.06),
        border: Border.all(
            color: AppColors.green.withValues(alpha: 0.2), width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Column(children: [
        Text('🏆', style: TextStyle(fontSize: 32)),
        SizedBox(height: 8),
        Text('Módulo de Certificación',
            style: TextStyle(
                color: AppColors.green,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
        SizedBox(height: 6),
        Text(
          'Este módulo se desbloquea automáticamente cuando el alumno completa todos los módulos anteriores.\n\n'
          'Al completarlo, el sistema genera y envía automáticamente un certificado PDF firmado al estudiante.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ]),
    );
  }
}

// ─── Helpers UI ───────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionTitle(this.title, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _EmptyModulesState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyModulesState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final textS = Theme.of(context).textTheme.bodyMedium?.color ??
        AppColors.textSecondary;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.layers_outlined, size: 48, color: textS),
        const SizedBox(height: 16),
        Text('Sin módulos', style: TextStyle(color: textS, fontSize: 14)),
        const SizedBox(height: 6),
        Text('Agrega módulos para estructurar el curso',
            style: TextStyle(color: textS, fontSize: 12)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Agregar primer módulo'),
        ),
      ]),
    );
  }
}
