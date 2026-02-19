import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/motivation.dart';
import 'motivation_cache_service.dart';

class MotivationService {
  static const String assetPath = 'assets/data/motivation.json';

  /// Önce yerel önbellekten yükler. Cache boşsa asset'ten yükler.
  /// Cache varsa asset ile birleştirir (Firebase'den henüz gelmemiş eski veriler için).
  static Future<List<Motivation>> loadAll() async {
    try {
      final cached = await MotivationCacheService.loadFromCache();
      if (cached.isNotEmpty) {
        final assetItems = await _loadFromAsset();
        return await MotivationCacheService.mergeWithAsset(assetItems);
      }
      return await _loadFromAsset();
    } catch (e) {
      return await _loadFromAsset();
    }
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
