import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final rtdbServiceProvider = Provider<RtdbService>((ref) => RtdbService());

// ── Modelo de sesión activa RTDB ───────────────────────────────────────────────

class LiveSessionRtdb {
  final String sessionId;
  final String studentId;
  final String studentName;
  final String scenarioId;
  final String scenarioTitle;
  final String manikinId;
  final String courseId;
  final String institutionId;
  final String status;
  final int startedAt;
  final int heartbeat;

  const LiveSessionRtdb({
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.scenarioId,
    required this.scenarioTitle,
    required this.manikinId,
    required this.courseId,
    required this.institutionId,
    required this.status,
    required this.startedAt,
    required this.heartbeat,
  });

  bool get isAlive =>
      DateTime.now().millisecondsSinceEpoch - heartbeat < 60000;

  factory LiveSessionRtdb.fromMap(String id, Map<dynamic, dynamic> data) =>
      LiveSessionRtdb(
        sessionId:     id,
        studentId:     data['studentId']     as String? ?? '',
        studentName:   data['studentName']   as String? ?? 'Estudiante',
        scenarioId:    data['scenarioId']    as String? ?? '',
        scenarioTitle: data['scenarioTitle'] as String? ?? '',
        manikinId:     data['manikinId']     as String? ?? '',
        courseId:      data['courseId']      as String? ?? '',
        institutionId: data['institutionId'] as String? ?? '',
        status:        data['status']        as String? ?? 'active',
        startedAt:     (data['startedAt']    as int?)   ?? 0,
        heartbeat:     (data['heartbeat']    as int?)   ?? (data['startedAt'] as int? ?? 0),
      );
}

// ── Modelo de telemetría RTDB ─────────────────────────────────────────────────

class LiveTelemetryRtdb {
  final double depthMm;
  final int ratePerMin;
  final double forceKg;
  final int compressionCount;
  final int correctCompressionCount;
  final double correctPct;
  final double sessionScore;
  final bool decompressedFully;
  final double recoilPct;
  final int pauseCount;
  final double maxPauseSec;
  final bool sensorOk;
  final bool calibrated;
  final int updatedAt;

  const LiveTelemetryRtdb({
    this.depthMm               = 0,
    this.ratePerMin            = 0,
    this.forceKg               = 0,
    this.compressionCount      = 0,
    this.correctCompressionCount = 0,
    this.correctPct            = 0,
    this.sessionScore          = 0,
    this.decompressedFully     = false,
    this.recoilPct             = 100,
    this.pauseCount            = 0,
    this.maxPauseSec           = 0,
    this.sensorOk              = true,
    this.calibrated            = false,
    this.updatedAt             = 0,
  });

  factory LiveTelemetryRtdb.fromMap(Map<dynamic, dynamic> data) =>
      LiveTelemetryRtdb(
        depthMm:                 (data['depthMm']                 as num?)?.toDouble() ?? 0,
        ratePerMin:               (data['ratePerMin']               as num?)?.toInt()    ?? 0,
        forceKg:                 (data['forceKg']                 as num?)?.toDouble() ?? 0,
        compressionCount:         (data['compressionCount']         as num?)?.toInt()    ?? 0,
        correctCompressionCount:  (data['correctCompressionCount']  as num?)?.toInt()    ?? 0,
        correctPct:              (data['correctPct']              as num?)?.toDouble() ?? 0,
        sessionScore:            (data['sessionScore']            as num?)?.toDouble() ?? 0,
        decompressedFully:        data['decompressedFully']        as bool? ?? false,
        recoilPct:               (data['recoilPct']               as num?)?.toDouble() ?? 100,
        pauseCount:               (data['pauseCount']               as num?)?.toInt()    ?? 0,
        maxPauseSec:             (data['maxPauseSec']             as num?)?.toDouble() ?? 0,
        sensorOk:                 data['sensorOk']                 as bool? ?? true,
        calibrated:               data['calibrated']               as bool? ?? false,
        updatedAt:                (data['updatedAt']               as int?)             ?? 0,
      );

  bool get hasData => compressionCount > 0 || depthMm > 0;
}

// ── RtdbService ───────────────────────────────────────────────────────────────

class RtdbService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // ── Presencia ───────────────────────────────────────────────────────────────

  /// Registra la presencia del usuario con onDisconnect para limpieza automática.
  Future<void> registerPresence(String userId) async {
    final presenceRef = _db.ref('presence/$userId');
    await presenceRef.set({'online': true, 'lastSeen': ServerValue.timestamp});
    await presenceRef.onDisconnect().set({
      'online': false,
      'lastSeen': ServerValue.timestamp,
    });
  }

  Future<void> setOffline(String userId) async {
    try {
      await _db.ref('presence/$userId').set({
        'online': false,
        'lastSeen': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('[RTDB] Error setOffline: $e');
    }
  }

  // ── Live Sessions Reader ────────────────────────────────────────────────────

  /// Escucha sesiones activas de un curso desde RTDB (más barato que Firestore stream).
  Stream<List<LiveSessionRtdb>> watchCourseLiveSessions({
    required String institutionId,
    required String courseId,
  }) {
    final path = 'live_sessions/$institutionId/$courseId';
    return _db
        .ref(path)
        .onValue
        .map((event) {
          final data = event.snapshot.value;
          if (data == null) return <LiveSessionRtdb>[];
          if (data is! Map) return <LiveSessionRtdb>[];
          final sessions = <LiveSessionRtdb>[];
          data.forEach((key, value) {
            if (value is Map) {
              try {
                final entry = LiveSessionRtdb.fromMap(key.toString(), value);
                if (entry.isAlive) sessions.add(entry);
              } catch (e) {
                debugPrint('[RTDB] Error parsing session $key: $e');
              }
            }
          });
          return sessions;
        })
        .handleError((e) {
          debugPrint('[RTDB] watchCourseLiveSessions error: $e');
          return <LiveSessionRtdb>[];
        });
  }

  /// Escucha todas las sesiones activas de una institución (para admin dashboard).
  Stream<List<LiveSessionRtdb>> watchInstitutionLiveSessions(
      String institutionId) {
    return _db
        .ref('live_sessions/$institutionId')
        .onValue
        .map((event) {
          final raw = event.snapshot.value;
          if (raw == null || raw is! Map) return <LiveSessionRtdb>[];
          final sessions = <LiveSessionRtdb>[];
          raw.forEach((courseId, courseData) {
            if (courseData is Map) {
              courseData.forEach((sessionId, sessionData) {
                if (sessionData is Map) {
                  try {
                    final entry =
                        LiveSessionRtdb.fromMap(sessionId.toString(), sessionData);
                    if (entry.isAlive) sessions.add(entry);
                  } catch (e) {
                    debugPrint('[RTDB] Error parsing session: $e');
                  }
                }
              });
            }
          });
          return sessions;
        })
        .handleError((e) {
          debugPrint('[RTDB] watchInstitutionLiveSessions error: $e');
          return <LiveSessionRtdb>[];
        });
  }

  // ── Telemetría Reader ───────────────────────────────────────────────────────

  /// Escucha telemetría BLE en tiempo real de una sesión.
  Stream<LiveTelemetryRtdb> watchTelemetry(String sessionId) {
    return _db
        .ref('telemetry/$sessionId')
        .onValue
        .map((event) {
          final data = event.snapshot.value;
          if (data == null || data is! Map) return const LiveTelemetryRtdb();
          return LiveTelemetryRtdb.fromMap(data);
        })
        .handleError((e) {
          debugPrint('[RTDB] watchTelemetry error: $e');
          return const LiveTelemetryRtdb();
        });
  }

  // ── Limpiar sesión ──────────────────────────────────────────────────────────

  Future<void> removeLiveSession({
    required String institutionId,
    required String courseId,
    required String sessionId,
  }) async {
    try {
      await _db
          .ref('live_sessions/$institutionId/$courseId/$sessionId')
          .remove();
    } catch (e) {
      debugPrint('[RTDB] Error removeLiveSession: $e');
    }
  }
}
