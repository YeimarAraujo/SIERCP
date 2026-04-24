// lib/core/security/secure_storage_service.dart
//
// RETO 4 — Almacenamiento seguro de tokens y datos sensibles
// Usa flutter_secure_storage para guardar en el Keystore (Android)
// y Keychain (iOS) — NUNCA en SharedPreferences

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ── Provider ─────────────────────────────────────────────────────────────────
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

// ── Keys ─────────────────────────────────────────────────────────────────────
class SecureKeys {
  static const authToken = 'auth_token';
  static const refreshToken = 'refresh_token';
  static const userPin = 'user_pin';
  static const biometricKey = 'biometric_key';
  static const lastUserId = 'last_user_id';
}

// ── Service ───────────────────────────────────────────────────────────────────
class SecureStorageService {
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true, // AES256 en Android
  );

  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );

  // ── Escribir ───────────────────────────────────────────────────────────────
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  // ── Leer ──────────────────────────────────────────────────────────────────
  Future<String?> read(String key) async {
    return _storage.read(key: key);
  }

  // ── Eliminar ──────────────────────────────────────────────────────────────
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  // ── Limpiar todo (logout) ──────────────────────────────────────────────────
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // ── Helpers específicos ───────────────────────────────────────────────────
  Future<void> saveAuthToken(String token) =>
      write(SecureKeys.authToken, token);

  Future<String?> getAuthToken() => read(SecureKeys.authToken);

  Future<void> saveRefreshToken(String token) =>
      write(SecureKeys.refreshToken, token);

  Future<String?> getRefreshToken() => read(SecureKeys.refreshToken);

  Future<void> clearSession() async {
    await delete(SecureKeys.authToken);
    await delete(SecureKeys.refreshToken);
  }
}
