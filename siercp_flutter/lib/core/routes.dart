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
import '../analytics/presentation/dashboard/analytics_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../models/guide.dart';
import '../models/course_module.dart';
import '../screens/Courses/Teacher/course_editor_screen.dart';
import '../screens/Courses/Student/student_course_detail_screen.dart';
import '../screens/Courses/Student/student_module_viewer_screen.dart';
import '../screens/Courses/Student/module_practica_screen.dart';
import '../screens/Courses/Student/module_quiz_screen.dart';
import '../screens/Courses/Student/module_certificacion_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/instructor_students_screen.dart';

import '../screens/student_detail_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStateProvider.notifier);
  
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isAuth = authState.value?.isAuthenticated ?? false;
      final isLoading = authState.isLoading;
      final location = state.matchedLocation;

      // Si todavía está cargando el estado inicial, nos quedamos en splash
      if (isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      // Lógica de redirección basada en autenticación
      if (location == '/splash') {
        return isAuth ? '/home' : '/login';
      }

      final isPublic = location == '/login' || location == '/register';
      
      if (!isAuth) {
        return isPublic ? null : '/login';
      }

      if (isAuth && isPublic) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),

          GoRoute(
            path: '/session',
            builder: (_, state) => SessionScreen(
              scenarioId: state.uri.queryParameters['scenario'],
              courseId: state.uri.queryParameters['courseId'],
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
          GoRoute(path: '/scenarios', builder: (_, __) => const ScenarioSelectScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
          GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsDashboardScreen()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
          GoRoute(
            path: '/instructor/students',
            builder: (_, __) => const InstructorStudentsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => StudentDetailScreen(
                  userId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),

          // ── Editor de curso (Instructor/Admin) ───────────────────────────
          GoRoute(
            path: '/course-editor/:courseId',
            builder: (_, state) => CourseEditorScreen(
              courseId: state.pathParameters['courseId']!,
            ),
          ),

          // ── Course Detail (instructor/admin) ─────────────────────────────
          GoRoute(
            path: '/courses/:id',
            builder: (_, state) => CourseDetailScreen(
              courseId: state.pathParameters['id']!,
            ),
          ),
          
          // Alias legacy para compatibilidad
          GoRoute(
            path: '/course-detail/:courseId',
            builder: (_, state) => CourseDetailScreen(
              courseId: state.pathParameters['courseId']!,
            ),
          ),
          GoRoute(
            path: '/student-course/:courseId',
            builder: (context, state) {
              final user = ref.read(currentUserProvider);
              return StudentCourseDetailScreen(
                courseId: state.pathParameters['courseId']!,
                studentId: user?.id ?? '',
                courseTitle: 'Detalle del Curso',
                instructorName: '',
              );
            },
          ),

          // ── Vista de detalle del ALUMNO (lista de módulos) ────────────────
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

          // ── Práctica guiada (Entrenamiento) ──────────────────────────────
          GoRoute(
            path: '/student/practica',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return ModulePracticaScreen(
                module: extra['module'] as CourseModule,
                courseId: extra['courseId'] as String,
              );
            },
          ),

          // ── Evaluación teórica (Quiz) ───────────────────────────────────
          GoRoute(
            path: '/student/quiz',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return ModuleQuizScreen(
                module: extra['module'] as CourseModule,
                courseId: extra['courseId'] as String,
                studentId: extra['studentId'] as String,
              );
            },
          ),

          // ── Certificación ───────────────────────────────────────────────
          GoRoute(
            path: '/student/certificacion',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return ModuleCertificacionScreen(
                courseId: extra['courseId'] as String,
                studentId: extra['studentId'] as String,
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

          // ── Reportes PDF ──────────────────────────────────────────────────
          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),

          // ── Admin routes ──────────────────────────────────────────────────
          GoRoute(path: '/admin/users', builder: (_, __) => const ManageUsersScreen()),
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
              'Ruta no encontrada: ${state.uri}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    ),
  );
});

/// Clase auxiliar para notificar cambios de autenticación al GoRouter sin recrearlo.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    _subscription = ref.listen(authStateProvider, (_, __) {
      notifyListeners();
    });
  }

  late final ProviderSubscription _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
