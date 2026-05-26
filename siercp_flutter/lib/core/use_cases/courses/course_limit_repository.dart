import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:siercp/core/constants/constants.dart';

class CourseLimitDoc {
  final int monthlyCreated;
  final DateTime lastReset;

  const CourseLimitDoc({required this.monthlyCreated, required this.lastReset});
}

class CourseLimitRepository {
  final FirebaseFirestore _db;

  CourseLimitRepository() : _db = FirebaseFirestore.instance;

  Future<CourseLimitDoc?> get(String uid) async {
    final doc = await _db
        .collection(AppConstants.colCourseLimits)
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    final d = doc.data()!;
    return CourseLimitDoc(
      monthlyCreated: (d['monthlyCreated'] as int?) ?? 0,
      lastReset:      (d['lastReset'] as Timestamp).toDate(),
    );
  }

  Future<bool> canCreate(String uid, String role) async {
    final limit = _limitForRole(role);
    if (limit == null) return true; // sin límite personal

    final doc = await get(uid);
    if (doc == null) return true; // primer curso, sin documento aún

    final now       = DateTime.now();
    final sameMonth = doc.lastReset.year == now.year &&
        doc.lastReset.month == now.month;
    final count = sameMonth ? doc.monthlyCreated : 0;
    return count < limit;
  }

  Future<void> increment(String uid) async {
    final now    = DateTime.now();
    final docRef = _db.collection(AppConstants.colCourseLimits).doc(uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        tx.set(docRef, {
          'monthlyCreated': 1,
          'lastReset':      Timestamp.fromDate(DateTime(now.year, now.month)),
        });
        return;
      }
      final d         = snap.data()!;
      final lastReset = (d['lastReset'] as Timestamp).toDate();
      final sameMonth = lastReset.year == now.year && lastReset.month == now.month;
      if (sameMonth) {
        tx.update(docRef, {'monthlyCreated': FieldValue.increment(1)});
      } else {
        tx.set(docRef, {
          'monthlyCreated': 1,
          'lastReset':      Timestamp.fromDate(DateTime(now.year, now.month)),
        });
      }
    });
  }

  // Retorna el límite mensual según el rol. null = sin límite personal.
  static int? _limitForRole(String role) {
    switch (role) {
      case AppConstants.roleUsuario:
        return AppConstants.courseLimitUsuario;
      case AppConstants.roleUsuarioSST:
        return AppConstants.courseLimitUsuarioSST;
      case AppConstants.roleUsuarioProfesional:
        return AppConstants.courseLimitUsuarioPro;
      default:
        return null; // INSTRUCTOR, ADMIN, SUPER_ADMIN sin límite personal
    }
  }
}
