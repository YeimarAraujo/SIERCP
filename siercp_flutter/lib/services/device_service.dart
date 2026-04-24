import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final deviceServiceProvider = Provider<DeviceService>((ref) => DeviceService());

// ─── DeviceInfo ───────────────────────────────────────────────────────────────
/// Datos de telemetria enriquecida del ESP32.
/// El ESP32 calcula TODOS los datos; Flutter solo los consume y muestra.
class DeviceInfo {
  final String macAddress;
  // Datos instantaneos
  final double fuerzaKg;
  final double profundidadMm;
  final int frecuenciaCpm;
  // Contadores
  final int compresiones;
  final int compresionesCorrectas;
  // Estado
  final bool recoilOk;
  final bool enCompresion;
  final bool compresionCorrecta;
  // Metricas acumuladas
  final double calidadPct;
  final double recoilPct;
  final double avgProfundidadMm;
  final double avgFuerzaKg;
  final int pausas;
  final double maxPausaSeg;
  // Sistema
  final bool sensorOk;
  final bool calibrado;
  final int timestamp;
  final bool isActive;
  // Backward-compat: campos legacy
  final double ritmoCpm;
  final double oxigeno;
  final double presion;
  final double temperatura;

  const DeviceInfo({
    required this.macAddress,
    required this.fuerzaKg,
    required this.profundidadMm,
    required this.frecuenciaCpm,
    required this.compresiones,
    required this.compresionesCorrectas,
    required this.recoilOk,
    required this.enCompresion,
    required this.compresionCorrecta,
    required this.calidadPct,
    required this.recoilPct,
    required this.avgProfundidadMm,
    required this.avgFuerzaKg,
    required this.pausas,
    required this.maxPausaSeg,
    required this.sensorOk,
    required this.calibrado,
    required this.timestamp,
    required this.isActive,
    this.ritmoCpm = 0.0,
    this.oxigeno = 98.0,
    this.presion = 0.0,
    this.temperatura = 36.5,
  });

  factory DeviceInfo.fromMap(String mac, Map<dynamic, dynamic> data) {
    int ts = 0;
    if (data['timestamp'] is num) {
      ts = (data['timestamp'] as num).toInt();
    }
    
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // Ventana de 30 segundos para permitir desajustes de reloj y lag de red.
    // Si ts == 0 (ej. Firebase no evaluó el server-value), lo marcamos activo de todas formas
    // ya que onValue acaba de dispararse.
    final isActive = ts == 0 || (nowMs - ts).abs() < 30000;

    // Detectar formato nuevo vs legacy
    final isNewFormat = data.containsKey('fuerza_kg');

    if (isNewFormat) {
      return DeviceInfo(
        macAddress:           mac,
        fuerzaKg:             (data['fuerza_kg'] as num?)?.toDouble() ?? 0.0,
        profundidadMm:        (data['profundidad_mm'] as num?)?.toDouble() ?? 0.0,
        frecuenciaCpm:        (data['frecuencia_cpm'] as num?)?.toInt() ?? 0,
        compresiones:         (data['compresiones'] as num?)?.toInt() ?? 0,
        compresionesCorrectas:(data['compresiones_correctas'] as num?)?.toInt() ?? 0,
        recoilOk:             data['recoil_ok'] == true,
        enCompresion:         data['en_compresion'] == true,
        compresionCorrecta:   data['compresion_correcta'] == true,
        calidadPct:           (data['calidad_pct'] as num?)?.toDouble() ?? 0.0,
        recoilPct:            (data['recoil_pct'] as num?)?.toDouble() ?? 0.0,
        avgProfundidadMm:     (data['avg_profundidad_mm'] as num?)?.toDouble() ?? 0.0,
        avgFuerzaKg:          (data['avg_fuerza_kg'] as num?)?.toDouble() ?? 0.0,
        pausas:               (data['pausas'] as num?)?.toInt() ?? 0,
        maxPausaSeg:          (data['max_pausa_seg'] as num?)?.toDouble() ?? 0.0,
        sensorOk:             data['sensor_ok'] != false,
        calibrado:            data['calibrado'] == true,
        timestamp:            ts,
        isActive:             isActive,
        ritmoCpm:             (data['frecuencia_cpm'] as num?)?.toDouble() ?? 0.0,
        oxigeno:              98.0,
        presion:              (data['fuerza_kg'] as num?)?.toDouble() ?? 0.0,
        temperatura:          36.5,
      );
    }

    // Legacy format (backward-compat)
    return DeviceInfo(
      macAddress:           mac,
      fuerzaKg:             (data['presion'] as num?)?.toDouble() ?? 0.0,
      profundidadMm:        0.0,
      frecuenciaCpm:        (data['ritmo_cardiaco'] as num?)?.toInt() ?? 0,
      compresiones:         0,
      compresionesCorrectas:0,
      recoilOk:             false,
      enCompresion:         false,
      compresionCorrecta:   false,
      calidadPct:           0.0,
      recoilPct:            0.0,
      avgProfundidadMm:     0.0,
      avgFuerzaKg:          0.0,
      pausas:               0,
      maxPausaSeg:          0.0,
      sensorOk:             true,
      calibrado:            false,
      timestamp:            ts,
      isActive:             isActive,
      ritmoCpm:             (data['ritmo_cardiaco'] as num?)?.toDouble() ?? 0.0,
      oxigeno:              (data['oxigeno'] as num?)?.toDouble() ?? 0.0,
      presion:              (data['presion'] as num?)?.toDouble() ?? 0.0,
      temperatura:          (data['temperatura'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Tiempo desde la ultima actualizacion en milisegundos
  int get msSinceUpdate => DateTime.now().millisecondsSinceEpoch - timestamp;

  String get statusLabel => isActive ? 'Conectado' : 'Desconectado';
  String get lastUpdateLabel {
    if (timestamp == 0) return 'Sin datos';
    final secs = msSinceUpdate ~/ 1000;
    if (secs < 60) return 'hace ${secs}s';
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
    // keepSynced mantiene conexión persistente → datos llegan en ~50ms
    _telemetria.keepSynced(true);
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

  // ── Stream de un dispositivo especifico ───────────────────────────────────
  Stream<DeviceInfo?> streamDevice(String macAddress) {
    final childRef = _telemetria.child(macAddress);
    // keepSynced en el nodo específico → recibimos actualizaciones al instante
    childRef.keepSynced(true);
    return childRef.onValue.map((event) {
      if (event.snapshot.value == null) return null;
      final data = Map<dynamic, dynamic>.from(
        event.snapshot.value as Map,
      );
      return DeviceInfo.fromMap(macAddress, data);
    });
  }

  // ── Stream del estado de conexion general ─────────────────────────────────
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
            isConnected: true,
            macAddress: entry.key,
            lastTimestamp: ts,
          );
        }
      }
      return DeviceStatus.disconnected();
    });
  }

  // ── Verificar si un dispositivo especifico esta activo ────────────────────
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
