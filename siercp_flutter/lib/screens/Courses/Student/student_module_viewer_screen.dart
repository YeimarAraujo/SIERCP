// ─── student_module_viewer_screen.dart ───────────────────────────────────────
// El ALUMNO ve aquí el contenido de un módulo de Teoría:
//   • PDF → se muestra con flutter_pdfview (inline, sin salir de la app).
//   • Video YouTube → se reproduce dentro de la app con youtube_player_iframe.
//   • Texto → se muestra directamente.
// Al finalizar, el alumno puede marcar el módulo como completado.

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'dart:io';
import '../../../core/theme.dart';
import '../../../models/course_module.dart';
import '../../../services/course_service.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────
class StudentModuleViewerScreen extends ConsumerStatefulWidget {
  final CourseModule module;
  final String courseId;
  final String studentId;
  final bool isCompleted;

  const StudentModuleViewerScreen({
    super.key,
    required this.module,
    required this.courseId,
    required this.studentId,
    required this.isCompleted,
  });

  @override
  ConsumerState<StudentModuleViewerScreen> createState() =>
      _StudentModuleViewerScreenState();
}

class _StudentModuleViewerScreenState
    extends ConsumerState<StudentModuleViewerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _marking = false;
  bool _completed = false;

  // ── PDF ────────────────────────────────────────────────────────────────────
  String? _localPdfPath;
  bool _loadingPdf = false;
  String? _pdfError;

  // ── YouTube ────────────────────────────────────────────────────────────────
  YoutubePlayerController? _ytController;

  @override
  void initState() {
    super.initState();
    _completed = widget.isCompleted;

    final tabs = _buildTabs();
    _tabController = TabController(length: tabs.length, vsync: this);

    if (widget.module.pdfUrl != null) {
      _loadPdf(widget.module.pdfUrl!);
    }

    // Inicializar YouTube con youtube_player_iframe
    if (widget.module.videoUrl != null) {
      final videoId = YoutubePlayerController.convertUrlToId(
        widget.module.videoUrl!,
      );
      if (videoId != null) {
        _ytController = YoutubePlayerController.fromVideoId(
          videoId: videoId,
          params: const YoutubePlayerParams(
            showFullscreenButton: true,
            mute: false,
            showControls: true,
            playsInline: true,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ytController?.close(); // close() en lugar de dispose()
    super.dispose();
  }

  // ── Descargar PDF a temp y mostrarlo localmente ─────────────────────────────
  Future<void> _loadPdf(String url) async {
    setState(() {
      _loadingPdf = true;
      _pdfError = null;
    });
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('HTTP \${response.statusCode}');
      }
      final dir = await getTemporaryDirectory();
      final file = File('\${dir.path}/module_\${widget.module.id}.pdf');
      await file.writeAsBytes(response.bodyBytes);
      setState(() {
        _localPdfPath = file.path;
        _loadingPdf = false;
      });
    } catch (e) {
      setState(() {
        _pdfError = 'No se pudo cargar el PDF: \$e';
        _loadingPdf = false;
      });
    }
  }

  // ── Tabs disponibles ────────────────────────────────────────────────────────
  List<_TabItem> _buildTabs() {
    final tabs = <_TabItem>[];
    if (widget.module.pdfUrl != null) {
      tabs.add(_TabItem(label: 'PDF', icon: Icons.picture_as_pdf_outlined));
    }
    if (widget.module.videoUrl != null) {
      tabs.add(
        _TabItem(label: 'Video', icon: Icons.play_circle_outline_rounded),
      );
    }
    if (widget.module.textContent != null &&
        widget.module.textContent!.isNotEmpty) {
      tabs.add(
        _TabItem(label: 'Contenido', icon: Icons.text_snippet_outlined),
      );
    }
    if (tabs.isEmpty) {
      tabs.add(_TabItem(label: 'Info', icon: Icons.info_outline_rounded));
    }
    return tabs;
  }

  // ── Marcar como completado ──────────────────────────────────────────────────
  Future<void> _markComplete() async {
    setState(() => _marking = true);
    try {
      await ref.read(courseServiceProvider).markModuleComplete(
            courseId: widget.courseId,
            moduleId: widget.module.id,
            studentId: widget.studentId,
          );
      setState(() {
        _completed = true;
        _marking = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('¡Módulo completado! 🎉'),
          ]),
          backgroundColor: AppColors.green,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _marking = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: \$e'),
          backgroundColor: AppColors.red.withValues(alpha: 0.9),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final tabs = _buildTabs();

    // YoutubePlayerScaffold envuelve el Scaffold completo para manejar
    // correctamente el fullscreen en youtube_player_iframe.
    // Si no hay video, se renderiza el Scaffold directamente.
    if (_ytController != null) {
      return YoutubePlayerScaffold(
        controller: _ytController!,
        aspectRatio: 16 / 9,
        builder: (context, player) => _buildScaffold(
          context,
          theme,
          textP,
          textS,
          tabs,
          player,
        ),
      );
    }

    return _buildScaffold(context, theme, textP, textS, tabs, null);
  }

  Scaffold _buildScaffold(
    BuildContext context,
    ThemeData theme,
    Color textP,
    Color textS,
    List<_TabItem> tabs,
    Widget? player,
  ) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.module.title,
              style: TextStyle(
                color: textP,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.module.type.label,
              style: TextStyle(color: AppColors.brand, fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (_completed)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.green, size: 14),
                SizedBox(width: 4),
                Text(
                  'Completado',
                  style: TextStyle(
                    color: AppColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
            ),
        ],
        bottom: tabs.length > 1
            ? TabBar(
                controller: _tabController,
                indicatorColor: AppColors.brand,
                labelColor: AppColors.brand,
                unselectedLabelColor: textS,
                tabs: tabs
                    .map(
                      (t) => Tab(icon: Icon(t.icon, size: 16), text: t.label),
                    )
                    .toList(),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: tabs.length > 1
                ? TabBarView(
                    controller: _tabController,
                    children: _buildTabViews(player, tabs),
                  )
                : _buildTabViews(player, tabs).first,
          ),

          // ── Botón "Marcar como completado" ─────────────────────────────
          if (!_completed)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton.icon(
                  onPressed: _marking ? null : _markComplete,
                  icon: _marking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                  label: Text(
                    _marking ? 'Guardando...' : 'Marcar como completado',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildTabViews(Widget? player, List<_TabItem> tabs) {
    final views = <Widget>[];
    if (widget.module.pdfUrl != null) views.add(_buildPdfTab());
    if (widget.module.videoUrl != null) views.add(_buildVideoTab(player));
    if (widget.module.textContent != null &&
        widget.module.textContent!.isNotEmpty) {
      views.add(_buildTextTab());
    }
    if (views.isEmpty) views.add(_buildEmptyTab());
    return views;
  }

  // ── Vista PDF ──────────────────────────────────────────────────────────────
  Widget _buildPdfTab() {
    if (_loadingPdf) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: AppColors.brand),
          SizedBox(height: 16),
          Text('Cargando PDF...', style: TextStyle(fontSize: 13)),
        ]),
      );
    }
    if (_pdfError != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.red),
          const SizedBox(height: 12),
          Text(
            _pdfError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.red, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _loadPdf(widget.module.pdfUrl!),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reintentar'),
          ),
        ]),
      );
    }
    if (_localPdfPath == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }
    return PDFView(
      filePath: _localPdfPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: false,
      pageFling: false,
      pageSnap: false,
      fitEachPage: true,
      onError: (error) => setState(() => _pdfError = error.toString()),
    );
  }

  // ── Vista Video YouTube ────────────────────────────────────────────────────
  // [player] viene del builder de YoutubePlayerScaffold; null si no hay video.
  Widget _buildVideoTab(Widget? player) {
    if (_ytController == null || player == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.play_disabled_rounded, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          const Text('URL de video no válida', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            widget.module.videoUrl ?? '',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ]),
      );
    }

    final theme = Theme.of(context);
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reproductor YouTube integrado (16:9)
          player,
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.module.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.play_circle_fill_rounded,
                      size: 14, color: Colors.red),
                  const SizedBox(width: 6),
                  Text(
                    'YouTube · Reproducción integrada',
                    style: TextStyle(color: textS, fontSize: 12),
                  ),
                ]),
                if (widget.module.textContent != null &&
                    widget.module.textContent!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    widget.module.textContent!,
                    style: TextStyle(color: textS, fontSize: 14, height: 1.6),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Vista Texto ────────────────────────────────────────────────────────────
  Widget _buildTextTab() {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Text(
        widget.module.textContent ?? '',
        style: TextStyle(color: textP, fontSize: 15, height: 1.7),
      ),
    );
  }

  // ── Empty ──────────────────────────────────────────────────────────────────
  Widget _buildEmptyTab() {
    return const Center(
      child: Text(
        'Este módulo no tiene contenido aún.',
        style: TextStyle(fontSize: 13, color: Colors.grey),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  const _TabItem({required this.label, required this.icon});
}
