import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course_module.dart';

final courseServiceProvider = Provider((ref) => CourseService());

class CourseService {
  final _db = FirebaseFirestore.instance;

  CollectionReference _modulesRef(String courseId) =>
      _db.collection('courses').doc(courseId).collection('modules');

  // ── Leer módulos ordenados ────────────────────────────────────────────────
  Future<List<CourseModule>> getModules(String courseId) async {
    final snap = await _modulesRef(courseId).orderBy('order').get();
    return snap.docs.map(CourseModule.fromDoc).toList();
  }

  // ── Crear módulo ──────────────────────────────────────────────────────────
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
      'type': type.name,
      'config': config,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Actualizar módulo ─────────────────────────────────────────────────────
  Future<void> updateModule(
    String courseId,
    String moduleId, {
    required String title,
    required ModuleType type,
    required Map<String, dynamic> config,
  }) async {
    await _modulesRef(courseId).doc(moduleId).update({
      'title': title,
      'type': type.name,
      'config': config,
    });
  }

  // ── Eliminar módulo ───────────────────────────────────────────────────────
  Future<void> deleteModule(String courseId, String moduleId) async {
    await _modulesRef(courseId).doc(moduleId).delete();
    // Re-ordenar los restantes
    final remaining = await getModules(courseId);
    final batch = _db.batch();
    for (int i = 0; i < remaining.length; i++) {
      batch.update(_modulesRef(courseId).doc(remaining[i].id), {'order': i});
    }
    await batch.commit();
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
}
