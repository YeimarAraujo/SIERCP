import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

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
