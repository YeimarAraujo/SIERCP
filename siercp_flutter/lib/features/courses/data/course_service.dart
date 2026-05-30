import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/features/courses/data/models/course_module.dart';

final courseModulesProvider = FutureProvider.family<List<CourseModule>, String>(
  (ref, courseId) => ref.read(courseServiceProvider).getModules(courseId),
);

final courseServiceProvider = Provider((ref) => CourseService());

class CourseService {
  final _db = FirebaseFirestore.instance;

  CollectionReference _modulesRef(String courseId) =>
      _db.collection('courses').doc(courseId).collection('modules');

  // Usamos la subcolección 'enrollments' porque los estudiantes tienen permiso
  // para escribir en su propio documento de inscripción cuando se unen al curso.
  CollectionReference _progressRef(String courseId) =>
      _db.collection('courses').doc(courseId).collection('enrollments');

  // ── Leer módulos ordenados ─────────────────────────────────────────────────
  /// Lee la subcolección `courses/{courseId}/modules`.
  /// Si está vacía, usa el array `modules[]` del documento del curso
  /// (formato legado guardado por el panel web antes del refactor).
  Future<List<CourseModule>> getModules(String courseId) async {
    // 1. Intentar subcolección (formato canónico)
    final snap = await _modulesRef(courseId).orderBy('order').get();
    if (snap.docs.isNotEmpty) {
      return snap.docs.map(CourseModule.fromDoc).toList();
    }

    // 2. Fallback: array en el documento del curso (formato web legacy)
    final courseDoc = await _db.collection('courses').doc(courseId).get();
    if (!courseDoc.exists) return [];
    final data = courseDoc.data()!;
    final raw = data['modules'];
    if (raw == null || raw is! List || (raw).isEmpty) return [];

    final entries = <CourseModule>[];
    for (int i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is Map) {
        entries.add(CourseModule.fromArrayEntry(
          courseId, i, Map<String, dynamic>.from(item),
        ));
      }
    }
    entries.sort((a, b) => a.order.compareTo(b.order));
    return entries;
  }

  // ── Crear módulo ───────────────────────────────────────────────────────────
  Future<void> createModule({
    required String courseId,
    required String title,
    required ModuleType type,
    required Map<String, dynamic> config,
  }) async {
    final existing = await getModules(courseId);
    final ref = _modulesRef(courseId).doc();
    await ref.set({
      'courseId': courseId,
      'order': existing.length,
      'title': title,
      'type': type.toString().split('.').last,
      'config': config,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Actualizar totalModules en el curso padre
    await _db.collection('courses').doc(courseId).update({
      'totalModules': existing.length + 1,
    });
  }

  // ── Actualizar módulo ──────────────────────────────────────────────────────
  Future<void> updateModule(
    String courseId,
    String moduleId, {
    required String title,
    required ModuleType type,
    required Map<String, dynamic> config,
  }) async {
    await _modulesRef(courseId).doc(moduleId).update({
      'title': title,
      'type': type.toString().split('.').last,
      'config': config,
    });
  }

  // ── Eliminar módulo ────────────────────────────────────────────────────────
  Future<void> deleteModule(String courseId, String moduleId) async {
    await _modulesRef(courseId).doc(moduleId).delete();
    // Re-ordenar los restantes
    final remaining = await getModules(courseId);
    final batch = _db.batch();
    for (int i = 0; i < remaining.length; i++) {
      batch.update(_modulesRef(courseId).doc(remaining[i].id), {'order': i});
    }
    await batch.commit();

    // Actualizar totalModules en el curso padre
    await _db.collection('courses').doc(courseId).update({
      'totalModules': remaining.length,
    });
  }

  // ── Reordenar módulos (drag & drop) ───────────────────────────────────────
  Future<void> reorderModules(String courseId, List<String> orderedIds) async {
    final batch = _db.batch();
    for (int i = 0; i < orderedIds.length; i++) {
      batch.update(_modulesRef(courseId).doc(orderedIds[i]), {'order': i});
    }
    await batch.commit();
    // Actualizar totalModules en el curso padre
    await _db
        .collection('courses')
        .doc(courseId)
        .update({'totalModules': orderedIds.length});
  }

  // ── Obtener progreso del alumno ────────────────────────────────────────────

  Future<Set<String>> getStudentProgress(
      String courseId, String studentId) async {
    final doc = await _progressRef(courseId).doc(studentId).get();

    if (!doc.exists) return {};

    final data = doc.data()! as Map<String, dynamic>;
    // Usamos 'completedModuleIds' para la lista de IDs para evitar conflicto
    final completed = List<String>.from(data['completedModuleIds'] ?? []);
    return completed.toSet();
  }

  // ── Marcar módulo como completado ────────────────────
  Future<void> markModuleComplete({
    required String courseId,
    required String moduleId,
    required String studentId,
  }) async {
    final enrollRef = _progressRef(courseId).doc(studentId);

    // Actualizamos la lista de IDs y también incrementamos el contador entero
    // para mantener consistencia con FirestoreService.
    await enrollRef.update({
      'completedModuleIds': FieldValue.arrayUnion([moduleId]),
      'completedModules': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }
}
