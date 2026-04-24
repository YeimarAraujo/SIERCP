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
import '../models/guide.dart';
import '../models/course_module.dart';
import '../screens/Courses/Teacher/course_editor_screen.dart';
import '../screens/Courses/Student/student_course_detail_screen.dart';
import '../screens/Courses/Student/student_module_viewer_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuth = authState.value?.isAuthenticated ?? false;
      final isLoading = authState.isLoading;
      final location = state.matchedLocation;

      if (isLoading) return location == '/splash' ? null : '/splash';
      if (location == '/splash') return isAuth ? '/home' : '/login';

      final isPublic = location == '/login' || location == '/register';
      if (!isAuth) return isPublic ? null : '/login';
      if (isAuth && isPublic) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),

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

          GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
          GoRoute(path: '/courses', builder: (_, __) => const CoursesScreen()),
          GoRoute(
              path: '/scenarios',
              builder: (_, __) => const ScenarioSelectScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),

          // ── Editor de curso (Instructor/Admin) ───────────────────────────
          GoRoute(
            path: '/course-editor/:courseId',
            builder: (_, state) => CourseEditorScreen(
              courseId: state.pathParameters['courseId']!,
            ),
          ),

          // ── Course Detail (ruta legacy — mantiene compatibilidad) ─────────
          GoRoute(
            path: '/course-detail/:courseId',
            builder: (_, state) => CourseDetailScreen(
              courseId: state.pathParameters['courseId']!,
            ),
          ),

          // ── Course Detail (ruta con ID por path — alias legacy) ───────────
          GoRoute(
            path: '/courses/:id',
            builder: (_, state) => CourseDetailScreen(
              courseId: state.pathParameters['id']!,
            ),
          ),

          // ── Vista de detalle del ALUMNO (lista de módulos) ────────────────

          // Uso desde CoursesScreen (tap del alumno):
          //
          //   context.push('/student/course-detail', extra: {
          //     'courseId':      course.id,
          //     'studentId':     currentUser.id,
          //     'courseTitle':   course.title,
          //     'instructorName': course.instructorName,
          //   });
          //
          GoRoute(
            path: '/student/course-detail',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return StudentCourseDetailScreen(
                courseId: extra['courseId'] as String,
                studentId: extra['studentId'] as String,
                courseTitle: extra['courseTitle'] as String,
                instructorName: extra['instructorName'] as String,
              );
            },
          ),

          // ── Visor de módulo del ALUMNO (PDF inline + YouTube integrado) ───
          //
          // Uso desde StudentCourseDetailScreen (tap en un módulo):
          //
          //   context.push('/student/module-viewer', extra: {
          //     'module':      module,          // CourseModule
          //     'courseId':    courseId,
          //     'studentId':   studentId,
          //     'isCompleted': isCompleted,     // bool, opcional
          //   });
          //
          GoRoute(
            path: '/student/module-viewer',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return StudentModuleViewerScreen(
                module: extra['module'] as CourseModule,
                courseId: extra['courseId'] as String,
                studentId: extra['studentId'] as String,
                isCompleted: extra['isCompleted'] as bool? ?? false,
              );
            },
          ),

          // ── Guías ────────────────────────────────────────────────────────
          GoRoute(
            path: '/courses/:courseId/guides',
            builder: (_, state) => GuideListScreen(
              courseId: state.pathParameters['courseId']!,
              canEdit: state.uri.queryParameters['edit'] == 'true',
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

          // ── Selección de dispositivo ──────────────────────────────────────
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

          // ── Admin ─────────────────────────────────────────────────────────
          GoRoute(
              path: '/admin/users',
              builder: (_, __) => const ManageUsersScreen()),
          GoRoute(
            path: '/admin/users/:id',
            builder: (_, state) => UserDetailScreen(
              userId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
              path: '/admin/devices',
              builder: (_, __) => const DeviceStatusScreen()),
          GoRoute(
              path: '/admin/create-user',
              builder: (_, __) => const CreateUserScreen()),
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
            Text(
              'Ruta no encontrada: \${state.uri}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    ),
  );
});
