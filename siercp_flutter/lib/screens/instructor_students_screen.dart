import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../services/firestore_service.dart';
import '../models/user.dart';

final instructorStudentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  
  final courses = await ref.read(firestoreServiceProvider).getInstructorCourses(user.id);
  final courseIds = courses.map((c) => c.id).toList();
  
  return ref.read(firestoreServiceProvider).getInstructorStudents(courseIds);
});

class InstructorStudentsScreen extends ConsumerStatefulWidget {
  const InstructorStudentsScreen({super.key});

  @override
  ConsumerState<InstructorStudentsScreen> createState() => _InstructorStudentsScreenState();
}

class _InstructorStudentsScreenState extends ConsumerState<InstructorStudentsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(instructorStudentsProvider);
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final surface = theme.colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Estudiantes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(color: textP, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, correo o identificación...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                ),
              ),
            ),
          ),

          Expanded(
            child: studentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (students) {
                final filtered = students.where((s) {
                  final name = (s['studentName'] ?? '').toString().toLowerCase();
                  final email = (s['studentEmail'] ?? '').toString().toLowerCase();
                  final id = (s['studentId'] ?? '').toString().toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  return name.contains(query) || email.contains(query) || id.contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_outlined, size: 64, color: textS.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text(_searchQuery.isEmpty ? 'No tienes estudiantes inscritos' : 'No se encontraron resultados', 
                          style: TextStyle(color: textS)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final st = filtered[i];
                    return _StudentTile(student: st);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentTile extends ConsumerWidget {
  final Map<String, dynamic> student;
  const _StudentTile({required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sid = student['studentId'] as String;
    final statusAsync = ref.watch(usersStatusProvider([sid]));
    final userStatus = statusAsync.valueOrNull?.first;
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    final name = student['studentName'] as String? ?? 'Usuario';
    final email = student['studentEmail'] as String? ?? '';
    final initials = name.isNotEmpty ? name.split(' ').map((e) => e[0]).take(2).join().toUpperCase() : 'U';

    final isOnline = userStatus?.isOnline ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border.withValues(alpha: 0.3)),
        boxShadow: isDark ? null : AppShadows.card(false),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.brand.withValues(alpha: 0.1),
            child: Text(initials, style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: textP, fontWeight: FontWeight.bold)),
                Text(email, style: TextStyle(color: textS, fontSize: 12)),
              ],
            ),
          ),
          if (isOnline)
            const Badge(
              backgroundColor: AppColors.green,
              label: Text('En línea', style: TextStyle(fontSize: 8)),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final sid = student['studentId'] as String;
              context.push('/instructor/students/$sid');
            },
          ),
        ],
      ),
    );
  }
}
