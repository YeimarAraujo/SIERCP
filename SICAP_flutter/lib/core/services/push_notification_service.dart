import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:siercp/firebase_options.dart';

/// Handler de mensajes recibidos con la app en SEGUNDO PLANO o CERRADA.
///
/// Debe ser una función top-level anotada con `@pragma('vm:entry-point')` para
/// que el motor de Dart la conserve en release. Aquí NO se pinta UI: cuando el
/// mensaje FCM trae el bloque `notification`, el SISTEMA OPERATIVO muestra la
/// notificación automáticamente aunque la app esté cerrada. Por eso no hace
/// falta ningún paquete extra ni Cloud Functions de pago para el caso clave
/// (recibir notificaciones con la app cerrada).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint(
    'FCM background: ${message.messageId} - ${message.notification?.title}',
  );
}

/// Servicio de notificaciones push con Firebase Cloud Messaging (FCM).
///
/// 100% GRATUITO en el cliente. El ENVÍO a dispositivos con la app cerrada lo
/// hace el Cloudflare Worker gratuito (carpeta `cloudflare-worker/`), NO Cloud
/// Functions de pago.
///
/// Comportamiento por estado de la app:
///  - CERRADA / SEGUNDO PLANO: el SO muestra la notificación (payload
///    `notification`). Al tocarla se abre la app y se navega vía `data.link`.
///  - PRIMER PLANO: FCM no muestra nada por sí solo; aquí mostramos un banner
///    in-app (SnackBar) con acción para abrir el destino.
///
/// Además guarda el token en `users/{uid}.fcmToken` y suscribe a tópicos
/// (`all`, `role_<rol>`, `inst_<institutionId>`) para envíos masivos.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  /// Para mostrar SnackBars en primer plano sin un BuildContext directo.
  /// `main.dart` lo asigna a `MaterialApp.router(scaffoldMessengerKey: ...)`.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  /// Lo asigna `main.dart` con `router.go`. Si llega un tap antes, queda pendiente.
  void Function(String route)? _onNavigate;
  String? _pendingRoute;
  bool _initialized = false;

  set onNavigate(void Function(String route)? handler) {
    _onNavigate = handler;
    if (handler != null && _pendingRoute != null) {
      final route = _pendingRoute!;
      _pendingRoute = null;
      handler(route);
    }
  }

  /// Inicializa el pipeline de push. Llamar una vez en `main()` (Android/iOS).
  /// Es idempotente.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('Permiso notificaciones: ${settings.authorizationStatus}');

      // En iOS, permite que el SO muestre el banner también en primer plano.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Primer plano: mostramos un SnackBar in-app.
      FirebaseMessaging.onMessage.listen(_showForegroundBanner);

      // App en segundo plano y el usuario toca la notificación.
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => _navigateFromData(m.data),
      );

      // App abierta desde estado terminado por tocar una notificación.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _navigateFromData(initial.data);

      // Token: guardar + escuchar renovaciones.
      _messaging.onTokenRefresh.listen(_saveToken);
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('Error inicializando push: $e');
    }
  }

  /// Llamar tras login (por si el usuario inició sesión después de initialize()).
  Future<void> syncForCurrentUser() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('Error sincronizando token: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final users = FirebaseFirestore.instance.collection('users');
      await users.doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Tópico global (anuncios a todos).
      await subscribeToTopic('all');

      // Tópicos por rol e institución (si el doc del usuario los tiene).
      final snap = await users.doc(user.uid).get();
      final data = snap.data();
      final role = (data?['role'] as String?)?.trim();
      final institutionId = (data?['institutionId'] as String?)?.trim();
      if (role != null && role.isNotEmpty) {
        await subscribeToTopic('role_$role');
      }
      if (institutionId != null && institutionId.isNotEmpty) {
        await subscribeToTopic('inst_$institutionId');
      }
    } catch (e) {
      debugPrint('Error guardando token FCM: $e');
    }
  }

  void _showForegroundBanner(RemoteMessage message) {
    final n = message.notification;
    final messenger = messengerKey.currentState;
    if (n == null || messenger == null) return;

    final title = n.title ?? 'SIERCP';
    final body = n.body ?? '';
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (body.isNotEmpty) Text(body),
          ],
        ),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () => _navigateFromData(message.data),
        ),
      ),
    );
  }

  void _navigateFromData(Map<String, dynamic> data) {
    final raw = (data['link'] ?? data['route']) as String?;
    final route =
        (raw != null && raw.isNotEmpty && raw != '#') ? raw : '/notifications';
    if (_onNavigate != null) {
      _onNavigate!(route);
    } else {
      _pendingRoute = route; // se entrega cuando main() asigne onNavigate.
    }
  }

  Future<void> subscribeToTopic(String topic) =>
      _messaging.subscribeToTopic(topic);

  Future<void> unsubscribeFromTopic(String topic) =>
      _messaging.unsubscribeFromTopic(topic);

  /// Llamar al cerrar sesión para dejar de recibir push de ese usuario.
  Future<void> clearOnSignOut({String? role, String? institutionId}) async {
    try {
      await unsubscribeFromTopic('all');
      if (role != null && role.isNotEmpty) {
        await unsubscribeFromTopic('role_$role');
      }
      if (institutionId != null && institutionId.isNotEmpty) {
        await unsubscribeFromTopic('inst_$institutionId');
      }
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('Error limpiando token FCM: $e');
    }
  }
}
