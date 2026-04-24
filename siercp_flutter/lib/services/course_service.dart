import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course_module.dart';

final courseServiceProvider = Provider((ref) => CourseService());

class CourseService {
  final _db = FirebaseFirestore.instance;

  CollectionReference _modulesRef(String courseId) =>
      _db.collection('courses').doc(courseId).collection('modules');

  CollectionReference _progressRef(String courseId) =>
      _db.collection('courses').doc(courseId).collection('progress');

  // ── Leer módulos ordenados ─────────────────────────────────────────────────
  Future<List<CourseModule>> getModules(String courseId) async {
    final snap = await _modulesRef(courseId).orderBy('order').get();
    return snap.docs.map(CourseModule.fromDoc).toList();
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
      'type': type.name,
      'config': config,
      'createdAt': FieldValue.serverTimestamp(),
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
      'type': type.name,
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
  //
  // Retorna el Set de IDs de módulos que el alumno ya completó.
  // Si no existe el documento (alumno sin progreso), retorna Set vacío.
  //
  // Estructura Firestore:
  //   courses/{courseId}/progress/{studentId}
  //     ├── studentId:        String
  //     ├── courseId:         String
  //     ├── completedModules: List<String>  ← IDs de módulos completados
  //     └── lastUpdated:      Timestamp
  //
  Future<Set<String>> getStudentProgress(
      String courseId, String studentId) async {
    final doc = await _progressRef(courseId).doc(studentId).get();

    if (!doc.exists) return {};

    final data = doc.data()! as Map<String, dynamic>;
    final completed = List<String>.from(data['completedModules'] ?? []);
    return completed.toSet();
  }

  // ── Marcar módulo como completado ─────────────────────────────────────────
  //
  // Usa arrayUnion para evitar duplicados y merge:true para no pisar datos
  // existentes si el alumno ya tiene otros módulos completados.
  //
  Future<void> markModuleComplete({
    required String courseId,
    required String moduleId,
    required String studentId,
  }) async {
    final progressRef = _progressRef(courseId).doc(studentId);

    await progressRef.set(
      {
        'completedModules': FieldValue.arrayUnion([moduleId]),
        'lastUpdated': FieldValue.serverTimestamp(),
        'studentId': studentId,
        'courseId': courseId,
      },
      SetOptions(merge: true),
    );
  }
}

// ─── Estructura de Firestore ──────────────────────────────────────────────────
//
//  courses/{courseId}/
//    ├── modules/{moduleId}
//    │     ├── title:             String
//    │     ├── type:              String  (teoria | evaluacion_teorica |
//    │     │                               practica_guiada | certificacion)
//    │     ├── pdfUrl:            String?   ← URL de Firebase Storage
//    │     ├── videoUrl:          String?   ← URL de YouTube
//    │     ├── textContent:       String?
//    │     ├── passingScore:      int
//    │     ├── questions:         List<Map>
//    │     ├── requiredSessions:  List<Map>
//    │     └── order:             int
//    │
//    └── progress/{studentId}
//          ├── studentId:         String
//          ├── courseId:          String
//          ├── completedModules:  List<String>  ← IDs de módulos completados
//          └── lastUpdated:       Timestamp
