import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import '../models/motivation.dart';

/// Yerel önbellek: Firebase'den gelen motivasyon verilerini yazılabilir dosyada tutar.
/// assets/data/motivation.json read-only - runtime'da {documents}/data/motivation.json'a yazılır.
/// Anasayfa bu runtime dosyasından okur (assets ile aynı yapı).
class MotivationCacheService {
  static const String _cacheFileName = 'data/motivation.json';
  static const String _legacyCacheFileName = 'motivation_cache.json';

  static Future<String> _getCachePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_cacheFileName';
  }

  static Future<String> _getLegacyCachePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_legacyCacheFileName';
  }

  static Future<void> _ensureDataDir() async {
    final path = await _getCachePath();
    final file = File(path);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
  }

  /// Yerel önbellekten tüm motivasyonları yükler.
  /// Önce {documents}/data/motivation.json, yoksa motivation_cache.json (fallback).
  static Future<List<Motivation>> loadFromCache() async {
    for (final path in [
      await _getCachePath(),
      await _getLegacyCachePath(),
    ]) {
      try {
        final file = File(path);
        if (!await file.exists()) continue;
        final raw = await file.readAsString();
        if (raw.trim().isEmpty) continue;
        final decoded = json.decode(raw);
        if (decoded is! List) continue;
        return decoded.map((e) => Motivation.fromMap(Map<String, dynamic>.from(e))).toList();
      } catch (_) {}
    }
    return [];
  }

  /// Firestore'dan gelen veriyi önbelleğe ekler veya günceller.
  /// Aynı id varsa günceller, yoksa listeye ekler.
  static Future<void> upsertFromFirestore(
    String docId,
    Map<String, dynamic> itemData,
  ) async {
    try {
      final items = await loadFromCache();
      String? sentAtStr;
      final sentAt = itemData['sentAt'];
      if (sentAt != null) {
        if (sentAt is DateTime) {
          sentAtStr = sentAt.toIso8601String();
        } else if (sentAt is Timestamp) {
          sentAtStr = sentAt.toDate().toIso8601String();
        } else {
          sentAtStr = sentAt.toString();
        }
      }

      final newItem = Motivation.fromMap({
        'id': docId,
        'docId': docId,
        'title': itemData['title'] ?? '',
        'body': itemData['body'] ?? '',
        'sentAt': sentAtStr,
        'order': itemData['order'],
        'image': itemData['image'],
        'imageUrl': itemData['imageUrl'],
      });

      final index = items.indexWhere((m) => m.id == docId);
      List<Motivation> updated;
      if (index >= 0) {
        updated = [...items]..[index] = newItem;
      } else {
        updated = [...items, newItem];
      }

      // sentAt veya order'a göre sırala
      updated.sort((a, b) {
        final aOrder = a.order ?? 999;
        final bOrder = b.order ?? 999;
        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
        final aSent = a.sentAt ?? '';
        final bSent = b.sentAt ?? '';
        return aSent.compareTo(bSent);
      });

      await _saveToCache(updated);
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  static Future<void> _saveToCache(List<Motivation> items) async {
    await _ensureDataDir();
    final path = await _getCachePath();
    final file = File(path);
    final encoded = json.encode(items.map((m) => m.toMap()).toList());
    await file.writeAsString(encoded);
  }

  /// Dışarıdan liste kaydetmek için (asset seed vb.)
  static Future<void> saveItems(List<Motivation> items) async {
    await _saveToCache(items);
  }

  /// Önbelleği asset verisiyle birleştirir (ilk kurulumda cache boş olabilir).
  static Future<List<Motivation>> mergeWithAsset(List<Motivation> assetItems) async {
    final cached = await loadFromCache();
    if (cached.isEmpty) return assetItems;

    final cachedIds = cached.map((m) => m.id).toSet();
    final fromAsset = assetItems.where((m) => !cachedIds.contains(m.id)).toList();
    final merged = [...cached, ...fromAsset];
    merged.sort((a, b) {
      final aOrder = a.order ?? 999;
      final bOrder = b.order ?? 999;
      if (aOrder != bOrder) return aOrder.compareTo(bOrder);
      final aSent = a.sentAt ?? '';
      final bSent = b.sentAt ?? '';
      return aSent.compareTo(bSent);
    });
    return merged;
  }
}
