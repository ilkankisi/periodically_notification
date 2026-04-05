import 'package:flutter/foundation.dart';

import 'notification_store_service.dart';

class NotificationBadgeController extends ChangeNotifier {
  NotificationBadgeController._();

  static final NotificationBadgeController instance =
      NotificationBadgeController._();

  int _unreadCount = 0;

  int get unreadCount => _unreadCount;

  Future<void> refresh() async {
    await NotificationStoreService.syncFromBackend();
    final count = await NotificationStoreService.getUnreadCount();
    if (count != _unreadCount) {
      _unreadCount = count;
      notifyListeners();
    }
  }

  void setUnreadCount(int count) {
    if (count != _unreadCount) {
      _unreadCount = count;
      notifyListeners();
    }
  }
}

