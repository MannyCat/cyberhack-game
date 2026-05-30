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
      backgroundColor: const Color(0xFF0a0e17),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  children: [
                    const Icon(Icons.notifications, color: Color(0xFF00e5ff), size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'УВЕДОМЛЕНИЯ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    if (notifications.isNotEmpty) ...[
                      const Spacer(),
                      Text(
                        '${notifications.length}',
                        style: const TextStyle(color: Color(0xFF4a5568), fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                    if (notificationProvider.hasUnread) ...[
                      const SizedBox(width: 16),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => notificationProvider.markAllAsRead(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00e5ff).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF00e5ff).withValues(alpha: 0.3)),
                            ),
                            child: const Text('ПРОЧЕТАТЬ ВСЕ', style: TextStyle(color: Color(0xFF00e5ff), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ),
                        ),
                      ),
                    ],
                    if (notifications.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => notificationProvider.clearAll(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF1744).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFF1744).withValues(alpha: 0.3)),
                            ),
                            child: const Text('ОЧИСТИТЬ', style: TextStyle(color: Color(0xFFFF1744), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Content ──
              Expanded(
                child: notifications.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
                            onDismiss: () {
                              notificationProvider.clearAll();
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_off_outlined, size: 72, color: Color(0xFF1e293b)),
          const SizedBox(height: 20),
          const Text('Нет уведомлений', style: TextStyle(color: Color(0xFF4a5568), fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'Здесь будут отображаться атаки, сообщения банды и события.',
            style: TextStyle(color: Color(0xFF3a4060), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatefulWidget {
  final GameNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final typeConfig = _getTypeConfig(widget.notification.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: widget.notification.isRead
                  ? const Color(0xFF0d1220)
                  : typeConfig.color.withValues(alpha: _isHovered ? 0.1 : 0.06),
              border: Border.all(
                color: widget.notification.isRead
                    ? const Color(0xFF1e293b)
                    : typeConfig.color.withValues(alpha: 0.3),
                width: widget.notification.isRead ? 0.5 : 1.5,
              ),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: widget.notification.isRead
                        ? const Color(0xFF111827)
                        : typeConfig.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.notification.isRead
                          ? const Color(0xFF1e293b)
                          : typeConfig.color.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    typeConfig.icon,
                    color: widget.notification.isRead ? const Color(0xFF4a5568) : typeConfig.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 18),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.notification.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: widget.notification.isRead
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : typeConfig.color,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeConfig.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              typeConfig.label,
                              style: TextStyle(color: typeConfig.color.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Spacer(),
                          // Dismiss button (visible on hover)
                          if (_isHovered)
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: widget.onDismiss,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF1744).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.close, color: Color(0xFFFF1744), size: 16),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.notification.body,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: widget.notification.isRead ? 0.35 : 0.6),
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _timeAgo(widget.notification.createdAt),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Unread indicator
                if (!widget.notification.isRead)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                      color: typeConfig.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: typeConfig.color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1),
                      ],
                    ),
                  )
                else
                  const SizedBox(width: 10),
              ],
            ),
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
      'attack' => const _NotificationTypeConfig(icon: Icons.shield, color: Color(0xFFFF1744), label: 'Атака'),
      'clan' => const _NotificationTypeConfig(icon: Icons.groups, color: Color(0xFFa855f7), label: 'Банда'),
      'event' => const _NotificationTypeConfig(icon: Icons.calendar_today, color: Color(0xFF00e5ff), label: 'Событие'),
      'system' => const _NotificationTypeConfig(icon: Icons.info_outline, color: Color(0xFF78909c), label: 'Система'),
      'reward' => const _NotificationTypeConfig(icon: Icons.card_giftcard, color: Color(0xFFFFD700), label: 'Награда'),
      _ => const _NotificationTypeConfig(icon: Icons.notifications, color: Color(0xFF00F0FF), label: 'Общее'),
    };
  }
}

class _NotificationTypeConfig {
  final IconData icon;
  final Color color;
  final String label;

  const _NotificationTypeConfig({required this.icon, required this.color, required this.label});
}
