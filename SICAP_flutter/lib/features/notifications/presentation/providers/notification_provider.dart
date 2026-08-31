import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/features/notifications/data/models/notification.dart';
import 'package:siercp/core/services/firestore_service.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';

/// Notificaciones personales del usuario (colección `notifications`).
final notificationsStreamProvider = StreamProvider<List<NotificationModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final firestore = ref.read(firestoreServiceProvider);

  return firestore.watchNotifications(user.id).handleError((error) {
    debugPrint('❌ Error en Stream de Notificaciones: $error');
    // Si hay error (permisos, etc), devolvemos lista vacía para no bloquear la UI
    return <NotificationModel>[];
  });
});

/// Metadatos del doc del usuario necesarios para los broadcasts:
/// `role`, `institutionId` (no expuestos en UserModel) y `lastBroadcastSeenAt`.
final _userMetaProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(<String, dynamic>{});
  return ref
      .read(firestoreServiceProvider)
      .watchUserDocRaw(user.id)
      .handleError((_) => <String, dynamic>{});
});

/// Anuncios masivos (colección `broadcasts`) filtrados por la audiencia que
/// corresponde al usuario (all / su rol / su institución). El estado de lectura
/// se calcula contra `lastBroadcastSeenAt` del propio usuario.
final broadcastsStreamProvider = StreamProvider<List<NotificationModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final meta = ref.watch(_userMetaProvider).value ?? const {};
  final role = meta['role'] as String?;
  final institutionId = meta['institutionId'] as String?;
  final ts = meta['lastBroadcastSeenAt'];
  final lastSeen = ts is Timestamp ? ts.toDate() : null;

  return ref
      .read(firestoreServiceProvider)
      .watchBroadcasts(
        role: role,
        institutionId: institutionId,
        lastSeen: lastSeen,
      )
      .handleError((error) {
    debugPrint('❌ Error en Stream de Broadcasts: $error');
    return <NotificationModel>[];
  });
});

/// Lista combinada (personales + broadcasts) ordenada por fecha descendente.
/// Es lo que debe consumir la pantalla de Notificaciones y la campanita.
final combinedNotificationsProvider = Provider<List<NotificationModel>>((ref) {
  final personal = ref.watch(notificationsStreamProvider).value ?? [];
  final broadcasts = ref.watch(broadcastsStreamProvider).value ?? [];
  final all = [...personal, ...broadcasts]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return all;
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final all = ref.watch(combinedNotificationsProvider);
  return all.where((n) => !n.isRead).length;
});
