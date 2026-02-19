import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/motivation.dart';
import 'motivation_cache_service.dart';

class MotivationService {
  static const String assetPath = 'assets/data/motivation.json';

  /// Runtime dosyası: {documents}/data/motivation.json (FCM ile güncellenir)
  /// Önce runtime'dan okur. Yoksa asset'ten seed edip runtime'a yazar.
  static Future<List<Motivation>> loadAll() async {
    try {
      final cached = await MotivationCacheService.loadFromCache();
      if (cached.isNotEmpty) {
        final assetItems = await _loadFromAsset();
        return await MotivationCacheService.mergeWithAsset(assetItems);
      }
      final assetItems = await _loadFromAsset();
      await _seedRuntimeFromAsset(assetItems);
      return assetItems;
    } catch (e) {
      final assetItems = await _loadFromAsset();
      await _seedRuntimeFromAsset(assetItems);
      return assetItems;
    }
  }

  /// İlk kurulumda asset verisini runtime dosyasına kopyala
  static Future<void> _seedRuntimeFromAsset(List<Motivation> items) async {
    if (items.isEmpty) return;
    try {
      await MotivationCacheService.saveItems(items);
    } catch (_) {}
  }

  static Future<List<Motivation>> _loadFromAsset() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      if (raw.trim().isEmpty) return [];
      final decoded = json.decode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => Motivation.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Motivation? latest(List<Motivation> list) {
    if (list.isEmpty) return null;
    return list.last;
  }
}
