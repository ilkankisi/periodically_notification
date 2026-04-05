import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_entry.dart';
import 'auth_service.dart';
import 'backend_service.dart';

/// Basit bildirim store'u - günlük içerik, refleksiyon hatırlatmaları ve sunucu yanıt bildirimleri.
class NotificationStoreService {
  static const _keyNotifications = 'notifications_store_v1';

  static const _localOnlyTypes = {
    'REFLECTION_REMINDER',
    'DAILY_WIDGET',
  };

  static Future<List<NotificationEntry>> _loadRaw() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyNotifications);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => NotificationEntry.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<NotificationEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(entries.map((e) => e.toMap()).toList());
    await prefs.setString(_keyNotifications, encoded);
  }

  static Future<void> addNotification(NotificationEntry entry) async {
    final list = await _loadRaw();
    list.insert(0, entry);
    await _save(list);
  }

  static Future<List<NotificationEntry>> loadAll() async {
    final list = await _loadRaw();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Sunucudaki `in_app_notifications` kayıtlarını çeker ve yerel liste ile birleştirir.
  static Future<void> syncFromBackend() async {
    if (!AuthService.isLoggedIn) return;
    if (!await BackendService.ensureToken()) return;
    final raw = await BackendService.client.getNotifications();
    final serverEntries = raw
        .map((m) => NotificationEntry.fromServerJson(Map<String, dynamic>.from(m)))
        .toList();
    final local = await _loadRaw();
    final localOnly =
        local.where((e) => _localOnlyTypes.contains(e.type)).toList();
    final serverIds = {for (final s in serverEntries) s.id};
    final merged = [...serverEntries];
    for (final l in localOnly) {
      if (!serverIds.contains(l.id)) merged.add(l);
    }
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _save(merged);
  }

  static Future<void> markAllRead() async {
    if (AuthService.isLoggedIn && await BackendService.ensureToken()) {
      await BackendService.client.postNotificationsReadAll();
      await syncFromBackend();
    }
    final list = await _loadRaw();
    final updated = list.map((e) => e.copyWith(read: true)).toList();
    await _save(updated);
  }

  static Future<int> getUnreadCount() async {
    final list = await _loadRaw();
    return list.where((e) => !e.read).length;
  }
}

