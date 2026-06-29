import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';

final isDemoProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.isAnonymous ?? false;
});

class DemoGuard extends ConsumerWidget {
  final Widget child;
  final String featureName;

  const DemoGuard({super.key, required this.child, required this.featureName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(isDemoProvider);
    if (!isDemo) return child;
    return _DemoLockedPage(featureName: featureName);
  }
}

class _DemoLockedPage extends StatelessWidget {
  final String featureName;
  const _DemoLockedPage({required this.featureName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 72, color: AppColors.accent.withValues(alpha: 0.5)),
              const SizedBox(height: 24),
              Text(
                featureName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Crea una cuenta o inicia sesión para acceder a esta función.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.person_add),
                label: const Text('Registrarse / Iniciar Sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
