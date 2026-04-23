import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final deviceServiceProvider = Provider<DeviceService>((ref) => DeviceService());

// ─── DeviceInfo ───────────────────────────────────────────────────────────────
class DeviceInfo {
  final String macAddress;
  final double ritmoCpm;
  final double oxigeno;
  final double presion;
  final double temperatura;
  final int timestamp;
  final bool isActive; // timestamp < 5 segundos

  const DeviceInfo({
    required this.macAddress,
    required this.ritmoCpm,
    required this.oxigeno,
    required this.presion,
    required this.temperatura,
    required this.timestamp,
    required this.isActive,
  });

  factory DeviceInfo.fromMap(String mac, Map<dynamic, dynamic> data) {
    final ts = (data['timestamp'] as num?)?.toInt() ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final isActive = ts > 0 && (nowMs - ts) < 5000;
    return DeviceInfo(
      macAddress:  mac,
      ritmoCpm:    (data['ritmo_cardiaco'] as num?)?.toDouble() ?? 0.0,
      oxigeno:     (data['oxigeno']        as num?)?.toDouble() ?? 0.0,
      presion:     (data['presion']        as num?)?.toDouble() ?? 0.0,
      temperatura: (data['temperatura']   as num?)?.toDouble() ?? 0.0,
      timestamp:   ts,
      isActive:    isActive,
    );
  }

  /// Tiempo desde la última actualización en milisegundos
  int get msSinceUpdate => DateTime.now().millisecondsSinceEpoch - timestamp;

  String get statusLabel => isActive ? 'Conectado' : 'Desconectado';
  String get lastUpdateLabel {
    if (timestamp == 0) return 'Sin datos';
    final secs = msSinceUpdate ~/ 1000;
    if (secs < 60)  return 'hace ${secs}s';
    return 'hace ${secs ~/ 60}min';
  }
}

// ─── DeviceStatus ─────────────────────────────────────────────────────────────
class DeviceStatus {
  final bool isConnected;
  final String? macAddress;
  final int? lastTimestamp;

  const DeviceStatus({
    required this.isConnected,
    this.macAddress,
    this.lastTimestamp,
  });

  factory DeviceStatus.disconnected() =>
      const DeviceStatus(isConnected: false);
}

// ─── DeviceService ────────────────────────────────────────────────────────────
class DeviceService {
  final DatabaseReference _telemetria =
      FirebaseDatabase.instance.ref('telemetria');

  // ── Stream de todos los dispositivos disponibles ──────────────────────────
  Stream<List<DeviceInfo>> streamAvailableDevices() {
    return _telemetria.onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final raw = Map<String, dynamic>.from(
        event.snapshot.value as Map,
      );
      final List<DeviceInfo> devices = [];
      raw.forEach((mac, data) {
        if (data is Map) {
          devices.add(DeviceInfo.fromMap(mac, data));
        }
      });
      // Ordenar: activos primero
      devices.sort((a, b) => b.isActive ? 1 : -1);
      return devices;
    });
  }

  // ── Stream de un dispositivo específico ───────────────────────────────────
  Stream<DeviceInfo?> streamDevice(String macAddress) {
    return _telemetria.child(macAddress).onValue.map((event) {
      if (event.snapshot.value == null) return null;
      final data = Map<dynamic, dynamic>.from(
        event.snapshot.value as Map,
      );
      return DeviceInfo.fromMap(macAddress, data);
    });
  }

  // ── Stream del estado de conexión general ─────────────────────────────────
  Stream<DeviceStatus> streamConnectionStatus() {
    return _telemetria.onValue.map((event) {
      if (event.snapshot.value == null) {
        return DeviceStatus.disconnected();
      }
      final raw = Map<String, dynamic>.from(
        event.snapshot.value as Map,
      );

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (final entry in raw.entries) {
        final data = entry.value;
        if (data is! Map) continue;
        final ts = (data['timestamp'] as num?)?.toInt() ?? 0;
        if (ts > 0 && (nowMs - ts) < 5000) {
          return DeviceStatus(
            isConnected:   true,
            macAddress:    entry.key,
            lastTimestamp: ts,
          );
        }
      }
      return DeviceStatus.disconnected();
    });
  }

  // ── Verificar si un dispositivo específico está activo ────────────────────
  Future<bool> isDeviceActive(String macAddress) async {
    final snap = await _telemetria.child(macAddress).get();
    if (!snap.exists || snap.value == null) return false;
    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    final ts = (data['timestamp'] as num?)?.toInt() ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return ts > 0 && (nowMs - ts) < 5000;
  }

  // ── Obtener lista actual de dispositivos activos ──────────────────────────
  Future<List<DeviceInfo>> getAvailableDevices() async {
    final snap = await _telemetria.get();
    if (!snap.exists || snap.value == null) return [];
    final raw = Map<String, dynamic>.from(snap.value as Map);
    final List<DeviceInfo> devices = [];
    raw.forEach((mac, data) {
      if (data is Map) devices.add(DeviceInfo.fromMap(mac, data));
    });
    devices.sort((a, b) => b.isActive ? 1 : -1);
    return devices;
  }
}
