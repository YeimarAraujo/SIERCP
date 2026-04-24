import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/theme.dart';
import '../models/alert_course.dart';
import '../providers/session_provider.dart';
import '../providers/auth_provider.dart';
import '../services/admin_service.dart';
import '../services/export_service.dart';
import '../services/session_service.dart';
import '../widgets/section_label.dart';
import '../models/session.dart';

class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  // ─── Create course dialog ────────────────────────────────────────────────────
  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final estudiantesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline_rounded,
                color: AppColors.brand, size: 20),
            SizedBox(width: 10),
            Text('Crear nuevo curso'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre del curso',
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: estudiantesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Estudiantes (cédulas)',
                  hintText: 'Ej: 1234567, 9876543...',
                  prefixIcon: Icon(Icons.people_alt_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Crear'),
            onPressed: () async {
              try {
                final user = ref.read(currentUserProvider);
                await ref.read(sessionServiceProvider).createCourse(
                      name: nameCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      instructorId: user?.id ?? '',
                      instructorName: user?.fullName ?? '',
                    );
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ref.invalidate(coursesProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(children: [
                        Icon(Icons.check_circle_outline,
                            color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text('Curso creado con éxito'),
                      ]),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.red.withValues(alpha: 0.9),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // ─── Enroll student by cedula dialog ────────────────────────────────────────
  void _showEnrollDialog(String courseId) {
    final cedulaCtrl = TextEditingController();
    bool loading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add_outlined, color: AppColors.brand, size: 20),
              SizedBox(width: 10),
              Text('Inscribir estudiante'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: cedulaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cédula / Número de identificación',
                  hintText: 'Ej: 1234567890',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'El estudiante debe estar registrado en SIERCP con esa cédula.',
                style: TextStyle(
                  color: Theme.of(ctx).textTheme.bodyMedium?.color,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton.icon(
              icon: loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('Inscribir'),
              onPressed: loading
                  ? null
                  : () async {
                      setSt(() => loading = true);
                      try {
                        final user = ref.read(currentUserProvider);
                        await ref
                            .read(adminServiceProvider)
                            .enrollStudentByCedula(
                              courseId: courseId,
                              cedula: cedulaCtrl.text.trim(),
                              instructorId: user?.id ?? '',
                            );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ref.invalidate(coursesProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(children: [
                                Icon(Icons.check_circle_outline,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text('Estudiante inscrito con éxito'),
                              ]),
                            ),
                          );
                        }
                      } catch (e) {
                        setSt(() => loading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor:
                                  AppColors.red.withValues(alpha: 0.9),
                            ),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Join Course Dialog (Students) — con opción QR ─────────────────────────
  void _showJoinDialog() {
    final codeCtrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.sensor_door_outlined,
                  color: AppColors.brand, size: 20),
              SizedBox(width: 10),
              Text('Unirse a un curso'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Text field with QR scan button ───────────────────────────
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Código del curso',
                  hintText: 'Ej: X9J2P1',
                  prefixIcon: const Icon(Icons.key_outlined),
                  suffixIcon: IconButton(
                    tooltip: 'Escanear QR',
                    icon: const Icon(Icons.qr_code_scanner_rounded,
                        color: AppColors.brand),
                    onPressed: () async {
                      // Cerramos el diálogo actual y abrimos el scanner
                      Navigator.pop(ctx);
                      final scanned = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (_) => const _QRScannerPage(),
                        ),
                      );
                      if (scanned != null && scanned.isNotEmpty) {
                        // Reabrimos el diálogo con el código ya relleno
                        if (context.mounted) {
                          _showJoinDialogWithCode(scanned);
                        }
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // ── Quick scan hint ──────────────────────────────────────────
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 12,
                      color: Theme.of(ctx)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Escribe el código o toca el ícono QR para escanear.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(ctx)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              icon: loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.login_rounded, size: 16),
              label: const Text('Unirse'),
              onPressed: loading
                  ? null
                  : () => _doJoinCourse(
                        ctx,
                        codeCtrl.text.trim().toUpperCase(),
                        setSt,
                        (v) => loading = v,
                      ),
            ),
          ],
        ),
      ),
    );
  }

  /// Igual que _showJoinDialog pero con el código ya rellenado tras escanear
  void _showJoinDialogWithCode(String code) {
    final codeCtrl = TextEditingController(text: code);
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.qr_code_rounded, color: AppColors.brand, size: 20),
              SizedBox(width: 10),
              Text('Unirse a un curso'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Green banner: QR escaneado ───────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.green.withValues(alpha: 0.3),
                      width: 0.8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        color: AppColors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'QR escaneado correctamente',
                      style: TextStyle(
                          color: AppColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Código del curso',
                  prefixIcon: const Icon(Icons.key_outlined),
                  suffixIcon: IconButton(
                    tooltip: 'Escanear de nuevo',
                    icon: const Icon(Icons.qr_code_scanner_rounded,
                        color: AppColors.brand),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final scanned = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (_) => const _QRScannerPage(),
                        ),
                      );
                      if (scanned != null &&
                          scanned.isNotEmpty &&
                          context.mounted) {
                        _showJoinDialogWithCode(scanned);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              icon: loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.login_rounded, size: 16),
              label: const Text('Unirse'),
              onPressed: loading
                  ? null
                  : () => _doJoinCourse(
                        ctx,
                        codeCtrl.text.trim().toUpperCase(),
                        setSt,
                        (v) => loading = v,
                      ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lógica real de unirse al curso — compartida por ambos diálogos
  Future<void> _doJoinCourse(
    BuildContext ctx,
    String code,
    StateSetter setSt,
    void Function(bool) setLoading,
  ) async {
    if (code.isEmpty) return;
    setSt(() => setLoading(true));

    try {
      final user = ref.read(currentUserProvider);
      await ref.read(sessionServiceProvider).joinCourse(
            code,
            studentId: user?.id ?? '',
            studentName: user?.fullName ?? '',
            studentEmail: user?.email ?? '',
            identificacion: user?.identificacion,
          );
      if (context.mounted) {
        Navigator.pop(ctx);
        ref.invalidate(coursesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Te has unido al curso con éxito'),
            ]),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ ERROR joinCourse: $e');
      setSt(() => setLoading(false));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Verifica el código ($e)'),
            backgroundColor: AppColors.red.withValues(alpha: 0.9),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isInstructor = currentUser?.isInstructor ?? false;
    final isAdmin = currentUser?.isAdmin ?? false;
    final canManage = isInstructor || isAdmin;

    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(coursesProvider),
          color: AppColors.brand,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cursos',
                              style: TextStyle(
                                color: textP,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              )),
                          const SizedBox(height: 2),
                          Text(
                            canManage
                                ? 'Gestión de entrenamiento RCP'
                                : 'Tus cursos de entrenamiento',
                            style: TextStyle(color: textS, fontSize: 12),
                          ),
                        ],
                      ),
                      if (canManage)
                        ElevatedButton.icon(
                          onPressed: _showCreateDialog,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Nuevo'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: SectionLabel(
                    canManage ? 'Cursos activos' : 'Mis cursos',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: coursesAsync.when(
                  loading: () => const SizedBox(
                    height: 80,
                    child: Center(
                        child:
                            CircularProgressIndicator(color: AppColors.brand)),
                  ),
                  error: (e, __) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text('Error al cargar cursos: $e',
                          style: TextStyle(color: textS)),
                    ),
                  ),
                  data: (courses) => courses.isEmpty
                      ? _EmptyCoursesState(
                          canManage: canManage,
                          onCreate:
                              canManage ? _showCreateDialog : _showJoinDialog,
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: courses
                                .map((c) => _CourseCard(
                                      course: c,
                                      canManage: canManage,
                                      onEnroll: () => _showEnrollDialog(c.id),
                                    ))
                                .toList(),
                          ),
                        ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
      floatingActionButton: !canManage
          ? FloatingActionButton.extended(
              onPressed: _showJoinDialog,
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Unirse a curso'),
            )
          : null,
    );
  }
}

// ─── QR Scanner Page ───────────────────────────────────────────────────────────
class _QRScannerPage extends StatefulWidget {
  const _QRScannerPage();

  @override
  State<_QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<_QRScannerPage> {
  final MobileScannerController _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _scanned = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue;
    if (raw == null || raw.isEmpty) return;

    // Extraemos solo el código: si el QR contiene un JSON u otra estructura
    // buscamos el campo "code", si no, usamos el valor raw completo.
    String code = raw;
    try {
      // Soporte para QR generado como: siercp://course?code=X9J2P1
      final uri = Uri.tryParse(raw);
      if (uri != null && uri.queryParameters.containsKey('code')) {
        code = uri.queryParameters['code']!;
      }
    } catch (_) {}

    setState(() => _scanned = true);
    _ctrl.stop();
    Navigator.of(context).pop(code.toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear código QR',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _torchOn ? Colors.amber : Colors.white,
            ),
            onPressed: () {
              _ctrl.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
          IconButton(
            icon:
                const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
            onPressed: () => _ctrl.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Camera view ──────────────────────────────────────────────────
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
          ),

          // ── Overlay: dark frame with transparent window ──────────────────
          _ScannerOverlay(),

          // ── Bottom hint ──────────────────────────────────────────────────
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Apunta al código QR del curso',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Scanner overlay (dark mask + transparent square) ─────────────────────────
class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const scanSize = 240.0;
    final top = (size.height - scanSize) / 2 - 40;
    final left = (size.width - scanSize) / 2;

    return Stack(
      children: [
        // Dark background
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.55),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Positioned(
                top: top,
                left: left,
                child: Container(
                  width: scanSize,
                  height: scanSize,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Corner decoration
        Positioned(
          top: top - 2,
          left: left - 2,
          child: _CornerFrame(size: scanSize + 4),
        ),
      ],
    );
  }
}

class _CornerFrame extends StatelessWidget {
  final double size;
  const _CornerFrame({required this.size});

  @override
  Widget build(BuildContext context) {
    const cornerLen = 24.0;
    const thick = 3.0;
    const r = 12.0;
    final c = AppColors.brand;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(c, cornerLen, thick, r),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double len, thick, radius;
  const _CornerPainter(this.color, this.len, this.thick, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = thick
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, radius)
        ..arcToPoint(Offset(radius, 0), radius: Radius.circular(radius))
        ..lineTo(len, 0),
      p,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, 0)
        ..lineTo(size.width - radius, 0)
        ..arcToPoint(Offset(size.width, radius),
            radius: Radius.circular(radius))
        ..lineTo(size.width, len),
      p,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - len)
        ..lineTo(0, size.height - radius)
        ..arcToPoint(Offset(radius, size.height),
            radius: Radius.circular(radius), clockwise: false)
        ..lineTo(len, size.height),
      p,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, size.height)
        ..lineTo(size.width - radius, size.height)
        ..arcToPoint(Offset(size.width, size.height - radius),
            radius: Radius.circular(radius), clockwise: false)
        ..lineTo(size.width, size.height - len),
      p,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── QR Display Dialog (para el instructor) ────────────────────────────────────
/// Llamar desde _CourseCard cuando el instructor quiere mostrar el QR del curso
class CourseQrDialog extends StatelessWidget {
  final String inviteCode;
  final String courseTitle;

  const CourseQrDialog({
    super.key,
    required this.inviteCode,
    required this.courseTitle,
  });

  static void show(BuildContext ctx,
      {required String inviteCode, required String courseTitle}) {
    showDialog(
      context: ctx,
      builder: (_) => CourseQrDialog(
        inviteCode: inviteCode,
        courseTitle: courseTitle,
      ),
    );
  }

  // El QR codifica una URI: siercp://course?code=X9J2P1
  // Esto permite extraerlo limpio en el scanner.
  String get _qrData => 'siercp://course?code=$inviteCode';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCard : Colors.white;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: bg,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Row(
              children: [
                const Icon(Icons.qr_code_2_rounded,
                    color: AppColors.brand, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'QR del curso',
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              courseTitle,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // QR Code
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: QrImageView(
                data: _qrData,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF1A1A2E),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Invite code badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.brand.withValues(alpha: 0.25), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.key_rounded,
                      size: 14, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    inviteCode,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'SpaceMono',
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Muestra este QR o comparte el código con tus estudiantes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────────
class _EmptyCoursesState extends StatelessWidget {
  final bool canManage;
  final VoidCallback onCreate;
  const _EmptyCoursesState({required this.canManage, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final textT = theme.textTheme.bodySmall?.color ?? AppColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 40),
      child: Column(
        children: [
          Icon(Icons.school_outlined,
              size: 52, color: textT.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            canManage
                ? 'Aún no has creado ningún curso'
                : 'No estás inscrito en ningún curso',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: textS, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            canManage
                ? 'Crea tu primer curso para comenzar a gestionar estudiantes.'
                : 'Pide a tu instructor el código para unirte o aguarda a que te inscriban.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textT, fontSize: 12),
          ),
          if (canManage) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Crear primer curso'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 46)),
            ),
          ] else ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.sensor_door_outlined, size: 16),
              label: const Text('Unirse con código'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 46)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Course card ───────────────────────────────────────────────────────────────
class _CourseCard extends ConsumerWidget {
  final CourseModel course;
  final bool canManage;
  final VoidCallback onEnroll;
  const _CourseCard({
    required this.course,
    required this.canManage,
    required this.onEnroll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final textT = theme.textTheme.bodySmall?.color ?? AppColors.textTertiary;
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    final sessionsAsync = ref.watch(sessionsHistoryProvider);
    final allSessions = sessionsAsync.value ?? [];
    final courseSessions = allSessions
        .where((s) =>
            s.courseId == course.id && s.status == SessionStatus.completed)
        .toList();
    final approved =
        courseSessions.where((s) => s.metrics?.approved == true).length;
    final requiredCount = course.totalModules > 0 ? course.totalModules : 4;
    final progress =
        requiredCount > 0 ? (approved / requiredCount).clamp(0.0, 1.0) : 0.0;
    final isComplete = approved >= requiredCount;
    final remaining = (requiredCount - approved).clamp(0, requiredCount);
    final progressColor = isComplete ? AppColors.green : AppColors.brand;

    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: isDark ? null : AppShadows.card(false),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isComplete
                              ? [AppColors.green, const Color(0xFF00C853)]
                              : [AppColors.brand, AppColors.accent],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        isComplete
                            ? Icons.emoji_events_rounded
                            : Icons.menu_book_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(course.title,
                              style: TextStyle(
                                color: textP,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              )),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded,
                                  size: 11, color: textS),
                              const SizedBox(width: 4),
                              Text(course.instructorName,
                                  style: TextStyle(color: textS, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // ── Invite code + tap para mostrar QR ───────────────────
                    if (course.inviteCode != null && canManage)
                      GestureDetector(
                        onTap: () => CourseQrDialog.show(
                          context,
                          inviteCode: course.inviteCode!,
                          courseTitle: course.title,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.brand.withValues(alpha: 0.25),
                                width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.qr_code_rounded,
                                  size: 10, color: AppColors.accent),
                              const SizedBox(width: 4),
                              Text(
                                course.inviteCode!,
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'SpaceMono',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: border,
                    valueColor: AlwaysStoppedAnimation(progressColor),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${(progress * 100).toInt()}% completado',
                        style: TextStyle(color: textT, fontSize: 10)),
                    if (canManage)
                      Row(
                        children: [
                          Icon(Icons.people_outline, size: 11, color: textT),
                          const SizedBox(width: 4),
                          Text('${course.studentCount ?? 0} estudiantes',
                              style: TextStyle(color: textT, fontSize: 10)),
                        ],
                      )
                    else
                      Text(
                          isComplete
                              ? 'Completado'
                              : 'Faltan $remaining sesiones',
                          style: TextStyle(color: textT, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          if (canManage) ...[
            Divider(color: border, height: 0.5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  _ActionButton(
                    icon: Icons.layers_outlined,
                    label: 'Módulos',
                    color: AppColors.accent,
                    onTap: () => context.push('/course-editor/${course.id}'),
                  ),
                  _ActionButton(
                    icon: Icons.person_add_outlined,
                    label: 'Inscribir',
                    onTap: onEnroll,
                  ),
                  _ActionButton(
                    icon: Icons.groups_2_outlined,
                    label: 'Alumnos',
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _StudentsBottomSheet(courseId: course.id),
                    ),
                  ),
                  _ActionButton(
                    icon: Icons.download_outlined,
                    label: 'Exportar',
                    color: AppColors.green,
                    onTap: () => _exportStudentGrades(context, ref, course),
                  ),
                  _ActionButton(
                    icon: Icons.qr_code_2_rounded,
                    label: 'QR',
                    color: AppColors.cyan,
                    onTap: () => course.inviteCode != null
                        ? CourseQrDialog.show(
                            context,
                            inviteCode: course.inviteCode!,
                            courseTitle: course.title,
                          )
                        : null,
                  ),
                  _ActionButton(
                    icon: Icons.monitor_heart_outlined,
                    label: 'En Vivo',
                    color: AppColors.cyan,
                    onTap: () => context.push('/live/${course.id}'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (!canManage) {
      return GestureDetector(
        onTap: () {
          final user = ref.read(currentUserProvider);
          context.push(
            '/student/course-detail',
            extra: {
              'courseId': course.id,
              'studentId': user?.id ?? '',
              'courseTitle': course.title,
              'instructorName': course.instructorName,
            },
          );
        },
        child: card,
      );
    }

    return card;
  }

  Future<void> _exportStudentGrades(
    BuildContext context,
    WidgetRef ref,
    CourseModel course,
  ) async {
    try {
      final exportSvc = ref.read(exportServiceProvider);
      await exportSvc.exportCourseGradesCSV(course);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('CSV de notas exportado'),
            ]),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: AppColors.red.withValues(alpha: 0.9),
          ),
        );
      }
    }
  }
}

// ─── Action button inside card ─────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.brand;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: c),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    color: c,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Students bottom sheet ─────────────────────────────────────────────────────
class _StudentsBottomSheet extends ConsumerWidget {
  final String courseId;
  const _StudentsBottomSheet({required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(courseStudentsProvider(courseId));
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final bg = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.groups_2_outlined,
                      color: AppColors.brand, size: 20),
                  const SizedBox(width: 10),
                  Text('Estudiantes del curso',
                      style: TextStyle(
                          color: textP,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Divider(color: border, height: 0.5),
            Expanded(
              child: studentsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: TextStyle(color: textS)),
                ),
                data: (students) => students.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_off_outlined,
                                size: 40, color: textS),
                            const SizedBox(height: 12),
                            Text('Sin estudiantes inscritos',
                                style: TextStyle(color: textS, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.all(16),
                        itemCount: students.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _StudentTile(student: students[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Student tile ──────────────────────────────────────────────────────────────
class _StudentTile extends ConsumerWidget {
  final dynamic student;
  const _StudentTile({required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final border = theme.colorScheme.outline;

    final score = student['avgScore'] as double? ?? 0.0;
    final scoreColor = score >= 85
        ? AppColors.green
        : score >= 70
            ? AppColors.amber
            : AppColors.red;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface2,
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.brand.withValues(alpha: 0.15),
            child: Text(
              (student['studentName'] as String?)?.isNotEmpty == true
                  ? (student['studentName'] as String)
                      .substring(0, 1)
                      .toUpperCase()
                  : 'E',
              style: const TextStyle(
                color: AppColors.brand,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['studentName'] ?? 'Estudiante',
                  style: TextStyle(
                      color: textP, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 10, color: textS),
                    const SizedBox(width: 4),
                    Text(student['identificacion'] ?? '—',
                        style: TextStyle(color: textS, fontSize: 10)),
                    const SizedBox(width: 8),
                    Icon(Icons.history_outlined, size: 10, color: textS),
                    const SizedBox(width: 4),
                    Text('${student['sessionCount'] ?? 0} sesiones',
                        style: TextStyle(color: textS, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${score.toStringAsFixed(0)}%',
              style: TextStyle(
                color: scoreColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'SpaceMono',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
