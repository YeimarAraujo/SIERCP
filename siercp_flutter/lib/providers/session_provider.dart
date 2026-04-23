import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../models/alert_course.dart';
import '../models/user.dart';
import '../services/session_service.dart';
import '../services/device_service.dart';
import '../services/audio_service.dart';
import 'auth_provider.dart';
import 'guide_provider.dart'; // para selectedDeviceMacProvider

final audioServiceProvider = Provider((ref) => AudioService());

// ─── Active Session State ──────────────────────────────────────────────────────
class ActiveSessionState {
  final SessionModel? session;
  final LiveSessionData liveData;
  final List<double> depthHistory;
  final List<AlertModel> alerts;
  final bool isConnected;
  final Duration elapsed;

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
  });

  ActiveSessionState copyWith({
    SessionModel? session,
    LiveSessionData? liveData,
    List<double>? depthHistory,
    List<AlertModel>? alerts,
    bool? isConnected,
    Duration? elapsed,
  }) =>
      ActiveSessionState(
        session: session ?? this.session,
        liveData: liveData ?? this.liveData,
        depthHistory: depthHistory ?? this.depthHistory,
        alerts: alerts ?? this.alerts,
        isConnected: isConnected ?? this.isConnected,
        elapsed: elapsed ?? this.elapsed,
      );
}

// ─── Active Session Notifier ───────────────────────────────────────────────────
/// La telemetría del ESP32 llega via Firebase Realtime Database.
/// El maniquí NO se conecta por Bluetooth a la app — envía directamente a Firebase.
class ActiveSessionNotifier extends Notifier<ActiveSessionState> {
  Timer? _timer;
  // Mantenemos dos variables separadas para evitar cast inválido
  StreamSubscription<DeviceInfo?>? _telemetrySub;
  StreamSubscription<List<DeviceInfo>>? _telemetrySubMulti;

  // ── Variables para análisis de compresiones reales ──
  bool _inCompression = false;
  double _peakForce = 0.0;
  final List<int> _compressionTimestamps = [];
  double _sumDepths = 0.0;

  @override
  ActiveSessionState build() => const ActiveSessionState();

  Future<void> startSession(String scenarioId) async {
    final sessionService = ref.read(sessionServiceProvider);
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('No hay usuario autenticado.');

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
      state =
          state.copyWith(elapsed: state.elapsed + const Duration(seconds: 1));
    });

    // ── Escuchar telemetría desde Firebase Realtime Database ──────────────
    _startFirebaseTelemetryListener(audioService);
  }

  void _startFirebaseTelemetryListener(AudioService audioService) {
    final deviceService = ref.read(deviceServiceProvider);
    final selectedMac = ref.read(selectedDeviceMacProvider);

    if (selectedMac != null && selectedMac.isNotEmpty) {
      // Escuchar un maniquí específico
      _telemetrySub = deviceService.streamDevice(selectedMac).listen(
        (deviceInfo) {
          if (deviceInfo != null && deviceInfo.isActive) {
            _processFirebaseTelemetry(deviceInfo, audioService);
          }
        },
        onError: (_) {}, // ignorar errores de red
      );
    } else {
      // Sin maniquí seleccionado: escuchar todos y usar el primer activo
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
    // Los datos vienen del nodo de telemetría en RTDB
    final rawForce = deviceInfo.presion; // fuerza/presión del sensor HX711
    final rawRate = deviceInfo.ritmoCpm.toInt();

    // ── UMBRALES DE DETECCIÓN ───────────────────────────────────────────
    const double inicioCompresion = 4.0;
    const double finCompresion = 2.0;

    // ── DETECCIÓN DE CICLO PICO/BAJADA ─────────────────────────────────
    int count = state.liveData.compressionCount;
    double depth = state.liveData.depthMm;

    if (rawForce >= inicioCompresion && !_inCompression) {
      _inCompression = true;
      _peakForce = rawForce;
    } else if (rawForce > _peakForce && _inCompression) {
      _peakForce = rawForce;
    } else if (rawForce <= finCompresion && _inCompression) {
      _inCompression = false;
      count = state.liveData.compressionCount + 1;

      depth = (_peakForce * 1.5).clamp(0.0, 80.0);
      _sumDepths += depth;

      _compressionTimestamps.add(DateTime.now().millisecondsSinceEpoch);

      // ── FRECUENCIA REAL (CPM) ─────────────────────────────────────────
      int currentRate = rawRate > 0 ? rawRate : 0;
      if (_compressionTimestamps.length >= 2) {
        final span =
            _compressionTimestamps.last - _compressionTimestamps.first;
        if (span > 0) {
          currentRate =
              ((_compressionTimestamps.length - 1) / (span / 60000.0))
                  .round();
        }
      }

      // Audio Feedback (each 5 compressions)
      if (count > 0 && count % 5 == 0) {
        if (depth < 50.0) {
          audioService.playFeedback('mas_profundo');
        } else if (currentRate < 100) {
          audioService.playFeedback('mas_rapido');
        } else {
          audioService.playFeedback('bien');
        }
      }

      _peakForce = 0.0;
    }

    // ── FRECUENCIA PARA UI ──────────────────────────────────────────────
    int rate = rawRate > 0 ? rawRate : 0;
    if (_compressionTimestamps.length >= 2) {
      final span =
          _compressionTimestamps.last - _compressionTimestamps.first;
      if (span > 0) {
        rate = ((_compressionTimestamps.length - 1) / (span / 60000.0))
            .round();
      }
    }

    // ── DESCOMPRESIÓN COMPLETA ──────────────────────────────────────────
    final decompressed = !_inCompression && rawForce < finCompresion;

    // ── CALIDAD ACUMULADA ───────────────────────────────────────────────
    final avgDepth = count > 0 ? _sumDepths / count : 0.0;
    final ok = avgDepth >= 50.0 && avgDepth <= 60.0 ? 1.0 : 0.0;
    final newPct = count > 0
        ? ((state.liveData.correctPct * (count - 1) + ok * 100) / count)
            .clamp(0.0, 100.0)
        : 0.0;

    _onLiveData(LiveSessionData(
      depthMm: depth,
      ratePerMin: rate,
      forceKg: rawForce,
      compressionCount: count,
      correctPct: newPct.toDouble(),
      decompressedFully: decompressed,
      oxygen: deviceInfo.oxigeno > 0 ? deviceInfo.oxigeno : 98.0,
    ));
  }

  void _onLiveData(LiveSessionData data) {
    final newHistory = [...state.depthHistory, data.depthMm];
    final trimmed = newHistory.length > 20
        ? newHistory.sublist(newHistory.length - 20)
        : newHistory;

    List<AlertModel> newAlerts = state.alerts;
    if (data.alertMessage != null) {
      final alert = AlertModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sessionId: state.session?.id ?? '',
        type: _parseAlertType(data.alertType),
        title: _alertTitle(data.alertType),
        message: data.alertMessage!,
        timestamp: DateTime.now(),
      );
      newAlerts = [alert, ...state.alerts].take(5).toList();
    }

    state = state.copyWith(
      liveData: data,
      depthHistory: trimmed,
      alerts: newAlerts,
    );
  }

  AlertType _parseAlertType(String? t) {
    switch (t) {
      case 'ok':
        return AlertType.ok;
      case 'warning':
        return AlertType.warning;
      case 'error':
        return AlertType.error;
      default:
        return AlertType.info;
    }
  }

  String _alertTitle(String? type) {
    switch (type) {
      case 'ok':
        return 'Técnica correcta';
      case 'warning':
        return 'Atención';
      case 'error':
        return 'Corrección requerida';
      default:
        return 'Información';
    }
  }

  Future<SessionModel> endSession() async {
    _timer?.cancel();
    _telemetrySub?.cancel();
    _telemetrySubMulti?.cancel();
    _telemetrySub = null;
    _telemetrySubMulti = null;

    // Capturar todo lo necesario antes de limpiar el estado
    final currentSession = state.session;
    if (currentSession == null) {
      throw Exception('No hay sesión activa para finalizar.');
    }
    final sessionId = currentSession.id;

    final sessionService = ref.read(sessionServiceProvider);
    final liveData = state.liveData;
    final elapsed = state.elapsed;
    final count = liveData.compressionCount;

    // ── Profundidad promedio real ──────────────────────────────────────────
    final avgDepth = count > 0 ? _sumDepths / count : 0.0;

    // ── Frecuencia promedio real ───────────────────────────────────────────
    final avgRate = liveData.ratePerMin.toDouble();

    // ── Puntaje compuesto según AHA ────────────────────────────────────────
    final depthScore =
        (avgDepth >= 50 && avgDepth <= 60) ? 40.0 : (avgDepth > 0 ? 20.0 : 0.0);
    final rateScore =
        (avgRate >= 100 && avgRate <= 120) ? 30.0 : (avgRate > 0 ? 15.0 : 0.0);
    final qualScore = liveData.correctPct * 0.30;
    final totalScore = (depthScore + rateScore + qualScore).clamp(0.0, 100.0);

    // ── Violaciones detectadas ─────────────────────────────────────────────
    final List<AhaViolation> violations = [];
    if (avgDepth < 50 && count > 0) {
      violations.add(AhaViolation(
          type: 'error',
          message: 'Profundidad insuficiente (< 50 mm)',
          count: count));
    }
    if (avgDepth > 60 && count > 0) {
      violations.add(AhaViolation(
          type: 'warning',
          message: 'Compresión excesiva (> 60 mm)',
          count: count));
    }
    if (avgRate < 100 && count > 0) {
      violations.add(AhaViolation(
          type: 'error',
          message: 'Frecuencia muy lenta (< 100/min)',
          count: 1));
    }
    if (avgRate > 120 && count > 0) {
      violations.add(AhaViolation(
          type: 'warning',
          message: 'Frecuencia muy rápida (> 120/min)',
          count: 1));
    }
    if (count < 10) {
      violations.add(AhaViolation(
          type: 'error',
          message: 'Muy pocas compresiones registradas',
          count: 1));
    }
    final metrics = SessionMetrics(
      totalCompressions: count,
      averageDepthMm: avgDepth,
      averageRatePerMin: avgRate,
      correctCompressionsPct: liveData.correctPct,
      averageForcKg: liveData.forceKg,
      interruptionCount: 0,
      maxPauseSeconds: 0.0,
      score: totalScore,
      approved: totalScore >= 70,
      violations: violations,
    );

    // Limpiar contadores internos ya que los capturamos arriba
    _compressionTimestamps.clear();
    _sumDepths = 0.0;
    _inCompression = false;
    _peakForce = 0.0;

    // Intentar guardar en Firestore; si falla, devolver modelo local
    SessionModel finished;
    try {
      await sessionService.endSession(sessionId, metrics, elapsed.inSeconds);
      final saved = await sessionService.getSession(sessionId);
      finished = saved ??
          SessionModel(
            id: sessionId,
            studentId: currentSession.studentId,
            scenarioId: currentSession.scenarioId,
            scenarioTitle: currentSession.scenarioTitle,
            patientType: currentSession.patientType,
            status: SessionStatus.completed,
            startedAt: currentSession.startedAt,
            endedAt: DateTime.now(),
            metrics: metrics,
          );
    } catch (_) {
      // Firestore falló — devolvemos el resultado localmente para no bloquear la navegación
      finished = SessionModel(
        id: sessionId,
        studentId: currentSession.studentId,
        scenarioId: currentSession.scenarioId,
        scenarioTitle: currentSession.scenarioTitle,
        patientType: currentSession.patientType,
        status: SessionStatus.completed,
        startedAt: currentSession.startedAt,
        endedAt: DateTime.now(),
        metrics: metrics,
      );
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
    FutureProvider.family<List, String>((ref, courseId) async {
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
