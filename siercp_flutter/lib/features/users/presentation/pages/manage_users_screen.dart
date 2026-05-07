import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/users/data/models/user.dart';
import 'package:siercp/core/services/bulk_upload_service.dart';
import 'package:siercp/features/auth/data/firebase_auth_service.dart';
import 'package:siercp/core/services/firestore_service.dart';
import 'package:siercp/features/users/data/admin_service.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';

class ManageUsersScreen extends ConsumerStatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  ConsumerState<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends ConsumerState<ManageUsersScreen> {
  String _selectedFilter = 'TODOS';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  bool _isImporting = false;

  static const _filters = ['TODOS', 'ADMIN', 'INSTRUCTOR', 'ESTUDIANTE'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleCsvImport() async {
    setState(() => _isImporting = true);
    try {
      final bulkService = BulkUploadService(
        ref.read(firestoreServiceProvider),
        ref.read(firebaseAuthServiceProvider),
      );
      
      final result = await bulkService.uploadStudentsFromCsv();
      
      if (!mounted) return;

      if (result['success'] == true) {
        ref.invalidate(allUsersProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: AppColors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final border = theme.colorScheme.outline;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text('Directorio de Usuarios'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          if (_isImporting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.upload_file_outlined),
              onPressed: _handleCsvImport,
              tooltip: 'Importar Estudiantes (CSV)',
            ),
          IconButton(
            icon: Icon(Icons.refresh_outlined, color: textP),
            onPressed: () => ref.invalidate(allUsersProvider),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton: _buildFab(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, correo o cédula…',
                prefixIcon: const Icon(Icons.search_outlined),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Role filter chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _filters.length,
              itemBuilder: (_, i) {
                final f = _filters[i];
                final selected = _selectedFilter == f;
                return FilterChip(
                  label: Text(f == 'TODOS' ? 'Todos' : _roleLabel(f)),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedFilter = f),
                  selectedColor: AppColors.brand.withValues(alpha: 0.18),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.brand : textS,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: selected ? AppColors.brand : border,
                    width: selected ? 1.5 : 0.5,
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // User list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(allUsersProvider),
              color: AppColors.brand,
              child: usersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_outlined, color: textS, size: 40),
                      const SizedBox(height: 12),
                      Text('Error al cargar usuarios', style: TextStyle(color: textP, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(e.toString(), style: TextStyle(color: textS, fontSize: 11)),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                        onPressed: () => ref.invalidate(allUsersProvider),
                      ),
                    ],
                  ),
                ),
                data: (users) {
                  final filtered = users.where((u) {
                    final matchRole = _selectedFilter == 'TODOS' || u.role == _selectedFilter;
                    final q = _searchQuery;
                    final matchSearch = q.isEmpty ||
                        u.fullName.toLowerCase().contains(q) ||
                        u.email.toLowerCase().contains(q) ||
                        (u.identificacion ?? '').contains(q);
                    return matchRole && matchSearch;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search_outlined, size: 48, color: textS.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('Sin resultados', style: TextStyle(color: textP, fontWeight: FontWeight.w500)),
                          Text('Prueba con otra búsqueda o filtro', style: TextStyle(color: textS, fontSize: 12)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final u = filtered[i];
                      return _UserCard(
                        user: u,
                        isDark: isDark,
                        onTap: () => context.push('/admin/users/${u.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildFab(BuildContext context) {
    final user = ref.watch(authStateProvider).value?.user;
    if (user == null || !user.isAdmin) return null;
    return FloatingActionButton.extended(
      onPressed: () => context.push('/admin/create-user'),
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('Crear usuario', style: TextStyle(fontWeight: FontWeight.w700)),
      elevation: 4,
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'ADMIN': return 'Admin';
      case 'INSTRUCTOR': return 'Instructores';
      case 'ESTUDIANTE': return 'Estudiantes';
      default: return role;
    }
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final bool isDark;
  final VoidCallback onTap;
  const _UserCard({required this.user, required this.isDark, required this.onTap});

  Color get _roleColor {
    switch (user.role) {
      case 'ADMIN': return AppColors.amber;
      case 'INSTRUCTOR': return AppColors.accent;
      default: return AppColors.cyan;
    }
  }

  IconData get _roleIcon {
    switch (user.role) {
      case 'ADMIN': return Icons.admin_panel_settings_outlined;
      case 'INSTRUCTOR': return Icons.school_outlined;
      default: return Icons.person_outline;
    }
  }

  String _formatLastActive(DateTime? date) {
    if (date == null) return 'Nunca';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Hace poco';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays == 1) return 'Ayer';
    return 'Hace ${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: border, width: 0.5),
            boxShadow: isDark ? null : AppShadows.card(false),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _roleColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    user.initials,
                    style: TextStyle(
                      color: _roleColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName.isEmpty ? user.email : user.fullName,
                      style: TextStyle(
                        color: textP,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: user.isOnline ? AppColors.green : AppColors.darkTextTertiary.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          user.isOnline ? 'En línea' : _formatLastActive(user.lastActive),
                          style: TextStyle(color: textS, fontSize: 10, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    if (user.identificacion != null && user.identificacion!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 10, color: textS),
                          const SizedBox(width: 4),
                          Text(user.identificacion!, style: TextStyle(color: textS, fontSize: 10)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Role badge + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _roleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_roleIcon, size: 10, color: _roleColor),
                        const SizedBox(width: 4),
                        Text(
                          user.role,
                          style: TextStyle(
                            color: _roleColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(Icons.chevron_right, size: 16, color: textS),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}



