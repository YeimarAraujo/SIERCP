import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:siercp/features/session/data/models/session.dart';
import 'package:siercp/features/session/data/sim_bridge_service.dart';

LiveSessionData _data() => LiveSessionData(
      depthMm: 55.26,
      ratePerMin: 110,
      forceKg: 0,
      compressionCount: 12,
      correctCompressionCount: 9,
      correctPct: 75,
      sessionScore: 81.23,
      decompressedFully: true,
      recoilPct: 91.67,
      pauseCount: 1,
      maxPauseSec: 3.21,
      sensorOk: true,
      calibrated: true,
    );

void main() {
  test('el paquete usa los campos que espera Unity', () {
    final packet = jsonDecode(SimBridgeService.encodePacket(
      sessionId: 'abc',
      scenarioId: 'descargaElectrica',
      sequence: 7,
      depths: const [10.04, 55.26],
      data: _data(),
    )) as Map<String, dynamic>;

    expect(packet['v'], SimBridgeService.protocolVersion);
    expect(packet['sid'], 'abc');
    expect(packet['sc'], 'descargaElectrica');
    expect(packet['d'], [10.0, 55.3]);
    expect(packet['c'], 12);
    expect(packet['cc'], 9);
    expect(packet['r'], 110);
    expect(packet['ok'], isTrue);
    expect(packet['end'], isFalse);
    expect(packet.keys, isNot(contains('studentName')));
  });

  test('apagado por defecto: no acumula ni publica', () {
    final bridge = SimBridgeService();
    expect(bridge.enabled, isFalse);
    expect(() => bridge.addSample('abc', 'paroCardiaco', _data()), returnsNormally);
  });

  test('valida la IP opcional del PC', () {
    expect(SimBridgeService.isValidTarget(''), isTrue);
    expect(SimBridgeService.isValidTarget('192.168.1.20'), isTrue);
    expect(SimBridgeService.isValidTarget('mi-pc'), isFalse);
  });

  test('difunde en la red del equipo y reconoce al simulador', () {
    expect(SimBridgeService.broadcastOf('192.168.1.45'), '192.168.1.255');
    expect(SimBridgeService.broadcastOf('169.254.3.4'), isNull);
    expect(SimBridgeService.isSimulatorReply('{"sicapsim":1}'), isTrue);
    expect(SimBridgeService.isSimulatorReply('{"probe":1}'), isFalse);
  });
}
