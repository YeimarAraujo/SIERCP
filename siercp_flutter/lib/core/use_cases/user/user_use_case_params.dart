/// Parámetros para crear un usuario nuevo con rol asignado.
class CreateUserParams {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String role;
  final String? identificacion;
  final String? institutionId;
  final String? approvedBy;

  const CreateUserParams({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.identificacion,
    this.institutionId,
    this.approvedBy,
  });
}

/// Lanzado por [CreateCourseUseCase] cuando el usuario supera su límite mensual.
class CourseLimitException implements Exception {
  final String message;
  const CourseLimitException(this.message);

  @override
  String toString() => message;
}
