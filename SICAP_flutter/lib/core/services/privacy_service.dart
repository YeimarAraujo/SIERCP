import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:siercp/core/constants/constants.dart';

/// Datos del representante legal de un menor de edad (Ley 1581, art. 7).
class Guardian {
  const Guardian({
    required this.name,
    required this.documentType,
    required this.document,
    required this.relationship,
    required this.email,
  });

  final String name;
  final String documentType;
  final String document;
  final String relationship;
  final String email;

  Map<String, String> toJson() => {
        'name': name,
        'documentType': documentType,
        'document': document,
        'relationship': relationship,
        'email': email,
      };
}

/// Autorización de datos y derechos del titular, contra /api/privacy.
///
/// La constancia la guarda el servidor con fecha e IP; la app no puede
/// escribirla directamente en Firestore.
class PrivacyService {
  PrivacyService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static Uri get _uri => Uri.parse('${AppConstants.apiBaseUrl}/privacy');

  Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw Exception('Sesión no válida. Inicia sesión nuevamente.');
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final res = await _client.post(_uri, headers: await _headers(), body: jsonEncode(body));
    final data = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw PrivacyException(
        (data['error'] as String?) ?? 'Error ${res.statusCode}',
        needsGuardian: data['needsGuardian'] == true,
      );
    }
    return data;
  }

  /// Registra la autorización de la política vigente.
  Future<void> recordConsent({
    required String birthDate,
    required bool marketing,
    Guardian? guardian,
  }) =>
      _post({
        'action': 'consent',
        'policyVersion': AppConstants.privacyPolicyVersion,
        'channel': 'app',
        'birthDate': birthDate,
        'marketing': marketing,
        if (guardian != null) 'guardian': guardian.toJson(),
      });

  Future<void> setMarketing(bool enabled) =>
      _post({'action': 'marketing', 'enabled': enabled, 'channel': 'app'});

  /// Abre una consulta o reclamo. Devuelve la fecha límite de respuesta.
  Future<DateTime> request(String type, String message) async {
    final data = await _post({'action': 'request', 'type': type, 'message': message});
    return DateTime.parse(data['dueAt'] as String).toLocal();
  }

  /// Descarga todos los datos del usuario a un archivo JSON.
  Future<File> exportData() async {
    final res = await _client.get(_uri, headers: await _headers());
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw PrivacyException((data['error'] as String?) ?? 'Error ${res.statusCode}');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/mis-datos-sicap.json');
    return file.writeAsBytes(res.bodyBytes);
  }
}

class PrivacyException implements Exception {
  PrivacyException(this.message, {this.needsGuardian = false});

  final String message;
  final bool needsGuardian;

  @override
  String toString() => message;
}
