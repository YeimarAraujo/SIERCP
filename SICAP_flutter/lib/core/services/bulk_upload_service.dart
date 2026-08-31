import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/features/auth/data/firebase_auth_service.dart';
import 'package:siercp/core/services/firestore_service.dart';
import 'package:siercp/features/users/data/models/user.dart';

final bulkUploadServiceProvider = Provider((ref) => BulkUploadService(
  ref.watch(firestoreServiceProvider),
  ref.watch(firebaseAuthServiceProvider),
));

class BulkUploadService {
  final FirestoreService _firestore;
  final FirebaseAuthService _auth;

  BulkUploadService(this._firestore, this._auth);

  /// Selecciona y parsea un CSV para previsualizar los datos.
  Future<List<Map<String, String>>> pickAndParseCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null) return [];

      final bytes = result.files.first.bytes;
      if (bytes == null) return [];

      final csvString = utf8.decode(bytes);
      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);

      if (rows.length <= 1) return [];

      List<Map<String, String>> students = [];
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 3) continue;

        students.add({
          'firstName': row[0].toString().trim(),
          'lastName': row[1].toString().trim(),
          'email': row[2].toString().trim(),
          'idNum': row.length > 3 ? row[3].toString().trim() : '',
        });
      }
      return students;
    } catch (e) {
      debugPrint('Error parseando CSV: $e');
      return [];
    }
  }

  /// Procesa la inscripción masiva en un curso.
  Future<BulkUploadResult> processBulkEnrollment({
    required String courseId,
    required List<Map<String, String>> students,
  }) async {
    int created = 0;
    int enrolled = 0;
    int errors = 0;

    for (final student in students) {
      try {
        final email = student['email']!;
        final firstName = student['firstName']!;
        final lastName = student['lastName']!;
        final idNum = student['idNum'];

        // 1. Crear o recuperar usuario
        UserModel? user = await _firestore.getUserByEmail(email);
        
        if (user == null) {
          // Crear cuenta nueva
          user = await _auth.adminCreateUser(
            email: email,
            password: 'Siercp2026*', // Contraseña genérica
            firstName: firstName,
            lastName: lastName,
            role: 'student',
            identificacion: idNum,
          );
          created++;
        }

        // 2. Inscribir en el curso
        await _firestore.enrollStudent(
          courseId: courseId,
          studentId: user.id,
          studentName: user.fullName,
          studentEmail: user.email,
          identificacion: user.identificacion,
        );
        enrolled++;
      } catch (e) {
        debugPrint('Error inscribiendo estudiante: $e');
        errors++;
      }
    }

    return BulkUploadResult(
      total: students.length,
      created: created,
      enrolled: enrolled,
      errors: errors,
    );
  }

  /// Procesa un archivo CSV y registra a los estudiantes (General).
  Future<Map<String, dynamic>> uploadStudentsFromCsv() async {
    final students = await pickAndParseCsv();
    if (students.isEmpty) return {'success': false, 'message': 'No se seleccionó archivo o está vacío'};

    final result = await processBulkEnrollment(courseId: 'general', students: students);
    
    return {
      'success': true,
      'created': result.created,
      'message': 'Proceso completado. ${result.created} alumnos nuevos registrados.'
    };
  }
}

class BulkUploadResult {
  final int total;
  final int created;
  final int enrolled;
  final int errors;

  BulkUploadResult({
    required this.total,
    required this.created,
    required this.enrolled,
    required this.errors,
  });
}
