import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/device_provider.dart'; // Added for device status
import '../widgets/section_label.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final realStats = ref.watch(userStatsProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final cardColor = theme.inputDecorationTheme.fillColor ?? AppColors.card;
    final borderColor = theme.dividerTheme.color ?? AppColors.cardBorder;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Header with Edit button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => context.push('/profile/edit'),
                      icon: const Icon(Icons.edit_note_rounded, color: AppColors.brand),
                      tooltip: 'Editar perfil',
                    ),
                  ],
                ),
              ),
              
              // Avatar + info
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.brand, AppColors.brand2],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brand.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            image: user?.avatarUrl != null 
                                ? DecorationImage(image: NetworkImage(user!.avatarUrl!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: user?.avatarUrl == null 
                            ? Center(
                                child: Text(
                                  user?.initials ?? 'A',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800),
                                ),
                              )
                            : null,
                        ),
                        if (user?.isOnline == true)
                          Positioned(
                            bottom: 5,
                            right: 5,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: AppColors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.scaffoldBackgroundColor, width: 3),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      user?.fullName.isNotEmpty == true
                          ? user!.fullName
                          : (user?.isAdmin == true ? 'Administrador' : 'Usuario'),
                      style: TextStyle(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(
                          color: secondaryTextColor, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Badge(
                          label: user?.role ?? 'ESTUDIANTE',
                          color: user?.role == 'ADMIN'
                              ? AppColors.amber
                              : user?.role == 'INSTRUCTOR'
                                  ? AppColors.accent
                                  : AppColors.cyan,
                          bg: (user?.role == 'ADMIN'
                              ? AppColors.amber
                              : user?.role == 'INSTRUCTOR'
                                  ? AppColors.accent
                                  : AppColors.cyan).withValues(alpha: 0.12),
                        ),
                        const SizedBox(width: 8),
                        _Badge(label: 'SIERCP v2.0', color: AppColors.brand, bg: AppColors.brandBg),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats grid (Ocultar para Admin)
              if (user?.isAdmin != true)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Consumer(
                    builder: (context, ref, child) {
                      final isLandscape = MediaQuery.of(context).orientation ==
                          Orientation.landscape;
                      return GridView.count(
                        crossAxisCount: isLandscape ? 4 : 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: isLandscape ? 2.2 : 1.9,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _StatCard(
                              label: 'Sesiones totales',
                              value: '${realStats?.totalSessions ?? 0}',
                              color: textColor,
                              cardColor: cardColor,
                              borderColor: borderColor),
                          _StatCard(
                              label: 'Promedio global',
                              value:
                                  '${(realStats?.averageScore ?? 0).toStringAsFixed(0)}%',
                              color: AppColors.green,
                              cardColor: cardColor,
                              borderColor: borderColor),
                          _StatCard(
                              label: 'Horas práctica',
                              value:
                                  '${(realStats?.totalHours ?? 0).toStringAsFixed(1)}h',
                              color: AppColors.cyan,
                              cardColor: cardColor,
                              borderColor: borderColor),
                          _StatCard(
                              label: 'Racha actual',
                              value: '${realStats?.streakDays ?? 0}d',
                              color: AppColors.amber,
                              cardColor: cardColor,
                              borderColor: borderColor),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),

              // Settings
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SectionLabel('Configuración'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border.all(color: borderColor, width: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _ToggleTile(label: 'Modo Escuro', value: isDark, onChanged: (v) {
                        ref.read(themeModeProvider.notifier).toggleTheme(v);
                      }, textColor: textColor, trackColor: borderColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Admin/Instructor Section: Equipment
              if (user?.isAdmin == true || user?.isInstructor == true) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: SectionLabel('Equipos y Conectividad'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      border: Border.all(color: borderColor, width: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Consumer(builder: (context, ref, child) {
                          final devices = ref.watch(devicesStreamProvider).valueOrNull ?? [];
                          final connectedCount = devices.where((d) => d.status == 'online').length;
                          return _NavTile(
                            label: 'Maniquíes SIERCP',
                            value: connectedCount > 0 ? '$connectedCount conectados' : 'Desconectados',
                            onTap: () => context.push('/admin/devices'),
                            textColor: textColor,
                            secondaryColor: connectedCount > 0 ? AppColors.green : secondaryTextColor,
                            icon: Icons.developer_board,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // About
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SectionLabel('Acerca de'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border.all(color: borderColor, width: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _NavTile(label: 'Versión de la app', value: '2.0.0',
                          textColor: textColor, secondaryColor: secondaryTextColor, onTap: () {}),
                      Divider(color: borderColor, height: 0.5),
                      _NavTile(label: 'Guías AHA 2020', value: '',
                          textColor: textColor, secondaryColor: secondaryTextColor, onTap: () {}),
                      Divider(color: borderColor, height: 0.5),
                      _NavTile(label: 'Política de privacidad', value: '',
                          textColor: textColor, secondaryColor: secondaryTextColor, onTap: () {}),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Logout
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authStateProvider.notifier).logout();
                  },
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Cerrar sesión'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red, width: 0.5),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color, bg;
  const _Badge({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final Color? cardColor;
  final Color? borderColor;
  const _StatCard({required this.label, required this.value, required this.color, this.cardColor, this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: cardColor ?? AppColors.card,
      border: Border.all(color: borderColor ?? AppColors.cardBorder, width: 0.5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary, fontSize: 11)),
      const Spacer(),
      Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'SpaceMono')),
    ]),
  );
}

class _ToggleTile extends StatefulWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? textColor;
  final Color? trackColor;
  const _ToggleTile({required this.label, required this.value, required this.onChanged, this.textColor, this.trackColor});

  @override
  State<_ToggleTile> createState() => _ToggleTileState();
}

class _ToggleTileState extends State<_ToggleTile> {
  late bool _val;

  @override
  void initState() { super.initState(); _val = widget.value; }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.label, style: TextStyle(color: widget.textColor ?? AppColors.textPrimary, fontSize: 13)),
        Switch(
          value: _val,
          onChanged: (v) { setState(() => _val = v); widget.onChanged(v); },
          activeThumbColor: AppColors.brand,
          trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.brand.withValues(alpha: 0.4) : (widget.trackColor ?? AppColors.cardBorder)),
        ),
      ],
    ),
  );
}

class _NavTile extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? secondaryColor;
  final IconData? icon;
  const _NavTile({required this.label, required this.value, required this.onTap, this.textColor, this.secondaryColor, this.icon});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: textColor?.withValues(alpha: 0.7) ?? AppColors.textPrimary.withValues(alpha: 0.7)),
                const SizedBox(width: 12),
              ],
              Text(label, style: TextStyle(color: textColor ?? AppColors.textPrimary, fontSize: 13)),
            ],
          ),
          Row(children: [
            if (value.isNotEmpty)
              Text(value, style: TextStyle(color: secondaryColor ?? AppColors.accent, fontSize: 12)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 12, color: secondaryColor ?? AppColors.textTertiary),
          ]),
        ],
      ),
    ),
  );
}

