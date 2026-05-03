import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../services/ble_service.dart';
import '../core/rcp_engine.dart';
import 'auth_provider.dart';
import '../services/session_service.dart';
import '../services/audio_service.dart';
import 'session_provider.dart';

enum SessionMode { training, evaluation }

final sessionModeProvider = StateProvider<SessionMode>((ref) => SessionMode.training);
final rcpEngineProvider = Provider((ref) => RcpEngine.instance);

class BleSessionNotifier extends Notifier<ActiveSessionState> {
  Timer? _timer;
  StreamSubscription<RcpTelemetry>? _telemetrySub;
  int _lastCount = 0;

  @override
  ActiveSessionState build() {
    // Escuchar cambios en el servicio BLE para actualizar el estado de conexión
    ref.listen(bleServiceProvider, (previous, next) {
      if (state.isConnected != next.isConnected) {
        state = state.copyWith(isConnected: next.isConnected);
      }
    });

    return const ActiveSessionState();
  }

  Future<void> startSession(String scenarioId, {String? courseId}) async {
    final sessionService = ref.read(sessionServiceProvider);
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('No hay usuario autenticado.');

    final bleService = ref.read(bleServiceProvider);
    final engine = ref.read(rcpEngineProvider);
    
    engine.reset();

    final session = await sessionService.startSession(
      studentId: user.id,
      studentName: user.fullName,
      scenarioId: scenarioId,
      courseId: courseId,
    );

    final audioService = ref.read(audioServiceProvider);
    await audioService.init();

    state = state.copyWith(
      session: session, 
      isConnected: bleService.isConnected,
      elapsed: Duration.zero,
      depthHistory: [],
    );

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsed: state.elapsed + const Duration(seconds: 1));
    });

    _telemetrySub?.cancel();
    _telemetrySub = bleService.telemetryStream.listen((data) {
      _processBleTelemetry(data, audioService);
    });
  }

  void _processBleTelemetry(RcpTelemetry data, AudioService audioService) {
    final engine = ref.read(rcpEngineProvider);
    final mode = ref.read(sessionModeProvider);
    
    engine.evaluate(data);
    bool nuevaComp = false;

    // Detectar si el hardware incrementó el contador
    if (engine.compresionesTotales > _lastCount) {
      nuevaComp = true;
      _lastCount = engine.compresionesTotales;
    }

    // Audio Feedback local instantáneo (sólo en modo entrenamiento)
    if (nuevaComp && mode == SessionMode.training) {
      if (engine.compresionesTotales % 5 == 0) {
        if (!engine.compresionCorrecta) {
          if (engine.picoProfundidad < RcpEngine.ahaMinDepthMm) {
            audioService.playFeedback('mas_profundo');
          } else if (engine.picoProfundidad > RcpEngine.ahaMaxDepthMm) {
            audioService.playFeedback('menos_profundo');
          } else if (engine.currentCpm < RcpEngine.ahaMinRateCpm) {
            audioService.playFeedback('mas_rapido');
          }
        } else {
          audioService.playFeedback('excelente');
        }
      }
    }

    // Actualizar historial de profundidad para la onda
    final newHistory = [...state.depthHistory, data.depthMm];
    final trimmed = newHistory.length > 50
        ? newHistory.sublist(newHistory.length - 50)
        : newHistory;

    // Actualizar UI periódicamente (o si hay nueva compresión)
    // Siempre actualizamos el estado para que los contadores del hardware se reflejen de inmediato
    _updateMetricsState(engine, data, trimmed);
  }

  void _updateMetricsState(RcpEngine engine, RcpTelemetry data, List<double> history) {
    double correctPct = engine.compresionesTotales > 0 
        ? (engine.compresionesCorrectas / engine.compresionesTotales) * 100 
        : 0;
        
    double recoilPct = engine.compresionesTotales > 0 
        ? (engine.recoilCorrectos / engine.compresionesTotales) * 100 
        : 100;

    final liveData = LiveSessionData(
      depthMm: data.depthMm,
      ratePerMin: engine.currentCpm,
      forceKg: data.forceKg,
      compressionCount: engine.compresionesTotales,
      correctCompressionCount: engine.compresionesCorrectas,
      correctPct: correctPct,
      sessionScore: _calculateTempScore(engine), 
      decompressedFully: engine.recoilOk,
      recoilPct: recoilPct,
      pauseCount: engine.pausasCount,
      maxPauseSec: engine.maxPausaSeg,
      sensorOk: true,
      calibrated: true,
    );

    state = state.copyWith(liveData: liveData, depthHistory: history);
  }

  double _calculateTempScore(RcpEngine engine) {
    if (engine.compresionesTotales == 0) return 0;
    double score = 0;
    score += (engine.compresionesCorrectas / engine.compresionesTotales) * 40;
    score += (engine.recoilCorrectos / engine.compresionesTotales) * 30;
    score += (engine.freqCorrectas / engine.compresionesTotales) * 30;
    return score.clamp(0, 100);
  }

  Future<SessionModel> endSession() async {
    _timer?.cancel();
    _telemetrySub?.cancel();
    
    final currentSession = state.session;
    if (currentSession == null) throw Exception('No hay sesión activa.');

    final engine = ref.read(rcpEngineProvider);
    final sessionService = ref.read(sessionServiceProvider);

    // Calcular métricas finales
    double depthScore = engine.compresionesTotales > 0 ? (engine.compresionesCorrectas / engine.compresionesTotales * 100) : 0;
    double recoilScore = engine.compresionesTotales > 0 ? (engine.recoilCorrectos / engine.compresionesTotales * 100) : 100;
    double rateScore = engine.compresionesTotales > 0 ? (engine.freqCorrectas / engine.compresionesTotales * 100) : 0;
    
    // Chest Compression Fraction (CCF) - Simplificado para este MVP
    double ccf = engine.pausasCount > 0 ? (1.0 - (engine.maxPausaSeg / 120.0)) * 100 : 100; 

    final metrics = SessionMetrics(
      totalCompressions: engine.compresionesTotales,
      correctCompressions: engine.compresionesCorrectas,
      averageDepthMm: engine.compresionesTotales > 0 ? (engine.sumProfundidad / engine.compresionesTotales) : 0,
      averageRatePerMin: engine.compresionesTotales > 0 ? (engine.sumBpm / engine.compresionesTotales) : 0,
      correctCompressionsPct: depthScore,
      averageForcKg: engine.compresionesTotales > 0 ? (engine.sumFuerza / (state.depthHistory.length > 0 ? state.depthHistory.length : 1)) : 0,
      recoilPct: recoilScore,
      interruptionCount: engine.pausasCount,
      maxPauseSeconds: engine.maxPausaSeg,
      ccfPct: ccf.clamp(0, 100),
      depthScore: depthScore,
      rateScore: rateScore,
      recoilScore: recoilScore,
      score: _calculateTempScore(engine),
      approved: _calculateTempScore(engine) >= 70,
      violations: [], 
    );

    try {
      final finished = await sessionService.endSession(
        currentSession.id, 
        metrics, 
        state.elapsed.inSeconds,
      );
      
      await sessionService.updateCourseProgressAfterSession(currentSession.studentId, metrics);
      state = state.copyWith(session: finished, isConnected: false);
      
      debugPrint("✅ Sesión guardada profesionalmente: ${finished.id}");
      return finished;
    } catch (e) {
      debugPrint("❌ Error al finalizar sesión (guardando localmente): $e");
      final localFinished = currentSession.copyWithEnd(metrics: metrics, endedAt: DateTime.now());
      state = state.copyWith(session: localFinished, isConnected: false);
      return localFinished;
    } finally {
      // Forzar la actualización del historial siempre
      ref.invalidate(sessionsHistoryProvider);
    }
  }
}

final bleActiveSessionProvider = NotifierProvider<BleSessionNotifier, ActiveSessionState>(BleSessionNotifier.new);
