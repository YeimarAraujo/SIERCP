import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/features/notifications/data/models/notification.dart';
import 'package:siercp/core/services/firestore_service.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';

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

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsStreamProvider).value ?? [];
  return notifications.where((n) => !n.isRead).length;
});
