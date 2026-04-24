import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../providers/theme_provider.dart';
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
              const SizedBox(height: 24),
              // Avatar + info
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.brand, AppColors.brand2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brand.withValues(alpha: 0.35),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          user?.initials ?? 'A',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      // Si el nombre está vacío (típico del Admin), mostrar 'Administrador'
                      user?.fullName.isNotEmpty == true
                          ? user!.fullName
                          : (user?.isAdmin == true ? 'Administrador' : 'Usuario'),
                      style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(
                          color: secondaryTextColor, fontSize: 12),
                    ),
                    // Mostrar cédula si está disponible
                    if (user?.identificacion != null && (user?.identificacion?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.badge_outlined, size: 12, color: secondaryTextColor),
                          const SizedBox(width: 4),
                          Text(
                            user!.identificacion!,
                            style: TextStyle(color: secondaryTextColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
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
                        const SizedBox(width: 6),
                        _Badge(label: 'SIERCP', color: AppColors.cyan, bg: AppColors.cyanBg),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats grid
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: const SectionLabel('Configuración'),
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
                      Divider(color: borderColor, height: 0.5),
                      _ToggleTile(label: 'Notificaciones de alerta', value: true, onChanged: (_) {}, textColor: textColor, trackColor: borderColor),
                      Divider(color: borderColor, height: 0.5),
                      _NavTile(label: 'Idioma', value: 'Español', onTap: () {}, textColor: textColor, secondaryColor: secondaryTextColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // About
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: const SectionLabel('Acerca de'),
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
  const _NavTile({required this.label, required this.value, required this.onTap, this.textColor, this.secondaryColor});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textColor ?? AppColors.textPrimary, fontSize: 13)),
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

