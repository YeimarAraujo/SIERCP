import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/core/use_cases/courses/course_limit_repository.dart';
import 'package:siercp/core/use_cases/user/user_use_case_params.dart';

class CreateCourseParams {
  final String title;
  final String description;
  final String creatorId;
  final String creatorRole;
  final String? institutionId;
  final String? instructorId;
  final String? inviteCode;

  const CreateCourseParams({
    required this.title,
    required this.description,
    required this.creatorId,
    required this.creatorRole,
    this.institutionId,
    this.instructorId,
    this.inviteCode,
  });
}

class CreateCourseUseCase {
  final CourseLimitRepository _limits;

  const CreateCourseUseCase({required CourseLimitRepository limits})
      : _limits = limits;

  static const _limitedRoles = {
    AppConstants.roleUsuario,
    AppConstants.roleUsuarioSST,
    AppConstants.roleUsuarioProfesional,
  };

  Future<DocumentReference> execute(CreateCourseParams params) async {
    final needsCheck = _limitedRoles.contains(params.creatorRole);

    if (needsCheck) {
      final canCreate =
          await _limits.canCreate(params.creatorId, params.creatorRole);
      if (!canCreate) {
        final limit = params.creatorRole == AppConstants.roleUsuario
            ? AppConstants.courseLimitUsuario
            : AppConstants.courseLimitUsuarioPro;
        throw CourseLimitException(
          'Has alcanzado el límite de $limit cursos por mes para tu plan.',
        );
      }
    }

    final db     = FirebaseFirestore.instance;
    final docRef = db.collection(AppConstants.colCourses).doc();

    await docRef.set({
      'title':         params.title,
      'description':   params.description,
      'createdBy':     params.creatorId,
      'instructorId':  params.instructorId ?? params.creatorId,
      'institutionId': params.institutionId ?? '',
      'inviteCode':    params.inviteCode ?? '',
      'isActive':      true,
      'createdAt':     FieldValue.serverTimestamp(),
      'updatedAt':     FieldValue.serverTimestamp(),
    });

    if (needsCheck) {
      await _limits.increment(params.creatorId);
    }

    return docRef;
  }
}
