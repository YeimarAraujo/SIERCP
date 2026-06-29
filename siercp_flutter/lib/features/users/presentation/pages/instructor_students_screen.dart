import 'package:flutter/material.dart';
import 'package:siercp/core/widgets/app_logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/core/services/firestore_service.dart';
import 'package:siercp/core/services/rtdb_service.dart';
import 'package:siercp/core/providers/org_context_provider.dart';
import 'package:siercp/features/courses/data/models/alert_course.dart';

class _LiveSessionWithCourse {
  final LiveSessionRtdb session;
  final CourseModel course;
  const _LiveSessionWithCourse({required this.session, required this.course});
}

final _instructorCoursesForLiveProvider =
    FutureProvider.family<List<CourseModel>, String>((ref, institutionId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final db = ref.read(firestoreServiceProvider);
  final allCourses = await db.getCoursesByInstitution(institutionId);
  return allCourses.where((c) => c.isInstructorOf(user.id)).toList();
});

final instructorLiveSessionsProvider =
    StreamProvider<List<_LiveSessionWithCourse>>((ref) {
  final user = ref.watch(currentUserProvider);
  final orgCtx = ref.watch(orgContextProvider);
  final institutionId = orgCtx.activeOrgId ?? user?.institutionId ?? '';
  if (institutionId.isEmpty) return Stream.value([]);

  final coursesAsync =
      ref.watch(_instructorCoursesForLiveProvider(institutionId));
  final courses = coursesAsync.valueOrNull ?? [];
  final courseIds = courses.map((c) => c.id).toSet();
  if (courseIds.isEmpty) return Stream.value([]);

  final rtdbService = ref.watch(rtdbServiceProvider);
  return rtdbService
      .watchInstitutionLiveSessions(institutionId)
      .map((sessions) {
    return sessions
        .where((s) => courseIds.contains(s.courseId))
        .map((s) => _LiveSessionWithCourse(
              session: s,
              course: courses.firstWhere((c) => c.id == s.courseId),
            ))
        .toList();
  });
});

class InstructorStudentsScreen extends ConsumerWidget {
  const InstructorStudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(instructorLiveSessionsProvider);
    final theme = Theme.of(context);
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesiones en Vivo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: sessionsAsync.when(
        loading: () => const AppLogoLoader(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.live_tv_outlined,
                      size: 64, color: textS.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('No hay sesiones activas en este momento',
                      style: TextStyle(color: textS)),
                ],
              ),
            );
          }

          final Map<String, List<_LiveSessionWithCourse>> grouped = {};
          for (final item in sessions) {
            grouped.putIfAbsent(item.course.title, () => []);
            grouped[item.course.title]!.add(item);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.map((entry) {
              return _CourseSessionGroup(
                courseId: entry.value.first.course.id,
                courseTitle: entry.key,
                sessions: entry.value,
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _CourseSessionGroup extends StatelessWidget {
  final String courseId;
  final String courseTitle;
  final List<_LiveSessionWithCourse> sessions;

  const _CourseSessionGroup({
    required this.courseId,
    required this.courseTitle,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/courses/$courseId'),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_book,
                      size: 20, color: AppColors.brand),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(courseTitle,
                      style: TextStyle(
                          color: textP,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                      '${sessions.length} activa${sessions.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: textS.withValues(alpha: 0.5)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...sessions.map((item) => _SessionTile(
                session: item.session,
                courseId: item.course.id,
              )),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final LiveSessionRtdb session;
  final String courseId;

  const _SessionTile({required this.session, required this.courseId});

  String _timeAgo(int startedAt) {
    final diff = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(startedAt));
    if (diff.inMinutes < 1) return 'Justo ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    return 'Hace ${diff.inHours}h ${diff.inMinutes % 60}min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.green.withValues(alpha: 0.15),
              child: const Icon(Icons.person, color: AppColors.green, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.studentName,
                      style: TextStyle(
                          color: textP,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(session.scenarioTitle,
                      style: TextStyle(color: textS, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(_timeAgo(session.startedAt),
                          style: TextStyle(color: textS, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.visibility_outlined,
                    size: 18, color: AppColors.brand),
              ),
              onPressed: () => context.push('/live/$courseId'),
            ),
          ],
        ),
      ),
    );
  }
}
