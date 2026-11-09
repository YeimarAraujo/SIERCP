import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/core/providers/org_context_provider.dart';
import 'package:siercp/core/services/bulk_upload_service.dart';
import 'package:siercp/core/services/firestore_service.dart';
import 'package:siercp/core/services/tenant_service.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/auth/data/firebase_auth_service.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/users/data/admin_service.dart';

class ManageUsersScreen extends ConsumerStatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  ConsumerState<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends ConsumerState<ManageUsersScreen>
    with SingleTickerProviderStateMixin {
  String _selectedRole = 'TODOS';
  String _searchQuery = '';
  bool _isImporting = false;
  final _searchCtrl = TextEditingController();
  late final AnimationController _fadeCtrl;

  static const _roleFilters = [
    ('TODOS', 'Todos', Icons.groups_outlined),
    (AppConstants.roleAdmin, 'Admins', Icons.admin_panel_settings_outlined),
    (AppConstants.roleInstructor, 'Instructores', Icons.school_outlined),
    (AppConstants.roleUsuarioSST, 'SST', Icons.health_and_safety_outlined),
    (
      AppConstants.roleUsuarioProfesional,
      'Profesionales',
      Icons.badge_outlined
    ),
    (AppConstants.roleUsuario, 'Usuarios', Icons.person_outline),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleCsvImport() async {
    setState(() => _isImporting = true);
    try {
      final result = await BulkUploadService(
        ref.read(firestoreServiceProvider),
        ref.read(firebaseAuthServiceProvider),
      ).uploadStudentsFromCsv();
      if (!mounted) return;
      ref.invalidate(orgUsersProvider);
      _showSnack(result['message'] as String,
          isError: result['success'] != true);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.red : AppColors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final orgCtx = ref.watch(orgContextProvider);
    final currentUser = ref.watch(currentUserProvider);
    final membersAsync = ref.watch(orgUsersProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeCtrl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OrgHeader(
                orgName: orgCtx.activeOrgName ?? 'Mi Organización',
                isDark: isDark,
                isImporting: _isImporting,
                onImport:
                    currentUser?.isAdmin == true ? _handleCsvImport : null,
                onRefresh: () => ref.invalidate(orgUsersProvider),
                onBack: () => context.go('/home'),
              ),
              _SearchAndFilters(
                searchCtrl: _searchCtrl,
                searchQuery: _searchQuery,
                selectedRole: _selectedRole,
                roleFilters: _roleFilters,
                membersAsync: membersAsync,
                onSearchChange: (v) =>
                    setState(() => _searchQuery = v.toLowerCase()),
                onRoleChange: (r) => setState(() => _selectedRole = r),
                isDark: isDark,
              ),
              Expanded(
                child: membersAsync.when(
                  loading: () => const _MembersLoadingSkeleton(),
                  error: (e, _) => _ErrorState(
                    error: e.toString(),
                    onRetry: () => ref.invalidate(orgUsersProvider),
                  ),
                  data: (members) {
                    final filtered = _applyFilters(members);
                    if (filtered.isEmpty) {
                      return _EmptyState(
                        hasFilters:
                            _selectedRole != 'TODOS' || _searchQuery.isNotEmpty,
                        onInvite: currentUser?.isAdmin == true
                            ? () => context.push('/admin/create-user')
                            : null,
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async => ref.invalidate(orgUsersProvider),
                      color: AppColors.brand,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _MemberCard(
                          member: filtered[i],
                          isDark: isDark,
                          canEdit: currentUser?.isAdmin == true,
                          onTap: () => context.push(
                            '/admin/users/${filtered[i].user.id}',
                          ),
                          onRoleChange: (newRole) => _handleRoleChange(
                            filtered[i],
                            newRole,
                            currentUser?.id ?? '',
                          ),
                          onRemove: () => _handleRemove(
                            filtered[i],
                            currentUser?.id ?? '',
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: currentUser?.isAdmin == true
          ? _InviteFab(onTap: () => context.push('/admin/create-user'))
          : null,
    );
  }

  List<OrgMember> _applyFilters(List<OrgMember> members) {
    return members.where((m) {
      final matchRole = _selectedRole == 'TODOS' || m.role == _selectedRole;
      final q = _searchQuery;
      final matchSearch = q.isEmpty ||
          m.user.fullName.toLowerCase().contains(q) ||
          m.user.email.toLowerCase().contains(q) ||
          (m.user.identificacion ?? '').contains(q);
      return matchRole && matchSearch;
    }).toList();
  }

  Future<void> _handleRoleChange(
    OrgMember member,
    String newRole,
    String adminId,
  ) async {
    try {
      await ref.read(adminServiceProvider).changeUserRole(
            member.membershipId,
            newRole,
            adminId,
          );
      ref.invalidate(orgUsersProvider);
      _showSnack('Rol actualizado correctamente');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _handleRemove(OrgMember member, String adminId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmRemoveDialog(userName: member.user.fullName),
    );
    if (confirm != true) return;
    try {
      await ref
          .read(adminServiceProvider)
          .removeFromOrg(member.user.id, adminId);
      _showSnack('${member.user.firstName} eliminado de la organización');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }
}

// ── Header con info de la org ─────────────────────────────────────────────────

class _OrgHeader extends StatelessWidget {
  final String orgName;
  final bool isDark;
  final bool isImporting;
  final VoidCallback? onImport;
  final VoidCallback onRefresh;
  final VoidCallback onBack;

  const _OrgHeader({
    required this.orgName,
    required this.isDark,
    required this.isImporting,
    required this.onImport,
    required this.onRefresh,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg2 : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Icon(Icons.arrow_back_ios_new, size: 20, color: textP),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Directorio',
                  style: TextStyle(
                    color: textP,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  orgName,
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isImporting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.brand),
            )
          else if (onImport != null)
            IconButton(
              icon: Icon(Icons.upload_file_outlined, color: textS),
              onPressed: onImport,
              tooltip: 'Importar CSV',
            ),
          IconButton(
            icon: Icon(Icons.refresh_outlined, color: textS),
            onPressed: onRefresh,
            tooltip: 'Actualizar',
          ),
        ],
      ),
    );
  }
}

// ── Barra de búsqueda + filtros ───────────────────────────────────────────────

class _SearchAndFilters extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String searchQuery;
  final String selectedRole;
  final List<(String, String, IconData)> roleFilters;
  final AsyncValue<List<OrgMember>> membersAsync;
  final ValueChanged<String> onSearchChange;
  final ValueChanged<String> onRoleChange;
  final bool isDark;

  const _SearchAndFilters({
    required this.searchCtrl,
    required this.searchQuery,
    required this.selectedRole,
    required this.roleFilters,
    required this.membersAsync,
    required this.onSearchChange,
    required this.onRoleChange,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final border = theme.colorScheme.outline;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearchChange,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, correo o cédula…',
              prefixIcon: const Icon(Icons.search_outlined, size: 20),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        searchCtrl.clear();
                        onSearchChange('');
                      },
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemCount: roleFilters.length,
            itemBuilder: (_, i) {
              final (role, label, icon) = roleFilters[i];
              final selected = selectedRole == role;
              final count = role == 'TODOS'
                  ? membersAsync.valueOrNull?.length
                  : membersAsync.valueOrNull
                      ?.where((m) => m.role == role)
                      .length;

              return _FilterChip(
                label: label,
                icon: icon,
                count: count,
                selected: selected,
                border: border,
                textS: textS,
                onTap: () => onRoleChange(role),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final int? count;
  final bool selected;
  final Color border;
  final Color textS;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.border,
    required this.textS,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brand.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.brand : border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: selected ? AppColors.brand : textS,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.brand : textS,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.brand.withValues(alpha: 0.2)
                      : border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? AppColors.brand : textS,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Card de miembro ───────────────────────────────────────────────────────────

class _MemberCard extends StatelessWidget {
  final OrgMember member;
  final bool isDark;
  final bool canEdit;
  final VoidCallback onTap;
  final ValueChanged<String> onRoleChange;
  final VoidCallback onRemove;

  const _MemberCard({
    required this.member,
    required this.isDark,
    required this.canEdit,
    required this.onTap,
    required this.onRoleChange,
    required this.onRemove,
  });

  Color get _roleColor => switch (member.role) {
        AppConstants.roleSuperAdmin => AppColors.amber,
        AppConstants.roleAdmin => AppColors.orange,
        AppConstants.roleInstructor => AppColors.accent,
        AppConstants.roleUsuarioSST => AppColors.green,
        AppConstants.roleUsuarioProfesional => AppColors.cyan,
        _ => AppColors.brand2,
      };

  IconData get _roleIcon => switch (member.role) {
        AppConstants.roleSuperAdmin => Icons.shield_outlined,
        AppConstants.roleAdmin => Icons.admin_panel_settings_outlined,
        AppConstants.roleInstructor => Icons.school_outlined,
        AppConstants.roleUsuarioSST => Icons.health_and_safety_outlined,
        _ => Icons.person_outline,
      };

  String get _roleLabel => switch (member.role) {
        AppConstants.roleSuperAdmin => 'Super Admin',
        AppConstants.roleAdmin => 'Admin',
        AppConstants.roleInstructor => 'Instructor',
        AppConstants.roleUsuarioSST => 'Usuario SST',
        AppConstants.roleUsuarioProfesional => 'Profesional',
        _ => 'Usuario',
      };

  String _formatLastActive(DateTime? date) {
    if (date == null) return 'Nunca';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Ahora';
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
    final u = member.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
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
                // ── Avatar con estado online ───────────────────
                Stack(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _roleColor.withValues(alpha: 0.25),
                            _roleColor.withValues(alpha: 0.10),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          u.initials,
                          style: TextStyle(
                            color: _roleColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    if (u.isOnline)
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: surface,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // ── Info del usuario ───────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.fullName.isEmpty ? u.email : u.fullName,
                        style: TextStyle(
                          color: textP,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        u.email,
                        style: TextStyle(color: textS, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (u.identificacion != null &&
                          u.identificacion!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.badge_outlined, size: 10, color: textS),
                            const SizedBox(width: 3),
                            Text(
                              u.identificacion!,
                              style: TextStyle(color: textS, fontSize: 10),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.access_time, size: 10, color: textS),
                            const SizedBox(width: 3),
                            Text(
                              _formatLastActive(u.lastActive),
                              style: TextStyle(color: textS, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Badge de rol + menú ────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _roleColor.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_roleIcon, size: 10, color: _roleColor),
                          const SizedBox(width: 4),
                          Text(
                            _roleLabel,
                            style: TextStyle(
                              color: _roleColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canEdit) ...[
                      const SizedBox(height: 6),
                      _MemberMenu(
                        currentRole: member.role,
                        onRoleChange: onRoleChange,
                        onRemove: onRemove,
                      ),
                    ] else
                      const SizedBox(height: 6),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Menú de acciones por miembro ──────────────────────────────────────────────

class _MemberMenu extends StatelessWidget {
  final String currentRole;
  final ValueChanged<String> onRoleChange;
  final VoidCallback onRemove;

  const _MemberMenu({
    required this.currentRole,
    required this.onRoleChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      iconSize: 16,
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.more_horiz,
        size: 16,
        color: Theme.of(context).textTheme.bodySmall?.color,
      ),
      itemBuilder: (_) => [
        ...AppConstants.assignableRoles.where((r) => r != currentRole).map(
              (r) => PopupMenuItem(
                value: 'role:$r',
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz_outlined, size: 14),
                    const SizedBox(width: 8),
                    Text('Cambiar a ${_roleLabel(r)}',
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.person_remove_outlined,
                  size: 14, color: AppColors.red),
              SizedBox(width: 8),
              Text('Quitar de la org',
                  style: TextStyle(color: AppColors.red, fontSize: 13)),
            ],
          ),
        ),
      ],
      onSelected: (v) {
        if (v == 'remove') {
          onRemove();
        } else if (v.startsWith('role:')) {
          onRoleChange(v.substring(5));
        }
      },
    );
  }

  String _roleLabel(String role) => switch (role) {
        AppConstants.roleAdmin => 'Admin',
        AppConstants.roleInstructor => 'Instructor',
        AppConstants.roleUsuarioSST => 'Usuario SST',
        AppConstants.roleUsuarioProfesional => 'Profesional',
        _ => 'Usuario',
      };
}

// ── Estado vacío ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback? onInvite;

  const _EmptyState({required this.hasFilters, this.onInvite});

  @override
  Widget build(BuildContext context) {
    final textP =
        Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = Theme.of(context).textTheme.bodyMedium?.color ??
        AppColors.textSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters
                    ? Icons.filter_list_off_outlined
                    : Icons.people_outline,
                size: 40,
                color: AppColors.brand.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'Sin resultados'
                  : 'Esta organización no tiene miembros aún',
              style: TextStyle(
                color: textP,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Prueba con otra búsqueda o limpia los filtros.'
                  : 'Invita a tu equipo para empezar.',
              style: TextStyle(color: textS, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (onInvite != null && !hasFilters) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onInvite,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Invitar primer miembro'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 44),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _MembersLoadingSkeleton extends StatelessWidget {
  const _MembersLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerBase = isDark ? AppColors.darkBg2 : AppColors.lightBg2;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 6,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          height: 78,
          decoration: BoxDecoration(
            color: shimmerBase,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.darkSurface2 : AppColors.lightBorder,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface2
                            : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: 140,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface2
                            : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final textP =
        Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = Theme.of(context).textTheme.bodyMedium?.color ??
        AppColors.textSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_outlined, size: 40, color: textS),
            const SizedBox(height: 12),
            Text('Error al cargar miembros',
                style: TextStyle(
                    color: textP, fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 4),
            Text(error,
                style: TextStyle(color: textS, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 3),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(140, 40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── FAB de invitación ─────────────────────────────────────────────────────────

class _InviteFab extends StatelessWidget {
  final VoidCallback onTap;
  const _InviteFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onTap,
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.person_add_outlined),
      label:
          const Text('Invitar', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// ── Diálogo de confirmación de baja ──────────────────────────────────────────

class _ConfirmRemoveDialog extends StatelessWidget {
  final String userName;
  const _ConfirmRemoveDialog({required this.userName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quitar de la organización'),
      content: Text(
        '¿Estás seguro de quitar a $userName?\n\n'
        'Su cuenta no será eliminada del sistema. '
        'Solo perderá acceso a esta organización.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red, minimumSize: const Size(80, 40)),
          child: const Text('Quitar'),
        ),
      ],
    );
  }
}
