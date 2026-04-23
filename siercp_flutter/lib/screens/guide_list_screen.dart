import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/guide.dart';
import '../providers/auth_provider.dart';
import '../providers/guide_provider.dart';
import '../widgets/guide_progress_card.dart';
import '../widgets/guide_list_tile.dart';
import '../widgets/category_filter_chips.dart';
import '../core/theme.dart';

class GuideListScreen extends ConsumerWidget {
  final String courseId;
  final bool canEdit;
  const GuideListScreen({super.key, required this.courseId, this.canEdit = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user           = ref.watch(currentUserProvider);
    final guidesAsync    = ref.watch(courseGuidesProvider(courseId));
    final progressAsync  = ref.watch(userGuideProgressProvider(user?.id ?? ''));
    final selectedCat    = ref.watch(selectedGuideCategoryProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: guidesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (guides) {
          final progressMap = progressAsync.value ?? {};

          // Resumen de progreso
          final required  = guides.where((g) => g.required).length;
          final completed = guides.where((g) => progressMap[g.id]?.completed ?? false).length;
          final reqDone   = guides.where((g) => g.required && (progressMap[g.id]?.completed ?? false)).length;
          final summary   = GuideProgressSummary(
            totalGuides:       guides.length,
            completedGuides:   completed,
            requiredGuides:    required,
            requiredCompleted: reqDone,
          );

          // Filtrar por categoría
          final filtered = selectedCat == null
              ? guides
              : guides.where((g) => g.category == selectedCat).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(courseGuidesProvider(courseId)),
            color: AppColors.brand,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: GuideProgressCard(summary: summary)),
                SliverToBoxAdapter(child: const SizedBox(height: 4)),
                const SliverToBoxAdapter(child: CategoryFilterChips()),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                if (filtered.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_outlined,
                              size: 52,
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          Text(
                            guides.isEmpty
                                ? 'No hay guías en este curso aún'
                                : 'No hay guías en esta categoría',
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                              fontSize: 14,
                            ),
                          ),
                          if (canEdit && guides.isEmpty) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Agregar primera guía'),
                              onPressed: () => context.push('/courses/$courseId/add-guide'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => GuideListTile(
                        guide:    filtered[i],
                        progress: progressMap[filtered[i].id],
                        canManage: canEdit,
                        onTap: () => context.push(
                          '/guides/${filtered[i].id}/view',
                          extra: filtered[i],
                        ),
                      ),
                      childCount: filtered.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/courses/$courseId/add-guide'),
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar guía'),
            )
          : null,
    );
  }
}
