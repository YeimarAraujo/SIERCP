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
  final bool isAnonymous;
  final String? error;

  const AuthState({
    this.user,
    this.isAuthenticated = false,
    this.isAnonymous = false,
    this.error,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isAuthenticated,
    bool? isAnonymous,
    String? error,
  }) =>
      AuthState(
        user:            user ?? this.user,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isAnonymous:     isAnonymous ?? this.isAnonymous,
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
    final authService = ref.read(firebaseAuthServiceProvider);
    try {
      final user = await authService.login(email: email, password: password);
      if (user.isAdmin || user.isSuperAdmin) {
        await authService.logout();
        throw Exception(
            'Los administradores deben iniciar sesión desde la versión web.');
      }
      await _postLoginSetup(user);
      state = AsyncData(AuthState(user: user, isAuthenticated: true, isAnonymous: false));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  // ── Demo (anónimo) ─────────────────────────────────────────────────────────

  Future<void> loginAnonymously() async {
    try {
      debugPrint('[Demo] Step 1: signing in anonymously...');
      final result = await FirebaseAuth.instance.signInAnonymously();
      final uid = result.user!.uid;
      debugPrint('[Demo] Step 2: signed in as uid=$uid');

      debugPrint('[Demo] Step 3: checking if user doc exists...');
      final doc = await FirebaseFirestore.instance
          .collection(AppConstants.colUsers)
          .doc(uid)
          .get();

      if (!doc.exists) {
        debugPrint('[Demo] Step 4: creating user doc...');
        await FirebaseFirestore.instance
            .collection(AppConstants.colUsers)
            .doc(uid)
            .set({
          'id': uid,
          'email': 'demo@siercp.app',
          'firstName': 'Demo',
          'lastName': 'Usuario',
          'role': AppConstants.roleUsuario,
          'isActive': true,
          'institutionId': '',
          'coursesCreated': 0,
          'coursesCreatedThisMonth': 0,
          'courseCreationMonth': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[Demo] Step 4: user doc created');
      } else {
        debugPrint('[Demo] Step 4: user doc already exists');
      }

      debugPrint('[Demo] Step 5: re-reading profile...');
      final profileDoc = await FirebaseFirestore.instance
          .collection(AppConstants.colUsers)
          .doc(uid)
          .get();
      if (!profileDoc.exists) {
        debugPrint('[Demo] ERROR: profile doc not found after create!');
        await FirebaseAuth.instance.signOut();
        throw Exception('No se pudo crear el perfil de demo.');
      }
      debugPrint('[Demo] Step 5: profile read OK');

      debugPrint('[Demo] Step 6: parsing user model...');
      final userModel = UserModel.fromFirestore(profileDoc);
      debugPrint('[Demo] Step 6: userModel=${userModel.fullName} role=${userModel.role}');

      debugPrint('[Demo] Step 7: post-login setup...');
      await _postLoginSetup(userModel);
      debugPrint('[Demo] Step 7: setup complete');

      debugPrint('[Demo] Step 8: setting auth state...');
      state = AsyncData(AuthState(user: userModel, isAuthenticated: true, isAnonymous: true));
      debugPrint('[Demo] Step 8: auth state set successfully');
    } catch (e, st) {
      debugPrint('[Demo] ERROR in loginAnonymously: $e');
      debugPrint('[Demo] Stack trace: $st');
      state = AsyncError(e, st);
      rethrow;
    }
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
      state = AsyncData(AuthState(user: user, isAuthenticated: true, isAnonymous: false));
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

    ref.read(orgContextProvider.notifier).reset();
    state = const AsyncData(AuthState());

    await Future<void>.delayed(Duration.zero);

    await authService.logout();
  }

  Future<void> sendPasswordReset(String email) async {
    final authService = ref.read(firebaseAuthServiceProvider);
    await authService.sendPasswordReset(email);
  }

  // ── Helpers privados ──────────────────────────────────────────────────────
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

      // SECURITY: cuentas administrativas (ADMIN / SUPER_ADMIN) son solo del
      // panel web. Si una sesión persistida pertenece a un admin, la cerramos
      // en vez de activarla (defensa en profundidad junto al check de login).
      if (user.isAdmin) {
        await FirebaseAuth.instance.signOut();
        return const AuthState(
          error: 'Las cuentas de administrador deben usar el panel web.',
        );
      }

      if (!user.isActive) {
        await FirebaseAuth.instance.signOut();
        return const AuthState(error: 'Cuenta desactivada');
      }

      await _postLoginSetup(user);
      return AuthState(user: user, isAuthenticated: true, isAnonymous: FirebaseAuth.instance.currentUser?.isAnonymous ?? false);
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
