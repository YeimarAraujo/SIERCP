import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/routes.dart';
import 'providers/theme_provider.dart';
import 'services/local_storage_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Manejar mensajes en background (alertas de sesión, etc.)
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configurar la URL de Realtime Database explícitamente
  FirebaseDatabase.instance.databaseURL =
      'https://siercp-default-rtdb.firebaseio.com';

  // Configurar notificaciones push
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FirebaseMessaging.instance
      .requestPermission(alert: true, badge: true, sound: true);

  // Inicializar almacenamiento local (SQLite)
  await LocalStorageService.init();
  await LocalStorageService().preloadCache();

  // Mantener sincronización activa del nodo de telemetría para lectura rápida
  FirebaseDatabase.instance.ref('telemetria').keepSynced(true);

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: SiercpApp()));
}

class SiercpApp extends ConsumerWidget {
  const SiercpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final currentThemeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'SIERCP',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: currentThemeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
