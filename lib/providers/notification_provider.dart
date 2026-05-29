import 'package:flutter/foundation.dart';

class GameNotification {
  final String id;
  final String title;
  final String body;
  final String type; // attack, clan, event, system, reward
  final DateTime createdAt;
  final bool isRead;
  final String? actionRoute; // optional route to navigate to

  const GameNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.actionRoute,
  });
}

class NotificationProvider extends ChangeNotifier {
  final List<GameNotification> _notifications = [];
  int _unreadCount = 0;

  List<GameNotification> get notifications => List.unmodifiable(_notifications.reversed);
  int get unreadCount => _unreadCount;
  bool get hasUnread => _unreadCount > 0;

  void addNotification(GameNotification notification) {
    _notifications.add(notification);
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  void addAttackNotification({required String attackerName, required String damage}) {
    addNotification(GameNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '⚠️ АТАКА ОБНАРУЖЕНА',
      body: '$attackerName атаковал вашу сеть! Урон: $damage',
      type: 'attack',
      createdAt: DateTime.now(),
      actionRoute: '/game/network',
    ));
  }

  void addClanNotification({required String message}) {
    addNotification(GameNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Банда',
      body: message,
      type: 'clan',
      createdAt: DateTime.now(),
      actionRoute: '/game/clan',
    ));
  }

  void addEventNotification({required String eventName}) {
    addNotification(GameNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Событие',
      body: '$eventName начался! Присоединяйтесь!',
      type: 'event',
      createdAt: DateTime.now(),
      actionRoute: '/game/events',
    ));
  }

  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = GameNotification(
        id: _notifications[idx].id,
        title: _notifications[idx].title,
        body: _notifications[idx].body,
        type: _notifications[idx].type,
        createdAt: _notifications[idx].createdAt,
        isRead: true,
        actionRoute: _notifications[idx].actionRoute,
      );
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = GameNotification(
        id: _notifications[i].id,
        title: _notifications[i].title,
        body: _notifications[i].body,
        type: _notifications[i].type,
        createdAt: _notifications[i].createdAt,
        isRead: true,
        actionRoute: _notifications[i].actionRoute,
      );
    }
    _unreadCount = 0;
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
  }
}
