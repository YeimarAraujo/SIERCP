import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/core/providers/org_context_provider.dart';
import 'package:siercp/features/users/data/models/user.dart';
import 'package:siercp/features/auth/data/firebase_auth_service.dart';
import 'package:siercp/core/services/firestore_service.dart';

// ── AuthState ─────────────────────────────────────────────────────────────────

class AuthState {
  final UserModel? user;
  final bool isAuthenticated;
  final String? error;

  const AuthState({
    this.user,
    this.isAuthenticated = false,
    this.error,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isAuthenticated,
    String? error,
  }) =>
      AuthState(
        user:            user ?? this.user,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        error:           error,
      );

  // ── Shortcuts de rol (basados en el campo global del UserModel) ──────────
  // Para checks de SUPER_ADMIN que no dependen de org.
  bool get isSuperAdmin =>
      user?.role == AppConstants.roleSuperAdmin;
}

// ── AuthNotifier ──────────────────────────────────────────────────────────────

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    try {
      final firebaseUser = await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => null);

      if (firebaseUser == null) return const AuthState();

      // SECURITY (HIGH-03): On timeout we sign out rather than creating a
      // synthetic authenticated session with fabricated profile data.
      // A network-throttling MitM could deliberately delay Firestore to force
      // the old fallback path and obtain a valid isAuthenticated session.
      return await _fetchAndActivate(firebaseUser.uid).timeout(
        const Duration(seconds: 10),
        onTimeout: () async {
          debugPrint('[Auth] Timeout al obtener perfil — cerrando sesión por seguridad');
          await FirebaseAuth.instance.signOut();
          return const AuthState(error: 'Tiempo de espera agotado. Intenta de nuevo.');
        },
      );
    } catch (e) {
      debugPrint('[Auth] Error durante inicialización: $e');
      return const AuthState();
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    final authService = ref.read(firebaseAuthServiceProvider);
    state = await AsyncValue.guard(() async {
      final user = await authService.login(email: email, password: password);
      await _postLoginSetup(user);
      return AuthState(user: user, isAuthenticated: true);
    });
  }

  // ── Registro ──────────────────────────────────────────────────────────────

  Future<void> register({
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
    state = const AsyncLoading();
    final authService = ref.read(firebaseAuthServiceProvider);
    try {
      final user = await authService.register(
        email:          email,
        password:       password,
        firstName:      firstName,
        lastName:       lastName,
        role:           role,
        identificacion: identificacion,
        documentType:   documentType,
        department:     department,
        city:           city,
        phoneNumber:    phoneNumber,
      );
      state = AsyncData(AuthState(user: user, isAuthenticated: true));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    final authService = ref.read(firebaseAuthServiceProvider);
    final uid = state.value?.user?.id;
    if (uid != null) {
      await ref.read(firestoreServiceProvider).updateUserPresence(uid, false);
    }
    // Limpiar contexto de org
    ref.read(orgContextProvider.notifier).reset();
    await authService.logout();
    state = const AsyncData(AuthState());
  }

  Future<void> sendPasswordReset(String email) async {
    final authService = ref.read(firebaseAuthServiceProvider);
    await authService.sendPasswordReset(email);
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  /// Obtiene el perfil del usuario y activa el OrgContext.
  Future<AuthState> _fetchAndActivate(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(AppConstants.colUsers)
          .doc(uid)
          .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        return const AuthState();
      }

      final user = UserModel.fromFirestore(doc);

      if (!user.isActive) {
        await FirebaseAuth.instance.signOut();
        return const AuthState(error: 'Cuenta desactivada');
      }

      await _postLoginSetup(user);
      return AuthState(user: user, isAuthenticated: true);
    } catch (e) {
      debugPrint('[Auth] Error al obtener perfil: $e');
      return const AuthState(error: 'Error de conexión');
    }
  }

  /// Acciones post-login: presencia + OrgContext.
  /// Los errores individuales se capturan para que un fallo en la presencia
  /// o en la carga de memberships no bloquee el login completo.
  Future<void> _postLoginSetup(UserModel user) async {
    final futures = <Future>[
      ref
          .read(firestoreServiceProvider)
          .updateUserActivity(user.id)
          .catchError((e) => debugPrint('[Auth] updateUserActivity error: $e')),
    ];
    // SuperAdmin no pertenece a ninguna org — no buscar memberships.
    if (!user.isSuperAdmin) {
      futures.add(
        ref
            .read(orgContextProvider.notifier)
            .loadForUser(user.id)
            .catchError((e) => debugPrint('[Auth] loadForUser error: $e')),
      );
    }
    await Future.wait(futures);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final currentUserStreamProvider = StreamProvider<UserModel?>((ref) {
  // Usar valueOrNull evita que AsyncLoading/AsyncError durante el logout
  // mantenga el stream activo sobre un UID ya desautenticado.
  final user = ref.watch(authStateProvider).valueOrNull?.user;
  if (user == null) return Stream.value(null);
  return ref.read(firestoreServiceProvider).watchUser(user.id);
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(currentUserStreamProvider).valueOrNull ??
      ref.watch(authStateProvider).value?.user;
});

// ── Compatibilidad legado: stream de todos los usuarios (SOLO SUPER_ADMIN) ───
// Migra a orgMembersStreamProvider del TenantService para uso en pantallas admin.
final usersStreamProvider = StreamProvider<List<UserModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isSuperAdmin) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection(AppConstants.colUsers)
      .snapshots()
      .map((snap) => snap.docs.map(UserModel.fromFirestore).toList());
});
