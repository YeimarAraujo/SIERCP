import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:siercp/l10n/app_localizations.dart';
import 'package:siercp/firebase_options.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/core/routes.dart';
import 'package:siercp/core/theme/theme_provider.dart';
import 'package:siercp/core/theme/locale_provider.dart';
import 'package:siercp/core/services/local_storage_service.dart';
import 'package:siercp/core/services/firestore_service.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/reports/presentation/providers/report_cache_provider.dart';
import 'package:siercp/core/services/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:siercp/core/constants/environment.dart';
import 'package:siercp/core/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    name: 'siercp',
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Configuración global de Firestore
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  // Pre-warm Firestore: triggers lazy init (SQLite persistence, gRPC, etc.)
  // during splash instead of blocking the main thread on the first real query.
  try {
    await FirebaseFirestore.instance
        .collection('_warmup')
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    // Colección dummy que no existe — el objetivo es forzar la inicialización.
  }

  // RTDB (Configurada exclusivamente vía --dart-define=RTDB_URL=...)
  if (Environment.isConfigured) {
    FirebaseDatabase.instance.databaseURL = Environment.rtdbUrl;
    FirebaseDatabase.instance.ref('telemetria').keepSynced(true);
  }

  if (!kIsWeb) {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    await LocalStorageService.init();
  }

  // Notificaciones push (FCM) — recibir incluso con la app cerrada.
  Future<void> initNotifications() async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await PushNotificationService.instance.initialize();
      }
    } catch (e) {
      debugPrint('Error notificaciones: $e');
    }
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final container = ProviderContainer();
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
  initNotifications();
}

class SiercpApp extends ConsumerWidget {
  const SiercpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Conecta el tap de las notificaciones push con GoRouter.
    PushNotificationService.instance.onNavigate = router.go;
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentLocale = ref.watch(localeControllerProvider);

    // Inicializar el servicio de sincronización
    ref.read(syncServiceProvider);
    return LifecycleObserver(
      child: MaterialApp.router(
        scaffoldMessengerKey: PushNotificationService.messengerKey,
        title: 'SIERCP',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: currentThemeMode,
        locale: currentLocale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es'),
          Locale('en'),
        ],
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

class _LifecycleObserverState extends ConsumerState<LifecycleObserver>
    with WidgetsBindingObserver {
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
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      firestore.updateUserStatus(user.id, isOnline: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProvider, (prev, next) {
      if (next != null && prev == null) {
        ref
            .read(firestoreServiceProvider)
            .updateUserStatus(next.id, isOnline: true);
      }
    });

    return widget.child;
  }
}
