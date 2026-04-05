import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/notification_entry.dart';
import 'notification_store_service.dart';
import 'notification_badge_controller.dart';

/// Ön planda gelen APNs verisi için yerel bildirim (sistem tepsisi).
class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _tzInitialized = false;

  /// [PushNotificationService.initialize] ve arka plan işleyicide birer kez çağrılabilir.
  static Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      ),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      const channel = AndroidNotificationChannel(
        'daily_widget_channel',
        'Günlük içerik',
        description: 'Yeni motivasyon bildirimleri',
        importance: Importance.high,
      );
      await android.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  static Future<void> _ensureTz() async {
    if (_tzInitialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.local);
    _tzInitialized = true;
  }

  /// Kullanıcı "Bugün bu sözle ne yaptın?" alanına aksiyon eklediğinde,
  /// ertesi gün için hatırlatma bildirimi planlar.
  static Future<void> scheduleTomorrowReflectionReminder(String quote) async {
    await init();
    await _ensureTz();

    final now = tz.TZDateTime.now(tz.local);
    //final scheduled = now.add(const Duration(days: 1));
    final scheduled = now.add(const Duration(minutes: 1)); // TEST için
    final id = now.millisecondsSinceEpoch.abs() % 2147483647;

    final title = 'Dünkü sözünü hatırlıyor musun?';
    final body =
        'Dün hayatına “$quote” sözüyle dokunabildik, acaba bugün dokunabilecek miyiz?';

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_widget_channel',
          'Günlük içerik',
          channelDescription: 'Yeni motivasyon bildirimleri',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );

    final entry = NotificationEntry(
      id: id.toString(),
      title: title,
      body: body,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      read: false,
      type: 'REFLECTION_REMINDER',
    );
    await NotificationStoreService.addNotification(entry);
    await NotificationBadgeController.instance.refresh();
  }

  static Map<String, String> _titleBodyFromAps(Map<String, dynamic> data) {
    final aps = data['aps'];
    if (aps is Map) {
      final alert = aps['alert'];
      if (alert is Map) {
        return {
          'title': (alert['title'] ?? '').toString().trim(),
          'body': (alert['body'] ?? '').toString().trim(),
        };
      }
      if (alert is String && alert.trim().isNotEmpty) {
        return {'title': '', 'body': alert.trim()};
      }
    }
    return {'title': '', 'body': ''};
  }

  /// APNs `userInfo` — günlük içerik veya yorum yanıtı.
  static Future<void> showFromPushData(
    Map<String, dynamic> data, {
    required bool isForeground,
  }) async {
    final t = data['type']?.toString();
    final isDaily = t == 'DAILY_WIDGET' || t == 'DAILY_WIDGET_UPDATE';
    final isCommentReply = t == 'COMMENT_REPLY';
    if (!isDaily && !isCommentReply) return;

    if (!isForeground) {
      return;
    }

    String title;
    String body;
    String entryType;
    if (isCommentReply) {
      final fromAps = _titleBodyFromAps(data);
      title = fromAps['title']!.isNotEmpty ? fromAps['title']! : 'Yeni yanıt';
      body = fromAps['body']!.isNotEmpty ? fromAps['body']! : 'Yorumunuza yanıt var.';
      entryType = 'COMMENT_REPLY';
    } else {
      title = (data['title'] ?? 'DAHA').toString().trim();
      body = (data['body'] ?? '').toString().trim();
      if (title.isEmpty) {
        final fromAps = _titleBodyFromAps(data);
        if (fromAps['title']!.isNotEmpty) title = fromAps['title']!;
      }
      if (title.isEmpty) title = 'DAHA';
      if (body.isEmpty) {
        final fromAps = _titleBodyFromAps(data);
        if (fromAps['body']!.isNotEmpty) body = fromAps['body']!;
      }
      if (body.isEmpty) body = 'Yeni içerik hazır.';
      entryType = 'DAILY_WIDGET';
    }

    final id = DateTime.now().millisecondsSinceEpoch;

    await _plugin.show(
      id.abs() % 2147483647,
      title,
      body.length > 350 ? '${body.substring(0, 347)}…' : body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_widget_channel',
          'Günlük içerik',
          channelDescription: 'Yeni motivasyon bildirimleri',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    final entry = NotificationEntry(
      id: id.toString(),
      title: title,
      body: body,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      read: false,
      type: entryType,
    );
    await NotificationStoreService.addNotification(entry);
    await NotificationBadgeController.instance.refresh();
  }
}
