import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/features/users/data/models/user.dart';

/// Búsqueda de personas en el servidor (/api/people).
///
/// Las reglas de Firestore no dejan leer perfiles de otras instituciones
/// (Ley 1581: acceso restringido). Inscribir por cédula necesita cruzar ese
/// límite, así que el servidor valida que quien busca sea personal de un curso o
/// institución y devuelve solo los datos necesarios.
class PeopleService {
  PeopleService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw Exception('Sesión no válida. Inicia sesión nuevamente.');
    final res = await _client.post(
      Uri.parse('${AppConstants.apiBaseUrl}/people'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(body),
    );
    final data = jsonDecode(res.body.isEmpty ? '{}' : res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(data['error'] ?? 'Error ${res.statusCode}');
    }
    return data;
  }

  static UserModel fromCard(Map<String, dynamic> card) => UserModel(
        id: card['uid'] as String,
        email: (card['email'] as String?) ?? '',
        firstName: (card['firstName'] as String?) ?? '',
        lastName: (card['lastName'] as String?) ?? '',
        role: (card['role'] as String?) ?? '',
        avatarUrl: card['avatarUrl'] as String?,
        identificacion: card['identification'] as String?,
      );

  /// Persona con esa cédula, o null si no existe.
  Future<UserModel?> findByIdentification(String identification) async {
    final data = await _post({'action': 'lookup', 'identification': identification});
    final person = data['person'];
    return person is Map<String, dynamic> ? fromCard(person) : null;
  }

  /// Persona con ese correo, o null si no existe.
  Future<UserModel?> findByEmail(String email) async {
    final data = await _post({'action': 'lookup', 'email': email});
    final person = data['person'];
    return person is Map<String, dynamic> ? fromCard(person) : null;
  }

  /// Perfiles mínimos de las personas con las que el usuario tiene relación.
  Future<List<UserModel>> getMany(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final data = await _post({'action': 'batch', 'ids': ids});
    return ((data['people'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(fromCard)
        .toList();
  }
}
