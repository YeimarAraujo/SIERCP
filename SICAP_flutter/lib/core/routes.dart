import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/core/providers/org_context_provider.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/auth/presentation/pages/splash_screen.dart';
import 'package:siercp/features/auth/presentation/pages/login_screen.dart';
import 'package:siercp/features/home/presentation/pages/main_shell.dart';
import 'package:siercp/features/home/presentation/pages/home_screen.dart';
import 'package:siercp/features/session/presentation/pages/session_screen.dart';
import 'package:siercp/features/session/presentation/pages/session_result_screen.dart';
import 'package:siercp/features/reports/presentation/pages/history_screen.dart';
import 'package:siercp/features/courses/presentation/pages/courses_screen.dart';
import 'package:siercp/features/courses/presentation/pages/course_detail_screen.dart';
import 'package:siercp/features/guides/presentation/pages/guide_list_screen.dart';
import 'package:siercp/features/guides/presentation/pages/guide_pdf_viewer_screen.dart';
import 'package:siercp/features/guides/presentation/pages/add_guide_screen.dart';
import 'package:siercp/features/users/presentation/pages/profile_screen.dart';
import 'package:siercp/features/skills/presentation/pages/skill_wallet_screen.dart';
import 'package:siercp/features/skills/presentation/pages/badges_screen.dart';
import 'package:siercp/features/skills/presentation/pages/learning_paths_screen.dart';
import 'package:siercp/features/skills/presentation/pages/ranking_screen.dart';
import 'package:siercp/features/scenarios/presentation/pages/scenario_select_screen.dart';
import 'package:siercp/features/scenarios/presentation/pages/scenario_detail_screen.dart';
import 'package:siercp/features/scenarios/presentation/pages/scenario_guide_screen.dart';
import 'package:siercp/features/simulation/presentation/pages/practice_menu_screen.dart';
import 'package:siercp/features/simulation/presentation/pages/theoretical_hub_screen.dart';
import 'package:siercp/features/simulation/presentation/pages/theoretical_cases_screen.dart';
import 'package:siercp/features/simulation/presentation/pages/quiz_screen.dart';
import 'package:siercp/features/simulation/presentation/pages/quiz_result_screen.dart';
import 'package:siercp/features/simulation/presentation/pages/practical_hub_screen.dart';
import 'package:siercp/features/simulation/presentation/pages/ecg_simulation_list_screen.dart';
import 'package:siercp/features/simulation/presentation/pages/ecg_monitor_screen.dart';
import 'package:siercp/features/simulation/presentation/pages/aed_simulator_screen.dart';
import 'package:siercp/features/simulation/presentation/pages/airway_simulator_screen.dart';
import 'package:siercp/features/simulation/presentation/pages/acls_simulator_screen.dart';
import 'package:siercp/features/simulation/presentation/pages/trauma_simulator_screen.dart';
import 'package:siercp/features/simulation/presentation/pages/random_quiz_screen.dart';
import 'package:siercp/features/simulation/presentation/pages/triage_screen.dart';
import 'package:siercp/features/simulation/data/models/quiz_session.dart';
import 'package:siercp/features/session/presentation/pages/live_instructor_screen.dart';
import 'package:siercp/features/auth/presentation/pages/register_screen.dart';
import 'package:siercp/features/auth/presentation/pages/institution_register_screen.dart';
import 'package:siercp/features/users/presentation/pages/manage_users_screen.dart';
import 'package:siercp/features/users/presentation/pages/user_detail_screen.dart';
import 'package:siercp/features/devices/presentation/pages/device_status_screen.dart';
import 'package:siercp/features/users/presentation/pages/create_user_screen.dart';
import 'package:siercp/features/devices/presentation/pages/device_selection_screen.dart';
import 'package:siercp/features/reports/presentation/pages/reports_screen.dart';
import 'package:siercp/features/users/presentation/pages/edit_profile_screen.dart';
import 'package:siercp/features/users/presentation/pages/certificates_screen.dart';
import 'package:siercp/features/guides/data/models/guide.dart';
import 'package:siercp/features/courses/data/models/course_module.dart';
import 'package:siercp/features/courses/presentation/pages/course_editor_screen.dart';
import 'package:siercp/features/courses/presentation/pages/student_course_detail_screen.dart';
import 'package:siercp/features/courses/presentation/pages/student_course_modules_screen.dart';
import 'package:siercp/features/courses/presentation/pages/student_module_viewer_screen.dart';
import 'package:siercp/features/courses/presentation/pages/module_practica_screen.dart';
import 'package:siercp/features/courses/presentation/pages/module_quiz_screen.dart';
import 'package:siercp/features/notifications/presentation/pages/notifications_screen.dart';
import 'package:siercp/features/users/presentation/pages/instructor_students_screen.dart';
import 'package:siercp/features/users/presentation/pages/student_detail_screen.dart';
import 'package:siercp/features/analytics/presentation/dashboard/analytics_screen.dart';
import 'package:siercp/features/calendar/presentation/pages/calendar_screen.dart';
// ── Nuevas pantallas multi-tenant ────────────────────────────────────────────
import 'package:siercp/features/org/presentation/pages/no_org_screen.dart';
import 'package:siercp/features/org/presentation/pages/org_switcher_screen.dart';
import 'package:siercp/features/users/presentation/pages/instructor_apply_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Garantiza que el splash (video de carga) se muestre un mínimo de tiempo
/// antes de saltar a /login o /home, aunque la auth resuelva al instante.
class _SplashGate extends ChangeNotifier {
  bool _done = false;

  bool get done => _done;

  _SplashGate() {
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (hasListeners) {
        _done = true;
        notifyListeners();
      }
    });
  }
}

final _splashGateProvider =
    ChangeNotifierProvider<_SplashGate>((ref) => _SplashGate());

// Rutas que no requieren contexto de organización
const _orgFreeRoutes = {'/no-org', '/org-select'};
// Rutas que requieren rol ADMIN en la org activa
const _adminRoutes = {'/admin/'};

/// Reconstruye un [CourseModule] desde el `extra` de navegación.
/// Las pantallas pasan `module.toMap()` (mapa serializable) para sobrevivir a
/// deep links y restauración de estado; aquí lo deserializamos.
CourseModule? _moduleFromExtra(Object? raw) {
  if (raw is CourseModule) return raw; // compatibilidad con llamadas directas
  if (raw is Map) return CourseModule.fromMap(Map<String, dynamic>.from(raw));
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final appListenable = _AppListenable(ref);

  ref.onDispose(() {
    appListenable.dispose();
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: appListenable,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isAuth = authState.value?.isAuthenticated ?? false;
      final isLoading = authState.isLoading;
      final location = state.matchedLocation;

      // ── 1. Splash: esperar carga inicial + tiempo mínimo del video ────────
      final splashDone = ref.read(_splashGateProvider).done;
      if (isLoading || !splashDone) {
        return location == '/splash' ? null : '/splash';
      }
      if (location == '/splash') {
        if (!isAuth) return '/login';
        return '/home';
      }

      // ── 2. Guard de autenticación ─────────────────────────────────────────
      final isPublic = location == '/login' ||
          location == '/register' ||
          location == '/register-institution';
      if (!isAuth) return isPublic ? null : '/login';
      if (isAuth && (location == '/login' || location == '/register'))
        return '/home';

      final authValue = ref.read(authStateProvider).value;
      final user = ref.read(currentUserProvider);

      // ── 4. Guard de contexto de organización ──────────────────────────────
      if (_orgFreeRoutes.contains(location)) return null;

      final orgCtx = ref.read(orgContextProvider);
      if (orgCtx.isLoading) return null; // Espera silenciosa

      // Solo ADMIN está obligado a tener org. USUARIO e INSTRUCTOR
      // pueden usar la plataforma sin pertenecer a ninguna organización.
      if (!orgCtx.hasOrg) {
        final roleGlobal = user?.role ?? authValue?.user?.role;
        if (roleGlobal == AppConstants.roleAdmin) return '/no-org';
        // Todos los demás (USUARIO, INSTRUCTOR, etc.) pasan al home.
      }

      // ── 5. Guard de rol admin para rutas /admin/* ─────────────────────────
      if (_adminRoutes.any(location.startsWith)) {
        if (!orgCtx.isAdmin) return '/home';
      }

      // ── 6. Guard de rol instructor para rutas live y course-editor ────────
      if (location.startsWith('/live/') ||
          location.startsWith('/course-editor/')) {
        // Permite si instructor por membership O por rol global.
        // La detección por asignación de curso (isInstructorOnCourseProvider) es
        // async y se verifica en la página; no bloqueamos aquí para no rechazar
        // usuarios legítimos mientras el provider carga.
        final roleGlobal = user?.role ?? authValue?.user?.role ?? '';
        final isInstructorByRole = roleGlobal == AppConstants.roleInstructor ||
            roleGlobal == AppConstants.roleAdmin ||
            roleGlobal == AppConstants.roleSuperAdmin;
        if (!orgCtx.isInstructor && !isInstructorByRole) {
          // Solo bloquear si la org ya cargó y el rol no es instructor.
          // Si orgCtx aún está cargando, dejamos pasar.
          if (!orgCtx.isLoading) return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/register-institution',
          builder: (_, __) => const InstitutionRegisterScreen()),

      // ── Pantallas de org (fuera del shell) ───────────────────────────────
      GoRoute(path: '/no-org', builder: (_, __) => const NoOrgScreen()),
      GoRoute(
          path: '/org-select', builder: (_, __) => const OrgSwitcherScreen()),

      // ── Shell principal (botón nav bar) ──────────────────────────────────────
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),

          GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
          GoRoute(path: '/courses', builder: (_, __) => const CoursesScreen()),
          GoRoute(
              path: '/calendar', builder: (_, __) => const CalendarScreen()),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),

          // ── Simulación / Práctica ───────────────────────────────────────
          GoRoute(
            path: '/simulation',
            builder: (_, __) => const PracticeMenuScreen(),
            routes: [
              // Teoría
              GoRoute(
                path: 'theoretical',
                builder: (_, __) => const TheoreticalHubScreen(),
                routes: [
                  GoRoute(
                    path: 'evaluations/:topicId',
                    builder: (_, state) => QuizScreen(
                      topicId: state.pathParameters['topicId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'result/:sessionId',
                    builder: (_, state) => QuizResultScreen(
                      sessionId: state.pathParameters['sessionId']!,
                      result: state.extra as QuizSessionResult?,
                    ),
                  ),
                  GoRoute(
                    path: 'cases',
                    builder: (_, state) => TheoreticalCasesScreen(
                      type: state.uri.queryParameters['type'],
                    ),
                  ),
                  GoRoute(
                    path: 'random',
                    builder: (_, __) => const RandomQuizScreen(),
                  ),
                  GoRoute(
                    path: 'triage',
                    builder: (_, __) => const TriageScreen(),
                  ),
                ],
              ),
              // Práctica con maniquí
              GoRoute(
                path: 'practical',
                builder: (_, __) => const PracticalHubScreen(),
              ),
              GoRoute(
                path: 'practical/session',
                builder: (_, state) => SessionScreen(
                  scenarioId: state.uri.queryParameters['scenario'],
                  courseId: state.uri.queryParameters['courseId'],
                ),
              ),
              GoRoute(
                path: 'practical/session-result/:id',
                builder: (_, state) => SessionResultScreen(
                  sessionId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'practical/scenario-detail/:id',
                builder: (_, state) => ScenarioDetailScreen(
                  scenarioId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'practical/scenario-guide',
                builder: (_, state) => ScenarioGuideScreen(
                  scenarioId: state.uri.queryParameters['scenario'] ?? 'adulto',
                  courseId: state.uri.queryParameters['courseId'],
                ),
              ),
              // Monitor ECG
              GoRoute(
                path: 'ecg',
                builder: (_, __) => const EcgSimulationListScreen(),
              ),
              GoRoute(
                path: 'ecg/:scenarioId',
                builder: (_, state) => EcgMonitorScreen(
                  scenarioId: state.pathParameters['scenarioId']!,
                ),
              ),
              // Triage (legacy — ruta antigua en simulaciones)
              GoRoute(
                path: 'triage',
                builder: (_, __) => const TriageScreen(),
              ),

              // AED Simulator (separada de /simulation para evitar conflictos de ruta)
              GoRoute(
                  path: 'aed-simulator',
                  builder: (_, __) => const AedSimulatorScreen()),
              // Vía Aérea Simulator
              GoRoute(
                  path: 'airway-simulator',
                  builder: (_, __) => const AirwaySimulatorScreen()),
              // RCP Avanzada (ACLS) Simulator
              GoRoute(
                  path: 'acls-simulator',
                  builder: (_, __) => const AclsSimulatorScreen()),
              // Trauma Prehospitalario Simulator
              GoRoute(
                  path: 'trauma-simulator',
                  builder: (_, __) => const TraumaSimulatorScreen()),
            ],
          ),

          // Alias legacy
          GoRoute(
              path: '/scenarios',
              builder: (_, __) => const ScenarioSelectScreen()),

          // ── Skill Passport (S2/S4) ───────────────────────────────────────
          GoRoute(
              path: '/skills', builder: (_, __) => const SkillWalletScreen()),
          GoRoute(path: '/badges', builder: (_, __) => const BadgesScreen()),
          GoRoute(
              path: '/learning-paths',
              builder: (_, __) => const LearningPathsScreen()),
          GoRoute(path: '/ranking', builder: (_, __) => const RankingScreen()),

          // ── Perfil ───────────────────────────────────────────────────────
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(
              path: '/profile/edit',
              builder: (_, __) => const EditProfileScreen()),
          GoRoute(
              path: '/profile/certificados',
              builder: (_, __) => const CertificatesScreen()),

          // ── Analytics ───────────────────────────────────────────────────
          GoRoute(
              path: '/analytics',
              builder: (_, __) => const AnalyticsDashboardScreen()),
          GoRoute(
              path: '/notifications',
              builder: (_, __) => const NotificationsScreen()),

          // ── Instructor ───────────────────────────────────────────────────
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

          // ── Cursos ───────────────────────────────────────────────────────
          GoRoute(
            path: '/course-editor/:courseId',
            builder: (_, state) => CourseEditorScreen(
              courseId: state.pathParameters['courseId']!,
            ),
          ),
          GoRoute(
            path: '/courses/:id',
            builder: (_, state) => CourseDetailScreen(
              courseId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/course-detail/:courseId',
            builder: (_, state) => CourseDetailScreen(
              courseId: state.pathParameters['courseId']!,
            ),
          ),
          GoRoute(
            path: '/student/course-detail',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return StudentCourseDetailScreen(
                courseId: extra?['courseId'] ?? '',
                studentId: extra?['studentId'],
                courseTitle: extra?['courseTitle'],
                instructorName: extra?['instructorName'],
              );
            },
          ),
          GoRoute(
            path: '/student/course-modules/:courseId',
            builder: (_, state) => StudentCourseModulesScreen(
              courseId: state.pathParameters['courseId']!,
            ),
          ),
          GoRoute(
            path: '/student/module-viewer',
            builder: (_, state) {
              // SECURITY (MED-09): hard cast crashes on deep link / state restore.
              final extra = state.extra as Map<String, dynamic>?;
              final module = _moduleFromExtra(extra?['module']);
              if (extra == null || module == null) return const HomeScreen();
              return StudentModuleViewerScreen(
                module: module,
                courseId: extra['courseId'] as String,
                studentId: extra['studentId'] as String,
                isCompleted: extra['isCompleted'] as bool? ?? false,
              );
            },
          ),
          GoRoute(
            path: '/student/practica',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final module = _moduleFromExtra(extra?['module']);
              if (extra == null || module == null) return const HomeScreen();
              return ModulePracticaScreen(
                module: module,
                courseId: extra['courseId'] as String,
              );
            },
          ),
          GoRoute(
            path: '/student/quiz',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final module = _moduleFromExtra(extra?['module']);
              if (extra == null || module == null) return const HomeScreen();
              return ModuleQuizScreen(
                module: module,
                courseId: extra['courseId'] as String,
                studentId: extra['studentId'] as String,
              );
            },
          ),
          // Ruta /student/certificacion retirada (S6.2 — certificados Tipo A → Skills).

          // ── Guías ────────────────────────────────────────────────────────
          GoRoute(
            path: '/courses/:courseId/guides',
            builder: (context, state) {
              // SECURITY (HIGH-04): canEdit must be derived from the user's
              // role, never from a URL query parameter that any user can craft.
              final orgCtx = ref.read(orgContextProvider);
              return GuideListScreen(
                courseId: state.pathParameters['courseId']!,
                canEdit: orgCtx.isAdmin || orgCtx.isInstructor,
              );
            },
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
                    body: Center(child: Text('Guía no encontrada')));
              }
              return GuidePDFViewerScreen(guide: guide);
            },
          ),

          // ── Dispositivos ─────────────────────────────────────────────────
          GoRoute(
              path: '/session/device-select',
              builder: (_, __) => const DeviceSelectionScreen()),

          // ── Live instructor ───────────────────────────────────────────────
          GoRoute(
            path: '/live/:courseId',
            builder: (_, state) => LiveInstructorScreen(
              courseId: state.pathParameters['courseId']!,
            ),
          ),

          // ── Instructor apply (USUARIO → independiente) ───────────────────
          GoRoute(
              path: '/instructor-apply',
              builder: (_, __) => const InstructorApplyScreen()),

          // ── Admin ─────────────────────────────────────────────────────────
          GoRoute(
              path: '/admin/users',
              builder: (_, __) => const ManageUsersScreen()),
          GoRoute(
              path: '/admin/devices',
              builder: (_, __) => const DeviceStatusScreen()),
          GoRoute(
              path: '/admin/create-user',
              builder: (_, __) => const CreateUserScreen()),
          GoRoute(
            path: '/admin/users/:id',
            builder: (_, state) => UserDetailScreen(
              userId: state.pathParameters['id']!,
            ),
          ),
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
            Text('Ruta match: ${state.matchedLocation}',
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    ),
  );
});

// ── Listenable que reacciona a auth + cambios de org ─────────────────────────

class _AppListenable extends ChangeNotifier {
  _AppListenable(Ref ref) {
    _authSub = ref.listen(authStateProvider, (_, __) => notifyListeners());
    _splashSub = ref.listen(_splashGateProvider, (_, __) => notifyListeners());
    _orgSub = ref.listen(orgContextProvider, (prev, next) {
      // Solo notificar si cambia hasOrg o el activeOrgId (no en isLoading)
      if (prev?.hasOrg != next.hasOrg ||
          prev?.activeOrgId != next.activeOrgId) {
        notifyListeners();
      }
    });
  }

  late final ProviderSubscription _authSub;
  late final ProviderSubscription _orgSub;
  late final ProviderSubscription _splashSub;

  @override
  void dispose() {
    _authSub.close();
    _orgSub.close();
    _splashSub.close();
    super.dispose();
  }
}
