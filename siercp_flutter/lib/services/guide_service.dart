import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/guide.dart';

final guideServiceProvider = Provider<GuideService>((ref) => GuideService());

class GuideService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference get _guides => _db.collection('guides');

  Future<String> uploadPDF(
    File file,
    String courseId,
    String guideId, {
    void Function(double progress)? onProgress,
  }) async {
    // Validar tamaño ≤ 10 MB
    final bytes = await file.length();
    if (bytes > 10 * 1024 * 1024) {
      throw Exception('El archivo supera los 10 MB permitidos.');
    }

    final path = 'guides/$courseId/$guideId.pdf';
    final ref = _storage.ref(path);
    final uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: 'application/pdf'),
    );

    // Reportar progreso
    uploadTask.snapshotEvents.listen((snap) {
      final pct = snap.bytesTransferred / snap.totalBytes;
      onProgress?.call(pct);
    });

    await uploadTask;
    return await ref.getDownloadURL();
  }

  Future<void> createGuide(GuideModel guide) async {
    await _guides.doc(guide.id).set(guide.toFirestore());

    // Agregar el ID al array del curso
    await _db.collection('courses').doc(guide.courseId).update({
      'guideIds': FieldValue.arrayUnion([guide.id]),
      if (guide.required) 'requiredGuideCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateGuide(GuideModel guide) async {
    await _guides.doc(guide.id).update({
      'title': guide.title,
      'description': guide.description,
      'category': guide.category.value,
      'required': guide.required,
      'order': guide.order,
      'estimatedMinutes': guide.estimatedMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteGuide(String guideId, String courseId) async {
    final doc = await _guides.doc(guideId).get();
    final wasRequired =
        (doc.data() as Map<String, dynamic>?)?['required'] ?? false;

    try {
      await _storage.ref('guides/$courseId/$guideId.pdf').delete();
    } catch (_) {}

    // Eliminar de Firestore
    await _guides.doc(guideId).delete();

    // Actualizar curso
    await _db.collection('courses').doc(courseId).update({
      'guideIds': FieldValue.arrayRemove([guideId]),
      if (wasRequired) 'requiredGuideCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<GuideModel>> getGuidesByCourse(String courseId) async {
    final snap = await _guides
        .where('courseId', isEqualTo: courseId)
        .orderBy('order')
        .get();
    return snap.docs.map(GuideModel.fromFirestore).toList();
  }

  Stream<List<GuideModel>> streamGuidesByCourse(String courseId) {
    return _guides
        .where('courseId', isEqualTo: courseId)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(GuideModel.fromFirestore).toList());
  }

  Future<void> markGuideAsCompleted(
    String userId,
    String guideId,
    int timeSpentSeconds,
  ) async {
    final ref = _db
        .collection('guideProgress')
        .doc(userId)
        .collection('guides')
        .doc(guideId);

    final existing = await ref.get();
    final prevCount =
        existing.exists ? (existing.data()?['viewCount'] ?? 0) as int : 0;

    await ref.set({
      'guideId': guideId,
      'userId': userId,
      'completed': true,
      'completedAt': FieldValue.serverTimestamp(),
      'timeSpentSeconds': timeSpentSeconds,
      'viewCount': prevCount + 1,
      'lastPageReached': 9999,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateGuideProgress(
    String userId,
    String guideId, {
    required int timeSpentSeconds,
    required int lastPageReached,
    bool incrementViewCount = false,
  }) async {
    final ref = _db
        .collection('guideProgress')
        .doc(userId)
        .collection('guides')
        .doc(guideId);

    final updates = <String, dynamic>{
      'guideId': guideId,
      'userId': userId,
      'timeSpentSeconds': timeSpentSeconds,
      'lastPageReached': lastPageReached,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (incrementViewCount) {
      updates['viewCount'] = FieldValue.increment(1);
    }

    await ref.set(updates, SetOptions(merge: true));
  }

  Future<Map<String, GuideProgress>> getUserGuideProgress(String userId) async {
    final snap = await _db
        .collection('guideProgress')
        .doc(userId)
        .collection('guides')
        .get();

    final result = <String, GuideProgress>{};
    for (final doc in snap.docs) {
      result[doc.id] = GuideProgress.fromMap(doc.data(), doc.id, userId);
    }
    return result;
  }

  Stream<Map<String, GuideProgress>> streamUserGuideProgress(String userId) {
    return _db
        .collection('guideProgress')
        .doc(userId)
        .collection('guides')
        .snapshots()
        .map((snap) {
      final result = <String, GuideProgress>{};
      for (final doc in snap.docs) {
        result[doc.id] = GuideProgress.fromMap(doc.data(), doc.id, userId);
      }
      return result;
    });
  }

  Future<GuideProgressSummary> getCourseGuideProgressSummary(
    String userId,
    String courseId,
  ) async {
    final guides = await getGuidesByCourse(courseId);
    final progressMap = await getUserGuideProgress(userId);

    final required = guides.where((g) => g.required).length;
    final requiredCompleted = guides
        .where((g) => g.required && (progressMap[g.id]?.completed ?? false))
        .length;
    final completed =
        guides.where((g) => progressMap[g.id]?.completed ?? false).length;

    return GuideProgressSummary(
      totalGuides: guides.length,
      completedGuides: completed,
      requiredGuides: required,
      requiredCompleted: requiredCompleted,
    );
  }

  Future<Map<String, int>> getGuideStudentStats(
    String guideId,
    List<String> studentIds,
  ) async {
    int completedCount = 0;
    for (final uid in studentIds) {
      final doc = await _db
          .collection('guideProgress')
          .doc(uid)
          .collection('guides')
          .doc(guideId)
          .get();
      if (doc.exists && (doc.data()?['completed'] ?? false)) {
        completedCount++;
      }
    }
    return {
      'total': studentIds.length,
      'completed': completedCount,
    };
  }
}
