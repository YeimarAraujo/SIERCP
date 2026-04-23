import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../models/maniqui.dart';
import 'firestore_service.dart';
import 'firebase_auth_service.dart';

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(
    ref.read(firestoreServiceProvider),
    ref.read(firebaseAuthServiceProvider),
  );
});

final allUsersProvider = FutureProvider<List<UserModel>>((ref) {
  return ref.read(adminServiceProvider).getUsers();
});

final allManiquisProvider = FutureProvider<List<ManiquiModel>>((ref) {
  return ref.read(adminServiceProvider).getManiquis();
});

class AdminService {
  final FirestoreService _db;
  final FirebaseAuthService _authSvc;
  AdminService(this._db, this._authSvc);

  Future<UserModel> adminCreateUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String? identificacion,
  }) =>
      _authSvc.adminCreateUser(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: role,
        identificacion: identificacion,
      );

  Future<List<UserModel>> getUsers() => _db.getAllUsers();

  Future<List<ManiquiModel>> getManiquis() => _db.getManikins();

  Future<void> deleteUser(String userId) => _db.deleteUser(userId);

  Future<void> toggleUserActive(String userId) => _db.toggleUserActive(userId);

  /// Inscribe un estudiante por cédula a un curso (para instructores).
  Future<void> enrollStudentByCedula({
    required String courseId,
    required String cedula,
    required String instructorId,
  }) async {
    final student = await _db.getUserByIdentificacion(cedula);
    if (student == null) {
      throw Exception('No se encontró ningún usuario con esa cédula.');
    }
    if (!student.isStudent) {
      throw Exception('El usuario no tiene rol de Estudiante.');
    }

    await _db.enrollStudent(
      courseId:       courseId,
      studentId:      student.id,
      studentName:    student.fullName,
      studentEmail:   student.email,
      identificacion: student.identificacion,
    );
  }
}
