import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/simulation/data/aed/aed_audio_service.dart';
import 'package:siercp/features/simulation/data/aed/aed_scenarios.dart';

enum _AedPhase {
  off,
  connectElectrodes,
  electrodesPlaced,
  analyzing,
  shockRecommended,
  charging,
  pressShockButton,
  shockDelivered,
  cpr,
  noShockRecommended,
  shockBlocked,
  placeElectrodesFirst,
  analyzeFirst,
  decisionPrompt,
  decisionCorrect,
  decisionWrong,
  waitForAnalysis,
  completed,
}

class AedSimulatorScreen extends StatefulWidget {
  const AedSimulatorScreen({super.key});

  @override
  State<AedSimulatorScreen> createState() => _AedSimulatorScreenState();
}

class _AedSimulatorScreenState extends State<AedSimulatorScreen>
    with TickerProviderStateMixin {
  final AedAudioService _audio = AedAudioService();
  final ScrollController _scenarioScrollCtrl = ScrollController();

  _AedPhase _phase = _AedPhase.off;
  AedScenario _currentScenario = kAedScenarios.first;
  int _cycleCount = 0;
  bool _audioEnabled = true;

  Timer? _analysisTimer;
  int _analysisDotCount = 0;
  Timer? _dotTimer;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _audio.init();
    } catch (_) {}
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    _dotTimer?.cancel();
    _audio.dispose();
    _scenarioScrollCtrl.dispose();
    super.dispose();
  }

  void _setPhase(_AedPhase newPhase) {
    if (!mounted) return;
    setState(() {
      _phase = newPhase;
    });
  }

  Future<void> _speak(String text) async {
    if (!_audioEnabled) return;
    try {
      await _audio.speakText(text);
    } catch (_) {}
  }

  // ── Button handlers ────────────────────────────────────────

  Future<void> _onPowerOn() async {
    if (_phase != _AedPhase.off) return;
    _setPhase(_AedPhase.connectElectrodes);
    if (_audioEnabled) await _audio.playPowerOnBeep();
    await _speak('Conecte los electrodos al tórax del paciente');
  }

  Future<void> _onPlaceElectrodes() async {
    if (_phase == _AedPhase.connectElectrodes) {
      _setPhase(_AedPhase.electrodesPlaced);
      await _speak('Electrodos colocados. Presione analizar.');
    } else {
      _setPhase(_AedPhase.placeElectrodesFirst);
      if (_audioEnabled) await _audio.playErrorBuzz();
      await _speak('Coloque los electrodos primero');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) _setPhase(_AedPhase.connectElectrodes);
    }
  }

  Future<void> _onAnalyze() async {
    if (_phase == _AedPhase.electrodesPlaced) {
      await _startAnalysis();
    } else if (_phase == _AedPhase.cpr || _phase == _AedPhase.shockDelivered) {
      if (_currentScenario.id == 'aed_fv_ciclo' && _cycleCount < 2) {
        await _startAnalysis();
      } else {
        await _speak('Análisis completado. Siga las indicaciones.');
      }
    } else {
      _setPhase(_AedPhase.analyzeFirst);
      if (_audioEnabled) await _audio.playErrorBuzz();
      await _speak('Coloque los electrodos y encienda el equipo primero');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) _setPhase(_phase == _AedPhase.off ? _AedPhase.off : _phase);
    }
  }

  Future<void> _startAnalysis() async {
    _setPhase(_AedPhase.analyzing);
    if (_audioEnabled) await _audio.playAnalysisBeep();
    await _speak('Analizando ritmo, no toque al paciente');

    _analysisDotCount = 0;
    _dotTimer?.cancel();
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() {
          _analysisDotCount = (_analysisDotCount + 1) % 4;
        });
      }
    });

    await Future.delayed(const Duration(seconds: 3));
    _dotTimer?.cancel();

    if (!mounted) return;

    if (_currentScenario.isDecisionMode) {
      _setPhase(_AedPhase.decisionPrompt);
      await _speak('¿Descarga recomendada?');
    } else if (_currentScenario.rhythmType == AedRhythmType.shockable) {
      _setPhase(_AedPhase.shockRecommended);
      if (_audioEnabled) await _audio.playAnalysisBeep();
      await _speak('Descarga recomendada, cargando');

      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      _setPhase(_AedPhase.pressShockButton);
      if (_audioEnabled) await _audio.playChargingTone();
      await _speak('Presione el botón naranja para descargar');
    } else {
      _setPhase(_AedPhase.noShockRecommended);
      if (_audioEnabled) await _audio.playCompletionChime();
      await _speak('No se recomienda descarga. Inicie RCP.');
    }
  }

  Future<void> _onShock() async {
    if (_phase == _AedPhase.pressShockButton) {
      _setPhase(_AedPhase.shockDelivered);
      if (_audioEnabled) await _audio.playShockSound();
      await _speak('Descarga aplicada');
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      _setPhase(_AedPhase.cpr);
      await _speak('Inicie RCP. Treinta compresiones, dos ventilaciones');
    } else if (_phase == _AedPhase.pressShockButton) {
      await _speak('Presione el botón naranja para descargar');
    } else if (_phase == _AedPhase.noShockRecommended ||
        _phase == _AedPhase.cpr) {
      _setPhase(_AedPhase.shockBlocked);
      if (_audioEnabled) await _audio.playErrorBuzz();
      await _speak('Descarga bloqueada, este ritmo no es desfibrilable');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted)
        _setPhase(_phase == _AedPhase.cpr
            ? _AedPhase.cpr
            : _AedPhase.noShockRecommended);
    } else {
      _setPhase(_AedPhase.analyzeFirst);
      if (_audioEnabled) await _audio.playErrorBuzz();
      await _speak('Analice el ritmo primero');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) _setPhase(_phase);
    }
  }

  Future<void> _onCpr() async {
    if (_phase == _AedPhase.cpr ||
        _phase == _AedPhase.noShockRecommended ||
        _phase == _AedPhase.shockDelivered) {
      _setPhase(_AedPhase.cpr);
      if (_audioEnabled) await _audio.playCprMetronome();
      await _speak('RCP en curso. Treinta compresiones, dos ventilaciones');

      if (_currentScenario.id == 'aed_fv_ciclo' && _cycleCount < 2) {
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        _cycleCount++;
        _setPhase(_AedPhase.cpr);
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        await _speak('Reanalizando ritmo');
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        await _startAnalysis();
      } else {
        _setPhase(_AedPhase.completed);
        if (_audioEnabled) await _audio.playCompletionChime();
        await _speak('Escenario completado');
      }
    } else {
      _setPhase(_AedPhase.waitForAnalysis);
      if (_audioEnabled) await _audio.playErrorBuzz();
      await _speak('Espere el análisis del ritmo');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) _setPhase(_phase);
    }
  }

  // ── Decision mode ──────────────────────────────────────────

  Future<void> _onDecisionYes() async {
    if (_phase != _AedPhase.decisionPrompt) return;
    if (_currentScenario.rhythmType == AedRhythmType.shockable) {
      _setPhase(_AedPhase.decisionCorrect);
      await _speak('Correcto. Descarga recomendada.');
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      _setPhase(_AedPhase.pressShockButton);
      if (_audioEnabled) await _audio.playChargingTone();
      await _speak('Presione el botón naranja para descargar');
    } else {
      _setPhase(_AedPhase.decisionWrong);
      if (_audioEnabled) await _audio.playErrorBuzz();
      await _speak('Incorrecto. Este ritmo no es desfibrilable.');
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      _setPhase(_AedPhase.noShockRecommended);
      await _speak('Inicie RCP');
    }
  }

  Future<void> _onDecisionNo() async {
    if (_phase != _AedPhase.decisionPrompt) return;
    if (_currentScenario.rhythmType == AedRhythmType.nonShockable) {
      _setPhase(_AedPhase.decisionCorrect);
      await _speak('Correcto. No se recomienda descarga.');
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      _setPhase(_AedPhase.noShockRecommended);
      await _speak('Inicie RCP');
    } else {
      _setPhase(_AedPhase.decisionWrong);
      if (_audioEnabled) await _audio.playErrorBuzz();
      await _speak('Incorrecto. Este ritmo es desfibrilable.');
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      _setPhase(_AedPhase.shockRecommended);
      if (_audioEnabled) await _audio.playAnalysisBeep();
      await _speak('Descarga recomendada, cargando');
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      _setPhase(_AedPhase.pressShockButton);
      if (_audioEnabled) await _audio.playChargingTone();
      await _speak('Presione el botón naranja para descargar');
    }
  }

  // ── Helpers ────────────────────────────────────────────────

  void _resetScenario() {
    _analysisTimer?.cancel();
    _dotTimer?.cancel();
    _cycleCount = 0;
    _audio.stop();
    _setPhase(_AedPhase.off);
  }

  void _onScenarioChanged(AedScenario? scenario) {
    if (scenario == null || scenario.id == _currentScenario.id) return;
    _analysisTimer?.cancel();
    _dotTimer?.cancel();
    _audio.stop();
    setState(() {
      _currentScenario = scenario;
      _cycleCount = 0;
      _phase = _AedPhase.off;
    });
  }

  Color _rhythmColor() {
    if (_currentScenario.rhythmType == AedRhythmType.shockable) {
      return const Color(0xFFEF4444);
    }
    return const Color(0xFFF59E0B);
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('AED Trainer'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_audioEnabled ? Icons.volume_up : Icons.volume_off),
            onPressed: () => setState(() => _audioEnabled = !_audioEnabled),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildAedDisplay(),
                    const SizedBox(height: 12),
                    _buildScenarioInfo(),
                    const SizedBox(height: 16),
                    _buildControls(isDark),
                    const SizedBox(height: 16),
                    if (_phase == _AedPhase.decisionPrompt)
                      _buildDecisionButtons(),
                    const SizedBox(height: 12),
                    _buildScenarioSelector(isDark, textS),
                    const SizedBox(height: 12),
                    _buildResetButton(isDark, textS),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAedDisplay() {
    final displayLines = _getDisplayLines();

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 200),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: const Color(0xFF1E3A5F), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF88).withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AED',
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4A7A5C),
                  letterSpacing: 1.5,
                ),
              ),
              if (_phase != _AedPhase.off)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FF88).withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          ...displayLines.map((line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  line.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: line.big ? 20 : 14,
                    fontWeight: line.big ? FontWeight.w700 : FontWeight.w500,
                    color: line.color ?? const Color(0xFF00FF88),
                    height: 1.3,
                  ),
                ),
              )),
          const SizedBox(height: 12),
          if (_phase == _AedPhase.analyzing) _buildAnalyzingDots(),
          if (_phase == _AedPhase.completed) _buildHeartbeatIcon(),
        ],
      ),
    );
  }

  Widget _buildAnalyzingDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final dotActive = i < _analysisDotCount;
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: dotActive
                ? const Color(0xFF00FF88)
                : const Color(0xFF00FF88).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  Widget _buildHeartbeatIcon() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 1.15),
      duration: const Duration(milliseconds: 600),
      builder: (context, scale, _) {
        return Transform.scale(
          scale: scale,
          child: const Icon(
            Icons.favorite,
            color: Color(0xFF00FF88),
            size: 32,
          ),
        );
      },
    );
  }

  Widget _buildScenarioInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _rhythmColor().withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: _rhythmColor().withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: _rhythmColor(), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentScenario.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _rhythmColor(),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentScenario.description,
                  style: TextStyle(
                      fontSize: 11,
                      color: _rhythmColor().withValues(alpha: 0.7)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _rhythmColor().withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _currentScenario.rhythmType == AedRhythmType.shockable
                  ? 'DESFIBRILABLE'
                  : 'NO DESFIBRILABLE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: _rhythmColor(),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(bool isDark) {
    final canPower = _phase == _AedPhase.off;
    final canElectrodes = _phase == _AedPhase.connectElectrodes ||
        _phase == _AedPhase.placeElectrodesFirst;
    final canAnalyze = _phase == _AedPhase.electrodesPlaced ||
        _phase == _AedPhase.cpr ||
        _phase == _AedPhase.shockDelivered ||
        _phase == _AedPhase.analyzeFirst;
    final canShock = _phase == _AedPhase.pressShockButton ||
        _phase == _AedPhase.shockBlocked;
    final canCpr = _phase == _AedPhase.cpr ||
        _phase == _AedPhase.noShockRecommended ||
        _phase == _AedPhase.shockDelivered ||
        _phase == _AedPhase.waitForAnalysis;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _AedButton(
                icon: Icons.power_settings_new,
                label: 'Encender',
                color: const Color(0xFF10B981),
                enabled: canPower,
                onPressed: _onPowerOn,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AedButton(
                icon: Icons.monitor_heart_outlined,
                label: 'Parches',
                color: const Color(0xFF3B82F6),
                enabled: canElectrodes,
                onPressed: _onPlaceElectrodes,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _AedButton(
                icon: Icons.search,
                label: 'Analizar',
                color: const Color(0xFF8B5CF6),
                enabled: canAnalyze,
                onPressed: _onAnalyze,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AedButton(
                icon: Icons.bolt,
                label: 'Descarga',
                color: const Color(0xFFF97316),
                enabled: canShock,
                isDestructive: _phase == _AedPhase.noShockRecommended,
                onPressed: _onShock,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: _AedButton(
            icon: Icons.favorite,
            label: 'RCP',
            color: const Color(0xFFEF4444),
            enabled: canCpr,
            onPressed: _onCpr,
          ),
        ),
      ],
    );
  }

  Widget _buildDecisionButtons() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: const Color(0xFF00FF88).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text(
                      'SÍ',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    onPressed: _onDecisionYes,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    label: const Text(
                      'NO, RCP',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B7280),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    onPressed: _onDecisionNo,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioSelector(bool isDark, Color textS) {
    final bg = isDark ? const Color(0xFF162033) : const Color(0xFFF1F5F9);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.list, size: 18, color: Color(0xFF64748B)),
          const SizedBox(width: 10),
          Text('Escenario:', style: TextStyle(fontSize: 12, color: textS)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _currentScenario.id,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.w600,
                ),
                items: kAedScenarios.map((s) {
                  return DropdownMenuItem(
                    value: s.id,
                    child: Text(s.title, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val == null) return;
                  final scenario = kAedScenarios.firstWhere((s) => s.id == val);
                  _onScenarioChanged(scenario);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton(bool isDark, Color textS) {
    return TextButton.icon(
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Reiniciar escenario'),
      onPressed: _resetScenario,
      style: TextButton.styleFrom(foregroundColor: textS),
    );
  }

  // ── Display lines ──────────────────────────────────────────

  List<_DisplayLine> _getDisplayLines() {
    switch (_phase) {
      case _AedPhase.off:
        return const [];
      case _AedPhase.connectElectrodes:
        return [
          _DisplayLine('CONECTE', big: true),
          _DisplayLine('ELECTRODOS', big: true),
          _DisplayLine(''),
          _DisplayLine('al tórax del paciente'),
        ];
      case _AedPhase.electrodesPlaced:
        return [
          _DisplayLine('ELECTRODOS', big: true),
          _DisplayLine('COLOCADOS', big: true),
          _DisplayLine(''),
          _DisplayLine('PRESIONE ANALIZAR'),
        ];
      case _AedPhase.analyzing:
        return [
          _DisplayLine('ANALIZANDO', big: true),
          _DisplayLine('RITMO...', big: true),
          _DisplayLine(''),
          _DisplayLine('⚠ NO TOQUE AL', color: const Color(0xFFFF6B6B)),
          _DisplayLine('PACIENTE', color: const Color(0xFFFF6B6B)),
        ];
      case _AedPhase.shockRecommended:
        return [
          _DisplayLine('DESCARGA', big: true, color: const Color(0xFFFFA500)),
          _DisplayLine('RECOMENDADA',
              big: true, color: const Color(0xFFFFA500)),
          _DisplayLine(''),
          _DisplayLine('CARGANDO...'),
        ];
      case _AedPhase.charging:
        return [
          _DisplayLine('CARGANDO...', big: true),
          _DisplayLine(''),
          _DisplayLine('⚠ NO TOQUE AL'),
          _DisplayLine('PACIENTE', color: const Color(0xFFFF6B6B)),
        ];
      case _AedPhase.pressShockButton:
        return [
          _DisplayLine('DESCARGA', big: true, color: const Color(0xFFFFA500)),
          _DisplayLine('LISTA', big: true, color: const Color(0xFFFFA500)),
          _DisplayLine(''),
          _DisplayLine('PRESIONE BOTÓN'),
          _DisplayLine('NARANJA', color: const Color(0xFFF97316)),
        ];
      case _AedPhase.shockDelivered:
        return [
          _DisplayLine('DESCARGA', big: true),
          _DisplayLine('APLICADA', big: true),
          _DisplayLine(''),
          _DisplayLine('INICIE RCP'),
        ];
      case _AedPhase.cpr:
        return [
          _DisplayLine('INICIE RCP', big: true),
          _DisplayLine('30:2', big: true),
          _DisplayLine(''),
          _DisplayLine('100-120 comp/min'),
        ];
      case _AedPhase.noShockRecommended:
        return [
          _DisplayLine('NO SE', big: true, color: const Color(0xFF60A5FA)),
          _DisplayLine('RECOMIENDA', big: true, color: const Color(0xFF60A5FA)),
          _DisplayLine('DESCARGA', big: true, color: const Color(0xFF60A5FA)),
          _DisplayLine(''),
          _DisplayLine('INICIE RCP'),
        ];
      case _AedPhase.shockBlocked:
        return [
          _DisplayLine('ERROR', big: true, color: const Color(0xFFEF4444)),
          _DisplayLine('DESCARGA', color: const Color(0xFFEF4444)),
          _DisplayLine('BLOQUEADA', color: const Color(0xFFEF4444)),
        ];
      case _AedPhase.placeElectrodesFirst:
        return [
          _DisplayLine('COLOQUE LOS'),
          _DisplayLine('ELECTRODOS', big: true),
          _DisplayLine('PRIMERO'),
        ];
      case _AedPhase.analyzeFirst:
        return [
          _DisplayLine('ANALICE EL'),
          _DisplayLine('RITMO', big: true),
          _DisplayLine('PRIMERO'),
        ];
      case _AedPhase.waitForAnalysis:
        return [
          _DisplayLine('ESPERE'),
          _DisplayLine('ANÁLISIS', big: true),
          _DisplayLine('DEL RITMO'),
        ];
      case _AedPhase.decisionPrompt:
        return [
          _DisplayLine('ANÁLISIS', big: true),
          _DisplayLine('COMPLETADO', big: true),
          _DisplayLine(''),
          _DisplayLine('¿DESCARGA', color: const Color(0xFFFFA500)),
          _DisplayLine('RECOMENDADA?', color: const Color(0xFFFFA500)),
        ];
      case _AedPhase.decisionCorrect:
        return [
          _DisplayLine('CORRECTO', big: true, color: const Color(0xFF10B981)),
          _DisplayLine(''),
          _DisplayLine(_currentScenario.rhythmType == AedRhythmType.shockable
              ? 'DESCARGA INDICADA'
              : 'RCP INDICADA'),
        ];
      case _AedPhase.decisionWrong:
        return [
          _DisplayLine('INCORRECTO', big: true, color: const Color(0xFFEF4444)),
          _DisplayLine(''),
          _DisplayLine(_currentScenario.rhythmType == AedRhythmType.shockable
              ? 'ERA DESFIBRILABLE'
              : 'NO ERA DESFIBRILABLE'),
        ];
      case _AedPhase.completed:
        return [
          _DisplayLine('ESCENARIO', big: true),
          _DisplayLine('COMPLETADO', big: true),
          _DisplayLine(''),
          _DisplayLine('PACIENTE ESTABLE'),
        ];
    }
  }
}

// ── Supporting widgets ───────────────────────────────────────

class _AedButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final bool isDestructive;
  final VoidCallback? onPressed;

  const _AedButton({
    required this.icon,
    required this.label,
    required this.color,
    this.enabled = true,
    this.isDestructive = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isDestructive ? Colors.grey : color;
    return Opacity(
      opacity: enabled ? 1.0 : 0.35,
      child: SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: effectiveColor.withValues(alpha: 0.12),
            foregroundColor: enabled ? effectiveColor : Colors.grey,
            disabledBackgroundColor: effectiveColor.withValues(alpha: 0.05),
            disabledForegroundColor: Colors.grey.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              side: BorderSide(
                color: enabled
                    ? effectiveColor.withValues(alpha: 0.4)
                    : Colors.grey.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisplayLine {
  final String text;
  final bool big;
  final Color? color;

  const _DisplayLine(this.text, {this.big = false, this.color});
}
