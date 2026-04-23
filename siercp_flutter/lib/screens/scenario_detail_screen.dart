// lib/screens/scenario_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import 'package:audioplayers/audioplayers.dart';

// ─── Modelo de datos del escenario ───────────────────────────────────────────
class ScenarioDetailData {
  final String id;
  final String titulo;
  final String subtitulo;
  final String nombrePaciente;
  final String edadDescripcion;
  final double pesoKg;
  final String descripcionClinica;
  final String situacion;
  final double profMinMm;
  final double profMaxMm;
  final double fuerzaMinKg;
  final double fuerzaMaxKg;
  final int frecMinPpm;
  final int frecMaxPpm;
  final String relacionVentilacion;
  final String tecnica;
  final Color color;
  final IconData icono;
  final String audioFile;

  const ScenarioDetailData({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.nombrePaciente,
    required this.edadDescripcion,
    required this.pesoKg,
    required this.descripcionClinica,
    required this.situacion,
    required this.profMinMm,
    required this.profMaxMm,
    required this.fuerzaMinKg,
    required this.fuerzaMaxKg,
    required this.frecMinPpm,
    required this.frecMaxPpm,
    required this.relacionVentilacion,
    required this.tecnica,
    required this.color,
    required this.icono,
    required this.audioFile,
  });
}

// ─── Datos estáticos de los 3 escenarios ─────────────────────────────────────
const Map<String, ScenarioDetailData> kScenarios = {
  'adulto': ScenarioDetailData(
    id: 'adulto',
    titulo: 'Adulto',
    subtitulo: 'RCP estándar según guías AHA 2020',
    nombrePaciente: 'Carlos Mendoza',
    edadDescripcion: '45 años',
    pesoKg: 78,
    descripcionClinica:
        'Hombre de 45 años, 78 kg. Encontrado inconsciente en la sala '
        'de su casa por un familiar. No respira y no tiene pulso. '
        'No presenta trauma visible. Sin antecedentes conocidos.',
    situacion: 'Estás en el lugar del incidente. El servicio de emergencias '
        'está en camino (ETA 8 minutos). Debes iniciar RCP de inmediato.',
    profMinMm: 50,
    profMaxMm: 60,
    fuerzaMinKg: 30,
    fuerzaMaxKg: 60,
    frecMinPpm: 100,
    frecMaxPpm: 120,
    relacionVentilacion: '30:2',
    tecnica: 'Dos manos sobre el esternón',
    color: AppColors.red,
    icono: Icons.monitor_heart_outlined,
    audioFile: 'audio/caso_adulto.mp3',
  ),
  'nino': ScenarioDetailData(
      id: 'nino',
      titulo: 'Niño (1–8 años)',
      subtitulo: 'RCP pediátrico según guías AHA 2020',
      nombrePaciente: 'Sofía Ramírez',
      edadDescripcion: '5 años',
      pesoKg: 18,
      descripcionClinica:
          'Niña de 5 años, 18 kg. Encontrada inconsciente en el fondo '
          'de una piscina residencial. Fue rescatada del agua hace '
          '2 minutos. No respira. Pulso carotídeo débil.',
      situacion: 'Eres el primer respondiente. El área está asegurada. '
          'Aplica el protocolo pediátrico. Recuerda: una sola mano '
          'o dos dedos según el tamaño del niño.',
      profMinMm: 45,
      profMaxMm: 55,
      fuerzaMinKg: 15,
      fuerzaMaxKg: 30,
      frecMinPpm: 100,
      frecMaxPpm: 120,
      relacionVentilacion: '30:2',
      tecnica: 'Una mano o dos dedos',
      color: AppColors.accent,
      icono: Icons.child_care_outlined,
      audioFile: 'audio/caso_niño.mp3'),
  'lactante': ScenarioDetailData(
    id: 'lactante',
    titulo: 'Lactante (<1 año)',
    subtitulo: 'RCP pediátrico para lactantes menores de 1 año',
    nombrePaciente: 'Mateo García',
    edadDescripcion: '6 meses',
    pesoKg: 7.5,
    descripcionClinica: 'Lactante de 6 meses, 7.5 kg. La madre lo encontró sin '
        'respuesta en su cuna luego de una siesta. No respira. '
        'No tiene pulso braquial. Sin trauma ni fiebre reportada.',
    situacion: 'Estás en el hogar del paciente. Utiliza la técnica de '
        'dos dedos (índice y medio) sobre el esternón. '
        'El servicio de emergencias fue alertado.',
    profMinMm: 35,
    profMaxMm: 40,
    fuerzaMinKg: 5,
    fuerzaMaxKg: 15,
    frecMinPpm: 100,
    frecMaxPpm: 120,
    relacionVentilacion: '30:2',
    tecnica: 'Dos dedos (índice y medio)',
    color: Color(0xFFFF6B9D),
    icono: Icons.baby_changing_station_outlined,
    audioFile: 'audio/caso_lactante.mp3',
  ),
};

// ─── Pantalla principal ───────────────────────────────────────────────────────
class ScenarioDetailScreen extends ConsumerStatefulWidget {
  final String scenarioId;
  const ScenarioDetailScreen({super.key, required this.scenarioId});

  @override
  ConsumerState<ScenarioDetailScreen> createState() =>
      _ScenarioDetailScreenState();
}

class _ScenarioDetailScreenState extends ConsumerState<ScenarioDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scenario = kScenarios[widget.scenarioId];
    debugPrint('🔴 id recibido: "${widget.scenarioId}"');
    debugPrint('🔴 keys disponibles: ${kScenarios.keys.toList()}');
    debugPrint('🔴 encontrado: ${kScenarios.containsKey(widget.scenarioId)}');
    if (scenario == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/session?scenario=${widget.scenarioId}');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final textT = theme.textTheme.bodySmall?.color ?? AppColors.textTertiary;
    final color = scenario.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              children: [
                // ── Header ────────────────────────────────────────────────
                _Header(scenario: scenario, isDark: isDark),

                // ── Scrollable content ────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // Ficha del paciente
                        _PatientCard(
                          scenario: scenario,
                          isDark: isDark,
                          textP: textP,
                          textS: textS,
                          textT: textT,
                          color: color,
                        ),
                        const SizedBox(height: 16),

                        // Descripción clínica
                        _SectionCard(
                          icon: Icons.description_outlined,
                          label: 'Caso clínico',
                          color: color,
                          isDark: isDark,
                          textP: textP,
                          textS: textS,
                          child: Text(
                            scenario.descripcionClinica,
                            style: TextStyle(
                              color: textS,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Situación
                        _SectionCard(
                          icon: Icons.warning_amber_rounded,
                          label: 'Tu situación',
                          color: AppColors.amber,
                          isDark: isDark,
                          textP: textP,
                          textS: textS,
                          child: Text(
                            scenario.situacion,
                            style: TextStyle(
                              color: textS,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Parámetros AHA
                        _ProtocolCard(
                          scenario: scenario,
                          isDark: isDark,
                          textP: textP,
                          textS: textS,
                          textT: textT,
                          color: color,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ── Botón iniciar sesión ───────────────────────────────────────────
      bottomNavigationBar: _BottomAction(
        scenario: scenario,
        color: color,
      ),
    );
  }
}

// ─── Header con back button ───────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final ScenarioDetailData scenario;
  final bool isDark;
  const _Header({required this.scenario, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop(),
            color: textP,
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scenario.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(scenario.icono, color: scenario.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scenario.titulo,
                  style: TextStyle(
                    color: textP,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  scenario.subtitulo,
                  style: TextStyle(color: textS, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tarjeta del paciente ─────────────────────────────────────────────────────
class _PatientCard extends StatelessWidget {
  final ScenarioDetailData scenario;
  final bool isDark;
  final Color textP, textS, textT, color;

  const _PatientCard({
    required this.scenario,
    required this.isDark,
    required this.textP,
    required this.textS,
    required this.textT,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.1 : 0.06),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.25 : 0.18),
          width: 0.8,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          // Avatar del paciente
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_outline_rounded, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'PACIENTE',
                        style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  scenario.nombrePaciente,
                  style: TextStyle(
                    color: textP,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.cake_outlined,
                      label: scenario.edadDescripcion,
                      textS: textS,
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.monitor_weight_outlined,
                      label: '${scenario.pesoKg} kg',
                      textS: textS,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textS;
  const _InfoChip(
      {required this.icon, required this.label, required this.textS});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 12, color: textS),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: textS, fontSize: 11)),
        ],
      );
}

// ─── Sección con icono y label ────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final Color textP, textS;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.textP,
    required this.textS,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ─── Protocolo AHA ────────────────────────────────────────────────────────────
class _ProtocolCard extends StatelessWidget {
  final ScenarioDetailData scenario;
  final bool isDark;
  final Color textP, textS, textT, color;

  const _ProtocolCard({
    required this.scenario,
    required this.isDark,
    required this.textP,
    required this.textS,
    required this.textT,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rule_outlined, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                'PROTOCOLO AHA 2020',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Grid de parámetros 2x2
          Row(
            children: [
              Expanded(
                child: _ParamTile(
                  icon: Icons.straighten_outlined,
                  label: 'Profundidad',
                  value:
                      '${scenario.profMinMm.toInt()}–${scenario.profMaxMm.toInt()} mm',
                  color: color,
                  textP: textP,
                  textT: textT,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ParamTile(
                  icon: Icons.speed_outlined,
                  label: 'Frecuencia',
                  value: '${scenario.frecMinPpm}–${scenario.frecMaxPpm} ppm',
                  color: color,
                  textP: textP,
                  textT: textT,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ParamTile(
                  icon: Icons.compress_outlined,
                  label: 'Ventilación',
                  value: scenario.relacionVentilacion,
                  color: color,
                  textP: textP,
                  textT: textT,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ParamTile(
                  icon: Icons.back_hand_outlined,
                  label: 'Técnica',
                  value: scenario.tecnica,
                  color: color,
                  textP: textP,
                  textT: textT,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParamTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color, textP, textT;

  const _ParamTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.textP,
    required this.textT,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: textT, fontSize: 9, letterSpacing: 0.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: textP,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom CTA ───────────────────────────────────────────────────────────────
class _BottomAction extends StatefulWidget {
  final ScenarioDetailData scenario;
  final Color color;
  const _BottomAction({required this.scenario, required this.color});

  @override
  State<_BottomAction> createState() => _BottomActionState();
}

class _BottomActionState extends State<_BottomAction> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _player.stop();
      setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _player.play(AssetSource(widget.scenario.audioFile));
      setState(() {
        _isPlaying = true;
        _isLoading = false;
      });
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reproducir el audio')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Botón de audio ──────────────────────────────────────
          GestureDetector(
            onTap: _isLoading ? null : _toggleAudio,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                border: Border.all(
                  color: color.withValues(alpha: 0.25),
                  width: 0.8,
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  else
                    Icon(
                      _isPlaying
                          ? Icons.stop_circle_outlined
                          : Icons.volume_up_rounded,
                      color: color,
                      size: 18,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _isPlaying ? 'Detener audio' : 'Escuchar caso clínico',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Botón iniciar simulación ─────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                _player.stop(); // para el audio si estaba sonando
                context.go('/session?scenario=${widget.scenario.id}');
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text(
                'Iniciar simulación',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
