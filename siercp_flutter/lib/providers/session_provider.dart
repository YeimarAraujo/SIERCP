import 'dart:async';
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
  final DeviceInfo? lastDeviceInfo; // Mantiene el último estado completo del sensor

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
    this.lastDeviceInfo,
  });

  ActiveSessionState copyWith({
    SessionModel? session,
    LiveSessionData? liveData,
    List<double>? depthHistory,
    List<AlertModel>? alerts,
    bool? isConnected,
    Duration? elapsed,
    DeviceInfo? lastDeviceInfo,
  }) =>
      ActiveSessionState(
        session: session ?? this.session,
        liveData: liveData ?? this.liveData,
        depthHistory: depthHistory ?? this.depthHistory,
        alerts: alerts ?? this.alerts,
        isConnected: isConnected ?? this.isConnected,
        elapsed: elapsed ?? this.elapsed,
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

  Future<void> startSession(String scenarioId) async {
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
      throw Exception('Sensor de profundidad no disponible en el maniquí. Requerido para sesión válida.');
    }

    final session = await sessionService.startSession(
      studentId: user.id,
      studentName: user.fullName,
      scenarioId: scenarioId,
    );

    // Audio de inicio del escenario
    final audioService = ref.read(audioServiceProvider);
    await audioService.init();
    audioService.playStart();

    state = state.copyWith(session: session, isConnected: true);

    // Timer de duración
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsed: state.elapsed + const Duration(seconds: 1));
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
      _telemetrySubMulti = deviceService.streamAvailableDevices().listen((devices) {
        final active = devices.where((d) => d.isActive).toList();
        if (active.isNotEmpty) {
          _processFirebaseTelemetry(active.first, audioService);
        }
      }, onError: (_) {});
    }
  }

  void _processFirebaseTelemetry(DeviceInfo deviceInfo, AudioService audioService) {
    // Si el sensor láser falla en medio de la sesión, generamos una alerta
    if (!deviceInfo.sensorOk) {
      if (!state.alerts.any((a) => a.message.contains('Sensor de profundidad'))) {
        final alert = AlertModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sessionId: state.session?.id ?? '',
          type: AlertType.error,
          title: 'Error de Sensor',
          message: 'El sensor de profundidad láser se ha desconectado. Las métricas serán imprecisas.',
          timestamp: DateTime.now(),
        );
        state = state.copyWith(alerts: [alert, ...state.alerts].take(5).toList());
      }
    }

    // Comprobamos si hubo una nueva compresión
    bool nuevaCompresion = deviceInfo.compresiones > state.liveData.compressionCount;

    // Audio Feedback de Flutter (opcional, el ESP32 también lo tiene con JQ8900)
    if (nuevaCompresion && deviceInfo.compresiones > 0 && deviceInfo.compresiones % 5 == 0) {
      if (deviceInfo.profundidadMm < AppConstants.ahaMinDepthMm) {
        audioService.playFeedback('mas_profundo');
      } else if (deviceInfo.frecuenciaCpm < AppConstants.ahaMinRatePerMin) {
        audioService.playFeedback('mas_rapido');
      } else {
        audioService.playFeedback('bien');
      }
    }

    final data = LiveSessionData(
      depthMm: deviceInfo.profundidadMm,
      ratePerMin: deviceInfo.frecuenciaCpm,
      forceKg: deviceInfo.fuerzaKg,
      compressionCount: deviceInfo.compresiones,
      correctCompressionCount: deviceInfo.compresionesCorrectas,
      correctPct: deviceInfo.calidadPct,
      decompressedFully: deviceInfo.recoilOk,
      recoilPct: deviceInfo.recoilPct,
      oxygen: deviceInfo.oxigeno,
      pauseCount: deviceInfo.pausas,
      maxPauseSec: deviceInfo.maxPausaSeg,
      sensorOk: deviceInfo.sensorOk,
      calibrated: deviceInfo.calibrado,
    );

    final newHistory = [...state.depthHistory, data.depthMm];
    final trimmed = newHistory.length > 20 ? newHistory.sublist(newHistory.length - 20) : newHistory;

    state = state.copyWith(
      liveData: data,
      depthHistory: trimmed,
      lastDeviceInfo: deviceInfo, // Guardamos para usar en endSession
    );
  }

  Future<SessionModel> endSession() async {
    _timer?.cancel();
    _telemetrySub?.cancel();
    _telemetrySubMulti?.cancel();
    _telemetrySub = null;
    _telemetrySubMulti = null;

    final currentSession = state.session;
    if (currentSession == null) {
      throw Exception('No hay sesión activa para finalizar.');
    }
    final sessionId = currentSession.id;
    final sessionService = ref.read(sessionServiceProvider);
    
    // Tomar métricas finales del último estado reportado por el ESP32
    final devInfo = state.lastDeviceInfo;
    final count = devInfo?.compresiones ?? 0;
    final avgDepth = devInfo?.avgProfundidadMm ?? 0.0;
    final avgRate = (devInfo?.frecuenciaCpm ?? 0).toDouble();
    final recoilPct = devInfo?.recoilPct ?? 100.0;
    final pausas = devInfo?.pausas ?? 0;
    final correctPct = devInfo?.calidadPct ?? 0.0;

    // ── Puntaje compuesto AHA 2025 ────────────────────────────────────────
    // Profundidad (30%)
    double depthScore = 0.0;
    if (avgDepth >= AppConstants.ahaMinDepthMm && avgDepth <= AppConstants.ahaMaxDepthMm) {
      depthScore = 100.0 * AppConstants.ahaDepthWeight;
    } else if (avgDepth > 0) {
      depthScore = 50.0 * AppConstants.ahaDepthWeight; // penalización parcial
    }

    // Frecuencia (30%)
    double rateScore = 0.0;
    if (avgRate >= AppConstants.ahaMinRatePerMin && avgRate <= AppConstants.ahaMaxRatePerMin) {
      rateScore = 100.0 * AppConstants.ahaRateWeight;
    } else if (avgRate > 0) {
      rateScore = 50.0 * AppConstants.ahaRateWeight;
    }

    // Recoil (20%)
    double rScore = recoilPct * AppConstants.ahaRecoilWeight;

    // Interrupciones (20%)
    double iScore = 100.0 * AppConstants.ahaInterruptionWeight;
    if (pausas > 0) {
      iScore = (iScore - (pausas * 10)).clamp(0.0, 100.0); // -10 pts por pausa larga
    }

    final totalScore = (depthScore + rateScore + rScore + iScore).clamp(0.0, 100.0);

    // ── Violaciones detectadas ─────────────────────────────────────────────
    final List<AhaViolation> violations = [];
    if (avgDepth < AppConstants.ahaMinDepthMm && count > 0) {
      violations.add(AhaViolation(type: 'error', message: 'Profundidad insuficiente (< 50 mm)', count: count));
    }
    if (avgDepth > AppConstants.ahaMaxDepthMm && count > 0) {
      violations.add(AhaViolation(type: 'warning', message: 'Compresión excesiva (> 60 mm)', count: count));
    }
    if (avgRate < AppConstants.ahaMinRatePerMin && count > 0) {
      violations.add(AhaViolation(type: 'error', message: 'Frecuencia muy lenta (< 100/min)', count: 1));
    }
    if (avgRate > AppConstants.ahaMaxRatePerMin && count > 0) {
      violations.add(AhaViolation(type: 'warning', message: 'Frecuencia muy rápida (> 120/min)', count: 1));
    }
    if (count < 10) {
      violations.add(AhaViolation(type: 'error', message: 'Muy pocas compresiones registradas', count: 1));
    }
    if (pausas > 0) {
      violations.add(AhaViolation(type: 'warning', message: 'Pausas mayores a 10s detectadas', count: pausas));
    }
    if (recoilPct < 80.0) {
       violations.add(AhaViolation(type: 'warning', message: 'Recoil incompleto frecuente', count: 1));
    }

    final metrics = SessionMetrics(
      totalCompressions: count,
      correctCompressions: devInfo?.compresionesCorrectas ?? 0,
      averageDepthMm: avgDepth,
      averageRatePerMin: avgRate,
      correctCompressionsPct: correctPct,
      averageForcKg: devInfo?.avgFuerzaKg ?? 0.0,
      recoilPct: recoilPct,
      interruptionCount: pausas,
      maxPauseSeconds: devInfo?.maxPausaSeg ?? 0.0,
      depthScore: depthScore,
      rateScore: rateScore,
      recoilScore: rScore,
      interruptionScore: iScore,
      score: totalScore,
      approved: totalScore >= AppConstants.ahaPassScore,
      violations: violations,
    );

    SessionModel finished;
    try {
      await sessionService.endSession(sessionId, metrics, state.elapsed.inSeconds);
      // Actualizar progreso de curso si aplica
      await sessionService.updateCourseProgressAfterSession(currentSession.studentId, metrics);
      
      final saved = await sessionService.getSession(sessionId);
      finished = saved ?? currentSession.copyWithEnd(metrics: metrics, endedAt: DateTime.now());
    } catch (_) {
      finished = currentSession.copyWithEnd(metrics: metrics, endedAt: DateTime.now());
    }

    state = state.copyWith(session: finished, isConnected: false);
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

final activeSessionProvider = NotifierProvider<ActiveSessionNotifier, ActiveSessionState>(
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
  final todayCount = sessions.where((s) =>
      s.startedAt.day == today.day &&
      s.startedAt.month == today.month &&
      s.startedAt.year == today.year).length;

  final withMetrics = sessions.where((s) => s.metrics != null).toList();
  if (withMetrics.isEmpty) {
    return UserStats(sessionsToday: todayCount, totalSessions: sessions.length);
  }

  final avgScore = withMetrics.map((s) => s.metrics!.score).reduce((a, b) => a + b) / withMetrics.length;
  final bestScore = withMetrics.map((s) => s.metrics!.score).reduce((a, b) => a > b ? a : b);
  final totalHours = sessions.map((s) => s.duration.inSeconds).reduce((a, b) => a + b) / 3600.0;
  final avgDepth = withMetrics.map((s) => s.metrics!.averageDepthMm).reduce((a, b) => a + b) / withMetrics.length;
  final avgRate = withMetrics.map((s) => s.metrics!.averageRatePerMin).reduce((a, b) => a + b) / withMetrics.length;

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
final courseStudentsProvider = FutureProvider.family<List, String>((ref, courseId) async {
  try {
    return await ref.read(sessionServiceProvider).getCourseStudents(courseId);
  } catch (_) {
    return [];
  }
});

// ─── Device Status ────────────────────────────────────────────────────────────
final deviceStatusProvider = FutureProvider<DeviceStatusData>((ref) async {
  try {
    return await ref.read(sessionServiceProvider).getDeviceStatus();
  } catch (_) {
    return const DeviceStatusData(isConnected: false);
  }
});
