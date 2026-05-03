import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/rcp_engine.dart';

final bleServiceProvider = ChangeNotifierProvider((ref) => BleService());

class BleService extends ChangeNotifier {
  static const String serviceUuid = "12345678-1234-5678-1234-56789abcdef0";
  static const String telemetryCharUuid =
      "12345678-1234-5678-1234-56789abcdef1";
  static const String audioCharUuid = "12345678-1234-5678-1234-56789abcdef2";

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _telemetryChar;
  BluetoothCharacteristic? _audioChar;

  StreamSubscription? _notifySub;
  StreamSubscription? _connectionSub;
  final _telemetryController = StreamController<RcpTelemetry>.broadcast();

  Stream<RcpTelemetry> get telemetryStream => _telemetryController.stream;

  bool get isConnected => _connectedDevice != null;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: false, license: License.free);
      _connectedDevice = device;

      // Optimización de conectividad: Solicitar MTU mayor para paquetes de telemetría de 44 bytes
      // El valor por defecto de 23 bytes fragmentaría el paquete.
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await device.requestMtu(247);
          debugPrint("MTU negociado exitosamente");
        } catch (e) {
          debugPrint(
              "No se pudo negociar MTU, se usará el valor por defecto: $e");
        }
      }

      // Escuchar desconexiones
      _connectionSub?.cancel();
      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint("Dispositivo BLE desconectado");
          disconnect();
        }
      });

      final services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() ==
            serviceUuid.toLowerCase()) {
          for (var char in service.characteristics) {
            final charUuid = char.uuid.toString().toLowerCase();
            if (charUuid == telemetryCharUuid.toLowerCase()) {
              _telemetryChar = char;
            } else if (charUuid == audioCharUuid.toLowerCase()) {
              _audioChar = char;
            }
          }
        }
      }

      if (_telemetryChar != null) {
        await _telemetryChar!.setNotifyValue(true);
        // Usar onValueReceived para asegurar que recibimos el flujo constante
        _notifySub = _telemetryChar!.onValueReceived.listen((value) {
          if (value.isNotEmpty) {
            _parsePayload(value);
          }
        });

        debugPrint("Conexión establecida y notificaciones activadas");
        notifyListeners(); // Notificar a la UI
      } else {
        await disconnect();
        throw Exception(
            "No se encontró el servicio o característica de telemetría.");
      }
    } catch (e) {
      debugPrint("Error connecting to BLE: $e");
      await disconnect();
      throw Exception("Fallo al conectar: $e");
    }
  }

  void _parsePayload(List<int> value) {
    try {
      if (value.length >= 47) {
        final byteData = ByteData.sublistView(Uint8List.fromList(value));

        final timestamp = byteData.getUint32(0, Endian.little);

        for (int i = 0; i < 5; i++) {
          int offset = 4 + (i * 8);

          double force = byteData.getFloat32(offset, Endian.little);
          double depth = byteData.getFloat32(offset + 4, Endian.little);

          _telemetryController.add(RcpTelemetry(
            depthMm: depth,
            forceKg: force,
            timestamp: timestamp + (i * 20),
          ));
        }

        int compressions = byteData.getUint16(44, Endian.little);
        int bpm = byteData.getUint8(46);

        RcpEngine.instance.updateFromHardware(
          compressions: compressions,
          bpm: bpm,
        );

        debugPrint("ESP32 → Comp: $compressions | BPM: $bpm");
      }
    } catch (e) {
      debugPrint("Error en recepción BLE: $e");
    }
  }

  /// Inicia la sesión en el Hardware
  Future<void> startHardwareSession() async {
    if (_audioChar != null) {
      await _audioChar!.write([0x01], withoutResponse: false);
      debugPrint("Hardware Session Started");
    }
  }

  /// Detiene y resetea el Hardware
  Future<void> resetHardwareCounters() async {
    if (_audioChar != null) {
      await _audioChar!.write([0x00], withoutResponse: false);
      debugPrint("Hardware Session Reset/Stop");
    }
  }

  Future<void> triggerAudio(int track) async {
    if (_audioChar != null) {
      await _audioChar!.write([track], withoutResponse: true);
    }
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
    }
    _telemetryChar = null;
    _audioChar = null;
    notifyListeners();
  }
}
