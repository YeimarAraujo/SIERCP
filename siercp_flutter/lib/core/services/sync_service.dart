import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/services/firestore_service.dart';
import 'package:siercp/core/services/local_storage_service.dart';
import 'package:siercp/core/providers/connectivity_provider.dart';
import 'package:siercp/features/session/data/models/session.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    ref.read(firestoreServiceProvider),
    ref.read(localStorageServiceProvider),
    ref,
  );

  // Escuchar cambios de conectividad para disparar sincronización
  ref.listen(isOnlineProvider, (previous, next) {
    if (next == true && (previous == false || previous == null)) {
      debugPrint(
          '🌐 Conexión recuperada, disparando sincronización de cola...');
      service.processQueue();
    }
  });

  return service;
});

class SyncService {
  final FirestoreService _db;
  final LocalStorageService _localStorage;
  final Ref _ref;
  bool _isSyncing = false;

  SyncService(this._db, this._localStorage, this._ref);

  Future<void> processQueue() async {
    if (_isSyncing) return;

    final items = _localStorage.getPendingSyncItems();
    if (items.isEmpty) return;

    _isSyncing = true;
    debugPrint(
        '🔄 Procesando ${items.length} elementos en la cola de sincronización...');

    for (final item in items) {
      final id = item['id'] as String;
      final type = item['type'] as String;
      final data = item['data'] as Map<String, dynamic>;

      try {
        bool success = false;
        switch (type) {
          case 'session_complete':
            // Sincronizar una sesión que falló al completarse
            final sessionId = data['sessionId'] as String;
            final metricsMap = data['metrics'] as Map<String, dynamic>;
            final duration = data['duration'] as int;

            // Re-hidratar métricas (esto podría fallar si el modelo cambió, pero es poco probable)
            try {
              final metrics = SessionMetrics.fromMap(metricsMap);
              await _db.completeSession(sessionId, metrics, duration);
              success = true;
            } catch (e) {
              debugPrint(
                  '❌ Error al re-hidratar métricas para sincronización: $e');
              // Si el dato está corrupto, lo quitamos de la cola para no bloquearla
              success = true;
            }
            break;

          case 'enrollment':
            // Sincronizar una inscripción (no implementado aún en sync_queue pero listo para futuro)
            break;
        }

        if (success) {
          await _localStorage.removeSyncItem(id);
          debugPrint('✅ Item de sincronización procesado: $id');
        }
      } catch (e) {
        debugPrint('⚠️ Error al sincronizar item $id: $e');
        // Si falla por red, paramos y esperamos a la próxima vez que recupere conexión
        break;
      }
    }

    _isSyncing = false;
  }
}
