import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';

class TheoreticalHubScreen extends ConsumerStatefulWidget {
  const TheoreticalHubScreen({super.key});

  @override
  ConsumerState<TheoreticalHubScreen> createState() =>
      _TheoreticalHubScreenState();
}

class _TheoreticalHubScreenState
    extends ConsumerState<TheoreticalHubScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static const _allTypes = <_EvalType>[
    _EvalType(
      id: 'rcp',
      title: 'RCP',
      icon: Icons.favorite_outlined,
      color: Color(0xFFEF4444),
      desc: 'Reanimación cardiopulmonar en adultos, niños y lactantes',
      caseIds: ['eval_adulto_rcp', 'eval_pediatrico', 'eval_lactante', 'eval_dos_rescatadores', 'eval_rcp_via_aerea_avanzada', 'eval_rcp_hands_only', 'eval_rcp_dea'],
    ),
    _EvalType(
      id: 'dea',
      title: 'DEA',
      icon: Icons.electric_bolt_rounded,
      color: Color(0xFFF59E0B),
      desc: 'Desfibrilación externa automática',
      caseIds: ['eval_dea_fv', 'eval_dea_pediatrico', 'eval_dea_superficie_mojada', 'eval_dea_marcapasos', 'eval_dea_parches', 'eval_dea_vello'],
    ),
    _EvalType(
      id: 'ahogamiento',
      title: 'Ahogamiento',
      icon: Icons.water_drop_outlined,
      color: Color(0xFF06B6D4),
      desc: 'Rescate y reanimación en víctimas de ahogamiento',
      caseIds: ['eval_ahogamiento', 'eval_ahogamiento_agua_fria', 'eval_ahogamiento_pediatrico', 'eval_ahogamiento_agua_salada', 'eval_ahogamiento_lesion_cervical', 'eval_ahogamiento_vehiculo'],
    ),
    _EvalType(
      id: 'ovace',
      title: 'OVACE',
      icon: Icons.air_rounded,
      color: Color(0xFF8B5CF6),
      desc: 'Obstrucción de la vía aérea por cuerpo extraño',
      caseIds: ['eval_ovace_adulto', 'eval_ovace_lactante', 'eval_ovace_adulto_inconsciente', 'eval_ovace_nino', 'eval_ovace_obesidad', 'eval_ovace_embarazada'],
    ),
    _EvalType(
      id: 'electrocucion',
      title: 'Electrocución',
      icon: Icons.bolt_rounded,
      color: Color(0xFFF97316),
      desc: 'Lesiones eléctricas y paro cardíaco',
      caseIds: ['eval_electrocucion', 'eval_electrocucion_alto_voltaje', 'eval_electrocucion_rayo', 'eval_electrocucion_pediatrica', 'eval_electrocucion_banera', 'eval_electrocucion_arco'],
    ),
    _EvalType(
      id: 'sobredosis',
      title: 'Sobredosis',
      icon: Icons.medication_outlined,
      color: Color(0xFFEC4899),
      desc: 'Sobredosis por opioides y uso de naloxona',
      caseIds: ['eval_sobredosis', 'eval_sobredosis_benzodiacepinas', 'eval_sobredosis_cocaina', 'eval_sobredosis_opioides', 'eval_sobredosis_triciclicos', 'eval_sobredosis_paracetamol'],
    ),
    _EvalType(
      id: 'infarto',
      title: 'Infarto',
      icon: Icons.favorite_border_rounded,
      color: Color(0xFFB91C1C),
      desc: 'Reconocimiento y respuesta al infarto agudo de miocardio',
      caseIds: ['eval_infarto_paro', 'eval_infarto_edema_pulmonar', 'eval_infarto_inferior_bav', 'eval_infarto_anterior', 'eval_infarto_shock_cardiogenico', 'eval_infarto_derecho'],
    ),
    _EvalType(
      id: 'hipotermia',
      title: 'Hipotermia',
      icon: Icons.ac_unit_outlined,
      color: Color(0xFF059669),
      desc: 'Manejo del paro cardíaco por hipotermia severa',
      caseIds: ['eval_hipotermia', 'eval_hipotermia_avalancha', 'eval_hipotermia_neonatal'],
    ),
    _EvalType(
      id: 'hemorragia',
      title: 'Hemorragia',
      icon: Icons.bloodtype_outlined,
      color: Color(0xFFDC2626),
      desc: 'Control de hemorragias y uso de torniquete',
      caseIds: ['eval_hemorragia', 'eval_hemorragia_tce', 'eval_hemorragia_postparto'],
    ),
    _EvalType(
      id: 'anafilaxia',
      title: 'Anafilaxia',
      icon: Icons.vaccines_outlined,
      color: Color(0xFFD97706),
      desc: 'Reacción alérgica severa y administración de adrenalina',
      caseIds: ['eval_anafilaxia', 'eval_anafilaxia_picadura', 'eval_anafilaxia_alimento', 'eval_anafilaxia_ejercicio'],
    ),
    _EvalType(
      id: 'convulsion',
      title: 'Crisis Convulsiva',
      icon: Icons.psychology_alt_outlined,
      color: Color(0xFF6366F1),
      desc: 'Primeros auxilios durante una crisis convulsiva',
      caseIds: ['eval_convulsion', 'eval_convulsion_status', 'eval_convulsion_febril'],
    ),
    _EvalType(
      id: 'embarazada',
      title: 'Embarazada',
      icon: Icons.pregnant_woman_outlined,
      color: Color(0xFFEC4899),
      desc: 'Paro cardíaco y RCP en la paciente gestante',
      caseIds: ['eval_embarazada', 'eval_embarazada_eclampsia'],
    ),
    _EvalType(
      id: 'presion',
      title: 'Presión Arterial',
      icon: Icons.monitor_heart_outlined,
      color: Color(0xFFE11D48),
      desc: 'Crisis hipertensiva y shock hipovolémico',
      caseIds: ['eval_crisis_hipertensiva', 'eval_shock_hipovolemico', 'eval_presion_crisis_embarazo'],
    ),
    _EvalType(
      id: 'infeccion',
      title: 'Infección',
      icon: Icons.local_hospital_outlined,
      color: Color(0xFFD97706),
      desc: 'Sepsis y shock séptico',
      caseIds: ['eval_sepsis', 'eval_infeccion_shock_pediatrico', 'eval_infeccion_meningitis', 'eval_infeccion_neumonia', 'eval_infeccion_urosepsis', 'eval_infeccion_endocarditis'],
    ),
    _EvalType(
      id: 'metabolico',
      title: 'Metabólico',
      icon: Icons.science_outlined,
      color: Color(0xFF7C3AED),
      desc: 'Cetoacidosis diabética y emergencias metabólicas',
      caseIds: ['eval_cetoacidosis', 'eval_metabolico_hiperosmolar', 'eval_metabolico_hipoglucemia', 'eval_metabolico_acidosis_lactica', 'eval_metabolico_tormenta_tiroidea', 'eval_metabolico_insuficiencia_suprarrenal'],
    ),
    _EvalType(
      id: 'ecg',
      title: 'ECG',
      icon: Icons.monitor_heart_outlined,
      color: Color(0xFF10B981),
      desc: 'Interpretación de ritmos cardíacos en monitorización',
      caseIds: ['eval_ecg_fv', 'eval_ecg_tvsp', 'eval_ecg_asistolia', 'eval_ecg_tsv', 'eval_ecg_bav', 'eval_ecg_fa_rvr', 'eval_ritmo_fv', 'eval_ritmo_tv', 'eval_ritmo_asistolia', 'eval_ritmo_aesp', 'eval_ritmo_tsv', 'eval_ritmo_fa'],
    ),
    _EvalType(
      id: 'triage',
      title: 'Triage',
      icon: Icons.emergency_outlined,
      color: Color(0xFFE11D48),
      desc: 'Clasificación de pacientes según sistema START/ESI',
      caseIds: [],
    ),
  ];

  List<_EvalType> get _filteredTypes {
    if (_query.isEmpty) return _allTypes;
    final q = _query.toLowerCase();
    return _allTypes.where((t) =>
        t.title.toLowerCase().contains(q) ||
        t.desc.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final types = _filteredTypes;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18, color: textP),
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Evaluaciones Teóricas',
                              style: TextStyle(
                                  color: textP,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Selecciona el tipo de caso clínico',
                              style: TextStyle(color: textS, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(color: textP, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Buscar tipo de caso...',
                      hintStyle: TextStyle(color: textS.withValues(alpha: 0.5), fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: textS.withValues(alpha: 0.5)),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, size: 18, color: textS),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: types.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: textS.withValues(alpha: 0.3)),
                          const SizedBox(height: 8),
                          Text('Sin resultados para "$_query"', style: TextStyle(color: textS, fontSize: 13)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: types.length,
                      itemBuilder: (_, i) {
                        final type = types[i];
                        return _TypeCard(
                          type: type,
                          isDark: isDark,
                          textP: textP,
                          textS: textS,
                          onTap: type.id == 'triage'
                              ? () => context.push('/simulation/theoretical/triage')
                              : () => context.push(
                                  '/simulation/theoretical/cases?type=${type.id}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvalType {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final String desc;
  final List<String> caseIds;

  const _EvalType({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.desc,
    required this.caseIds,
  });
}

class _TypeCard extends StatelessWidget {
  final _EvalType type;
  final bool isDark;
  final Color textP;
  final Color textS;
  final VoidCallback onTap;

  const _TypeCard({
    required this.type,
    required this.isDark,
    required this.textP,
    required this.textS,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: border.withValues(alpha: 0.2), width: 0.5),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: type.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: type.color.withValues(alpha: 0.2), width: 0.8),
                    ),
                    child: Icon(type.icon, color: type.color, size: 28),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        type.title,
                        style: TextStyle(
                            color: textP,
                            fontSize: 14,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      type.id == 'triage'
                          ? 'Clasificación'
                          : '${type.caseIds.length} ${type.caseIds.length == 1 ? 'caso' : 'casos'}',
                      style: TextStyle(
                          color: type.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
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
