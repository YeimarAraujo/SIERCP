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
import 'package:siercp/l10n/app_localizations.dart';
import 'package:siercp/core/theme/locale_provider.dart';
import 'package:siercp/features/users/data/models/user.dart' show CertVerificationStatus;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showLanguageSelector(BuildContext context, WidgetRef ref, AppLocalizations loc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(loc.selectLanguage, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                title: const Text('Español'),
                onTap: () {
                  ref.read(localeControllerProvider.notifier).setLocale(const Locale('es'));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('English'),
                onTap: () {
                  ref.read(localeControllerProvider.notifier).setLocale(const Locale('en'));
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
      case 'SUPER_ADMIN':        return 'Super Admin';
      case 'ADMIN':              return loc.admin;
      case 'INSTRUCTOR':         return loc.instructor;
      case 'USUARIO_SST':        return 'Usuario SST';
      case 'USUARIO_PROFESIONAL': return 'Profesional';
      default:                   return 'Usuario';
    }
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final loc = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(loc.privacyPolicyTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final realStats = ref.watch(userStatsProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final loc = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeControllerProvider);
    
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
                          color: secondaryTextColor, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Badge(
                          label: _translateRole(user?.role ?? 'USUARIO', loc),
                          color: (user?.isSuperAdmin ?? false)
                              ? const Color(0xFFa855f7)
                              : (user?.isAdmin ?? false)
                                  ? AppColors.amber
                                  : (user?.isInstructor ?? false)
                                      ? AppColors.accent
                                      : AppColors.cyan,
                          bg: ((user?.isSuperAdmin ?? false)
                              ? const Color(0xFFa855f7)
                              : (user?.isAdmin ?? false)
                                  ? AppColors.amber
                                  : (user?.isInstructor ?? false)
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
                              label: loc.totalSessions,
                              value: '${realStats?.totalSessions ?? 0}',
                              color: textColor,
                              cardColor: cardColor,
                              borderColor: borderColor),
                          _StatCard(
                              label: loc.averageScore,
                              value:
                                  '${(realStats?.averageScore ?? 0).toStringAsFixed(0)}%',
                              color: AppColors.green,
                              cardColor: cardColor,
                              borderColor: borderColor),
                          _StatCard(
                              label: loc.practiceHours,
                              value:
                                  '${(realStats?.totalHours ?? 0).toStringAsFixed(1)}h',
                              color: AppColors.cyan,
                              cardColor: cardColor,
                              borderColor: borderColor),
                          _StatCard(
                              label: loc.currentStreak,
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

              // Certificates (visible to all users)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SectionLabel('Certificados'),
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
                    value: user?.certVerification == CertVerificationStatus.approved
                        ? 'Verificado'
                        : user?.certVerification == CertVerificationStatus.pending
                            ? 'En revisión'
                            : 'Subir certificado',
                    textColor: textColor,
                    secondaryColor: secondaryTextColor,
                    onTap: () => context.push('/profile/certificados'),
                    icon: Icons.workspace_premium_rounded,
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
                      _ToggleTile(label: loc.darkMode, value: isDark, onChanged: (v) {
                        ref.read(themeModeProvider.notifier).toggleTheme(v);
                      }, textColor: textColor, trackColor: borderColor),
                      Divider(color: borderColor, height: 0.5),
                      _ToggleTile(label: loc.alerts, value: true, onChanged: (_) {}, textColor: textColor, trackColor: borderColor),
                      Divider(color: borderColor, height: 0.5),
                      _NavTile(label: loc.language, value: currentLocale.languageCode == 'en' ? 'English' : 'Español', onTap: () => _showLanguageSelector(context, ref, loc), textColor: textColor, secondaryColor: secondaryTextColor),
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
                          final devices = ref.watch(devicesStreamProvider).valueOrNull ?? [];
                          final connectedCount = devices.where((d) => d.status == 'online').length;
                          return _NavTile(
                            label: loc.manikinsLabel,
                            value: connectedCount > 0 ? loc.devicesConnectedCount(connectedCount) : loc.disconnected,
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
                      _NavTile(label: loc.appVersion, value: '2.0.0',
                          textColor: textColor, secondaryColor: secondaryTextColor, onTap: () {}),
                      Divider(color: borderColor, height: 0.5),
                      _NavTile(label: loc.ahaGuidelines, value: '',
                          textColor: textColor, secondaryColor: secondaryTextColor, onTap: () async {
                            final url = Uri.parse('https://cpr.heart.org/-/media/cpr-files/cpr-guidelines-files/highlights/hghlghts_2020eccguidelines_spanish.pdf');
                            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(loc.errorOpeningLink)),
                                );
                              }
                            }
                          }),
                      Divider(color: borderColor, height: 0.5),
                      _NavTile(label: loc.privacyPolicy, value: '',
                          textColor: textColor, secondaryColor: secondaryTextColor, onTap: () => _showPrivacyPolicy(context)),
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
  void didUpdateWidget(_ToggleTile old) { super.didUpdateWidget(old); if (old.value != widget.value) _val = widget.value; }

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
