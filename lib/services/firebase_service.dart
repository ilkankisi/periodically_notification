import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_app_group_directory/flutter_app_group_directory.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'motivation_cache_service.dart';
import 'motivation_service.dart';

/// Firebase Messaging Service
/// Handles FCM topic subscription and message handling
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static const String _topic = 'daily_widget_all';
  static const String _widgetTitleKey = 'widget_title';
  static const String _widgetBodyKey = 'widget_body';
  static const String _widgetItemIdKey = 'widget_itemId';
  static const String _widgetUpdatedAtKey = 'widget_updatedAt';
  static const String _widgetImageUrlKey = 'widget_imageUrl';
  static const String _widgetImagePathKey = 'widget_imagePath'; // Android: yerel dosya yolu

  /// FCM işlendiğinde anasayfanın yenilenmesi için
  static final StreamController<void> onContentUpdated = StreamController<void>.broadcast();

  /// Initialize Firebase and subscribe to topic
  static Future<void> initialize() async {
    try {
      print('[INIT] Starting Firebase initialization...');
      
      // Create local instances
      final messaging = FirebaseMessaging.instance;
      final firestore = FirebaseFirestore.instance;
      
      // Request notification permissions with timeout
      print('[INIT] Requesting notification permissions...');
      try {
        NotificationSettings? settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        ).timeout(
          const Duration(seconds: 5),
        );

        if (settings != null) {
          if (settings.authorizationStatus == AuthorizationStatus.authorized) {
            print('[INIT] ✅ User granted notification permission');
          } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
            print('[INIT] ⚠️ User granted provisional notification permission');
          } else {
            print('[INIT] ⚠️ User declined notification permission');
          }
        } else {
          print('[INIT] ⚠️ Permission result is null');
        }
      } on TimeoutException {
        print('[INIT] ⚠️ Permission request timed out, continuing...');
      } catch (e) {
        print('[INIT] ⚠️ Error requesting permissions: $e');
      }

      // Get FCM token with timeout
      print('[INIT] Getting FCM token...');
      String? token;
      try {
        token = await messaging.getToken().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('[INIT] getToken timeout, skipping...');
            return null;
          },
        );
        if (token != null) {
          print('[INIT] ✅ FCM Token: $token');
        } else {
          print('[INIT] ⚠️ FCM Token is null');
        }
      } catch (e) {
        print('[INIT] ❌ Error getting FCM token: $e');
      }

      // Subscribe to topic with timeout
      print('[INIT] Subscribing to topic daily_widget_all...');
      try {
        await messaging.subscribeToTopic('daily_widget_all').timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('[INIT] subscribeToTopic timeout, skipping...');
          },
        );
        print('[INIT] ✅ Subscribed to topic: daily_widget_all');
      } catch (e) {
        print('[INIT] ❌ Error subscribing to topic: $e');
      }

      // Set up message handlers
      print('[INIT] Setting up message handlers...');
      _setupMessageHandlers(firestore);

      // Initialize home_widget with timeout
      print('[INIT] Initializing home_widget...');
      try {
        await HomeWidget.setAppGroupId('group.com.siyazilim.periodicallynotification').timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('[INIT] HomeWidget timeout, continuing...');
          },
        );
        print('[INIT] ✅ HomeWidget initialized');
      } catch (e) {
        print('[INIT] ❌ HomeWidget error: $e');
      }

      print('[INIT] ✅ Firebase initialization complete!');
    } catch (e) {
      print('[INIT] ❌ Critical error: $e');
      rethrow;
    }
  }

  /// Set up FCM message handlers
  static void _setupMessageHandlers(FirebaseFirestore firestore) {
    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[FCM_WIDGET] Foreground message received: ${message.messageId}');
      _handleMessage(message, firestore);
    });

    // Background message handler (must be top-level function)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Notification tap handler (when app is in background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[FCM_WIDGET] Notification tapped: ${message.messageId}');
      _handleMessage(message, firestore);
    });

    // Check if app was opened from a notification (when app was terminated)
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('[FCM_WIDGET] App opened from notification: ${message.messageId}');
        _handleMessage(message, firestore);
      }
    });
  }

  /// Handle incoming FCM message
  static Future<void> _handleMessage(RemoteMessage message, FirebaseFirestore firestore) async {
    try {
      print('[FCM_WIDGET] === MESSAGE HANDLER START ===');
      print('[FCM_WIDGET] Message ID: ${message.messageId}');
      print('[FCM_WIDGET] Message Data: ${message.data}');
      
      final data = message.data;
      final messageType = data['type'];
      print('[FCM_WIDGET] Message Type: $messageType');
      
      // Check if this is a daily widget message
      final isDailyWidget = messageType == 'DAILY_WIDGET' || messageType == 'DAILY_WIDGET_UPDATE';
      print('[FCM_WIDGET] Is Daily Widget: $isDailyWidget');
      
      if (isDailyWidget) {
        print('[FCM_WIDGET] ✅ Processing DAILY_WIDGET message');
        
        final itemId = data['itemId'];
        final docPath = data['docPath'];
        
        print('[FCM_WIDGET] ItemId: $itemId');
        print('[FCM_WIDGET] DocPath: $docPath');
        
        // Fetch full content from Firestore if docPath is provided
        Map<String, dynamic> widgetData = {
          'title': data['title'] ?? '',
          'body': data['body'] ?? '',
          'itemId': itemId ?? '',
          'updatedAt': data['updatedAt'] ?? DateTime.now().toIso8601String(),
          'imageUrl': data['imageUrl'] ?? '', // FCM payload'tan - Firestore fetch öncesi
        };
        
        print('[FCM_WIDGET] Initial widgetData: title=${widgetData['title']}, body=${widgetData['body']}');

        // If docPath is provided, fetch from Firestore for complete data
        if (docPath != null && docPath.isNotEmpty) {
          print('[FCM_WIDGET] Fetching from Firestore: $docPath');
          try {
            final doc = await firestore.doc(docPath).get();
            if (doc.exists) {
              final itemData = doc.data()!;
              print('[FCM_WIDGET] Raw Firestore data: $itemData');
              print('[FCM_WIDGET] Firestore keys: ${itemData.keys.toList()}');
              
              // Find body field - check all keys that contain "body" (case insensitive)
              String? bodyKey;
              dynamic bodyValue;
              
              for (final key in itemData.keys) {
                if (key.toLowerCase().trim() == 'body') {
                  bodyKey = key;
                  bodyValue = itemData[key];
                  break;
                }
              }
              
              // If not found, try exact match
              if (bodyKey == null) {
                bodyValue = itemData['body'];
              }
              
              print('[FCM_WIDGET] Firestore title: ${itemData['title']}');
              print('[FCM_WIDGET] Firestore body key: ${bodyKey ?? 'body'}');
              print('[FCM_WIDGET] Firestore body value: $bodyValue');
              print('[FCM_WIDGET] Firestore body type: ${bodyValue?.runtimeType}');
              
              widgetData['title'] = itemData['title'] ?? widgetData['title'];
              widgetData['body'] = bodyValue?.toString() ?? widgetData['body'];
              widgetData['imageUrl'] = itemData['imageUrl'] ?? data['imageUrl'] ?? '';

              await MotivationCacheService.upsertFromFirestore(itemId, itemData);
              print('[FCM_WIDGET] ✅ Motivation cache güncellendi');
              print('[FCM_WIDGET] ✅ Firestore data fetched: title=${widgetData['title']}, body=${widgetData['body']}');
            } else {
              print('[FCM_WIDGET] ⚠️ Firestore document does not exist');
              await _upsertCacheFromPayload(itemId, widgetData);
            }
          } catch (e) {
            print('[FCM_WIDGET] ❌ Error fetching from Firestore: $e');
            print('[FCM_WIDGET] Stack trace: ${StackTrace.current}');
            await _upsertCacheFromPayload(itemId ?? '', widgetData);
          }
        } else {
          print('[FCM_WIDGET] ⚠️ No docPath provided, using payload data');
          if (itemId != null && itemId.isNotEmpty) {
            await MotivationCacheService.upsertFromFirestore(
              itemId,
              {
                'title': widgetData['title'],
                'body': widgetData['body'],
                'sentAt': widgetData['updatedAt'],
              },
            );
            print('[FCM_WIDGET] ✅ Motivation cache (payload) güncellendi');
          }
        }

        print('[FCM_WIDGET] Final widgetData: title=${widgetData['title']}, body=${widgetData['body']}');
        print('[FCM_WIDGET] Calling _updateHomeWidget...');

        await _updateHomeWidget(widgetData);

        try {
          onContentUpdated.add(null);
        } catch (_) {}

        print('[FCM_WIDGET] ✅ _updateHomeWidget completed');
      } else {
        print('[FCM_WIDGET] ❌ Not a DAILY_WIDGET message. Type: $messageType');
        print('[FCM_WIDGET] Available keys in data: ${data.keys.toList()}');
      }
      
      print('[FCM_WIDGET] === MESSAGE HANDLER END ===');
    } catch (e) {
      print('[FCM_WIDGET] ❌ ERROR in _handleMessage: $e');
      print('[FCM_WIDGET] Stack trace: ${StackTrace.current}');
    }
  }

  /// Firestore fetch başarısız/boş olduğunda cache'i FCM payload ile güncelle
  static Future<void> _upsertCacheFromPayload(String itemId, Map<String, dynamic> widgetData) async {
    if (itemId.isEmpty) return;
    try {
      await MotivationCacheService.upsertFromFirestore(itemId, {
        'id': itemId,
        'title': widgetData['title'],
        'body': widgetData['body'],
        'sentAt': widgetData['updatedAt'],
        'imageUrl': widgetData['imageUrl'],
      });
      print('[FCM_WIDGET] ✅ Cache güncellendi (payload)');
    } catch (e) {
      print('[FCM_WIDGET] ⚠️ Cache payload update error: $e');
    }
  }

  /// Resmi indirir ve widget_cache klasörüne kaydeder.
  /// Android: filesDir + cacheDir. iOS: App Group container (AsyncImage WidgetKit'ta çalışmaz).
  static Future<String?> _downloadAndCacheWidgetImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl)).timeout(
        const Duration(seconds: 15),
      );
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
        print('[FCM_WIDGET] ✅ Resim kaydedildi (Android): ${supportFile.path}');
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
          print('[FCM_WIDGET] ✅ Resim kaydedildi (iOS App Group): ${file.path}');
          return file.path;
        }
      }
      return null;
    } catch (e) {
      print('[FCM_WIDGET] _downloadAndCacheWidgetImage error: $e');
      return null;
    }
  }

  /// Update home widget with new content
  static Future<void> _updateHomeWidget(Map<String, dynamic> data) async {
    try {
      print('[FCM_WIDGET] === UPDATE WIDGET START ===');
      print('[FCM_WIDGET] Data to save: title=${data['title']}, body=${data['body']}, itemId=${data['itemId']}');
      
      print('[FCM_WIDGET] Saving widget_title...');
      final title = data['title'] ?? 'Günün İçeriği';
      await HomeWidget.saveWidgetData<String>(_widgetTitleKey, title);
      print('[FCM_WIDGET] ✅ widget_title saved: $title');
      
      print('[FCM_WIDGET] Saving widget_body...');
      final body = data['body'] ?? '';
      await HomeWidget.saveWidgetData<String>(_widgetBodyKey, body);
      print('[FCM_WIDGET] ✅ widget_body saved: $body');
      
      print('[FCM_WIDGET] Saving widget_itemId...');
      final itemId = data['itemId'] ?? '';
      await HomeWidget.saveWidgetData<String>(_widgetItemIdKey, itemId);
      print('[FCM_WIDGET] ✅ widget_itemId saved: $itemId');
      
      print('[FCM_WIDGET] Saving widget_updatedAt...');
      final updatedAt = data['updatedAt'] ?? DateTime.now().toIso8601String();
      await HomeWidget.saveWidgetData<String>(_widgetUpdatedAtKey, updatedAt);
      print('[FCM_WIDGET] ✅ widget_updatedAt saved: $updatedAt');

      final imageUrl = data['imageUrl']?.toString().trim() ?? '';
      await HomeWidget.saveWidgetData<String>(_widgetImageUrlKey, imageUrl);

      // Android için resmi indir ve yerel yol kaydet (Glide async sorununu çözer)
      String? imagePath;
      if (imageUrl.isNotEmpty) {
        try {
          imagePath = await _downloadAndCacheWidgetImage(imageUrl);
          if (imagePath != null) {
            print('[FCM_WIDGET] ✅ Resim indirildi: $imagePath');
          }
        } catch (e) {
          print('[FCM_WIDGET] ⚠️ Resim indirme hatası: $e');
        }
      }
      await HomeWidget.saveWidgetData<String>(_widgetImagePathKey, imagePath ?? '');

      // iOS: App Group içine JSON dosyası yaz (UserDefaults sync sorunlarını aşmak için)
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
            print('[FCM_WIDGET] ✅ widget_data.json kaydedildi');
          }
        } catch (e) {
          print('[FCM_WIDGET] ⚠️ widget_data.json yazma hatası: $e');
        }
      }

      // Verify data was saved by reading it back from SharedPreferences
      print('[FCM_WIDGET] === VERIFYING SAVED DATA ===');
      final savedTitle = await HomeWidget.getWidgetData<String>(_widgetTitleKey, defaultValue: '');
      final savedBody = await HomeWidget.getWidgetData<String>(_widgetBodyKey, defaultValue: '');
      final savedItemId = await HomeWidget.getWidgetData<String>(_widgetItemIdKey, defaultValue: '');
      final savedUpdatedAt = await HomeWidget.getWidgetData<String>(_widgetUpdatedAtKey, defaultValue: '');
      
      print('[FCM_WIDGET] ✅ Verified widget_title in storage: $savedTitle');
      print('[FCM_WIDGET] ✅ Verified widget_body in storage: $savedBody');
      print('[FCM_WIDGET] ✅ Verified widget_itemId in storage: $savedItemId');
      print('[FCM_WIDGET] ✅ Verified widget_updatedAt in storage: $savedUpdatedAt');
      print('[FCM_WIDGET] === VERIFICATION COMPLETE ===');

      print('[FCM_WIDGET] Calling HomeWidget.updateWidget...');
      // Trigger widget update
      // Use qualifiedAndroidName for subpackage (widget.DailyWidgetProvider)
      await HomeWidget.updateWidget(
        name: 'DailyWidget',
        iOSName: 'DailyWidget',
        androidName: 'DailyWidgetProvider',
        qualifiedAndroidName: 'com.siyazilim.periodicallynotification.widget.DailyWidgetProvider',
      );
      print('[FCM_WIDGET] ✅ HomeWidget.updateWidget completed');

      // iOS: Native reloadAllTimelines zorla (ofKind bazen çalışmıyor)
      if (!kIsWeb && Platform.isIOS) {
        try {
          const channel = MethodChannel('com.siyazilim.periodicallynotification/widget');
          await channel.invokeMethod('reloadWidget');
          print('[FCM_WIDGET] ✅ Native reloadAllTimelines çağrıldı');
        } catch (e) {
          print('[FCM_WIDGET] ⚠️ Native reload hatası: $e');
        }
      }

      print('[FCM_WIDGET] ✅ Home widget updated successfully');
      print('[FCM_WIDGET] === UPDATE WIDGET END ===');
    } catch (e) {
      print('[FCM_WIDGET] ❌ ERROR updating home widget: $e');
      print('[FCM_WIDGET] Error type: ${e.runtimeType}');
      print('[FCM_WIDGET] Stack trace: ${StackTrace.current}');
    }
  }

  /// Unsubscribe from topic (if needed)
  Future<void> unsubscribe() async {
    await _messaging.unsubscribeFromTopic(_topic);
    print('Unsubscribed from topic: $_topic');
  }

  /// Uygulama açıldığında widget'ı güncelle.
  /// FCM arka planda geldiyse resim indirilememiş olabilir; bu metod düzeltir.
  /// Cache boşsa asset (motivation.json) ile birleşik veri kullanılır.
  ///
  /// Önemli: widget_updatedAt ile karşılaştır - bildirime basıldıktan sonra
  /// _handleMessage yeni veri yazarken, bu metod eski cache ile overwrite etmesin.
  static Future<void> refreshWidgetFromCache() async {
    try {
      final items = await MotivationService.loadAll();
      if (items.isEmpty) return;
      final latest = items.last;
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

      final widgetData = {
        'title': latest.title,
        'body': latest.body,
        'itemId': latest.id,
        'updatedAt': latestUpdated,
        'imageUrl': latest.imageUrl ?? '',
      };
      await _updateHomeWidget(widgetData);
    } catch (e) {
      print('[FCM_WIDGET] refreshWidgetFromCache error: $e');
    }
  }
}

/// Top-level background message handler
/// Must be a top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('[FCM_WIDGET] Background message received: ${message.messageId}');
  
  // Handle the message - create firestore instance for handler
  final firestore = FirebaseFirestore.instance;
  await FirebaseService._handleMessage(message, firestore);
}

