import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/features/session/data/models/session.dart';
import 'package:siercp/features/courses/data/models/alert_course.dart';
import 'package:siercp/features/users/data/models/user.dart';
import 'package:siercp/features/session/data/session_service.dart';
import 'package:siercp/features/devices/data/device_service.dart';
import 'package:siercp/core/services/audio_service.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/guides/presentation/providers/guide_provider.dart';
import 'package:siercp/features/reports/presentation/providers/report_cache_provider.dart';
import 'package:siercp/core/services/firestore_service.dart';
import 'package:siercp/features/session/presentation/providers/ble_session_provider.dart';
import 'package:siercp/core/providers/org_context_provider.dart';

final courseActiveSessionsProvider = StreamProvider.family<List<SessionModel>, String>((ref, courseId) {
  return ref.watch(firestoreServiceProvider).watchCourseActiveSessions(courseId);
});

final studentSessionsProvider = FutureProvider.family<List<SessionModel>, String>((ref, studentId) {
  return ref.read(firestoreServiceProvider).getStudentSessions(studentId);
});

final audioServiceProvider = Provider((ref) => AudioService());

// ─── Active Session State ──────────────────────────────────────────────────────
class ActiveSessionState {
  final SessionModel? session;
  final LiveSessionData liveData;
  final List<double> depthHistory;
  final List<AlertModel> alerts;
  final bool isConnected;
  final Duration elapsed;
  final DeviceInfo?
      initialDeviceInfo; // Guarda el estado cuando la sesión arranca
  final DeviceInfo?
      lastDeviceInfo; // Mantiene el último estado completo del sensor

  const ActiveSessionState({
    this.session,
    this.liveData = const LiveSessionData(
      depthMm: 0,
      ratePerMin: 0,
      forceKg: 0,
      compressionCount: 0,
      correctPct: 0,
      decompressedFully: false,
    ),
    this.depthHistory = const [],
    this.alerts = const [],
    this.isConnected = false,
    this.elapsed = Duration.zero,
    this.initialDeviceInfo,
    this.lastDeviceInfo,
  });

  ActiveSessionState copyWith({
    SessionModel? session,
    LiveSessionData? liveData,
    List<double>? depthHistory,
    List<AlertModel>? alerts,
    bool? isConnected,
    Duration? elapsed,
    DeviceInfo? initialDeviceInfo,
    DeviceInfo? lastDeviceInfo,
  }) =>
      ActiveSessionState(
        session: session ?? this.session,
        liveData: liveData ?? this.liveData,
        depthHistory: depthHistory ?? this.depthHistory,
        alerts: alerts ?? this.alerts,
        isConnected: isConnected ?? this.isConnected,
        elapsed: elapsed ?? this.elapsed,
        initialDeviceInfo: initialDeviceInfo ?? this.initialDeviceInfo,
        lastDeviceInfo: lastDeviceInfo ?? this.lastDeviceInfo,
      );
}

// ─── Active Session Notifier ───────────────────────────────────────────────────
class ActiveSessionNotifier extends Notifier<ActiveSessionState> {
  Timer? _timer;
  StreamSubscription<DeviceInfo?>? _telemetrySub;
  StreamSubscription<List<DeviceInfo>>? _telemetrySubMulti;

  @override
  ActiveSessionState build() => const ActiveSessionState();

  Future<void> startSession(String scenarioId, {String? courseId}) async {
    final sessionService = ref.read(sessionServiceProvider);
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('No hay usuario autenticado.');

    // Verificar si hay dispositivos activos y si sus sensores están OK antes de iniciar
    final deviceService = ref.read(deviceServiceProvider);
    final selectedMac = ref.read(selectedDeviceMacProvider);
    DeviceInfo? activeDevice;

    if (selectedMac != null && selectedMac.isNotEmpty) {
      activeDevice = await deviceService.streamDevice(selectedMac).first.timeout(const Duration(seconds: 3), onTimeout: () => null);
    } else {
      final devices = await deviceService.getAvailableDevices();
      if (devices.isNotEmpty) {
        activeDevice = devices.first;
      }
    }

    if (activeDevice != null && !activeDevice.sensorOk) {
      throw Exception(
          'Sensor de profundidad no disponible en el maniquí. Requerido para sesión válida.');
    }

    // RESET de estado para nueva sesión
    state = const ActiveSessionState();

    final session = await sessionService.startSession(
      studentId: user.id,
      studentName: user.fullName,
      scenarioId: scenarioId,
      courseId: courseId,
    );

    // Audio de inicio del escenario (ahora manejado por la UI con el contador)
    final audioService = ref.read(audioServiceProvider);
    await audioService.init();
    // audioService.playStart(); // Se movió a session_screen.dart para sincronizar con 3, 2, 1

    state = state.copyWith(session: session, isConnected: true);

    // Registrar sesión activa en RTDB para que el Web pueda monitorearla
    _registerLiveSessionInRtdb(session, courseId);

    // Timer de duración
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state =
          state.copyWith(elapsed: state.elapsed + const Duration(seconds: 1));
    });

    _startFirebaseTelemetryListener(audioService);
  }

  // ── RTDB helpers (telemetría en tiempo real para el monitor Web) ─────────────

  /// Registra la sesión como activa en RTDB para que el Web pueda listarla.
  void _registerLiveSessionInRtdb(SessionModel session, String? courseId) {
    if (session.id.startsWith('offline_') || session.id.startsWith('error_')) {
      return;
    }
    try {
      final orgCtx = ref.read(orgContextProvider);
      final institutionId = orgCtx.activeOrgId ?? 'no_org';
      final cId = courseId ?? 'free';
      FirebaseDatabase.instance
          .ref('live_sessions/$institutionId/$cId/${session.id}')
          .set({
        'studentId': session.studentId,
        'studentName': session.studentName,
        'scenarioId': session.scenarioId ?? '',
        'scenarioTitle': session.scenarioTitle ?? '',
        'manikinId': session.manikinId ?? '',
        'courseId': cId,
        'institutionId': institutionId,
        'status': 'active',
        'startedAt': ServerValue.timestamp,
        'heartbeat': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('[RTDB] Error registrando sesión: $e');
    }
  }

  /// Escribe datos de telemetría procesados en RTDB para el monitor Web.
  void _writeTelemetryToRtdb(LiveSessionData data) {
    final sessionId = state.session?.id;
    if (sessionId == null ||
        sessionId.startsWith('offline_') ||
        sessionId.startsWith('error_')) {
      return;
    }
    try {
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
      });
    } catch (e) {
      debugPrint('[RTDB] Error escribiendo telemetría: $e');
    }
  }

  /// Limpia los nodos RTDB al finalizar o abortar la sesión.
  void _cleanupRtdb(SessionModel session) {
    if (session.id.startsWith('offline_') || session.id.startsWith('error_')) {
      return;
    }
    try {
      final orgCtx = ref.read(orgContextProvider);
      final institutionId = orgCtx.activeOrgId ?? 'no_org';
      final cId = session.courseId ?? 'free';
      FirebaseDatabase.instance
          .ref('live_sessions/$institutionId/$cId/${session.id}')
          .remove();
      // La telemetría se mantiene 5 min para consulta post-sesión;
      // una Cloud Function la elimina después.
    } catch (e) {
      debugPrint('[RTDB] Error limpiando sesión: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────

  void _startFirebaseTelemetryListener(AudioService audioService) {
    final deviceService = ref.read(deviceServiceProvider);
    final selectedMac = ref.read(selectedDeviceMacProvider);

    if (selectedMac != null && selectedMac.isNotEmpty) {
      _telemetrySub = deviceService.streamDevice(selectedMac).listen(
        (deviceInfo) {
          if (deviceInfo != null && deviceInfo.isActive) {
            _processFirebaseTelemetry(deviceInfo, audioService);
          }
        },
        onError: (_) {},
      );
    } else {
      _telemetrySubMulti =
          deviceService.streamAvailableDevices().listen((devices) {
        final active = devices.where((d) => d.isActive).toList();
        if (active.isNotEmpty) {
          _processFirebaseTelemetry(active.first, audioService);
        }
      }, onError: (_) {});
    }
  }

  void _processFirebaseTelemetry(
      DeviceInfo deviceInfo, AudioService audioService) {
    // Si el sensor láser falla en medio de la sesión, generamos una alerta
    if (!deviceInfo.sensorOk) {
      if (!state.alerts
          .any((a) => a.message.contains('Sensor de profundidad'))) {
        final alert = AlertModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sessionId: state.session?.id ?? '',
          type: AlertType.error,
          title: 'Error de Sensor',
          message:
              'El sensor de profundidad láser se ha desconectado. Las métricas serán imprecisas.',
          timestamp: DateTime.now(),
        );
        state =
            state.copyWith(alerts: [alert, ...state.alerts].take(5).toList());
      }
    }

    // Comprobamos si hubo una nueva compresión (aseguramos que sea incremental para evitar fluctuaciones)
    final int rawCompressions = deviceInfo.compresiones;
    bool nuevaCompresion =
        rawCompressions > (state.lastDeviceInfo?.compresiones ?? 0);

    // Logging de telemetría para depuración (traceability)
    debugPrint(
        '[Telemetry] MAC: ${deviceInfo.macAddress} | Raw CP: $rawCompressions | Correct: ${deviceInfo.compresionesCorrectas} | isActive: ${deviceInfo.isActive}');

    // Audio Feedback de Flutter (opcional, el ESP32 también lo tiene con JQ8900)
    if (nuevaCompresion && deviceInfo.compresiones > 0) {
      // Usar lógica unificada de intervalos (3 para error, 10 para excelente)
      final bool isCorrect = deviceInfo.compresionCorrecta;
      final int interval = isCorrect ? 10 : 3;

      if (deviceInfo.compresiones % interval == 0) {
        if (!isCorrect) {
          // Prioridad 1: Profundidad
          if (deviceInfo.profundidadMm < AppConstants.ahaMinDepthMm) {
            audioService.playFeedback('mas_profundo');
          } else if (deviceInfo.profundidadMm > AppConstants.ahaMaxDepthMm) {
            audioService.playFeedback('menos_profundo');
          } 
          // Prioridad 2: Frecuencia
          else if (deviceInfo.frecuenciaCpm < AppConstants.ahaMinRatePerMin) {
            audioService.playFeedback('mas_rapido');
          } else if (deviceInfo.frecuenciaCpm > AppConstants.ahaMaxRatePerMin) {
            audioService.playFeedback('mas_lento');
          }
        } else {
          audioService.playFeedback('excelente');
        }
      }
    }

    // Guardar el offset inicial si es el primer dato que recibimos en esta sesión
    if (state.initialDeviceInfo == null) {
      state = state.copyWith(initialDeviceInfo: deviceInfo);
    }

    final initial = state.initialDeviceInfo;

    final metrics = _computeSessionMetrics(deviceInfo, initial, state.elapsed);

    final data = LiveSessionData(
      depthMm: deviceInfo.profundidadMm, // Instantaneous
      ratePerMin: deviceInfo.frecuenciaCpm, // Instantaneous
      forceKg: deviceInfo.fuerzaKg, // Instantaneous
      compressionCount: metrics.totalCompressions,
      correctCompressionCount: metrics.correctCompressions,
      correctPct: metrics.correctCompressionsPct,
      sessionScore: metrics.score, // Real-time isolated score
      decompressedFully: deviceInfo.recoilOk, // Instantaneous
      recoilPct: metrics.recoilPct, // Session average
      oxygen: deviceInfo.oxigeno,
      pauseCount: metrics.interruptionCount,
      maxPauseSec: metrics.maxPauseSeconds,
      sensorOk: deviceInfo.sensorOk,
      calibrated: deviceInfo.calibrado,
    );

    final newHistory = [...state.depthHistory, data.depthMm];
    final trimmed = newHistory.length > 40
        ? newHistory.sublist(newHistory.length - 40)
        : newHistory;

    // Escribe telemetría a RTDB para el monitor Web (no Firestore)
    _writeTelemetryToRtdb(data);

    state = state.copyWith(
      liveData: data,
      depthHistory: trimmed,
      lastDeviceInfo: deviceInfo,
    );
  }

  Future<SessionModel> endSession() async {
    final currentSession = state.session;
    if (currentSession == null) {
      throw Exception('No hay sesión activa para finalizar.');
    }

    // Grace Period: Esperamos 1.5 segundos para capturar los últimos paquetes de Firebase
    // que el microcontrolador envía al detectar el fin de la actividad.
    debugPrint(
        '[Session] Finalizando sesión... esperando último pulso de datos.');
    await Future.delayed(const Duration(milliseconds: 1500));

    _timer?.cancel();
    _telemetrySub?.cancel();
    _telemetrySubMulti?.cancel();
    _telemetrySub = null;
    _telemetrySubMulti = null;

    // Elimina sesión activa de RTDB
    _cleanupRtdb(currentSession);

    final sessionId = currentSession.id;
    final sessionService = ref.read(sessionServiceProvider);

    final metrics = _computeSessionMetrics(
        state.lastDeviceInfo ??
            const DeviceInfo(
                macAddress: '',
                fuerzaKg: 0,
                profundidadMm: 0,
                frecuenciaCpm: 0,
                compresiones: 0,
                compresionesCorrectas: 0,
                recoilOk: true,
                enCompresion: false,
                compresionCorrecta: true,
                calidadPct: 0,
                recoilPct: 0,
                avgProfundidadMm: 0,
                avgFuerzaKg: 0,
                pausas: 0,
                maxPausaSeg: 0,
                sensorOk: true,
                calibrado: false,
                timestamp: 0,
                isActive: false),
        state.initialDeviceInfo,
        state.elapsed);

    SessionModel finished;
    try {
      await sessionService.endSession(
          sessionId, metrics, state.elapsed.inSeconds);
      // Actualizar progreso de curso si aplica
      await sessionService.updateCourseProgressAfterSession(
          currentSession.studentId, metrics);

      final saved = await sessionService.getSession(sessionId);
      finished = saved ??
          currentSession.copyWithEnd(metrics: metrics, endedAt: DateTime.now());
    } catch (_) {
      finished =
          currentSession.copyWithEnd(metrics: metrics, endedAt: DateTime.now());
    }

    state = state.copyWith(session: finished, isConnected: false);

    // Forzar la actualización del historial de sesiones para que aparezca la recién finalizada
    ref.invalidate(sessionsHistoryProvider);

    // Invalidad cache de reportes (Requerimiento: cada vez que haya novedad borrar el guardado)
    try {
      final cache = ref.read(reportCacheProvider.notifier);
      cache.invalidateStudentReport(currentSession.studentId, currentSession.courseId ?? '');
      if (currentSession.courseId != null) {
        cache.invalidateCourseReport(currentSession.courseId!);
      }
    } catch (_) {}

    return finished;
  }

  void reset() {
    _timer?.cancel();
    _telemetrySub?.cancel();
    _telemetrySubMulti?.cancel();
    _telemetrySub = null;
    _telemetrySubMulti = null;
    if (state.session != null) {
      _cleanupRtdb(state.session!);
    }
    state = const ActiveSessionState();
  }

  SessionMetrics _computeSessionMetrics(
      DeviceInfo devInfo, DeviceInfo? initial, Duration elapsed) {
    // Cálculo robusto: Restamos el offset inicial, pero aseguramos que el resultado sea >= 0.
    // Si devInfo es menor que initial (inusual pero posible en desincronización), asumimos 0.
    int count = devInfo.compresiones - (initial?.compresiones ?? 0);
    if (count < 0) {
      debugPrint('[Warning] Conteo negativo detectado ($count). Usando 0.');
      count = 0;
    }

    debugPrint(
        '[Metrics] Final Calc: Raw(${devInfo.compresiones}) - Init(${initial?.compresiones ?? 0}) = $count CP');

    int correctCount =
        devInfo.compresionesCorrectas - (initial?.compresionesCorrectas ?? 0);
    if (correctCount < 0) correctCount = 0;

    double correctPct = 0.0;
    if (count > 0) {
      correctPct = (correctCount / count) * 100.0;
    }

    final int initialCount = initial?.compresiones ?? 0;
    final int devCount = devInfo.compresiones;

    double avgDepth = 0.0;
    double avgFuerza = 0.0;
    double recoilPct = 100.0;

    if (count > 0) {
      final double initialDepthSum =
          (initial?.avgProfundidadMm ?? 0.0) * initialCount;
      final double devDepthSum = devInfo.avgProfundidadMm * devCount;
      avgDepth = (devDepthSum - initialDepthSum) / count;
      if (avgDepth < 0) avgDepth = 0.0;

      final double initialFuerzaSum =
          (initial?.avgFuerzaKg ?? 0.0) * initialCount;
      final double devFuerzaSum = devInfo.avgFuerzaKg * devCount;
      avgFuerza = (devFuerzaSum - initialFuerzaSum) / count;
      if (avgFuerza < 0) avgFuerza = 0.0;

      final double initialRecoilSum =
          ((initial?.recoilPct ?? 100.0) / 100.0) * initialCount;
      final double devRecoilSum = (devInfo.recoilPct / 100.0) * devCount;
      recoilPct = ((devRecoilSum - initialRecoilSum) / count) * 100.0;
      recoilPct = recoilPct.clamp(0.0, 100.0);
    } else {
      recoilPct = devInfo.recoilPct;
    }

    int pausas = devInfo.pausas - (initial?.pausas ?? 0);
    if (pausas < 0) pausas = 0;

    // True Session Average Rate (CPM)
    // AHA: CPM = Total Compressions / Time in Minutes
    double avgRate = 0.0;
    if (elapsed.inSeconds > 5 && count > 0) {
      avgRate = (count / elapsed.inSeconds) * 60.0;
    } else {
      // Fallback to instantaneous if session is too short
      avgRate = devInfo.frecuenciaCpm.toDouble();
    }

    // Puntaje compuesto AHA 2025
    double depthScore = 0.0;
    if (avgDepth >= AppConstants.ahaMinDepthMm &&
        avgDepth <= AppConstants.ahaMaxDepthMm) {
      depthScore = 100.0 * AppConstants.ahaDepthWeight;
    } else if (avgDepth > 0) {
      depthScore = 50.0 * AppConstants.ahaDepthWeight;
    }

    double rateScore = 0.0;
    if (avgRate >= AppConstants.ahaMinRatePerMin &&
        avgRate <= AppConstants.ahaMaxRatePerMin) {
      rateScore = 100.0 * AppConstants.ahaRateWeight;
    } else if (avgRate > 0) {
      rateScore = 50.0 * AppConstants.ahaRateWeight;
    }

    double rScore = recoilPct * AppConstants.ahaRecoilWeight;

    double iScore = 100.0 * AppConstants.ahaInterruptionWeight;
    if (pausas > 0) {
      iScore = (iScore - (pausas * 10)).clamp(0.0, 100.0);
    }

    double totalScore = (depthScore + rateScore + rScore + iScore).clamp(0.0, 100.0);
    
    // Si no se hizo nada, el puntaje debe ser 0
    if (count == 0) {
      totalScore = 0.0;
    }

    // Violaciones
    final List<AhaViolation> violations = [];
    if (avgDepth > 0 && avgDepth < AppConstants.ahaMinDepthMm && count > 0) {
      violations.add(AhaViolation(
          type: 'error',
          message: 'Profundidad insuficiente (< 50 mm)',
          count: count));
    }
    if (avgDepth > AppConstants.ahaMaxDepthMm && count > 0) {
      violations.add(AhaViolation(
          type: 'warning',
          message: 'Compresión excesiva (> 60 mm)',
          count: count));
    }
    if (avgRate > 0 && avgRate < AppConstants.ahaMinRatePerMin && count > 0) {
      violations.add(const AhaViolation(
          type: 'error',
          message: 'Frecuencia muy lenta (< 100/min)',
          count: 1));
    }
    if (avgRate > AppConstants.ahaMaxRatePerMin && count > 0) {
      violations.add(const AhaViolation(
          type: 'warning',
          message: 'Frecuencia muy rápida (> 120/min)',
          count: 1));
    }
    if (count > 0 && count < 10) {
      violations.add(const AhaViolation(
          type: 'error',
          message: 'Muy pocas compresiones registradas',
          count: 1));
    }
    if (pausas > 0) {
      violations.add(AhaViolation(
          type: 'warning',
          message: 'Pausas mayores a 10s detectadas',
          count: pausas));
    }
    if (recoilPct < 80.0 && count > 0) {
      violations.add(const AhaViolation(
          type: 'warning', message: 'Recoil incompleto frecuente', count: 1));
    }

    double ccf = 0.0;
    if (elapsed.inSeconds > 0 && avgRate > 0) {
      // activeSeconds estimation based on average rate
      final activeSeconds = (count / avgRate) * 60.0;
      ccf = (activeSeconds / elapsed.inSeconds) * 100.0;
      ccf = ccf.clamp(0.0, 100.0);
    } else if (count > 0 && elapsed.inSeconds > 0) {
      // Basic fallback if avgRate calculation is unstable
      ccf = 100.0;
    }

    if (ccf > 0 && ccf < 60.0 && count > 0) {
      violations.add(const AhaViolation(
          type: 'error',
          message: 'Fracción de compresión (CCF) muy baja (< 60%)',
          count: 1));
    }

    return SessionMetrics(
      totalCompressions: count,
      correctCompressions: correctCount,
      averageDepthMm: avgDepth,
      averageRatePerMin: avgRate,
      correctCompressionsPct: correctPct,
      averageForceKg: avgFuerza,
      recoilPct: recoilPct,
      interruptionCount: pausas,
      maxPauseSeconds: devInfo.maxPausaSeg,
      ccfPct: ccf,
      depthScore: depthScore,
      rateScore: rateScore,
      recoilScore: rScore,
      interruptionScore: iScore,
      score: totalScore,
      approved: totalScore >= AppConstants.ahaPassScore,
      violations: violations,
    );
  }
}

// Extension to help copyWith on SessionModel
extension SessionModelCopy on SessionModel {
  SessionModel copyWithEnd({SessionMetrics? metrics, DateTime? endedAt}) {
    return SessionModel(
      id: id,
      studentId: studentId,
      studentName: studentName,
      manikinId: manikinId,
      scenarioId: scenarioId,
      scenarioTitle: scenarioTitle,
      patientType: patientType,
      status: SessionStatus.completed,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      metrics: metrics ?? this.metrics,
      courseId: courseId,
    );
  }
}

// REDIRECCIONAR AL PROVEEDOR BLE UNIFICADO
final activeSessionProvider = bleActiveSessionProvider;

// ─── Sessions History ────────────────────────────────────────────────────────
final sessionsHistoryProvider = FutureProvider<List<SessionModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(sessionServiceProvider).getSessions(user.id);
});

// ─── Scenarios ───────────────────────────────────────────────────────────────
final scenariosProvider = FutureProvider<List<ScenarioModel>>((ref) async {
  return ref.read(sessionServiceProvider).getScenarios();
});

// ─── Instructor por asignación de curso ──────────────────────────────────────
/// Detecta si el usuario es instructor en algún curso de la org activa,
/// aunque su membership tenga rol USUARIO.
/// Soluciona el caso donde admin asigna instructorId en el curso sin cambiar la membership.
final isInstructorOnCourseProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final orgCtx = ref.watch(orgContextProvider);
  if (orgCtx.isInstructor || (user.isInstructor)) return true;
  final orgId = orgCtx.activeOrgId;
  if (orgId == null || orgId.isEmpty) return false;
  return ref.read(sessionServiceProvider).isInstructorOnAnyCourse(user.id, orgId);
});

// ─── Courses ─────────────────────────────────────────────────────────────────

/// Cursos donde el usuario es INSTRUCTOR o ADMIN (cursos para gestionar).
final coursesProvider = FutureProvider<List<CourseModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final orgCtx = ref.watch(orgContextProvider);
  final effectiveRole = orgCtx.activeRole ?? user.role;
  return ref.read(sessionServiceProvider).getCoursesForUser(
    user.id,
    effectiveRole,
    institutionId: orgCtx.activeOrgId,
  );
});

/// Cursos donde el usuario está inscrito como ESTUDIANTE.
/// Se carga siempre (independientemente del rol) para el dashboard dual.
final enrolledCoursesProvider = FutureProvider<List<CourseModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(firestoreServiceProvider).getStudentCourses(user.id);
});

// ─── Alerts (Stream en tiempo real) ──────────────────────────────────────────
final recentAlertsProvider = StreamProvider<List<AlertModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  final orgCtx = ref.watch(orgContextProvider);

  // Usar el rol efectivo (membership > global) para determinar scope de alertas
  final effectiveRole = orgCtx.activeRole ?? user.role;
  final isInstructorOrAdmin = effectiveRole == 'INSTRUCTOR' ||
      effectiveRole == 'ADMIN' ||
      user.isAdmin;

  if (isInstructorOrAdmin) {
    debugPrint('📡 Escuchando alertas para usuario: ${user.id}');
    return ref.read(sessionServiceProvider).watchInstructorAlerts(user.id);
  }

  return Stream.value([]);
});

// ─── User Stats (calculadas desde historial) ─────────────────────────────────
final userStatsProvider = Provider<UserStats?>((ref) {
  final sessionsAsync = ref.watch(sessionsHistoryProvider);
  final sessions = sessionsAsync.value ?? [];
  if (sessions.isEmpty) return null;

  final today = DateTime.now();
  final todayCount = sessions
      .where((s) =>
          s.startedAt.day == today.day &&
          s.startedAt.month == today.month &&
          s.startedAt.year == today.year)
      .length;

  final withMetrics = sessions.where((s) => s.metrics != null).toList();
  if (withMetrics.isEmpty) {
    return UserStats(sessionsToday: todayCount, totalSessions: sessions.length);
  }

  final avgScore =
      withMetrics.map((s) => s.metrics!.score).reduce((a, b) => a + b) /
          withMetrics.length;
  final bestScore =
      withMetrics.map((s) => s.metrics!.score).reduce((a, b) => a > b ? a : b);
  final totalHours =
      sessions.map((s) => s.duration.inSeconds).reduce((a, b) => a + b) /
          3600.0;
  final avgDepth = withMetrics
          .map((s) => s.metrics!.averageDepthMm)
          .reduce((a, b) => a + b) /
      withMetrics.length;
  final avgRate = withMetrics
          .map((s) => s.metrics!.averageRatePerMin)
          .reduce((a, b) => a + b) /
      withMetrics.length;

  return UserStats(
    totalSessions: sessions.length,
    sessionsToday: todayCount,
    averageScore: avgScore,
    bestScore: bestScore,
    totalHours: totalHours,
    averageDepthMm: avgDepth,
    averageRatePerMin: avgRate,
  );
});

// ─── Course Students ─────────────────────────────────────────────────────────
final courseStudentsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, courseId) {
  return ref.read(sessionServiceProvider).watchCourseStudents(courseId);
});

// ─── Course Attendance ────────────────────────────────────────────────────────
final courseAttendanceProvider = StreamProvider.family<List<Map<String, dynamic>>, ({String courseId, DateTime date})>((ref, arg) {
  return ref.read(sessionServiceProvider).watchAttendance(arg.courseId, arg.date);
});

final courseAttendanceHistoryProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, courseId) {
  return ref.read(sessionServiceProvider).watchCourseAttendanceHistory(courseId);
});

// ─── Users Status ────────────────────────────────────────────────────────────
final usersStatusProvider = StreamProvider.family<List<UserModel>, List<String>>((ref, userIds) {
  return ref.read(sessionServiceProvider).watchUsersStatus(userIds);
});

final deviceStatusProvider = FutureProvider<DeviceStatusData>((ref) async {
  try {
    return await ref.read(sessionServiceProvider).getDeviceStatus();
  } catch (_) {
    return const DeviceStatusData(isConnected: false);
  }
});
