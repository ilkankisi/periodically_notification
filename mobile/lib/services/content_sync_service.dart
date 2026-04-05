import 'backend_service.dart';
import 'motivation_cache_service.dart';
import '../models/motivation.dart';
import '../utils/media_url.dart';

/// Faz 3: `daily_items` tek kaynak Go API (`GET /api/daily-items`).
class ContentSyncService {
  /// Postgres'teki tüm günlük içerikleri çeker, yerel cache ile birleştirir.
  static Future<void> syncFromBackend() async {
    try {
      final fromApi = await BackendService.client.fetchDailyItemsMotivations();
      if (fromApi.isEmpty) return;

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
        );
      }

      final merged = MotivationCacheService.sortByLatestFirst(existingById.values.toList());
      await MotivationCacheService.saveItems(merged);
      await MotivationCacheService.addDeliveredItemIds(merged.map((m) => m.id));
    } catch (e) {
      // Sessiz: offline veya backend kapalı — asset/cache ile devam
    }
  }
}
