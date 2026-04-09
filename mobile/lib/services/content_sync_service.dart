import 'package:flutter/foundation.dart';

import 'api_config.dart';
import 'backend_service.dart';
import 'motivation_cache_service.dart';
import '../models/motivation.dart';
import '../utils/media_url.dart';

/// Faz 3: `daily_items` tek kaynak Go API (`GET /api/daily-items`).
class ContentSyncService {
  /// Postgres'teki tüm günlük içerikleri çeker, yerel cache ile birleştirir.
  /// Anasayfa / Keşfet açılışında çağrılır.
  static Future<void> syncFromBackend() async {
    if (kDebugMode) {
      ApiConfig.debugLogResolvedUrl();
      debugPrint('[ContentSync] başlıyor…');
    }
    try {
      final fromApi = await BackendService.client.fetchDailyItemsMotivations();
      if (fromApi.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[ContentSync] API boş liste döndü veya istek başarısız — önbellek/asset ile devam.',
          );
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('[ContentSync] ${fromApi.length} kayıt birleştiriliyor…');
      }

      final existing = await MotivationCacheService.loadFromCache();
      final existingById = <String, Motivation>{for (final m in existing) m.id: m};

      for (final m in fromApi) {
        if (m.id.isEmpty) continue;
        final url = MediaUrl.resolveForDevice(m.imageUrl);
        existingById[m.id] = Motivation(
          id: m.id,
          title: m.title,
          body: m.body,
          sentAt: m.sentAt,
          order: m.order,
          imageUrl: url,
          category: m.category,
          author: m.author,
        );
      }

      final merged = MotivationCacheService.sortByLatestFirst(existingById.values.toList());
      await MotivationCacheService.saveItems(merged);
      await MotivationCacheService.addDeliveredItemIds(merged.map((m) => m.id));
      if (kDebugMode) {
        debugPrint('[ContentSync] tamam: ${merged.length} öğe cache’lendi.');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ContentSync] hata: $e');
        debugPrint('$st');
      }
    }
  }
}
