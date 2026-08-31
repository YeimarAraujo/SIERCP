import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:siercp/core/widgets/app_logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:siercp/core/providers/org_context_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/courses/data/models/alert_course.dart';
import 'package:siercp/features/session/presentation/providers/session_provider.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/users/data/admin_service.dart';
import 'package:siercp/core/widgets/demo_guard.dart';
import 'package:siercp/features/reports/data/export_service.dart';
import 'package:siercp/features/session/data/session_service.dart';
import 'package:siercp/core/services/firestore_service.dart';
import 'package:siercp/core/widgets/section_label.dart';
import 'package:siercp/features/session/data/models/session.dart';
import 'package:siercp/l10n/app_localizations.dart';

class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  final _searchInstructorCtrl = TextEditingController();
  final _searchStudentCtrl = TextEditingController();

  @override
  void dispose() {
    _searchInstructorCtrl.dispose();
    _searchStudentCtrl.dispose();
    super.dispose();
  }

  // ─── Create course bottom sheet ─────────────────────────────────────────────
  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final certCtrl = TextEditingController();
    final cedulaCtrl = TextEditingController();

    // Membresías del instructor (INSTRUCTOR o ADMIN) para el picker de org.
    final orgCtx = ref.read(orgContextProvider);
    final allMembs = orgCtx.allMemberships
        .where((m) => m.role == 'INSTRUCTOR' || m.role == 'ADMIN')
        .toList();
    // Pre-seleccionar la org activa si existe, o la primera disponible.
    final preselect = orgCtx.activeOrgId ??
        (allMembs.isNotEmpty ? allMembs.first.institutionId : null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final loc = AppLocalizations.of(ctx)!;
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final currentUser = ref.read(currentUserProvider);
        final coursesCreated = currentUser?.coursesCreatedThisMonth ?? 0;
        final isUsuario = currentUser?.isUsuario ?? false;
        final accentColor = AppColors.accent;

        bool loading = false;
        bool searchingUser = false;
        String? errorMsg;
        String? selectedOrgId = isUsuario ? null : preselect;

        // Lista de alumnos pendientes de inscripción: {id, name, cedula}
        final List<Map<String, String>> pendingStudents = [];
        // Preview del alumno encontrado
        Map<String, String>? foundStudent;
        String? searchError;

        return StatefulBuilder(
          builder: (ctx, setSt) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding:
                  EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header gradient
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_circle_outline_rounded,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(loc.createCourseTitle,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text(
                                    'Configura el nuevo curso de entrenamiento',
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.75),
                                        fontSize: 11)),
                              ]),
                        ),
                        if (isUsuario)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Text('$coursesCreated/3',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800)),
                          ),
                      ]),
                    ),
                    // ── Picker de org (solo si tiene 2+ orgs con rol instructor/admin) ──
                    if (allMembs.length > 1) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.business_rounded,
                                    size: 14, color: AppColors.brand),
                                const SizedBox(width: 6),
                                Text('Organización del curso',
                                    style: TextStyle(
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ]),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                // ignore: deprecated_member_use
                                value: selectedOrgId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                      Icons.apartment_rounded,
                                      size: 18),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: theme.colorScheme.outline
                                              .withValues(alpha: 0.4))),
                                  filled: true,
                                  fillColor: isDark
                                      ? theme
                                          .colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.4)
                                      : const Color(0xFFF8FAFC),
                                ),
                                items: allMembs
                                    .map((m) => DropdownMenuItem(
                                          value: m.institutionId,
                                          child: Text(m.institutionId,
                                              overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setSt(() => selectedOrgId = v),
                              ),
                            ]),
                      ),
                    ],
                    // ── Campos del curso ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(children: [
                        _SheetInput(
                          controller: nameCtrl,
                          label: loc.courseNameLabel,
                          hint: 'Ej. Soporte Vital Básico — Grupo A',
                          icon: Icons.menu_book_outlined,
                          isDark: isDark,
                          capitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 12),
                        _SheetInput(
                          controller: descCtrl,
                          label: loc.courseDescLabel,
                          hint: 'Breve descripción del curso y sus objetivos',
                          icon: Icons.description_outlined,
                          isDark: isDark,
                          maxLines: 2,
                          capitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 12),
                        _SheetInput(
                          controller: certCtrl,
                          label: 'Certificación',
                          hint: 'Ej. BLS Provider AHA 2025',
                          icon: Icons.verified_outlined,
                          isDark: isDark,
                          capitalization: TextCapitalization.words,
                        ),
                      ]),
                    ),
                    // ── Sección: Inscribir alumnos por cédula ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Divider(
                                color: theme.colorScheme.outline
                                    .withValues(alpha: 0.3)),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.group_add_rounded,
                                  size: 16, color: AppColors.brand),
                              const SizedBox(width: 8),
                              Text('Alumnos (opcional)',
                                  style: TextStyle(
                                      color: theme.textTheme.bodyLarge?.color,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Text('Se inscriben al crear el curso',
                                  style: TextStyle(
                                      color: theme.textTheme.bodySmall?.color,
                                      fontSize: 10)),
                            ]),
                            const SizedBox(height: 10),
                            // Buscador por cédula
                            Row(children: [
                              Expanded(
                                child: TextField(
                                  controller: cedulaCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Número de identificación',
                                    hintText: 'Cédula del alumno',
                                    prefixIcon: const Icon(Icons.badge_outlined,
                                        size: 18),
                                    isDense: true,
                                    filled: true,
                                    fillColor: isDark
                                        ? theme
                                            .colorScheme.surfaceContainerHighest
                                            .withValues(alpha: 0.4)
                                        : const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: theme.colorScheme.outline
                                                .withValues(alpha: 0.4))),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: theme.colorScheme.outline
                                                .withValues(alpha: 0.25))),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: AppColors.brand,
                                            width: 1.5)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: searchingUser
                                      ? null
                                      : () async {
                                          final cedula = cedulaCtrl.text.trim();
                                          if (cedula.isEmpty) return;
                                          if (pendingStudents.any(
                                              (s) => s['cedula'] == cedula)) {
                                            setSt(() => searchError =
                                                'Ya fue agregado');
                                            return;
                                          }
                                          setSt(() {
                                            searchingUser = true;
                                            searchError = null;
                                            foundStudent = null;
                                          });
                                          try {
                                            final u = await ref
                                                .read(adminServiceProvider)
                                                .findUserByCedula(cedula);
                                            if (u == null) {
                                              setSt(() {
                                                searchError =
                                                    'No se encontró usuario con esa cédula';
                                                searchingUser = false;
                                              });
                                            } else {
                                              setSt(() {
                                                foundStudent = {
                                                  'id': u.id,
                                                  'name': u.fullName,
                                                  'cedula': cedula,
                                                };
                                                searchingUser = false;
                                              });
                                            }
                                          } catch (_) {
                                            setSt(() {
                                              searchError =
                                                  'Error al buscar el usuario';
                                              searchingUser = false;
                                            });
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brand,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  child: searchingUser
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Icon(Icons.search_rounded,
                                          size: 20),
                                ),
                              ),
                            ]),
                            // Preview del alumno encontrado
                            if (foundStudent != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.green.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AppColors.green
                                          .withValues(alpha: 0.25)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.person_rounded,
                                      color: AppColors.green, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(foundStudent!['name']!,
                                              style: const TextStyle(
                                                  color: AppColors.green,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600)),
                                          Text(
                                              'Cédula: ${foundStudent!['cedula']!}',
                                              style: TextStyle(
                                                  color: theme.textTheme
                                                      .bodySmall?.color,
                                                  fontSize: 11)),
                                        ]),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setSt(() {
                                        pendingStudents.add(foundStudent!);
                                        foundStudent = null;
                                        cedulaCtrl.clear();
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                        foregroundColor: AppColors.green),
                                    child: const Text('Agregar',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ]),
                              ),
                            ],
                            if (searchError != null) ...[
                              const SizedBox(height: 6),
                              Text(searchError!,
                                  style: const TextStyle(
                                      color: AppColors.red, fontSize: 11)),
                            ],
                            // Lista de alumnos pendientes
                            if (pendingStudents.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ...pendingStudents.map((s) => Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.brand
                                          .withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: AppColors.brand
                                              .withValues(alpha: 0.15)),
                                    ),
                                    child: Row(children: [
                                      const Icon(Icons.person_outline_rounded,
                                          size: 14, color: AppColors.brand),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(s['name']!,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500)),
                                      ),
                                      Text(s['cedula']!,
                                          style: TextStyle(
                                              color: theme
                                                  .textTheme.bodySmall?.color,
                                              fontSize: 10)),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => setSt(
                                            () => pendingStudents.remove(s)),
                                        child: const Icon(Icons.close_rounded,
                                            size: 14, color: AppColors.red),
                                      ),
                                    ]),
                                  )),
                            ],
                          ]),
                    ),
                    // ── Mensaje de error ──
                    if (errorMsg != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.red.withValues(alpha: 0.2)),
                          ),
                          child: Row(children: [
                            Icon(Icons.error_outline,
                                color: AppColors.red.withValues(alpha: 0.8),
                                size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(errorMsg!,
                                  style: TextStyle(
                                      color:
                                          AppColors.red.withValues(alpha: 0.9),
                                      fontSize: 12)),
                            ),
                          ]),
                        ),
                      ),
                    // ── Botones ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(loc.cancelBtn),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: loading
                                ? null
                                : () async {
                                    final name = nameCtrl.text.trim();
                                    if (name.isEmpty) {
                                      setSt(() => errorMsg =
                                          'El nombre del curso es requerido');
                                      return;
                                    }
                                    if ((currentUser?.isAdmin == true) &&
                                        selectedOrgId == null) {
                                      setSt(() => errorMsg =
                                          'Selecciona la organización del curso');
                                      return;
                                    }
                                    setSt(() {
                                      loading = true;
                                      errorMsg = null;
                                    });
                                    final nav = Navigator.of(ctx);
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    final enrolled =
                                        List<Map<String, String>>.from(
                                            pendingStudents);
                                    try {
                                      final courseId = await ref
                                          .read(sessionServiceProvider)
                                          .createCourse(
                                            name: name,
                                            description: descCtrl.text.trim(),
                                            instructorId: currentUser?.id ?? '',
                                            instructorName:
                                                currentUser?.fullName ?? '',
                                            institutionId: selectedOrgId,
                                          );
                                      for (final s in enrolled) {
                                        try {
                                          await ref
                                              .read(adminServiceProvider)
                                              .enrollStudentByCedulaDirect(
                                                courseId: courseId,
                                                cedula: s['cedula']!,
                                                instructorId:
                                                    currentUser?.id ?? '',
                                              );
                                        } catch (_) {}
                                      }
                                      if (mounted) {
                                        nav.pop();
                                        ref.invalidate(coursesProvider);
                                        final msg = enrolled.isEmpty
                                            ? loc.courseCreatedSuccess
                                            : '${loc.courseCreatedSuccess} · ${enrolled.length} alumno(s) inscritos';
                                        messenger.showSnackBar(SnackBar(
                                          content: Row(children: [
                                            const Icon(
                                                Icons.check_circle_outline,
                                                color: Colors.white,
                                                size: 16),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(msg)),
                                          ]),
                                          backgroundColor: AppColors.green,
                                        ));
                                      }
                                    } catch (e) {
                                      setSt(() {
                                        loading = false;
                                        errorMsg = e.toString();
                                      });
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: SizedBox(
                              height: 20,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Opacity(
                                    opacity: loading ? 0 : 1,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                            Icons.add_circle_outline_rounded,
                                            size: 16),
                                        const SizedBox(width: 8),
                                        Text(loc.createBtn,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                  if (loading)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEnrollDialog(String courseId) {
    final cedulaCtrl = TextEditingController();
    bool loading = false;
    showDialog(
      context: context,
      builder: (ctx) {
        final loc = AppLocalizations.of(ctx)!;
        return StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.person_add_outlined,
                    color: AppColors.brand, size: 20),
                const SizedBox(width: 10),
                Text(loc.enrollStudentTitle),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: cedulaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: loc.cedulaLabel,
                    hintText: loc.cedulaHint,
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  loc.enrollInfo,
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
                  child: Text(loc.cancelBtn)),
              ElevatedButton.icon(
                icon: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.person_add_rounded, size: 16),
                label: Text(loc.enrollBtn),
                onPressed: loading
                    ? null
                    : () async {
                        setSt(() => loading = true);
                        final nav = Navigator.of(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final user = ref.read(currentUserProvider);
                          await ref
                              .read(adminServiceProvider)
                              .enrollStudentByCedula(
                                courseId: courseId,
                                cedula: cedulaCtrl.text.trim(),
                                instructorId: user?.id ?? '',
                              );
                          if (mounted) {
                            nav.pop();
                            ref.invalidate(coursesProvider);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Row(children: [
                                  const Icon(Icons.check_circle_outline,
                                      color: Colors.white, size: 16),
                                  const SizedBox(width: 8),
                                  Text(loc.enrollSuccess),
                                ]),
                              ),
                            );
                          }
                        } catch (e) {
                          setSt(() => loading = false);
                          if (mounted) {
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
        );
      },
    );
  }

  // ─── Join Course Dialog (Students) — con opción QR ─────────────────────────
  void _showJoinDialog() {
    final codeCtrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        final loc = AppLocalizations.of(ctx)!;
        return StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.sensor_door_outlined,
                    color: AppColors.brand, size: 20),
                const SizedBox(width: 10),
                Text(loc.joinCourseTitle),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: loc.courseCodeLabel,
                    hintText: loc.courseCodeHint,
                    prefixIcon: const Icon(Icons.key_outlined),
                    suffixIcon: IconButton(
                      tooltip: loc.scanQr,
                      icon: const Icon(Icons.qr_code_scanner_rounded,
                          color: AppColors.brand),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final scanned =
                            await Navigator.of(context).push<String>(
                          MaterialPageRoute(
                            builder: (_) => const _QRScannerPage(),
                          ),
                        );
                        if (scanned != null && scanned.isNotEmpty) {
                          if (context.mounted) {
                            _showJoinDialogWithCode(scanned);
                          }
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
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
                        loc.qrHint,
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
                child: Text(loc.cancelBtn),
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
                label: Text(loc.unirseBtn),
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
        );
      },
    );
  }

  void _showJoinDialogWithCode(String code) {
    final codeCtrl = TextEditingController(text: code);
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        final loc = AppLocalizations.of(ctx)!;
        return StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.qr_code_rounded,
                    color: AppColors.brand, size: 20),
                const SizedBox(width: 10),
                Text(loc.joinCourseTitle),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                        loc.qrSuccess,
                        style: const TextStyle(
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
                    labelText: loc.courseCodeLabel,
                    prefixIcon: const Icon(Icons.key_outlined),
                    suffixIcon: IconButton(
                      tooltip: loc.scanAgain,
                      icon: const Icon(Icons.qr_code_scanner_rounded,
                          color: AppColors.brand),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final scanned =
                            await Navigator.of(context).push<String>(
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
                child: Text(loc.cancelBtn),
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
                label: Text(loc.unirseBtn),
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
        );
      },
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

    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(ctx);

    try {
      final user = ref.read(currentUserProvider);
      await ref.read(sessionServiceProvider).joinCourse(
            code,
            studentId: user?.id ?? '',
            studentName: user?.fullName ?? '',
            studentEmail: user?.email ?? '',
            identificacion: user?.identificacion,
          );
      if (mounted) {
        nav.pop();
        ref.invalidate(coursesProvider);
        messenger.showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(loc.joinSuccess),
            ]),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('ERROR joinCourse: $e');
      setSt(() => setLoading(false));
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${loc.joinErrorInvalidCode} ($e)'),
            backgroundColor: AppColors.red.withValues(alpha: 0.9),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = ref.watch(isDemoProvider);
    if (isDemo) {
      return const DemoGuard(featureName: 'Cursos', child: SizedBox());
    }

    final coursesAsync = ref.watch(coursesProvider);
    final currentUser = ref.watch(currentUserProvider);
    final orgCtx = ref.watch(orgContextProvider);
    final loc = AppLocalizations.of(context)!;
    final isInstructorOnCourse =
        ref.watch(isInstructorOnCourseProvider).valueOrNull ?? false;
    final isAdmin = orgCtx.isAdmin || (currentUser?.isAdmin ?? false);
    final isInstructor = !isAdmin &&
        (orgCtx.isInstructor ||
            (currentUser?.isInstructor ?? false) ||
            isInstructorOnCourse);
    final isUsuario =
        !isInstructor && !isAdmin && (currentUser?.isUsuario ?? false);
    final canManage = isInstructor || isAdmin;
    final canCreate = canManage ||
        (isUsuario && (currentUser?.canCreateMoreCourses ?? false));
    final isAtLimit = !(currentUser?.canCreateMoreCourses ?? true);
    final coursesCreated = currentUser?.coursesCreatedThisMonth ?? 0;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = AppColors.accent;

    // ─── Header ─────────────────────────────────────────────────────
    Widget buildHeader() => Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(loc.coursesTitle,
                    style: TextStyle(
                        color: textP,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
              )),
              if (canCreate)
                isAtLimit
                    ? Tooltip(
                        message: 'Límite de 3 cursos alcanzado',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.red.withValues(alpha: 0.25),
                                width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline_rounded,
                                  size: 14,
                                  color: AppColors.red.withValues(alpha: 0.7)),
                              const SizedBox(width: 6),
                              Text('$coursesCreated/3',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.red.withValues(alpha: 0.8),
                                  )),
                            ],
                          ),
                        ),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: ElevatedButton.icon(
                          onPressed: _showCreateDialog,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text('Nuevo ($coursesCreated/3)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                        ),
                      ),
            ],
          ),
        );

    // ─── Build a single course list ─────────────────────────────────
    Widget buildCourseList(List<CourseModel> list,
            {bool sectionCanManage = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: isLandscape
              ? GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.85,
                  ),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) => sectionCanManage
                      ? _CourseCard(
                          course: list[i],
                          canManage: true,
                          onEnroll: () => _showEnrollDialog(list[i].id),
                        )
                      : _StudentCourseCard(course: list[i]),
                )
              : Column(
                  children: list
                      .map((c) => sectionCanManage
                          ? _CourseCard(
                              course: c,
                              canManage: true,
                              onEnroll: () => _showEnrollDialog(c.id),
                            )
                          : _StudentCourseCard(course: c))
                      .toList(),
                ),
        );

    // ─── Tab content with search ────────────────────────────────────
    Widget buildCourseTab(List<CourseModel> courseList,
        {required bool isInstructorSection}) {
      final ctrl =
          isInstructorSection ? _searchInstructorCtrl : _searchStudentCtrl;
      final query = ctrl.text.toLowerCase().trim();
      final filtered = query.isEmpty
          ? courseList
          : courseList
              .where((c) =>
                  c.title.toLowerCase().contains(query) ||
                  (c.inviteCode?.toLowerCase().contains(query) ?? false))
              .toList();

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o c\u00f3digo',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                ),
                filled: true,
                fillColor: isDark
                    ? theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4)
                    : const Color(0xFFF8FAFC),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      query.isEmpty
                          ? 'No hay cursos'
                          : 'Sin resultados para "$query"',
                      style: TextStyle(color: textS),
                    ),
                  )
                : isLandscape
                    ? GridView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.85,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => isInstructorSection
                            ? _CourseCard(
                                course: filtered[i],
                                canManage: true,
                                onEnroll: () =>
                                    _showEnrollDialog(filtered[i].id),
                              )
                            : _StudentCourseCard(course: filtered[i]),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => isInstructorSection
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _CourseCard(
                                  course: filtered[i],
                                  canManage: true,
                                  onEnroll: () =>
                                      _showEnrollDialog(filtered[i].id),
                                ),
                              )
                            : _StudentCourseCard(course: filtered[i]),
                      ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(coursesProvider),
          color: AppColors.brand,
          child: coursesAsync.when(
            loading: () => CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: buildHeader()),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80, child: AppLogoLoader()),
                ),
              ],
            ),
            error: (e, __) => CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: buildHeader()),
                SliverToBoxAdapter(
                  child: Center(
                    child: Text(loc.loadCoursesError(e.toString()),
                        style: TextStyle(color: textS)),
                  ),
                ),
              ],
            ),
            data: (courses) {
              if (courses.isEmpty) {
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: buildHeader()),
                    SliverToBoxAdapter(
                      child: _EmptyCoursesState(
                        canManage: canCreate && !isAtLimit,
                        onCreate: canCreate && !isAtLimit
                            ? _showCreateDialog
                            : _showJoinDialog,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                );
              }

              final userId = currentUser?.id ?? '';
              final instructorCourses =
                  courses.where((c) => c.isInstructorOf(userId)).toList();
              final studentCourses =
                  courses.where((c) => !c.isInstructorOf(userId)).toList();
              final showTabs = instructorCourses.isNotEmpty;

              // ── No tabs: solo estudiante ──
              if (!showTabs) {
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: buildHeader()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                        child: SectionLabel(loc.myCourses),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: buildCourseList(courses, sectionCanManage: false),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                );
              }

              // ── Tabs: instructor + estudiante ──
              return DefaultTabController(
                length: 2,
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    SliverToBoxAdapter(child: buildHeader()),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabBarDelegate(
                        TabBar(
                          labelColor: AppColors.brand,
                          unselectedLabelColor: textS,
                          indicatorColor: AppColors.brand,
                          dividerColor: Colors.transparent,
                          labelStyle: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          tabs: [
                            Tab(
                                text:
                                    'Instructor (${instructorCourses.length})'),
                            Tab(text: 'Estudiante (${studentCourses.length})'),
                          ],
                        ),
                      ),
                    ),
                  ],
                  body: TabBarView(
                    children: [
                      buildCourseTab(instructorCourses,
                          isInstructorSection: true),
                      buildCourseTab(studentCourses,
                          isInstructorSection: false),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showJoinDialog,
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add_rounded),
        label: Text(loc.joinCourseBtn),
      ),
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
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() => _hasPermission = status.isGranted);
    }
  }

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

    final code = _extractInviteCode(raw);
    if (code.isEmpty) return;

    setState(() => _scanned = true);
    _ctrl.stop();
    Navigator.of(context).pop(code.toUpperCase());
  }

  /// Extrae el código de invitación de cualquier formato QR soportado:
  ///   siercp://course?code=ABCD12     ← formato canónico (Flutter + Web)
  ///   https://domain.com/join/ABCD12  ← formato URL legacy
  ///   ABCD12                           ← código directo
  static String _extractInviteCode(String raw) {
    try {
      final uri = Uri.tryParse(raw);
      if (uri != null) {
        // Formato canónico: siercp://course?code=
        if (uri.queryParameters.containsKey('code')) {
          return uri.queryParameters['code']!;
        }
        // Formato URL legacy: .../join/{code}
        final segments = uri.pathSegments;
        final joinIdx = segments.indexOf('join');
        if (joinIdx >= 0 && joinIdx + 1 < segments.length) {
          return segments[joinIdx + 1];
        }
      }
    } catch (_) {}
    // Último recurso: usar el raw completo como código
    return raw.trim();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(loc.qrScannerTitle,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
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
          if (!_hasPermission)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_outlined,
                      size: 48, color: Colors.white38),
                  const SizedBox(height: 16),
                  Text(
                    loc.cameraPermissionRequired,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _checkPermission,
                    child: Text(loc.grantPermission),
                  ),
                ],
              ),
            )
          else
            MobileScanner(
              controller: _ctrl,
              onDetect: _onDetect,
            ),
          _ScannerOverlay(),
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
                  child: Text(
                    loc.aimQrHint,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
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
    final loc = AppLocalizations.of(context)!;
    final bg = isDark ? AppColors.darkCard : Colors.white;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: bg,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isLandscape ? 720 : 420,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: isLandscape
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                              size: 220,
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 5,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.qr_code_2_rounded,
                                color: AppColors.brand,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  loc.qrBtn,
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
                          const SizedBox(height: 6),
                          Text(
                            courseTitle,
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.brand.withValues(alpha: 0.25),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.key_rounded,
                                  size: 14,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    inviteCode,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            loc.qrHint,
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Share.share(
                                  loc.shareInviteText(courseTitle, inviteCode),
                                  subject: loc.shareInviteSubject,
                                );
                              },
                              icon: const Icon(Icons.share_rounded, size: 18),
                              label: Text(loc.shareInviteBtn),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.qr_code_2_rounded,
                          color: AppColors.brand,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            loc.qrBtn,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.brand.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.key_rounded,
                            size: 14,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              inviteCode,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      loc.qrHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Share.share(
                              loc.shareInviteText(courseTitle, inviteCode),
                              subject: loc.shareInviteSubject);
                        },
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: Text(loc.shareInviteBtn),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── TabBar delegate for sticky tab bar ────────────────────────────────────────
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
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
    final loc = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 40),
      child: Column(
        children: [
          Icon(Icons.school_outlined,
              size: 52, color: textT.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            canManage ? loc.noCoursesCreatedPlain : loc.noCoursesJoinedPlain,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: textS, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            canManage ? loc.noCoursesCreatedDesc : loc.noCoursesJoinedDesc,
            textAlign: TextAlign.center,
            style: TextStyle(color: textT, fontSize: 12),
          ),
          if (canManage) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(loc.createFirstCourseBtn),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 46)),
            ),
          ] else ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.sensor_door_outlined, size: 16),
              label: Text(loc.joinWithCodeBtn),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 46)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Course card ───────────────────────────────────────────────────────────────
// ─── Student Course Card (hero style, read-only) ─────────────────────────
class _StudentCourseCard extends ConsumerWidget {
  final CourseModel course;
  const _StudentCourseCard({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textS = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7);
    final user = ref.read(currentUserProvider);
    final loc = AppLocalizations.of(context)!;

    final sessionsAsync = ref.watch(sessionsHistoryProvider);
    final allSessions = sessionsAsync.value ?? [];
    final courseSessions = allSessions
        .where((s) =>
            s.courseId == course.id && s.status == SessionStatus.completed)
        .toList();
    final totalDone = courseSessions.length;
    final approved =
        courseSessions.where((s) => s.metrics?.approved == true).length;
    final requiredCount = course.totalModules > 0 ? course.totalModules : 4;
    final progress =
        requiredCount > 0 ? (approved / requiredCount).clamp(0.0, 1.0) : 0.0;
    final isComplete = approved >= requiredCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => context.push(
          '/student/course-detail',
          extra: {
            'courseId': course.id,
            'studentId': user?.id ?? '',
            'courseTitle': course.title,
            'instructorName': course.instructorName,
          },
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isComplete
                ? AppColors.green.withValues(alpha: 0.08)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isComplete
                  ? AppColors.green.withValues(alpha: 0.3)
                  : theme.dividerTheme.color ?? AppColors.cardBorder,
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isComplete
                          ? AppColors.green.withValues(alpha: 0.15)
                          : AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      isComplete
                          ? Icons.emoji_events_rounded
                          : Icons.menu_book_outlined,
                      color: isComplete ? AppColors.green : AppColors.accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(course.title,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: theme.textTheme.bodyLarge?.color),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                                size: 12, color: textS ?? Colors.grey),
                            const SizedBox(width: 4),
                            Text(course.instructorName,
                                style: TextStyle(fontSize: 11, color: textS)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isComplete
                      ? AppColors.green.withValues(alpha: 0.15)
                      : theme.dividerTheme.color?.withValues(alpha: 0.3) ??
                          AppColors.cardBorder.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation(
                      isComplete ? AppColors.green : AppColors.accent),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loc.approvedAndSessions(approved, requiredCount, totalDone),
                    style: TextStyle(
                        color: isComplete
                            ? AppColors.green
                            : textS?.withValues(alpha: 0.7),
                        fontSize: 11),
                  ),
                  Text('${(progress * 100).toInt()}%',
                      style: TextStyle(
                          color: isComplete ? AppColors.green : textS,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'SpaceMono')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseCard extends ConsumerWidget {
  final CourseModel course;
  final bool canManage;
  final VoidCallback? onEnroll;
  const _CourseCard({
    required this.course,
    required this.canManage,
    required this.onEnroll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final textT = theme.textTheme.bodySmall?.color ?? AppColors.textTertiary;
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    final currentUser = ref.watch(currentUserProvider);
    final orgCtx = ref.watch(orgContextProvider);
    final isInstructorOnCourse =
        ref.watch(isInstructorOnCourseProvider).valueOrNull ?? false;
    final isOwner = course.isInstructorOf(currentUser?.id ?? '');
    final isAdmin = orgCtx.isAdmin || (currentUser?.isAdmin ?? false);
    final canDelete = isAdmin || isOwner;
    final canEdit = isOwner || isAdmin || isInstructorOnCourse;

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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(isLandscape ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isComplete ? AppColors.green : AppColors.brand,
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
                    if (course.inviteCode != null && canManage)
                      Row(
                        children: [
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
                                    color:
                                        AppColors.brand.withValues(alpha: 0.25),
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
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (canDelete)
                            PopupMenuButton<String>(
                              icon:
                                  Icon(Icons.more_vert, size: 18, color: textS),
                              padding: EdgeInsets.zero,
                              onSelected: (val) {
                                if (val == 'delete') {
                                  _handleDelete(context, ref);
                                } else if (val == 'edit') {
                                  _handleEdit(context, ref);
                                }
                              },
                              itemBuilder: (ctx) => [
                                if (canEdit)
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.edit_outlined,
                                            size: 16),
                                        const SizedBox(width: 8),
                                        Text(loc.editCourseTitle,
                                            style:
                                                const TextStyle(fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                if (canDelete)
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded,
                                            size: 16, color: AppColors.red),
                                        const SizedBox(width: 8),
                                        Text(loc.deleteBtn,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.red)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                  ],
                ),
                SizedBox(height: isLandscape ? 8 : 14),
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
                    Text(loc.completedPct((progress * 100).toInt().toString()),
                        style: TextStyle(color: textT, fontSize: 10)),
                    if (canManage)
                      Consumer(
                        builder: (context, ref, _) {
                          final studentsAsync =
                              ref.watch(courseStudentsProvider(course.id));
                          return Row(
                            children: [
                              Icon(Icons.people_outline,
                                  size: 11, color: textT),
                              const SizedBox(width: 4),
                              studentsAsync.when(
                                loading: () => const SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.2,
                                        color: AppColors.brand)),
                                error: (_, __) => Text(
                                    '${course.studentCount ?? 0}',
                                    style:
                                        TextStyle(color: textT, fontSize: 10)),
                                data: (list) => Text(
                                    loc.studentsCount(list.length),
                                    style:
                                        TextStyle(color: textT, fontSize: 10)),
                              ),
                            ],
                          );
                        },
                      )
                    else
                      Text(
                          isComplete
                              ? loc.completed
                              : loc.remainingSessions(remaining),
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
                    label: loc.modulesBtn,
                    color: AppColors.accent,
                    onTap: () => context.push('/course-editor/${course.id}'),
                  ),
                  _ActionButton(
                    icon: Icons.person_add_outlined,
                    label: loc.courseEnroll,
                    onTap: onEnroll ?? () {},
                  ),
                  _ActionButton(
                    icon: Icons.groups_2_outlined,
                    label: loc.studentsBtn,
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _StudentsBottomSheet(
                        courseId: course.id,
                        canRemove: canManage,
                      ),
                    ),
                  ),
                  _ActionButton(
                    icon: Icons.download_outlined,
                    label: loc.courseExport,
                    color: AppColors.green,
                    onTap: () => _exportStudentGrades(context, ref, course),
                  ),
                  _ActionButton(
                    icon: Icons.qr_code_2_rounded,
                    label: loc.qrBtn,
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
                    label: loc.courseLive,
                    color: AppColors.cyan,
                    onTap: () => context.push('/live/${course.id}'),
                  ),
                  if (isAdmin)
                    _ActionButton(
                      icon: Icons.manage_accounts_outlined,
                      label: 'Instructor',
                      color: AppColors.amber,
                      onTap: () =>
                          _showAssignInstructorSheet(context, ref, course),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return GestureDetector(
      onTap: () {
        if (canManage) {
          context.push('/courses/${course.id}');
        } else {
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
        }
      },
      child: card,
    );
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.deleteCourseConfirmTitle),
        content: Text(loc.deleteCourseConfirmDesc(course.title)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.cancelBtn)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: Text(loc.deleteBtn),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(sessionServiceProvider).deleteCourse(course.id);
      ref.invalidate(coursesProvider);
    }
  }

  Future<void> _handleEdit(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController(text: course.title);
    final descCtrl = TextEditingController(text: course.description);

    final loc = AppLocalizations.of(context)!;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.editCourseTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: loc.courseNameLabel)),
            const SizedBox(height: 12),
            TextField(
                controller: descCtrl,
                decoration: InputDecoration(labelText: loc.courseDescLabel)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.cancelBtn)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.saveBtn),
          ),
        ],
      ),
    );

    if (saved == true) {
      await ref.read(sessionServiceProvider).updateCourse(course.id, {
        'title': nameCtrl.text.trim(),
        'description': descCtrl.text.trim(),
      });
      ref.invalidate(coursesProvider);
    }
  }

  Future<void> _exportStudentGrades(
    BuildContext context,
    WidgetRef ref,
    CourseModel course,
  ) async {
    try {
      final firestoreSvc = ref.read(firestoreServiceProvider);
      final exportSvc = ref.read(exportServiceProvider);

      final students = await firestoreSvc.getCourseStudents(course.id);

      await exportSvc.exportCourseGradesCSV(course, students);
      if (context.mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(loc.exportGradesSuccess),
            ]),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.exportGradesError(e.toString())),
            backgroundColor: AppColors.red.withValues(alpha: 0.9),
          ),
        );
      }
    }
  }

  /// Muestra un bottom sheet para asignar/cambiar el instructor del curso.
  Future<void> _showAssignInstructorSheet(
    BuildContext context,
    WidgetRef ref,
    CourseModel course,
  ) async {
    final orgCtx = ref.read(orgContextProvider);
    final orgId = orgCtx.activeOrgId ?? '';
    if (orgId.isEmpty) return;

    // Buscar usuarios de la org que pueden ser instructores
    final adminSvc = ref.read(adminServiceProvider);
    List<dynamic> orgMembers = [];
    try {
      final members = await adminSvc.getOrgUsers();
      orgMembers = members
          .map((m) => {
                'id': m.user.id,
                'uid': m.user.id,
                'firstName': m.user.firstName,
                'lastName': m.user.lastName,
                'email': m.user.email,
                'role': m.role,
              })
          .toList();
    } catch (_) {}

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AssignInstructorSheet(
        course: course,
        orgMembers: orgMembers,
        onAssign: (uid, name) async {
          try {
            await ref.read(firestoreServiceProvider).assignInstructor(
                  course.id,
                  uid,
                  name,
                );
            ref.invalidate(coursesProvider);
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Instructor asignado: $name')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: AppColors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }
}

// ─── Assign instructor sheet ────────────────────────────────────────────────────
class _AssignInstructorSheet extends StatefulWidget {
  final CourseModel course;
  final List<dynamic> orgMembers;
  final Future<void> Function(String uid, String name) onAssign;
  const _AssignInstructorSheet({
    required this.course,
    required this.orgMembers,
    required this.onAssign,
  });

  @override
  State<_AssignInstructorSheet> createState() => _AssignInstructorSheetState();
}

class _AssignInstructorSheetState extends State<_AssignInstructorSheet> {
  String _search = '';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    final filtered = widget.orgMembers.where((m) {
      final name =
          (m['firstName'] ?? '${m['name'] ?? ''}').toString().toLowerCase();
      final email = (m['email'] ?? '').toString().toLowerCase();
      return _search.isEmpty ||
          name.contains(_search.toLowerCase()) ||
          email.contains(_search.toLowerCase());
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              const Icon(Icons.manage_accounts_outlined,
                  color: AppColors.amber, size: 20),
              const SizedBox(width: 10),
              Text('Asignar instructor a "${widget.course.title}"',
                  style: TextStyle(
                      color: textP, fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o email...',
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 8),
          // List
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child:
                        Text('Sin resultados', style: TextStyle(color: textS)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final m = filtered[i];
                      final uid = m['id'] ?? m['uid'] ?? '';
                      final name =
                          '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'
                              .trim();
                      final isCurrentInstructor =
                          uid == widget.course.instructorId;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _loading
                              ? null
                              : () async {
                                  setState(() => _loading = true);
                                  await widget.onAssign(uid,
                                      name.isEmpty ? m['email'] ?? uid : name);
                                  if (mounted) setState(() => _loading = false);
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isCurrentInstructor
                                  ? AppColors.brand
                                      .withValues(alpha: isDark ? 0.2 : 0.08)
                                  : (isDark
                                      ? AppColors.darkCard
                                      : AppColors.lightSurface2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCurrentInstructor
                                    ? AppColors.brand.withValues(alpha: 0.4)
                                    : theme.colorScheme.outline
                                        .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    AppColors.brand.withValues(alpha: 0.15),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                      color: AppColors.brand,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name.isEmpty ? uid : name,
                                        style: TextStyle(
                                            color: textP,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500)),
                                    Text(m['email'] ?? '',
                                        style: TextStyle(
                                            color: textS, fontSize: 10)),
                                  ],
                                ),
                              ),
                              if (isCurrentInstructor)
                                const Icon(Icons.check_circle_rounded,
                                    color: AppColors.brand, size: 18),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
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
  final bool canRemove;
  const _StudentsBottomSheet({required this.courseId, this.canRemove = false});

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
                  Text(AppLocalizations.of(context)!.courseStudentsTitle,
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
                loading: () => const AppLogoLoader(),
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
                            Text(
                                AppLocalizations.of(context)!
                                    .noStudentsInscribed,
                                style: TextStyle(color: textS, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.all(16),
                        itemCount: students.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _StudentTile(
                          student: students[i],
                          courseId: courseId,
                          canRemove: canRemove,
                        ),
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
  final String courseId;
  final bool canRemove;
  const _StudentTile({
    required this.student,
    required this.courseId,
    this.canRemove = false,
  });

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
                    Text(
                        AppLocalizations.of(context)!
                            .sessionsCountLabel(student['sessionCount'] ?? 0),
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
          if (canRemove) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _confirmRemove(context, ref),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.red.withValues(alpha: 0.25)),
                ),
                child: const Icon(Icons.person_remove_outlined,
                    size: 16, color: AppColors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final name = student['studentName'] ?? 'este alumno';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar alumno'),
        content: Text('¿Eliminar a $name del curso?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Eliminar', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final studentId = student['studentId'] as String? ?? '';
    if (studentId.isEmpty) return;
    try {
      await ref
          .read(firestoreServiceProvider)
          .unenrollStudent(courseId, studentId);
      ref.invalidate(courseStudentsProvider(courseId));
      ref.invalidate(coursesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: AppColors.red),
        );
      }
    }
  }
}

// ─── Sheet input helper ────────────────────────────────────────────────────────
class _SheetInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isDark;
  final int maxLines;
  final TextCapitalization capitalization;

  const _SheetInput({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.maxLines = 1,
    this.capitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: capitalization,
      style: TextStyle(
        color: theme.textTheme.bodyLarge?.color,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.25),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
