import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/motivation.dart';
import 'motivation_cache_service.dart';
import 'user_motivation_service.dart';

class MotivationService {
  static const String assetPath = 'assets/data/motivations.json';

  /// Runtime dosyası: {documents}/data/motivations.json (FCM ile güncellenir)
  /// Önce runtime'dan okur. Yoksa asset'ten seed edip runtime'a yazar.
  /// Kullanıcının eklediği motivasyonlar listenin başına eklenir.
  static Future<List<Motivation>> loadAll() async {
    try {
      final assetItems = await loadFromAsset();
      List<Motivation> base;
      final cachedFiles = await MotivationCacheService.loadFromCache();
      if (cachedFiles.isNotEmpty) {
        base = await MotivationCacheService.mergeWithAsset(assetItems);
      } else {
        await _seedRuntimeFromAsset(assetItems);
        base = MotivationCacheService.sortByLatestFirst(assetItems);
      }
      base = _enrichMissingImagesFromAsset(base, assetItems);
      final userItems = await UserMotivationService.loadAll();
      return MotivationCacheService.sortByLatestFirst([...userItems, ...base]);
    } catch (e) {
      final assetItems = await loadFromAsset();
      await _seedRuntimeFromAsset(assetItems);
      var base = MotivationCacheService.sortByLatestFirst(
        _enrichMissingImagesFromAsset(assetItems, assetItems),
      );
      try {
        final userItems = await UserMotivationService.loadAll();
        base = MotivationCacheService.sortByLatestFirst([...userItems, ...base]);
      } catch (_) {}
      return base;
    }
  }

  /// API/cache satırında görsel yoksa, aynı [order] için asset'teki URL kullanılır (farklı id'ler).
  static List<Motivation> _enrichMissingImagesFromAsset(
    List<Motivation> items,
    List<Motivation> assetItems,
  ) {
    final byOrder = <int, Motivation>{};
    for (final a in assetItems) {
      if (a.order != null) byOrder[a.order!] = a;
    }
    return items.map((m) {
      final hasBase64 = m.imageBase64 != null && m.imageBase64!.trim().isNotEmpty;
      if (hasBase64) return m;
      final hasUrl = m.imageUrl != null && m.imageUrl!.trim().isNotEmpty;
      if (hasUrl) return m;
      if (m.order == null) return m;
      final a = byOrder[m.order!];
      final url = a?.imageUrl;
      if (url == null || url.trim().isEmpty) return m;
      return Motivation(
        id: m.id,
        title: m.title,
        body: m.body,
        sentAt: m.sentAt,
        order: m.order,
        imageBase64: m.imageBase64,
        imageUrl: url,
        category: m.category ?? a?.category,
        author: m.author,
      );
    }).toList();
  }

  /// İlk kurulumda asset verisini runtime dosyasına kopyala
  static Future<void> _seedRuntimeFromAsset(List<Motivation> items) async {
    if (items.isEmpty) return;
    try {
      await MotivationCacheService.saveItems(items);
    } catch (_) {}
  }

  /// Asset'ten motivasyon listesi yükle (widget seed için public)
  static Future<List<Motivation>> loadFromAsset() async {
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

  /// Anasayfa için: sadece bildirimle (FCM) gelen içerikler. Keşfet tüm cache'i kullanır.
  static Future<List<Motivation>> loadDeliveredOnly() async {
    final all = await loadAll();
    final deliveredIds = await MotivationCacheService.getDeliveredItemIds();
    if (deliveredIds.isEmpty) return [];
    final filtered = all.where((m) => deliveredIds.contains(m.id)).toList();
    return MotivationCacheService.sortByLatestFirst(filtered);
  }

  /// En son gönderilen içerik (liste sentAt azalan sırada olmalı)
  static Motivation? latest(List<Motivation> list) {
    if (list.isEmpty) return null;
    return list.first;
  }
}
