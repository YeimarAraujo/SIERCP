import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siercp/features/session/data/models/session.dart';

final simBridgeProvider =
    ChangeNotifierProvider<SimBridgeService>((ref) => SimBridgeService());

/// Reenvía la telemetría al simulador SICAP Sim (Unity) por la red local.
///
/// Es opcional: apagado por defecto, y un fallo aquí nunca debe afectar la
/// sesión, el puntaje ni Firebase. Los paquetes no llevan datos personales del
/// estudiante. Lo único que se lee de la red es la respuesta del simulador a la
/// búsqueda, para enviarle la sesión sin que nadie escriba su IP.
class SimBridgeService extends ChangeNotifier {
  static const int port = 47800;
  static const int protocolVersion = 1;
  static const int samplesPerPacket = 5;
  static const probePacket = '{"probe":1}';
  static const _probeEvery = Duration(seconds: 3);
  static const _lostAfter = Duration(seconds: 8);

  static const _enabledKey = 'sim_bridge_enabled';
  static const _targetKey = 'sim_bridge_target';

  bool _enabled = false;
  String _target = '';
  bool _loaded = false;
  RawDatagramSocket? _socket;
  Future<RawDatagramSocket?>? _opening;
  Timer? _probeTimer;
  InternetAddress? _manual;
  InternetAddress? _found;
  DateTime _lastReply = DateTime.fromMillisecondsSinceEpoch(0);
  List<InternetAddress> _broadcasts = [InternetAddress('255.255.255.255')];
  Set<String> _ownAddresses = const {};
  bool _alsoLocal = false;
  final List<double> _samples = [];
  int _sequence = 0;

  bool get enabled => _enabled;

  /// Práctica con gafas: SICAP VR corre en este mismo teléfono y también recibe
  /// la sesión, además del simulador del PC si está en la red.
  void setLocalSimulator(bool on) => _alsoLocal = on;

  /// IP escrita a mano. Solo hace falta si la búsqueda no encuentra el PC.
  String get target => _target;

  /// IP del simulador que respondió a la búsqueda.
  String? get simulatorAddress => _found?.address;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? false;
      _target = prefs.getString(_targetKey) ?? '';
      _applyTarget();
      _syncSearch();
      notifyListeners();
    } catch (e) {
      debugPrint('SimBridge: no se pudo leer la configuración: $e');
    }
  }

  Future<void> configure({required bool enabled, required String target}) async {
    _enabled = enabled;
    _target = target.trim();
    _applyTarget();
    _syncSearch();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);
      await prefs.setString(_targetKey, _target);
    } catch (e) {
      debugPrint('SimBridge: no se pudo guardar la configuración: $e');
    }
  }

  static bool isValidTarget(String value) =>
      value.trim().isEmpty || InternetAddress.tryParse(value.trim()) != null;

  /// Agrupa las muestras y publica un paquete cada [samplesPerPacket].
  void addSample(String sessionId, String? scenarioId, LiveSessionData data) {
    if (!_enabled) return;
    _samples.add(data.depthMm);
    if (_samples.length < samplesPerPacket) return;

    final packet = encodePacket(
      sessionId: sessionId,
      scenarioId: scenarioId,
      sequence: ++_sequence,
      depths: _samples,
      data: data,
    );
    _samples.clear();
    _send(packet);
  }

  void sessionEnded(String sessionId, LiveSessionData data) {
    if (!_enabled) return;
    _samples.clear();
    _send(encodePacket(
      sessionId: sessionId,
      sequence: ++_sequence,
      depths: const [],
      data: data,
      ended: true,
    ));
  }

  /// Dirección de difusión de la red de [ip], asumiendo la máscara /24 habitual.
  /// Muchos routers y celulares no dejan pasar 255.255.255.255.
  @visibleForTesting
  static String? broadcastOf(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4 || ip.startsWith('169.254.')) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}.255';
  }

  @visibleForTesting
  static bool isSimulatorReply(String text) => text.contains('"sicapsim"');

  /// Debe coincidir con TelemetryFrame.cs en el proyecto Unity.
  @visibleForTesting
  static String encodePacket({
    required String sessionId,
    String? scenarioId,
    required int sequence,
    required List<double> depths,
    required LiveSessionData data,
    bool ended = false,
  }) {
    double round(double value) => (value * 10).roundToDouble() / 10;
    return jsonEncode({
      'v': protocolVersion,
      'sid': sessionId,
      'sc': scenarioId ?? '',
      'seq': sequence,
      'd': depths.map(round).toList(),
      'c': data.compressionCount,
      'cc': data.correctCompressionCount,
      'r': data.ratePerMin,
      'ok': data.decompressedFully,
      'rp': round(data.recoilPct),
      'p': data.pauseCount,
      'mp': round(data.maxPauseSec),
      's': round(data.sessionScore),
      'sensor': data.sensorOk,
      'end': ended,
    });
  }

  void _applyTarget() => _manual = InternetAddress.tryParse(_target);

  void _syncSearch() {
    if (!_enabled) {
      _close();
      return;
    }
    if (_probeTimer != null) return;
    _probe();
    _probeTimer = Timer.periodic(_probeEvery, (_) => _probe());
  }

  void _probe() {
    if (_found != null &&
        DateTime.now().difference(_lastReply) > _lostAfter) {
      _found = null;
      notifyListeners();
    }
    unawaited(_findBroadcasts().whenComplete(() => _send(probePacket)));
  }

  Future<void> _findBroadcasts() async {
    if (_found != null) return;
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      // Las respuestas de SICAP VR en este mismo teléfono no son el PC.
      _ownAddresses = {
        for (final interface in interfaces)
          for (final address in interface.addresses) address.address,
      };
      _broadcasts = {
        '255.255.255.255',
        for (final interface in interfaces)
          for (final address in interface.addresses)
            if (broadcastOf(address.address) case final broadcast?) broadcast,
      }.map(InternetAddress.new).toList();
    } catch (e) {
      debugPrint('SimBridge: no se pudieron leer las redes: $e');
    }
  }

  Iterable<InternetAddress> get _destinations {
    final local = _alsoLocal ? [InternetAddress.loopbackIPv4] : const <InternetAddress>[];
    final found = _found;
    if (found != null) return [found, ...local];
    final manual = _manual;
    return manual == null ? [..._broadcasts, ...local] : [manual, ..._broadcasts, ...local];
  }

  void _send(String packet) {
    final bytes = utf8.encode(packet);
    final socket = _socket;
    if (socket != null) {
      _deliver(socket, bytes);
      return;
    }
    _open().then((opened) {
      if (opened != null) _deliver(opened, bytes);
    });
  }

  void _deliver(RawDatagramSocket socket, List<int> bytes) {
    try {
      for (final address in _destinations) {
        socket.send(bytes, address, port);
      }
    } catch (e) {
      debugPrint('SimBridge: envío fallido: $e');
      _closeSocket();
    }
  }

  Future<RawDatagramSocket?> _open() => _opening ??=
      RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then<RawDatagramSocket?>(
        (opened) {
          _opening = null;
          if (!_enabled) {
            opened.close();
            return null;
          }
          opened.broadcastEnabled = true;
          opened.listen((event) => _onSocketEvent(opened, event));
          return _socket = opened;
        },
      ).catchError((Object e) {
        _opening = null;
        debugPrint('SimBridge: red no disponible: $e');
        return null;
      });

  void _onSocketEvent(RawDatagramSocket socket, RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final reply = socket.receive();
    if (reply == null) return;
    if (!isSimulatorReply(utf8.decode(reply.data, allowMalformed: true))) return;
    if (reply.address.isLoopback || _ownAddresses.contains(reply.address.address)) return;

    final found = _found;
    if (found != null && found != reply.address) return;
    _lastReply = DateTime.now();
    if (found == null) {
      _found = reply.address;
      debugPrint('SimBridge: simulador en ${reply.address.address}');
      notifyListeners();
    }
  }

  void _closeSocket() {
    _socket?.close();
    _socket = null;
  }

  void _close() {
    _probeTimer?.cancel();
    _probeTimer = null;
    _closeSocket();
    _found = null;
    _samples.clear();
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }
}
