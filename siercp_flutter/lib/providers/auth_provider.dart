import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_service.dart';

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
    // Escuchar cambios de Firebase Auth
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return const AuthState();

    try {
      final db = ref.read(firestoreServiceProvider);
      final user = await db.getUser(firebaseUser.uid);
      if (user == null || !user.isActive) {
        await FirebaseAuth.instance.signOut();
        return const AuthState();
      }
      return AuthState(user: user, isAuthenticated: true);
    } catch (_) {
      return const AuthState();
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    final authService = ref.read(firebaseAuthServiceProvider);
    state = await AsyncValue.guard(() async {
      final user = await authService.login(email: email, password: password);
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

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authStateProvider).value?.user;
});
