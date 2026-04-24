import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/home_screen.dart';
import '../screens/session_screen.dart';
import '../screens/session_result_screen.dart';
import '../screens/history_screen.dart';
import '../screens/courses_screen.dart';
import '../screens/course_detail_screen.dart';
import '../screens/guide_list_screen.dart';
import '../screens/guide_pdf_viewer_screen.dart';
import '../screens/add_guide_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/scenario_select_screen.dart';
import '../screens/live_instructor_screen.dart';
import '../screens/register_screen.dart';
import '../screens/manage_users_screen.dart';
import '../screens/user_detail_screen.dart';
import '../screens/device_status_screen.dart';
import '../screens/create_user_screen.dart';
import '../screens/device_selection_screen.dart';
import '../screens/reports_screen.dart';
import '../models/guide.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuth    = authState.value?.isAuthenticated ?? false;
      final isLoading = authState.isLoading;
      final location  = state.matchedLocation;

      if (isLoading) return location == '/splash' ? null : '/splash';
      if (location == '/splash') return isAuth ? '/home' : '/login';

      final isPublic = location == '/login' || location == '/register';
      if (!isAuth) return isPublic ? null : '/login';
      if (isAuth && isPublic) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash',   builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home',    builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/session',
            builder: (_, state) => SessionScreen(
              scenarioId: state.uri.queryParameters['scenario'],
            ),
          ),
          GoRoute(
            path: '/session-result/:id',
            builder: (_, state) => SessionResultScreen(
              sessionId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(path: '/history',   builder: (_, __) => const HistoryScreen()),
          GoRoute(path: '/courses',   builder: (_, __) => const CoursesScreen()),
          GoRoute(path: '/scenarios', builder: (_, __) => const ScenarioSelectScreen()),
          GoRoute(path: '/profile',   builder: (_, __) => const ProfileScreen()),

          // ── Course Detail ────────────────────────────────────────────────
          GoRoute(
            path: '/courses/:id',
            builder: (_, state) => CourseDetailScreen(
              courseId: state.pathParameters['id']!,
            ),
          ),

          // ── Guías ────────────────────────────────────────────────────────
          GoRoute(
            path: '/courses/:courseId/guides',
            builder: (_, state) => GuideListScreen(
              courseId: state.pathParameters['courseId']!,
              canEdit:  state.uri.queryParameters['edit'] == 'true',
            ),
          ),
          GoRoute(
            path: '/courses/:courseId/add-guide',
            builder: (_, state) => AddGuideScreen(
              courseId: state.pathParameters['courseId']!,
            ),
          ),
          GoRoute(
            path: '/guides/:guideId/view',
            builder: (_, state) {
              final guide = state.extra as GuideModel?;
              if (guide == null) {
                return const Scaffold(
                  body: Center(child: Text('Guía no encontrada')),
                );
              }
              return GuidePDFViewerScreen(guide: guide);
            },
          ),

          // ── Selección de dispositivo ─────────────────────────────────────
          GoRoute(
            path: '/session/device-select',
            builder: (_, __) => const DeviceSelectionScreen(),
          ),

          // ── Live instructor ───────────────────────────────────────────────
          GoRoute(
            path: '/live/:courseId',
            builder: (_, state) => LiveInstructorScreen(
              courseId: state.pathParameters['courseId']!,
            ),
          ),

          // ── Reportes PDF ──────────────────────────────────────────────────
          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),

          // ── Admin routes ──────────────────────────────────────────────────
          GoRoute(path: '/admin/users',       builder: (_, __) => const ManageUsersScreen()),
          GoRoute(
            path: '/admin/users/:id',
            builder: (_, state) => UserDetailScreen(
              userId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(path: '/admin/devices',     builder: (_, __) => const DeviceStatusScreen()),
          GoRoute(path: '/admin/create-user', builder: (_, __) => const CreateUserScreen()),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('Ruta no encontrada: ${state.uri}',
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    ),
  );
});
