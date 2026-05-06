import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/guide.dart';
import '../providers/guide_provider.dart';
import '../core/theme.dart';

// Categorias de guías
class CategoryFilterChips extends ConsumerWidget {
  const CategoryFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedGuideCategoryProvider);
    final textS = Theme.of(context).textTheme.bodyMedium?.color ??
        AppColors.textSecondary;

    final categories = [null, ...GuideCategory.values];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final isAll = cat == null;
          final active = isAll ? selected == null : selected == cat;

          return FilterChip(
            selected: active,
            label: Text(
              isAll ? 'Todas' : '${cat.emoji} ${cat.label}',
              style: TextStyle(
                fontSize: 11,
                color: active ? Colors.white : textS,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            selectedColor: AppColors.brand,
            backgroundColor: Theme.of(context).colorScheme.surface,
            checkmarkColor: Colors.white,
            side: BorderSide(
              color: active
                  ? AppColors.brand
                  : Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.5),
              width: 0.5,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            onSelected: (_) {
              ref.read(selectedGuideCategoryProvider.notifier).state =
                  isAll ? null : cat;
            },
          );
        },
      ),
    );
  }
}
