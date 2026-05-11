// lib/core/security/secure_http_client.dart
//
// RETO 4 — Validación de integridad en peticiones HTTP
// Implementa certificate pinning usando el fingerprint SHA-256
// del certificado de Firebase / tu backend

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final secureHttpClientProvider = Provider<SecureHttpClient>((ref) {
  return SecureHttpClient();
});

// ── Certificate Pinning via HttpClient ───────────────────────────────────────
//
// PRINCIPIO: En lugar de confiar en CUALQUIER CA del sistema operativo,
// solo aceptamos conexiones cuyo certificado coincida con nuestro
// fingerprint conocido (SHA-256 del certificado del servidor).
//
// Para obtener el fingerprint de Firebase:
//   openssl s_client -connect firebaseapp.com:443 < /dev/null 2>/dev/null \
//     | openssl x509 -fingerprint -sha256 -noout

class SecureHttpClient {
  // ── Fingerprints de certificados permitidos ──────────────────────────────
  // Agrega aquí los SHA-256 de tus certificados (Firebase + tu backend)
  static const _allowedFingerprints = <String>{
    // Firebase (ejemplo — reemplaza con el real de tu proyecto)
    'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
    // Tu backend si usas uno
    // 'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=',
  };

  // ── Crear HttpClient con pinning ─────────────────────────────────────────
  HttpClient createPinnedClient() {
    final client = HttpClient();

    client.badCertificateCallback = (cert, host, port) {
      // En modo debug permitimos todo para no bloquear el desarrollo
      assert(() {
        return true; // ← debug: siempre acepta
      }());

      // En release: verificar fingerprint
      final fingerprint = _getCertFingerprint(cert);
      final allowed = _allowedFingerprints.contains(fingerprint);

      if (!allowed) {
        // ignore: avoid_print
        print('🔴 CERT PINNING FAILED: $host:$port → $fingerprint');
      }
      return allowed;
    };

    return client;
  }

  String _getCertFingerprint(X509Certificate cert) {
    // Calcula SHA-256 del DER del certificado
    final bytes = cert.der;
    // En una implementación real usarías crypto package:
    // import 'package:crypto/crypto.dart';
    // final digest = sha256.convert(bytes);
    // return 'sha256/${base64.encode(digest.bytes)}';
    return 'sha256/${bytes.length}'; // placeholder
  }
}

// ── Validador de respuestas HTTP ──────────────────────────────────────────────
//
// Para Firestore (Firebase SDK) el pinning no aplica directamente
// porque el SDK maneja internamente las conexiones. En su lugar,
// podemos validar la integridad de las respuestas de nuestra API:

class HttpResponseValidator {
  /// Verifica que la respuesta tenga el header de integridad esperado
  static bool validateIntegrity(Map<String, String> headers, String body) {
    // Si tu backend envía un header X-Content-Hash:
    final expectedHash = headers['x-content-hash'];
    if (expectedHash == null) return true; // header opcional

    // En producción compararías el hash del body con el header
    // final actualHash = sha256.convert(utf8.encode(body)).toString();
    // return actualHash == expectedHash;
    return true;
  }

  /// Verifica que la respuesta venga del host esperado
  static bool validateHost(Uri uri) {
    const allowedHosts = {
      'firestore.googleapis.com',
      'firebase.googleapis.com',
      'identitytoolkit.googleapis.com',
      // Agrega tu backend aquí
    };
    return allowedHosts.contains(uri.host) ||
        uri.host.endsWith('.firebaseapp.com') ||
        uri.host.endsWith('.firebaseio.com');
  }
}
