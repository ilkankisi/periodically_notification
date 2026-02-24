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

  /// Dışarıdan sıralama için (loadAll asset path vb.)
  static List<Motivation> sortByLatestFirst(List<Motivation> list) {
    final copy = List<Motivation>.from(list);
    copy.sort(_compareByLatestFirst);
    return copy;
  }

  /// En son gönderilen (sentAt) önce gelir; sonra order azalan.
  static int _compareByLatestFirst(Motivation a, Motivation b) {
    final aSent = a.sentAt ?? '';
    final bSent = b.sentAt ?? '';
    final sentCmp = bSent.compareTo(aSent); // Azalan: yeni önce
    if (sentCmp != 0) return sentCmp;
    final aOrder = a.order ?? 0;
    final bOrder = b.order ?? 0;
    return bOrder.compareTo(aOrder); // Azalan: büyük order önce
  }
  static const String _legacyCacheFileName = 'motivation_cache.json';
  static const String _deliveredIdsFileName = 'data/notification_delivered_ids.json';

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
        final items = decoded.map((e) => Motivation.fromMap(Map<String, dynamic>.from(e))).toList();
        items.sort(_compareByLatestFirst);
        return items;
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

      // En son gönderilen önce: sentAt azalan, sonra order azalan
      updated.sort((a, b) => _compareByLatestFirst(a, b));

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
    merged.sort((a, b) => _compareByLatestFirst(a, b));
    return merged;
  }

  /// Bildirimle (FCM) kullanıcıya ulaşan içerik id'leri. Anasayfada sadece bunlar gösterilir.
  static Future<String> _getDeliveredIdsPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_deliveredIdsFileName';
  }

  static Future<void> _ensureDataDirFor(String path) async {
    final file = File(path);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
  }

  /// FCM ile bildirim geldiğinde bu id kaydedilir. Anasayfa sadece bu id'lerdeki içerikleri listeler.
  static Future<void> addDeliveredItemId(String itemId) async {
    if (itemId.isEmpty) return;
    try {
      final path = await _getDeliveredIdsPath();
      await _ensureDataDirFor(path);
      final set = await getDeliveredItemIds();
      set.add(itemId);
      final file = File(path);
      await file.writeAsString(json.encode(set.toList()));
    } catch (_) {}
  }

  /// Birden fazla id'yi tek seferde delivered olarak işaretler (Firestore sync için).
  static Future<void> addDeliveredItemIds(Iterable<String> itemIds) async {
    final valid = itemIds.where((id) => id.isNotEmpty).toSet();
    if (valid.isEmpty) return;
    try {
      final path = await _getDeliveredIdsPath();
      await _ensureDataDirFor(path);
      final set = await getDeliveredItemIds();
      set.addAll(valid);
      final file = File(path);
      await file.writeAsString(json.encode(set.toList()));
    } catch (_) {}
  }

  /// Bildirimle gelen tüm içerik id'lerini döner.
  static Future<Set<String>> getDeliveredItemIds() async {
    try {
      final path = await _getDeliveredIdsPath();
      final file = File(path);
      if (!await file.exists()) return {};
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return {};
      final decoded = json.decode(raw);
      if (decoded is! List) return {};
      return decoded.map((e) => e.toString()).where((s) => s.isNotEmpty).toSet();
    } catch (_) {
      return {};
    }
  }
}
