import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:siercp/core/constants/constants.dart';

/// Acciones del Skill Passport contra el backend Vercel (plan Spark — sin Cloud
/// Functions). Autenticación con Firebase ID token en `Authorization: Bearer`.
class SkillService {
  SkillService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> _idToken() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) {
      throw Exception('Sesión no válida. Inicia sesión nuevamente.');
    }
    return token;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await _client.post(
      Uri.parse('${AppConstants.apiBaseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await _idToken()}',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Activa/desactiva el perfil público (opt-in). Devuelve el slug público.
  Future<String> setPublicProfile(bool enabled) async {
    final data = await _post('/skills/public-profile', {'enabled': enabled});
    return (data['publicSlug'] as String?) ?? '';
  }

  /// Evalúa una sesión completada y emite las skills correspondientes.
  /// El score se lee en el servidor desde el documento de sesión.
  /// Devuelve los códigos de skill emitidos (puede ser vacío).
  Future<List<String>> evaluateSession(String sessionId) async {
    final data = await _post('/skills/evaluate', {'sessionId': sessionId});
    return ((data['issued'] as List?) ?? const []).cast<String>();
  }
}
