import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/notification_provider.dart';
import '../services/firestore_service.dart';
import '../providers/auth_provider.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (user != null)
            TextButton(
              onPressed: () => ref.read(firestoreServiceProvider).markAllNotificationsAsRead(user.id),
              child: const Text('Leer todo'),
            ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No tienes notificaciones', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final n = list[i];
                  return _NotificationTile(notification: n);
                },
              ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final dynamic notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        if (!notification.isRead) {
          ref.read(firestoreServiceProvider).markNotificationAsRead(notification.id);
        }
        // Navegación opcional según el tipo
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead 
              ? Colors.transparent 
              : theme.colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notification.isRead 
                ? theme.dividerColor 
                : theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIcon(notification.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(notification.createdAt),
                        style: TextStyle(fontSize: 10, color: theme.hintColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(dynamic type) {
    IconData icon;
    Color color;

    switch (type.name) {
      case 'studentJoinedCourse':
        icon = Icons.person_add_rounded;
        color = AppColors.brand;
        break;
      case 'studentAddedToCourse':
        icon = Icons.school_rounded;
        color = AppColors.cyan;
        break;
      default:
        icon = Icons.info_outline_rounded;
        color = AppColors.amber;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
