import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/section_label.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:siercp/l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
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
      case 'ADMIN': return loc.admin;
      case 'INSTRUCTOR': return loc.instructor;
      default: return loc.student;
    }
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Políticas de Privacidad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Text(
            '1. Introducción\n\nEl Sistema de Entrenamiento en RCP se compromete a proteger la privacidad y seguridad de la información personal de sus usuarios. Esta política explica cómo recopilamos, usamos, almacenamos y protegemos los datos personales conforme a la normativa vigente en Colombia (Ley 1581 de 2012 y normas complementarias).\n\n2. Información que Recopilamos\n\nPodemos recopilar la siguiente información:\n\nDatos personales: nombre completo, número de identificación, correo electrónico, número de teléfono.\nDatos académicos o profesionales: institución, cargo, certificaciones previas.\nDatos de uso del sistema: progreso en módulos, resultados de evaluaciones, fechas de acceso.\nInformación técnica: dirección IP, tipo de dispositivo y navegador.\n\n3. Finalidad del Tratamiento de Datos\n\nLa información recopilada será utilizada para:\n\nGestionar el registro y acceso al sistema.\nRealizar seguimiento del progreso del usuario en los módulos de RCP.\nEmitir certificados de participación o aprobación.\nEnviar información relevante sobre capacitaciones o actualizaciones.\nMejorar la calidad del servicio y la experiencia del usuario.\n\n4. Almacenamiento y Seguridad\n\nLa información será almacenada en bases de datos seguras y se implementarán medidas técnicas, administrativas y organizativas para evitar acceso no autorizado, pérdida o alteración de la información.\n\n5. Compartición de Información\n\nLos datos personales no serán vendidos ni compartidos con terceros, salvo:\n\nCuando sea requerido por autoridad competente.\nCuando sea necesario para emitir certificaciones oficiales.\nCuando el usuario otorgue autorización expresa.\n\n6. Derechos del Usuario\n\nDe acuerdo con la legislación colombiana, el usuario tiene derecho a:\n\nConocer, actualizar y rectificar sus datos personales.\nSolicitar prueba de la autorización otorgada.\nRevocar la autorización o solicitar la eliminación de sus datos.\nPresentar quejas ante la Superintendencia de Industria y Comercio.\n\n7. Uso de Cookies\n\nEl sistema puede utilizar cookies para mejorar la experiencia de navegación y analizar el uso de la plataforma.\n\n8. Modificaciones a la Política\n\nNos reservamos el derecho de actualizar esta política en cualquier momento. Los cambios serán publicados en la plataforma.\n\n9. Contacto\n\nPara consultas relacionadas con la privacidad y tratamiento de datos, puede comunicarse a través del correo electrónico oficial del sistema.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
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
                          : (user?.isAdmin == true ? loc.admin : loc.user),
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
                          label: _translateRole(user?.role ?? 'ESTUDIANTE', loc),
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
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.9,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StatCard(label: loc.totalSessions, value: '${realStats?.totalSessions ?? 0}', color: textColor, cardColor: cardColor, borderColor: borderColor),
                    _StatCard(label: loc.averageScore, value: '${(realStats?.averageScore ?? 0).toStringAsFixed(0)}%', color: AppColors.green, cardColor: cardColor, borderColor: borderColor),
                    _StatCard(label: loc.practiceHours, value: '${(realStats?.totalHours ?? 0).toStringAsFixed(1)}h', color: AppColors.cyan, cardColor: cardColor, borderColor: borderColor),
                    _StatCard(label: loc.currentStreak, value: '${realStats?.streakDays ?? 0}d', color: AppColors.amber, cardColor: cardColor, borderColor: borderColor),
                  ],
                ),
              ),
              const SizedBox(height: 24),

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
                                  const SnackBar(content: Text('No se pudo abrir el enlace')),
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

