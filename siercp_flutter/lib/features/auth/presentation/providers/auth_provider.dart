import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/features/users/data/models/user.dart';
import 'package:siercp/features/auth/data/firebase_auth_service.dart';
import 'package:siercp/core/services/firestore_service.dart';

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
        user: user ?? this.user,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        error: error,
      );
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    try {
      final authStream = FirebaseAuth.instance.authStateChanges();
      // Timeout de 5 segundos para la primera respuesta de Auth
      final firebaseUser = await authStream.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      
      if (firebaseUser == null) return const AuthState();

      // Timeout de 5 segundos para obtener el perfil de Firestore
      return await _fetchUserProfile(firebaseUser.uid).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Timeout al obtener perfil de Firestore');
          return AuthState(
            user: UserModel(
              id: firebaseUser.uid,
              email: firebaseUser.email ?? '',
              firstName: 'Usuario',
              lastName: 'Cargando...',
              role: 'USUARIO',
            ),
            isAuthenticated: true,
          );
        },
      );
    } catch (e) {
      debugPrint('Error durante la inicialización de Auth: $e');
      return const AuthState();
    }
  }

  Future<AuthState> _fetchUserProfile(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
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
      
      // Update activity on successful profile fetch
      await ref.read(firestoreServiceProvider).updateUserActivity(uid);
      
      return AuthState(user: user, isAuthenticated: true);
    } catch (e) {
      debugPrint('Error al obtener perfil de usuario: $e');
      return const AuthState(error: 'Error de conexión');
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    final authService = ref.read(firebaseAuthServiceProvider);
    state = await AsyncValue.guard(() async {
      final user = await authService.login(email: email, password: password);
      // Update activity on login
      await ref.read(firestoreServiceProvider).updateUserActivity(user.id);
      return AuthState(user: user, isAuthenticated: true);
    });
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String? identificacion,
  }) async {
    state = const AsyncLoading();
    final authService = ref.read(firebaseAuthServiceProvider);
    state = await AsyncValue.guard(() async {
      final user = await authService.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: role,
        identificacion: identificacion,
      );
      return AuthState(user: user, isAuthenticated: true);
    });
  }

  Future<void> logout() async {
    final authService = ref.read(firebaseAuthServiceProvider);
    final uid = state.value?.user?.id;
    if (uid != null) {
      await ref.read(firestoreServiceProvider).updateUserPresence(uid, false);
    }
    await authService.logout();
    state = const AsyncData(AuthState());
  }

  Future<void> sendPasswordReset(String email) async {
    final authService = ref.read(firebaseAuthServiceProvider);
    await authService.sendPasswordReset(email);
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final usersStreamProvider = StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((snap) => snap.docs.map(UserModel.fromFirestore).toList());
});

final currentUserStreamProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  if (authState?.user == null) return Stream.value(null);
  return ref.read(firestoreServiceProvider).watchUser(authState!.user!.id);
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(currentUserStreamProvider).valueOrNull ?? ref.watch(authStateProvider).value?.user;
});
