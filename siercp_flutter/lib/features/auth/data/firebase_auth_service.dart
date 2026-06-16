import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/firebase_options.dart';
import 'package:siercp/features/users/data/models/user.dart';
import 'package:siercp/core/services/firestore_service.dart';

final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService(ref.read(firestoreServiceProvider));
});

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestore;

  FirebaseAuthService(this._firestore);

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;
    final user = await _firestore.getUser(uid);
    if (user == null) {
      await _auth.signOut();
      throw Exception('Perfil de usuario no encontrado en la base de datos.');
    }
    // M4 / SECURITY: las cuentas administrativas (ADMIN y SUPER_ADMIN) operan
    // exclusivamente desde el panel web. Nunca deben iniciar sesión en la app
    // móvil — si lo hicieran caerían en la pantalla "Institución no asignada".
    // `isAdmin` es true para ADMIN y SUPER_ADMIN.
    if (user.isAdmin) {
      await _auth.signOut();
      throw Exception(
        'Las cuentas de administrador no tienen acceso desde la aplicación '
        'móvil. Usa el panel de administración web.',
      );
    }
    if (!user.isActive) {
      await _auth.signOut();
      if (user.accountStatus == 'PENDING') {
        throw Exception(
          'Tu solicitud está pendiente de aprobación. '
          'Recibirás una notificación cuando el equipo de SIERCP active tu institución.',
        );
      }
      throw Exception('Tu cuenta está desactivada. Contacta al administrador.');
    }
    return user;
  }

  Future<UserModel> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String? identificacion,
    String? documentType,
    String? department,
    String? city,
    String? phoneNumber,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName('$firstName $lastName');

    final uid = credential.user!.uid;
    final user = UserModel(
      id: uid,
      email: email.trim(),
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      role: role,
      identificacion: identificacion?.trim(),
      documentType: documentType,
      department: department,
      city: city,
      phoneNumber: phoneNumber?.trim(),
      isActive: true,
      institutionId: uid,
    );
    try {
      await _firestore.createUser(user);
    } catch (e) {
      // Firestore write failed — eliminar el usuario de Auth para evitar
      // cuentas huérfanas que no pueden iniciar sesión.
      await credential.user?.delete().catchError((_) {});
      rethrow;
    }
    return user;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<UserModel> adminCreateUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String? identificacion,
  }) async {
    // Nombre único para la app temporal
    final tempAppName = 'adminCreate_${DateTime.now().millisecondsSinceEpoch}';

    // Inicializar segunda instancia de FirebaseApp
    final tempApp = await Firebase.initializeApp(
      name: tempAppName,
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final credential = await tempAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName('$firstName $lastName');

      final user = UserModel(
        id: credential.user!.uid,
        email: email.trim(),
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        role: role,
        identificacion: identificacion?.trim(),
        isActive: true,
      );

      await _firestore.createUser(user);

      // Cerrar sesión del usuario recién creado en la instancia temporal
      await tempAuth.signOut();
      return user;
    } finally {
      // Siempre eliminar la app temporal para liberar recursos
      await tempApp.delete();
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Obtiene el perfil completo del usuario actual desde Firestore.
  Future<UserModel?> getCurrentUserProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.getUser(uid);
  }

  /// Traduce errores de Firebase Auth a mensajes legibles en español.
  static String parseAuthError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No existe una cuenta con ese correo.';
        case 'wrong-password':
          return 'Contraseña incorrecta. Inténtalo de nuevo.';
        case 'email-already-in-use':
          return 'Ese correo ya está registrado.';
        case 'weak-password':
          return 'La contraseña es muy débil (mínimo 6 caracteres).';
        case 'invalid-email':
          return 'El formato del correo no es válido.';
        case 'user-disabled':
          return 'Tu cuenta está desactivada.';
        case 'too-many-requests':
          return 'Demasiados intentos. Espera un momento.';
        case 'network-request-failed':
          return 'Sin conexión a internet.';
        default:
          return 'Error de autenticación: ${e.message}';
      }
    }
    return e.toString();
  }
}
