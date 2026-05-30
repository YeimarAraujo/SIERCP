import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/features/session/data/models/session.dart';
import 'package:siercp/features/devices/data/ble_service.dart';
import 'package:siercp/core/utils/rcp_engine.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/session/data/session_service.dart';
import 'package:siercp/core/services/audio_service.dart';
import 'package:siercp/features/session/presentation/providers/session_provider.dart';
import 'package:siercp/core/providers/org_context_provider.dart';
import 'package:siercp/core/services/leaderboard_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionMode { training, evaluation }

final sessionModeProvider =
    StateProvider<SessionMode>((ref) => SessionMode.training);
final rcpEngineProvider = Provider((ref) => RcpEngine.instance);

class BleSessionNotifier extends Notifier<ActiveSessionState> {
  Timer? _timer;
  StreamSubscription<RcpTelemetry>? _telemetrySub;
  int _lastCount = 0;
  String? _rtdbInstitutionId;
  String? _rtdbCourseId;
  int _heartbeatTick = 0;
  DateTime? _lastTelemetryPush;

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

    // Obtener institutionId: primero del contexto de org activa;
    // si el estudiante no tiene membership (solo enrollment), leerlo
    // directamente del documento del curso para registrar la sesión
    // en el path RTDB correcto (institutionId/courseId/sessionId).
    var institutionId = ref.read(orgContextProvider).activeOrgId ?? '';
    if (institutionId.isEmpty && courseId != null && courseId.isNotEmpty) {
      try {
        final courseDoc = await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .get();
        if (courseDoc.exists) {
          institutionId =
              (courseDoc.data()?['institutionId'] as String?) ?? '';
        }
      } catch (_) {}
    }

    engine.reset();
    _lastCount = 0;

    final session = await sessionService.startSession(
      studentId: user.id,
      studentName: user.fullName,
      scenarioId: scenarioId,
      courseId: courseId,
      institutionId: institutionId,
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
      state =
          state.copyWith(elapsed: state.elapsed + const Duration(seconds: 1));
    });

    _registerLiveSessionInRtdb(session, courseId, institutionId);

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
      // Si la compresión fue incorrecta, dar feedback más seguido (cada 3)
      // Si fue excelente, dar feedback cada 10 para no saturar
      final bool isCorrect = engine.lastCompresionCorrecta;
      final int interval = isCorrect ? 10 : 3;

      if (engine.compresionesTotales % interval == 0) {
        if (!isCorrect) {
          // Prioridad 1: Profundidad (Crítico)
          if (engine.lastPicoProfundidad < RcpEngine.ahaMinDepthMm) {
            audioService.playFeedback('mas_profundo');
          } else if (engine.lastPicoProfundidad > RcpEngine.ahaMaxDepthMm) {
            audioService.playFeedback('menos_profundo');
          }
          // Prioridad 2: Frecuencia
          else if (engine.lastBpm < RcpEngine.ahaMinRateCpm) {
            audioService.playFeedback('mas_rapido');
          } else if (engine.lastBpm > RcpEngine.ahaMaxRateCpm) {
            audioService.playFeedback('mas_lento');
          }
          // Prioridad 3: Recoil (Si profundidad y frecuencia están bien pero falló algo, suele ser recoil)
          else if (!engine.recoilOk) {
            // No hay audio específico para recoil en AudioService aún,
            // pero podríamos añadirlo o simplemente no decir nada.
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

  void _updateMetricsState(
      RcpEngine engine, RcpTelemetry data, List<double> history) {
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

    _writeTelemetryToRtdb(liveData);
    state = state.copyWith(liveData: liveData, depthHistory: history);
  }

  void _updateLeaderboard(double sessionScore) {
    final user = ref.read(currentUserProvider);
    final institutionId = ref.read(orgContextProvider).activeOrgId;
    if (user == null || institutionId == null) return;

    final prevTotal = user.stats?.totalSessions ?? 0;
    final prevAvg   = user.stats?.averageScore  ?? 0.0;
    final newTotal  = prevTotal + 1;
    final newAvg    = ((prevAvg * prevTotal) + sessionScore) / newTotal;

    ref.read(leaderboardServiceProvider).updateEntry(
      uid:           user.id,
      institutionId: institutionId,
      displayName:   user.fullName,
      averageScore:  newAvg,
      totalSessions: newTotal,
    ).catchError((e) {
      debugPrint('[Leaderboard] Error al actualizar: $e');
    });
  }

  double _calculateTempScore(RcpEngine engine) {
    if (engine.compresionesTotales == 0) return 0;
    double score = 0;
    score += (engine.compresionesCorrectas / engine.compresionesTotales) * 40;
    score += (engine.recoilCorrectos / engine.compresionesTotales) * 30;
    score += (engine.freqCorrectas / engine.compresionesTotales) * 30;
    return score.clamp(0, 100);
  }

  Future<({SessionModel session, bool synced})> endSession() async {
    _timer?.cancel();
    _telemetrySub?.cancel();

    final currentSession = state.session;
    if (currentSession == null) throw Exception('No hay sesión activa.');

    _cleanupRtdb(currentSession.id);

    final engine = ref.read(rcpEngineProvider);
    final sessionService = ref.read(sessionServiceProvider);

    // Calcular métricas finales
    double depthScore = engine.compresionesTotales > 0
        ? (engine.compresionesCorrectas / engine.compresionesTotales * 100)
        : 0;
    double recoilScore = engine.compresionesTotales > 0
        ? (engine.recoilCorrectos / engine.compresionesTotales * 100)
        : 100;
    double rateScore = engine.compresionesTotales > 0
        ? (engine.freqCorrectas / engine.compresionesTotales * 100)
        : 0;

    // Chest Compression Fraction (CCF) - Simplificado para este MVP
    double ccf = engine.pausasCount > 0
        ? (1.0 - (engine.maxPausaSeg / 120.0)) * 100
        : 100;

    final metrics = SessionMetrics(
      totalCompressions: engine.compresionesTotales,
      correctCompressions: engine.compresionesCorrectas,
      averageDepthMm: engine.compresionesTotales > 0
          ? (engine.sumProfundidad / engine.compresionesTotales)
          : 0,
      averageRatePerMin: engine.compresionesTotales > 0
          ? (engine.sumBpm / engine.compresionesTotales)
          : 0,
      correctCompressionsPct: depthScore,
      averageForceKg: engine.compresionesTotales > 0
          ? (engine.sumFuerza /
              (state.depthHistory.isNotEmpty ? state.depthHistory.length : 1))
          : 0,
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

    // Mandar el RESET al hardware de inmediato tras capturar los datos
    // para que el maniquí esté en 0 para el siguiente estudiante
    // sin esperar a que termine la sincronización con la nube.
    try {
      ref.read(bleServiceProvider).resetHardwareCounters();
    } catch (e) {
      debugPrint("⚠️ No se pudo resetear hardware: $e");
    }

    try {
      final finished = await sessionService.endSession(
        currentSession.id,
        metrics,
        state.elapsed.inSeconds,
      );

      await sessionService.updateCourseProgressAfterSession(
          currentSession.studentId, metrics);
      state = state.copyWith(session: finished, isConnected: false);

      // Actualizar leaderboard institucional (fire-and-forget, no bloquea UI)
      _updateLeaderboard(metrics.score);

      debugPrint("Sesión guardada profesionalmente: ${finished.id}");
      return (session: finished, synced: true);
    } catch (e) {
      debugPrint("Error al finalizar sesión (guardando localmente): $e");
      final localFinished =
          currentSession.copyWithEnd(metrics: metrics, endedAt: DateTime.now());
      state = state.copyWith(session: localFinished, isConnected: false);
      return (session: localFinished, synced: false);
    } finally {
      // Forzar la actualización del historial siempre
      ref.invalidate(sessionsHistoryProvider);
    }
  }
  void _registerLiveSessionInRtdb(
      SessionModel session, String? courseId, String institutionId) {
    if (session.id.startsWith('offline_') || session.id.startsWith('error_')) {
      return;
    }
    _rtdbInstitutionId = institutionId.isEmpty ? 'no_org' : institutionId;
    _rtdbCourseId = (courseId != null && courseId.isNotEmpty) ? courseId : 'free';
    _heartbeatTick = 0;
    _lastTelemetryPush = null;

    final liveRef = FirebaseDatabase.instance
        .ref('live_sessions/$_rtdbInstitutionId/$_rtdbCourseId/${session.id}');

    liveRef.set({
      'studentId':     session.studentId,
      'studentName':   session.studentName,
      'scenarioId':    session.scenarioId    ?? '',
      'scenarioTitle': session.scenarioTitle ?? '',
      'manikinId':     session.manikinId     ?? '',
      'courseId':      _rtdbCourseId,
      'institutionId': _rtdbInstitutionId,
      'status':        'active',
      'startedAt':     ServerValue.timestamp,
      'heartbeat':     ServerValue.timestamp,
    }).catchError((e) => debugPrint('[RTDB] Error registrando sesión: $e'));

    // Limpieza automática si la app muere sin llamar endSession
    liveRef.onDisconnect().remove().catchError((_) {});
  }

  void _writeTelemetryToRtdb(LiveSessionData data) {
    final sessionId = state.session?.id;
    if (sessionId == null ||
        sessionId.startsWith('offline_') ||
        sessionId.startsWith('error_')) {
      return;
    }
    final now = DateTime.now();
    if (_lastTelemetryPush != null &&
        now.difference(_lastTelemetryPush!).inMilliseconds < 200) {
      return;
    }
    _lastTelemetryPush = now;

    FirebaseDatabase.instance.ref('telemetry/$sessionId').update({
      'depthMm':                data.depthMm,
      'ratePerMin':             data.ratePerMin,
      'forceKg':                data.forceKg,
      'compressionCount':       data.compressionCount,
      'correctCompressionCount': data.correctCompressionCount,
      'correctPct':             data.correctPct,
      'sessionScore':           data.sessionScore,
      'decompressedFully':      data.decompressedFully,
      'recoilPct':              data.recoilPct,
      'pauseCount':             data.pauseCount,
      'maxPauseSec':            data.maxPauseSec,
      'sensorOk':               data.sensorOk,
      'calibrated':             data.calibrated,
      'updatedAt':              ServerValue.timestamp,
    }).catchError((e) => debugPrint('[RTDB] Error telemetría: $e'));

    _heartbeatTick++;
    if (_heartbeatTick % 30 == 0 &&
        _rtdbInstitutionId != null &&
        _rtdbCourseId != null) {
      FirebaseDatabase.instance
          .ref('live_sessions/$_rtdbInstitutionId/$_rtdbCourseId/$sessionId/heartbeat')
          .set(ServerValue.timestamp)
          .catchError((_) {});
    }
  }

  void _cleanupRtdb(String sessionId) {
    if (sessionId.startsWith('offline_') || sessionId.startsWith('error_')) {
      return;
    }
    if (_rtdbInstitutionId != null && _rtdbCourseId != null) {
      FirebaseDatabase.instance
          .ref('live_sessions/$_rtdbInstitutionId/$_rtdbCourseId/$sessionId')
          .remove()
          .catchError((_) {});
    }
    FirebaseDatabase.instance
        .ref('telemetry/$sessionId')
        .remove()
        .catchError((_) {});
    _rtdbInstitutionId = null;
    _rtdbCourseId = null;
  }
}

final bleActiveSessionProvider =
    NotifierProvider<BleSessionNotifier, ActiveSessionState>(
        BleSessionNotifier.new);
