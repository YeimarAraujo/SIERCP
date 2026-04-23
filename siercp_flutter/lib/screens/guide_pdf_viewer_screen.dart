import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/guide.dart';
import '../providers/auth_provider.dart';
import '../services/guide_service.dart';
import '../core/theme.dart';

class GuidePDFViewerScreen extends ConsumerStatefulWidget {
  final GuideModel guide;
  const GuidePDFViewerScreen({super.key, required this.guide});

  @override
  ConsumerState<GuidePDFViewerScreen> createState() =>
      _GuidePDFViewerScreenState();
}

class _GuidePDFViewerScreenState extends ConsumerState<GuidePDFViewerScreen> {
  final PdfViewerController _pdfCtrl = PdfViewerController();

  int _currentPage = 1;
  int _totalPages  = 1;
  bool _loading    = true;
  bool _completed  = false;
  bool _canComplete = false;
  String? _localPath;
  String? _error;

  // Tracking de tiempo
  int _timeSpentSeconds  = 0;
  bool _isActive         = true;
  Timer? _readTimer;
  Timer? _inactivityTimer;

  static const int _inactivityThresholdSeconds = 120; // 2 minutos

  @override
  void initState() {
    super.initState();
    _loadPdf();
    _initTracking();
  }

  // ── Descargar PDF a cache local ──────────────────────────────────────────
  Future<void> _loadPdf() async {
    try {
      final url = widget.guide.pdfUrl;
      if (url.isEmpty) {
        setState(() {
          _error = 'Esta guía no tiene PDF disponible aún.';
          _loading = false;
        });
        return;
      }

      // Ruta de cache
      final tmpDir = await getTemporaryDirectory();
      final filePath = '${tmpDir.path}/guide_${widget.guide.id}.pdf';
      final file = File(filePath);

      // Si ya está en cache y no es más viejo de 24 horas, reutilizar
      if (file.existsSync()) {
        final age = DateTime.now().difference(
          await file.lastModified(),
        );
        if (age.inHours < 24) {
          setState(() { _localPath = filePath; _loading = false; });
          _incrementViewCount();
          return;
        }
      }

      // Descargar
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        setState(() { _localPath = filePath; _loading = false; });
        _incrementViewCount();
      } else {
        setState(() {
          _error = 'Error al descargar el PDF (${response.statusCode}).';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

  // ── Incrementar viewCount ─────────────────────────────────────────────────
  void _incrementViewCount() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    ref.read(guideServiceProvider).updateGuideProgress(
      user.id,
      widget.guide.id,
      timeSpentSeconds: 0,
      lastPageReached: 1,
      incrementViewCount: true,
    );
  }

  // ── Iniciar timers de lectura ─────────────────────────────────────────────
  void _initTracking() {
    _readTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isActive && !_completed) {
        setState(() => _timeSpentSeconds++);
        // Auto-guardar cada 30 segundos
        if (_timeSpentSeconds % 30 == 0) _saveProgress();
      }
    });
  }

  // ── Reiniciar timer de inactividad ────────────────────────────────────────
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    setState(() => _isActive = true);
    _inactivityTimer = Timer(
      const Duration(seconds: _inactivityThresholdSeconds),
      () => setState(() => _isActive = false),
    );
  }

  // ── Guardar progreso en Firestore ─────────────────────────────────────────
  void _saveProgress() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    ref.read(guideServiceProvider).updateGuideProgress(
      user.id,
      widget.guide.id,
      timeSpentSeconds: _timeSpentSeconds,
      lastPageReached: _currentPage,
    );
  }

  // ── Marcar como completada ────────────────────────────────────────────────
  Future<void> _markAsCompleted() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    await ref.read(guideServiceProvider).markGuideAsCompleted(
      user.id,
      widget.guide.id,
      _timeSpentSeconds,
    );

    setState(() => _completed = true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('¡Guía marcada como completada!'),
        ]),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Diálogo de confirmación de lectura ────────────────────────────────────
  void _showCompleteDialog() {
    final minSeconds = widget.guide.estimatedMinutes * 60 * 0.8;
    final hasSpentEnoughTime = _timeSpentSeconds >= minSeconds;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.check_circle_outline, color: AppColors.green, size: 22),
          const SizedBox(width: 10),
          const Text('Confirmar lectura'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Has leído completamente "${widget.guide.title}"?'),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.timer_outlined,
              label: 'Tiempo de lectura',
              value: _formatTime(_timeSpentSeconds),
            ),
            _InfoRow(
              icon: Icons.menu_book_outlined,
              label: 'Páginas vistas',
              value: '$_currentPage / $_totalPages',
            ),
            if (!hasSpentEnoughTime)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_outlined,
                      size: 14, color: AppColors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se recomienda al menos ${widget.guide.estimatedMinutes} minutos de lectura.',
                      style: const TextStyle(
                        color: AppColors.amber,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ]),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Seguir leyendo'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Sí, lo leí'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _markAsCompleted();
            },
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}min ${s.toString().padLeft(2, '0')}s';
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    _inactivityTimer?.cancel();
    _saveProgress(); // Guardar al cerrar
    _pdfCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final textS   = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final progress = _currentPage / _totalPages;

    return GestureDetector(
      onTap:          _resetInactivityTimer,
      onPanUpdate:    (_) => _resetInactivityTimer(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.guide.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!_loading && _localPath != null)
                Text(
                  'Página $_currentPage de $_totalPages  •  ${_formatTime(_timeSpentSeconds)}',
                  style: TextStyle(color: textS, fontSize: 10),
                ),
            ],
          ),
          actions: [
            // Indicador de actividad
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Icon(
                  _isActive ? Icons.circle : Icons.pause_circle_outline,
                  size: 12,
                  color: _isActive ? AppColors.green : AppColors.amber,
                ),
              ),
            ),
            // Botón completar
            if (!_completed && _canComplete)
              IconButton(
                tooltip: 'Marcar como completada',
                icon: const Icon(Icons.check_circle_outline_rounded),
                color: AppColors.green,
                onPressed: _showCompleteDialog,
              )
            else if (_completed)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.check_circle_rounded, color: AppColors.green),
              ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: _loading ? null : progress,
              backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation(
                _completed ? AppColors.green : AppColors.brand,
              ),
              minHeight: 4,
            ),
          ),
        ),

        body: _buildBody(),

        // Botón flotante para marcar si no está en AppBar
        floatingActionButton: (!_loading && !_completed && _canComplete)
            ? FloatingActionButton.extended(
                onPressed: _showCompleteDialog,
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.check_rounded),
                label: const Text('He leído esta guía'),
              )
            : null,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.brand),
            const SizedBox(height: 16),
            Text('Cargando guía...', style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 13,
            )),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf_outlined,
                  size: 56, color: AppColors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.red, fontSize: 14)),
              const SizedBox(height: 12),
              const Text(
                'Asegúrate de que el instructor haya cargado el archivo PDF.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return SfPdfViewer.file(
      File(_localPath!),
      controller: _pdfCtrl,
      onDocumentLoaded: (details) {
        setState(() => _totalPages = details.document.pages.count);
      },
      onPageChanged: (details) {
        setState(() {
          _currentPage = details.newPageNumber;
          // Permitir completar al llegar a la última página
          if (_currentPage >= _totalPages) {
            _canComplete = true;
          }
        });
        _resetInactivityTimer();
      },
    );
  }
}

// ─── Fila de información ──────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textS = Theme.of(context).textTheme.bodyMedium?.color
        ?? AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: textS),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(color: textS, fontSize: 12)),
          Text(value, style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}
