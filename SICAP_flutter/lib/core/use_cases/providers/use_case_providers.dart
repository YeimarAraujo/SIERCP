import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/use_cases/courses/course_limit_repository.dart';
import 'package:siercp/core/use_cases/courses/create_course_use_case.dart';
import 'package:siercp/core/use_cases/user/change_role_use_case.dart';
import 'package:siercp/core/use_cases/user/create_user_use_case.dart';
import 'package:siercp/core/use_cases/user/delete_user_use_case.dart';
import 'package:siercp/features/auth/data/firebase_auth_service.dart';

// ── Repositorios ──────────────────────────────────────────────────────────────

final courseLimitRepositoryProvider = Provider<CourseLimitRepository>(
  (_) => CourseLimitRepository(),
);

// ── UseCases ──────────────────────────────────────────────────────────────────

final createUserUseCaseProvider = Provider<CreateUserUseCase>((ref) {
  return CreateUserUseCase(auth: ref.read(firebaseAuthServiceProvider));
});

final deleteUserUseCaseProvider = Provider<DeleteUserUseCase>(
  (_) => const DeleteUserUseCase(),
);

final changeRoleUseCaseProvider = Provider<ChangeRoleUseCase>(
  (_) => const ChangeRoleUseCase(),
);

final createCourseUseCaseProvider = Provider<CreateCourseUseCase>((ref) {
  return CreateCourseUseCase(limits: ref.read(courseLimitRepositoryProvider));
});
