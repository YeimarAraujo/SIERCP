import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/session/presentation/providers/session_provider.dart';
import 'package:siercp/core/theme/theme_provider.dart';
import 'package:siercp/features/devices/presentation/providers/device_provider.dart';
import 'package:siercp/core/widgets/section_label.dart';
import 'package:siercp/core/widgets/demo_guard.dart';
import 'package:siercp/core/widgets/xp_strip.dart';
import 'package:siercp/l10n/app_localizations.dart';
import 'package:siercp/core/theme/locale_provider.dart';
import 'package:siercp/features/users/data/models/user.dart'
    show CertVerificationStatus;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showLanguageSelector(
      BuildContext context, WidgetRef ref, AppLocalizations loc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(loc.selectLanguage,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                title: const Text('Español'),
                onTap: () {
                  ref
                      .read(localeControllerProvider.notifier)
                      .setLocale(const Locale('es'));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('English'),
                onTap: () {
                  ref
                      .read(localeControllerProvider.notifier)
                      .setLocale(const Locale('en'));
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _translateRole(String role, AppLocalizations loc) {
    switch (role.toUpperCase()) {
      case 'SUPER_ADMIN':
        return 'Super Admin';
      case 'ADMIN':
        return loc.admin;
      case 'INSTRUCTOR':
        return loc.instructor;
      case 'USUARIO_SST':
        return 'Usuario SST';
      case 'USUARIO_PROFESIONAL':
        return 'Profesional';
      default:
        return 'Usuario';
    }
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final loc = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(loc.privacyPolicyTitle,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Text(
              loc.privacyPolicyContent,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.closeButton),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDemoProfile(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline,
                  size: 72, color: AppColors.accent.withValues(alpha: 0.5)),
              const SizedBox(height: 24),
              Text('Modo Demo',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: theme.textTheme.bodyLarge?.color)),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () async {
                  await ref.read(authStateProvider.notifier).logout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Salir modo demo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(isDemoProvider);
    if (isDemo) {
      return _buildDemoProfile(context, ref);
    }

    final user = ref.watch(currentUserProvider);
    final realStats = ref.watch(userStatsProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final loc = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeControllerProvider);
    final accentColor = AppColors.accent;

    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final cardColor = theme.inputDecorationTheme.fillColor ?? AppColors.card;
    final borderColor = theme.dividerTheme.color ?? AppColors.cardBorder;
    final secondaryTextColor =
        theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

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
                      icon: Icon(Icons.edit_note_rounded,
                          size: 30, color: accentColor),
                      tooltip: loc.editProfile,
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
                            color: AppColors.brand,
                            shape: BoxShape.circle,
                            image: user?.avatarUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(user!.avatarUrl!),
                                    fit: BoxFit.cover)
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
                                border: Border.all(
                                    color: theme.scaffoldBackgroundColor,
                                    width: 3),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      user?.fullName.isNotEmpty == true
                          ? user!.fullName
                          : (user?.isAdmin == true ? loc.admin : loc.user),
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
                          color: secondaryTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((user?.isAdmin ?? false) ||
                            (user?.isInstructor ?? false))
                          _Badge(
                            label: _translateRole(user?.role ?? 'USUARIO', loc),
                            color: (user?.isAdmin ?? false)
                                ? AppColors.amber
                                : AppColors.accent,
                            bg: ((user?.isAdmin ?? false)
                                    ? AppColors.amber
                                    : AppColors.accent)
                                .withValues(alpha: 0.12),
                          ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // XP / nivel
              if (user?.isAdmin != true) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: XpStrip(),
                ),
                const SizedBox(height: 16),
              ],

              // Certificates (visible to all users)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                //child: SectionLabel('Certificados'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border.all(color: borderColor, width: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _NavTile(
                    label: 'Certificados Profesionales',
                    value: user?.certVerification ==
                            CertVerificationStatus.approved
                        ? 'Verificado'
                        : user?.certVerification ==
                                CertVerificationStatus.pending
                            ? 'En revisión'
                            : 'Subir',
                    textColor: textColor,
                    secondaryColor: secondaryTextColor,
                    onTap: () => context.push('/profile/certificados'),
                    icon: Icons.workspace_premium_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border.all(color: borderColor, width: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _NavTile(
                    label: 'Competencias',
                    value: '',
                    textColor: textColor,
                    secondaryColor: secondaryTextColor,
                    onTap: () => context.push('/skills'),
                    icon: Icons.workspace_premium_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border.all(color: borderColor, width: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _NavTile(
                    label: 'Calendario',
                    value: '',
                    textColor: textColor,
                    secondaryColor: secondaryTextColor,
                    onTap: () => context.push('/calendar'),
                    icon: Icons.calendar_month_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border.all(color: borderColor, width: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _NavTile(
                    label: 'Historial',
                    value: '',
                    textColor: textColor,
                    secondaryColor: secondaryTextColor,
                    onTap: () => context.go('/history'),
                    icon: Icons.history,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Settings
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SectionLabel(loc.settings),
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
                      _ToggleTile(
                          label: loc.darkMode,
                          value: isDark,
                          onChanged: (v) {
                            ref.read(themeModeProvider.notifier).toggleTheme(v);
                          },
                          textColor: textColor,
                          trackColor: borderColor),
                      Divider(color: borderColor, height: 0.5),
                      _ToggleTile(
                          label: loc.alerts,
                          value: true,
                          onChanged: (_) {},
                          textColor: textColor,
                          trackColor: borderColor),
                      Divider(color: borderColor, height: 0.5),
                      _NavTile(
                          label: loc.language,
                          value: currentLocale.languageCode == 'en'
                              ? 'English'
                              : 'Español',
                          onTap: () => _showLanguageSelector(context, ref, loc),
                          textColor: textColor,
                          secondaryColor: secondaryTextColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Admin/Instructor Section: Equipment
              if (user?.isAdmin == true || user?.isInstructor == true) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: SectionLabel(loc.equipmentSectionTitle),
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
                          final devices =
                              ref.watch(devicesStreamProvider).valueOrNull ??
                                  [];
                          final connectedCount =
                              devices.where((d) => d.status == 'online').length;
                          return _NavTile(
                            label: loc.manikinsLabel,
                            value: connectedCount > 0
                                ? loc.devicesConnectedCount(connectedCount)
                                : loc.disconnected,
                            onTap: () => context.push('/admin/devices'),
                            textColor: textColor,
                            secondaryColor: connectedCount > 0
                                ? AppColors.green
                                : secondaryTextColor,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SectionLabel(loc.about),
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
                      _NavTile(
                          label: loc.ahaGuidelines,
                          value: '',
                          textColor: textColor,
                          secondaryColor: secondaryTextColor,
                          onTap: () async {
                            final url = Uri.parse(
                                'https://cpr.heart.org/-/media/cpr-files/cpr-guidelines-files/highlights/hghlghts_2020eccguidelines_spanish.pdf');
                            if (!await launchUrl(url,
                                mode: LaunchMode.externalApplication)) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(loc.errorOpeningLink)),
                                );
                              }
                            }
                          }),
                      Divider(color: borderColor, height: 0.5),
                      _NavTile(
                          label: loc.privacyPolicy,
                          value: '',
                          textColor: textColor,
                          secondaryColor: secondaryTextColor,
                          onTap: () => _showPrivacyPolicy(context)),
                      Divider(color: borderColor, height: 0.5),
                      _NavTile(
                          label: loc.appVersion,
                          value: '1.0',
                          textColor: textColor,
                          secondaryColor: secondaryTextColor,
                          onTap: () {}),
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
                  label: Text(loc.logout),
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
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textT = theme.textTheme.bodySmall?.color ?? AppColors.textTertiary;
    final cardSurface = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textT,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color:
                    theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleTile extends StatefulWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? textColor;
  final Color? trackColor;
  const _ToggleTile(
      {required this.label,
      required this.value,
      required this.onChanged,
      this.textColor,
      this.trackColor});

  @override
  State<_ToggleTile> createState() => _ToggleTileState();
}

class _ToggleTileState extends State<_ToggleTile> {
  late bool _val;

  @override
  void initState() {
    super.initState();
    _val = widget.value;
  }

  @override
  void didUpdateWidget(_ToggleTile old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _val = widget.value;
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.label,
                style: TextStyle(
                    color: widget.textColor ?? AppColors.textPrimary,
                    fontSize: 13)),
            Switch(
              value: _val,
              onChanged: (v) {
                setState(() => _val = v);
                widget.onChanged(v);
              },
              activeThumbColor: AppColors.brand,
              trackColor: WidgetStateProperty.resolveWith((s) =>
                  s.contains(WidgetState.selected)
                      ? AppColors.brand.withValues(alpha: 0.4)
                      : (widget.trackColor ?? AppColors.cardBorder)),
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
  const _NavTile(
      {required this.label,
      required this.value,
      required this.onTap,
      this.textColor,
      this.secondaryColor,
      this.icon});

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
                    Icon(icon,
                        size: 18,
                        color: textColor?.withValues(alpha: 0.7) ??
                            AppColors.textPrimary.withValues(alpha: 0.7)),
                    const SizedBox(width: 12),
                  ],
                  Text(label,
                      style: TextStyle(
                          color: textColor ?? AppColors.textPrimary,
                          fontSize: 13)),
                ],
              ),
              Row(children: [
                if (value.isNotEmpty)
                  Text(value,
                      style: TextStyle(
                          color: secondaryColor ?? AppColors.accent,
                          fontSize: 12)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios,
                    size: 12, color: secondaryColor ?? AppColors.textTertiary),
              ]),
            ],
          ),
        ),
      );
}
