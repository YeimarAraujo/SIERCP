import 'package:flutter/material.dart';
import 'package:siercp/core/widgets/app_logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/notifications/presentation/providers/notification_provider.dart';
import 'package:siercp/features/notifications/data/models/notification.dart';
import 'package:siercp/core/services/firestore_service.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Al abrir la pantalla, marca los anuncios masivos como vistos (sello por
    // usuario). Las notificaciones personales se marcan individualmente al tocar
    // o con "Leer todo".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref.read(firestoreServiceProvider).markBroadcastsSeen(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // La lista combina notificaciones personales + broadcasts (anuncios).
    final notifications = ref.watch(combinedNotificationsProvider);
    final personalAsync = ref.watch(notificationsStreamProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (user != null)
            TextButton(
              onPressed: () {
                final fs = ref.read(firestoreServiceProvider);
                fs.markAllNotificationsAsRead(user.id);
                fs.markBroadcastsSeen(user.id);
              },
              child: const Text('Leer todo'),
            ),
        ],
      ),
      body: personalAsync.isLoading && notifications.isEmpty
          ? const AppLogoLoader()
          : notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No tienes notificaciones',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    return _NotificationTile(notification: notifications[i]);
                  },
                ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final NotificationModel notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        // Los broadcasts no tienen estado de lectura por documento; ya se
        // marcan como vistos al abrir la pantalla. Las personales se marcan aquí.
        if (!notification.isBroadcast && !notification.isRead) {
          ref
              .read(firestoreServiceProvider)
              .markNotificationAsRead(notification.id);
        }
        final link = notification.link;
        if (link != null && link.isNotEmpty && link != '#') {
          context.go(link);
        }
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
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.8),
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

  Widget _buildIcon(NotificationType type) {
    IconData icon;
    Color color;

    switch (type) {
      case NotificationType.studentJoinedCourse:
        icon = Icons.person_add_rounded;
        color = AppColors.brand;
        break;
      case NotificationType.studentAddedToCourse:
        icon = Icons.school_rounded;
        color = AppColors.cyan;
        break;
      case NotificationType.enrollment:
        icon = Icons.how_to_reg_rounded;
        color = AppColors.brand;
        break;
      case NotificationType.certificate:
        icon = Icons.workspace_premium_rounded;
        color = AppColors.amber;
        break;
      case NotificationType.payment:
        icon = Icons.payments_rounded;
        color = AppColors.cyan;
        break;
      case NotificationType.courseUpdate:
        icon = Icons.menu_book_rounded;
        color = AppColors.brand;
        break;
      case NotificationType.liveSession:
        icon = Icons.podcasts_rounded;
        color = AppColors.brand;
        break;
      case NotificationType.quiz:
        icon = Icons.quiz_rounded;
        color = AppColors.cyan;
        break;
      case NotificationType.achievement:
        icon = Icons.emoji_events_rounded;
        color = AppColors.amber;
        break;
      case NotificationType.reminder:
        icon = Icons.alarm_rounded;
        color = AppColors.amber;
        break;
      case NotificationType.systemAlert:
        icon = Icons.campaign_rounded;
        color = AppColors.amber;
        break;
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
