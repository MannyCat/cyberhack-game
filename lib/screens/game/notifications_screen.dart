import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final notifications = notificationProvider.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('УВЕДОМЛЕНИЯ'),
        actions: [
          if (notificationProvider.hasUnread)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () => notificationProvider.markAllAsRead(),
                child: const Text(
                  'ПРОЧЕТАТЬ ВСЕ',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
            ),
          if (notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () => notificationProvider.clearAll(),
                child: const Text(
                  'ОЧИСТИТЬ',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFFFF1744)),
                ),
              ),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationCard(
                  notification: notification,
                  onTap: () {
                    notificationProvider.markAsRead(notification.id);
                    if (notification.actionRoute != null) {
                      context.go(notification.actionRoute!);
                    }
                  },
                  onDismissed: (_) {
                    notificationProvider.clearAll();
                    // Remove specific notification by re-adding all except this one
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Уведомление удалено'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Нет уведомлений',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Здесь будут отображаться атаки, сообщения банды и события.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final GameNotification notification;
  final VoidCallback onTap;
  final DismissDirectionCallback onDismissed;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final typeConfig = _getTypeConfig(notification.type);

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: onDismissed,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFF1744).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFF1744).withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.delete_outline, color: Color(0xFFFF1744), size: 20),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: notification.isRead
                ? const Color(0xFF111827)
                : typeConfig.color.withValues(alpha: 0.06),
            border: Border.all(
              color: notification.isRead
                  ? const Color(0xFF1e293b)
                  : typeConfig.color.withValues(alpha: 0.3),
              width: notification.isRead ? 0.5 : 1.5,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: notification.isRead
                      ? const Color(0xFF1a1f2e)
                      : typeConfig.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: notification.isRead
                        ? const Color(0xFF2a2f40)
                        : typeConfig.color.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  typeConfig.icon,
                  color: notification.isRead ? const Color(0xFF4a5568) : typeConfig.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: notification.isRead
                                ? Colors.white.withValues(alpha: 0.6)
                                : typeConfig.color,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: typeConfig.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            typeConfig.label,
                            style: TextStyle(
                              color: typeConfig.color.withValues(alpha: 0.7),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: notification.isRead ? 0.35 : 0.6),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeAgo(notification.createdAt),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              // Unread indicator
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: typeConfig.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: typeConfig.color.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                )
              else
                const Icon(Icons.chevron_right, color: Color(0xFF3a4060), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return '${diff.inHours} ч. назад';
    if (diff.inDays < 7) return '${diff.inDays} д. назад';
    return '${dateTime.day}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year}';
  }

  _NotificationTypeConfig _getTypeConfig(String type) {
    return switch (type) {
      'attack' => const _NotificationTypeConfig(
          icon: Icons.shield,
          color: Color(0xFFFF1744),
          label: 'Атака',
        ),
      'clan' => const _NotificationTypeConfig(
          icon: Icons.groups,
          color: Color(0xFFa855f7),
          label: 'Банда',
        ),
      'event' => const _NotificationTypeConfig(
          icon: Icons.calendar_today,
          color: Color(0xFF00e5ff),
          label: 'Событие',
        ),
      'system' => const _NotificationTypeConfig(
          icon: Icons.info_outline,
          color: Color(0xFF78909c),
          label: 'Система',
        ),
      'reward' => const _NotificationTypeConfig(
          icon: Icons.card_giftcard,
          color: Color(0xFFFFD700),
          label: 'Награда',
        ),
      _ => const _NotificationTypeConfig(
          icon: Icons.notifications,
          color: Color(0xFF00F0FF),
          label: 'Общее',
        ),
    };
  }
}

class _NotificationTypeConfig {
  final IconData icon;
  final Color color;
  final String label;

  const _NotificationTypeConfig({
    required this.icon,
    required this.color,
    required this.label,
  });
}
