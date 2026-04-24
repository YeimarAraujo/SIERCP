import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../models/alert_course.dart';
import '../models/user.dart';
import '../services/session_service.dart';
import '../services/device_service.dart';
import '../services/audio_service.dart';
import '../core/constants.dart';
import 'auth_provider.dart';
import 'guide_provider.dart';

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
      activeDevice = await deviceService.streamDevice(selectedMac).first;
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

    final session = await sessionService.startSession(
      studentId: user.id,
      studentName: user.fullName,
      scenarioId: scenarioId,
      courseId: courseId,
    );

    // Audio de inicio del escenario
    final audioService = ref.read(audioServiceProvider);
    await audioService.init();
    audioService.playStart();

    state = state.copyWith(session: session, isConnected: true);

    // Timer de duración
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state =
          state.copyWith(elapsed: state.elapsed + const Duration(seconds: 1));
    });

    _startFirebaseTelemetryListener(audioService);
  }

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
    if (nuevaCompresion &&
        deviceInfo.compresiones > 0 &&
        deviceInfo.compresiones % 5 == 0) {
      if (deviceInfo.profundidadMm < AppConstants.ahaMinDepthMm) {
        audioService.playFeedback('mas_profundo');
      } else if (deviceInfo.frecuenciaCpm < AppConstants.ahaMinRatePerMin) {
        audioService.playFeedback('mas_rapido');
      } else {
        audioService.playFeedback('bien');
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

    state = state.copyWith(
      liveData: data,
      depthHistory: trimmed,
      lastDeviceInfo: deviceInfo, // Guardamos para usar en endSession
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
    final sessionId = currentSession.id;
    final sessionService = ref.read(sessionServiceProvider);

    final metrics = _computeSessionMetrics(
        state.lastDeviceInfo ??
            DeviceInfo(
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

    return finished;
  }

  void reset() {
    _timer?.cancel();
    _telemetrySub?.cancel();
    _telemetrySubMulti?.cancel();
    _telemetrySub = null;
    _telemetrySubMulti = null;
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

    final totalScore =
        (depthScore + rateScore + rScore + iScore).clamp(0.0, 100.0);

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
      averageForcKg: avgFuerza,
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

final activeSessionProvider =
    NotifierProvider<ActiveSessionNotifier, ActiveSessionState>(
  ActiveSessionNotifier.new,
);

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

// ─── Courses ─────────────────────────────────────────────────────────────────
final coursesProvider = FutureProvider<List<CourseModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(sessionServiceProvider).getCoursesForUser(user.id, user.role);
});

// ─── Alerts (últimas de sesiones cerradas) ────────────────────────────────────
final recentAlertsProvider = FutureProvider<List<AlertModel>>((ref) async {
  return [];
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

// ─── Device Status ────────────────────────────────────────────────────────────
final deviceStatusProvider = FutureProvider<DeviceStatusData>((ref) async {
  try {
    return await ref.read(sessionServiceProvider).getDeviceStatus();
  } catch (_) {
    return const DeviceStatusData(isConnected: false);
  }
});
