import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/routes.dart';
import 'providers/theme_provider.dart';
import 'services/local_storage_service.dart';
import 'services/firestore_service.dart';
import 'providers/auth_provider.dart';
import 'providers/report_cache_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Manejar mensajes en background (alertas de sesión, etc.)
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Firebase con protección contra duplicados
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Configuración global de Firestore
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // RTDB
  FirebaseDatabase.instance.databaseURL =
      'https://siercp-default-rtdb.firebaseio.com';
  FirebaseDatabase.instance.ref('telemetria').keepSynced(true);

  if (!kIsWeb) {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    await LocalStorageService.init();
  }

  // Notificaciones push
  try {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  } catch (e) {
    debugPrint('Error al inicializar notificaciones: $e');
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final container = ProviderContainer();
  // Limpiar reportes viejos del cache (1-3 días)
  try {
    container.read(reportCacheProvider.notifier).clearOldReports();
  } catch (e) {
    debugPrint('Error al limpiar cache de reportes: $e');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SiercpApp(),
    ),
  );
}

class SiercpApp extends ConsumerWidget {
  const SiercpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final currentThemeMode = ref.watch(themeModeProvider);

    return LifecycleObserver(
      child: MaterialApp.router(
        title: 'SIERCP',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: currentThemeMode,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class LifecycleObserver extends ConsumerStatefulWidget {
  final Widget child;
  const LifecycleObserver({super.key, required this.child});

  @override
  ConsumerState<LifecycleObserver> createState() => _LifecycleObserverState();
}

class _LifecycleObserverState extends ConsumerState<LifecycleObserver> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final firestore = ref.read(firestoreServiceProvider);
    if (state == AppLifecycleState.resumed) {
      firestore.updateUserStatus(user.id, isOnline: true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      firestore.updateUserStatus(user.id, isOnline: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios de usuario para marcar online al iniciar sesión
    ref.listen(currentUserProvider, (prev, next) {
      if (next != null && prev == null) {
        ref.read(firestoreServiceProvider).updateUserStatus(next.id, isOnline: true);
      }
    });
    
    return widget.child;
  }
}
