import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_app_group_directory/flutter_app_group_directory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/motivation.dart';
import '../utils/media_url.dart';
import '../widgets/motivation_cached_image.dart';
import 'backend_service.dart';
import 'content_sync_service.dart';
import 'local_notification_service.dart';
import 'motivation_cache_service.dart';
import 'motivation_service.dart';

/// Uzak bildirim: yalnızca iOS APNs (Firebase yok). [AppDelegate] `periodically/push` kanalı.
class PushNotificationService {
  PushNotificationService._();

  static const MethodChannel _channel = MethodChannel('periodically/push');

  static const String _widgetTitleKey = 'widget_title';
  static const String _widgetBodyKey = 'widget_body';
  static const String _widgetItemIdKey = 'widget_itemId';
  static const String _widgetUpdatedAtKey = 'widget_updatedAt';
  static const String _widgetImageUrlKey = 'widget_imageUrl';
  static const String _widgetImagePathKey = 'widget_imagePath';

  static final StreamController<void> onContentUpdated = StreamController<void>.broadcast();

  static const String _prefsKeyLastApnsHex = 'push_last_apns_device_hex';
  static String? _lastApnsTokenHex;

  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKeyLastApnsHex);
      if (saved != null && saved.isNotEmpty) _lastApnsTokenHex = saved;
    } catch (_) {}

    if (!kIsWeb && Platform.isIOS) {
      _channel.setMethodCallHandler(_onPlatformMessage);
    }

    try {
      if (!kIsWeb && Platform.isIOS) {
        print('[PUSH] iOS APNs kanalı hazır');
      } else {
        print('[PUSH] Bu platformda uzak push yok (yalnızca iOS APNs)');
      }

      await LocalNotificationService.init();

      await HomeWidget.setAppGroupId('group.com.siyazilim.periodicallynotification').timeout(
        const Duration(seconds: 5),
        onTimeout: () => Future<bool?>.value(null),
      );

      await _seedWidgetFromAssetIfEmpty();
      await ContentSyncService.syncFromBackend();
      await syncApnsTokenWithBackendAfterAuth();
      print('[PUSH] initialize tamam');
    } catch (e) {
      print('[PUSH] initialize hata: $e');
      rethrow;
    }
  }

  static Future<dynamic> _onPlatformMessage(MethodCall call) async {
    switch (call.method) {
      case 'onApnsToken':
        final hex = call.arguments as String?;
        if (hex != null && hex.isNotEmpty) {
          _lastApnsTokenHex = hex;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_prefsKeyLastApnsHex, hex);
          } catch (_) {}
          try {
            final guestOk = await BackendService.client.registerApnsDeviceToken(hex);
            print('[PUSH] APNs token (misafir) ${guestOk ? "kaydedildi" : "kaydedilemedi"}');
            if (BackendService.client.hasToken) {
              final userOk = await BackendService.client.registerApnsDeviceTokenForAuthUser(hex);
              print('[PUSH] APNs token (kullanıcı) ${userOk ? "bağlandı" : "bağlanamadı"}');
            }
          } catch (e) {
            print('[PUSH] token kayıt hatası: $e');
          }
        }
        break;
      case 'onPushPayload':
        final args = call.arguments as List<dynamic>?;
        if (args == null || args.length < 2) break;
        final jsonStr = args[0] as String? ?? '';
        final isForeground = args[1] as bool? ?? false;
        if (jsonStr.isEmpty) break;
        Map<String, dynamic> map;
        try {
          map = Map<String, dynamic>.from(jsonDecode(jsonStr) as Map);
        } catch (e) {
          print('[PUSH] JSON parse: $e');
          break;
        }
        if (isForeground) {
          await LocalNotificationService.showFromPushData(map, isForeground: true);
        }
        await _handlePayload(map);
        break;
      default:
        break;
    }
    return null;
  }

  /// Oturum açıldıktan sonra veya uygulama açılışında son bilinen jetonla v1 kaydı.
  static Future<void> syncApnsTokenWithBackendAfterAuth() async {
    if (kIsWeb || !Platform.isIOS) return;
    if (!BackendService.client.hasToken) return;
    var hex = _lastApnsTokenHex;
    if (hex == null || hex.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        hex = prefs.getString(_prefsKeyLastApnsHex);
      } catch (_) {}
    }
    if (hex == null || hex.isEmpty) return;
    try {
      final ok = await BackendService.client.registerApnsDeviceTokenForAuthUser(hex);
      print('[PUSH] Oturum sonrası APNs eşleme ${ok ? "tamam" : "başarısız"}');
    } catch (e) {
      print('[PUSH] Oturum sonrası APNs: $e');
    }
  }

  /// Çıkışta JWT hâlâ geçerliyken sunucuda kullanıcı–cihaz bağını kaldırır.
  static Future<void> disassociateCurrentUserIfPossible() async {
    if (kIsWeb || !Platform.isIOS) return;
    if (!BackendService.client.hasToken) return;
    var hex = _lastApnsTokenHex;
    if (hex == null || hex.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        hex = prefs.getString(_prefsKeyLastApnsHex);
      } catch (_) {}
    }
    if (hex == null || hex.isEmpty) return;
    try {
      await BackendService.client.disassociateApnsDeviceToken(hex);
    } catch (e) {
      print('[PUSH] APNs disassociate: $e');
    }
  }

  static Future<void> _handlePayload(Map<String, dynamic> data) async {
    try {
      final messageType = data['type']?.toString();
      final isDailyWidget =
          messageType == 'DAILY_WIDGET' || messageType == 'DAILY_WIDGET_UPDATE';
      final isCommentReply = messageType == 'COMMENT_REPLY';

      if (!isDailyWidget && !isCommentReply) return;

      if (isCommentReply) {
        try {
          onContentUpdated.add(null);
        } catch (_) {}
        return;
      }

      final itemId = data['itemId'];

      final widgetData = <String, dynamic>{
        'title': data['title'] ?? '',
        'body': data['body'] ?? '',
        'itemId': itemId ?? '',
        'updatedAt': data['updatedAt'] ?? DateTime.now().toIso8601String(),
        'imageUrl': MediaUrl.resolveForDevice(data['imageUrl']?.toString()) ?? data['imageUrl']?.toString() ?? '',
      };

      final idStr = itemId?.toString() ?? '';
      if (idStr.isNotEmpty) {
        try {
          final raw = await BackendService.client.fetchDailyItemRaw(idStr);
          if (raw != null) {
            final m = Motivation.fromApiDailyItem(Map<String, dynamic>.from(raw));
            widgetData['title'] = m.title;
            widgetData['body'] = m.body;
            widgetData['imageUrl'] = m.displayImageUrl ?? MediaUrl.resolveForDevice(widgetData['imageUrl']?.toString()) ?? '';
            if (m.sentAt != null && m.sentAt!.isNotEmpty) {
              widgetData['updatedAt'] = m.sentAt;
            }
            await MotivationCacheService.upsertMotivation(idStr, {
              'title': m.title,
              'body': m.body,
              'sentAt': m.sentAt ?? widgetData['updatedAt'],
              'order': m.order,
              'imageUrl': m.displayImageUrl,
              'category': m.category,
            });
            await MotivationCacheService.addDeliveredItemId(idStr);
          } else {
            await _upsertCacheFromPayload(idStr, widgetData);
          }
        } catch (e) {
          await _upsertCacheFromPayload(idStr, widgetData);
        }
      }

      await _updateHomeWidget(widgetData);
      try {
        onContentUpdated.add(null);
      } catch (_) {}
    } catch (e) {
      print('[PUSH] _handlePayload: $e');
    }
  }

  static Future<void> _upsertCacheFromPayload(String itemId, Map<String, dynamic> widgetData) async {
    if (itemId.isEmpty) return;
    try {
      await MotivationCacheService.upsertMotivation(itemId, {
        'id': itemId,
        'title': widgetData['title'],
        'body': widgetData['body'],
        'sentAt': widgetData['updatedAt'],
        'imageUrl': MediaUrl.resolveForDevice(widgetData['imageUrl']?.toString()) ?? widgetData['imageUrl'],
      });
      await MotivationCacheService.addDeliveredItemId(itemId);
    } catch (e) {
      print('[PUSH] cache payload: $e');
    }
  }

  static Future<String?> _downloadAndCacheWidgetImage(String imageUrl) async {
    try {
      final resolved = MediaUrl.resolveForDevice(imageUrl) ?? imageUrl;
      final response = await http
          .get(
            Uri.parse(resolved),
            headers: MotivationCachedImage.httpHeaders,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final bytes = response.bodyBytes;

      if (!kIsWeb && Platform.isAndroid) {
        final supportDir = await getApplicationSupportDirectory();
        final supportCacheDir = Directory('${supportDir.path}/widget_cache');
        if (!await supportCacheDir.exists()) await supportCacheDir.create(recursive: true);
        final supportFile = File('${supportCacheDir.path}/widget_image.jpg');
        await supportFile.writeAsBytes(bytes);
        final cacheDir = await getTemporaryDirectory();
        final tempCacheDir = Directory('${cacheDir.path}/widget_cache');
        if (!await tempCacheDir.exists()) await tempCacheDir.create(recursive: true);
        await File('${tempCacheDir.path}/widget_image.jpg').writeAsBytes(bytes);
        return supportFile.path;
      }

      if (!kIsWeb && Platform.isIOS) {
        final dir = await FlutterAppGroupDirectory.getAppGroupDirectory(
          'group.com.siyazilim.periodicallynotification',
        );
        if (dir != null) {
          final cacheDir = Directory('${dir.path}/widget_cache');
          if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
          final file = File('${cacheDir.path}/widget_image.jpg');
          await file.writeAsBytes(bytes);
          return file.path;
        }
      }
      return null;
    } catch (e) {
      print('[PUSH] resim cache: $e');
      return null;
    }
  }

  static Future<void> _seedWidgetFromAssetIfEmpty() async {
    if (kIsWeb) return;
    try {
      final savedUpdatedAt = await HomeWidget.getWidgetData<String>(_widgetUpdatedAtKey, defaultValue: '') ?? '';
      if (savedUpdatedAt.isNotEmpty) return;

      final items = await MotivationService.loadFromAsset();
      final latest = MotivationService.latest(items);
      if (latest == null) return;

      await _updateHomeWidget({
        'title': latest.title,
        'body': latest.body,
        'itemId': latest.id,
        'updatedAt': latest.sentAt ?? DateTime.now().toIso8601String(),
        'imageUrl': latest.displayImageUrl ?? '',
      });
    } catch (e) {
      print('[PUSH] widget seed: $e');
    }
  }

  static Future<void> _updateHomeWidget(Map<String, dynamic> data) async {
    try {
      final title = data['title'] ?? 'Günün İçeriği';
      await HomeWidget.saveWidgetData<String>(_widgetTitleKey, title);

      final body = data['body'] ?? '';
      await HomeWidget.saveWidgetData<String>(_widgetBodyKey, body);

      final itemId = data['itemId'] ?? '';
      await HomeWidget.saveWidgetData<String>(_widgetItemIdKey, itemId);

      final updatedAt = data['updatedAt'] ?? DateTime.now().toIso8601String();
      await HomeWidget.saveWidgetData<String>(_widgetUpdatedAtKey, updatedAt);

      final rawImageUrl = data['imageUrl']?.toString().trim() ?? '';
      final imageUrl = MediaUrl.resolveForDevice(rawImageUrl) ?? rawImageUrl;
      await HomeWidget.saveWidgetData<String>(_widgetImageUrlKey, imageUrl);

      String? imagePath;
      if (imageUrl.isNotEmpty) {
        try {
          imagePath = await _downloadAndCacheWidgetImage(imageUrl);
        } catch (_) {}
      }
      await HomeWidget.saveWidgetData<String>(_widgetImagePathKey, imagePath ?? '');

      if (!kIsWeb && Platform.isIOS) {
        try {
          final dir = await FlutterAppGroupDirectory.getAppGroupDirectory(
            'group.com.siyazilim.periodicallynotification',
          );
          if (dir != null) {
            final cacheDir = Directory('${dir.path}/widget_cache');
            if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
            final jsonFile = File('${cacheDir.path}/widget_data.json');
            final jsonData = {
              'title': title,
              'body': body,
              'itemId': itemId,
              'updatedAt': updatedAt,
              'imagePath': imagePath ?? '',
            };
            await jsonFile.writeAsString(jsonEncode(jsonData));
          }
        } catch (_) {}
      }

      await HomeWidget.updateWidget(
        name: 'DailyWidget',
        iOSName: 'DailyWidget',
        androidName: 'DailyWidgetProvider',
        qualifiedAndroidName: 'com.siyazilim.periodicallynotification.widget.DailyWidgetProvider',
      );
    } catch (e) {
      print('[PUSH] widget güncelleme: $e');
    }
  }

  static Future<void> refreshWidgetFromCache() async {
    try {
      final items = await MotivationService.loadAll();
      if (items.isEmpty) return;
      final latest = MotivationService.latest(items);
      if (latest == null) return;
      final latestUpdated = latest.sentAt ?? DateTime.now().toIso8601String();

      final currentWidgetUpdated = await HomeWidget.getWidgetData<String>(
        _widgetUpdatedAtKey,
        defaultValue: '',
      );
      if (currentWidgetUpdated != null &&
          currentWidgetUpdated.isNotEmpty &&
          latestUpdated.compareTo(currentWidgetUpdated) <= 0) {
        return;
      }

      await _updateHomeWidget({
        'title': latest.title,
        'body': latest.body,
        'itemId': latest.id,
        'updatedAt': latestUpdated,
        'imageUrl': latest.displayImageUrl ?? '',
      });
    } catch (e) {
      print('[PUSH] refreshWidgetFromCache: $e');
    }
  }
}
