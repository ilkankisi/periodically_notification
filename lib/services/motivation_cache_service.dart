import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import '../models/motivation.dart';

/// Yerel önbellek: Firebase'den gelen motivasyon verilerini yazılabilir dosyada tutar.
/// Asset (motivation.json) okunamaz - bu service uygulama doküman dizininde JSON dosyası kullanır.
class MotivationCacheService {
  static const String _cacheFileName = 'motivation_cache.json';

  static Future<String> _getCachePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_cacheFileName';
  }

  /// Yerel önbellekten tüm motivasyonları yükler.
  static Future<List<Motivation>> loadFromCache() async {
    try {
      final path = await _getCachePath();
      final file = File(path);
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = json.decode(raw);
      if (decoded is! List) return [];
      return decoded.map((e) => Motivation.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [];
    }
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
    final path = await _getCachePath();
    final file = File(path);
    final encoded = json.encode(items.map((m) => m.toMap()).toList());
    await file.writeAsString(encoded);
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
