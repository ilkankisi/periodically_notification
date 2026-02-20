import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Kaydedilen içerikler - bildirimlerin tutulduğu yöntemle: cihazda {documents}/data/saved_items.json
class SavedItemsService {
  static const String _fileName = 'data/saved_items.json';

  static Future<String> _getPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_fileName';
  }

  static Future<void> _ensureDir() async {
    final path = await _getPath();
    final file = File(path);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
  }

  /// Kaydedilen kayıt: itemId + kaydedilme tarihi
  static Future<List<SavedEntry>> getSavedEntries() async {
    try {
      final path = await _getPath();
      final file = File(path);
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = json.decode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => SavedEntry(
                itemId: e['itemId']?.toString() ?? '',
                savedAt: e['savedAt']?.toString() ?? '',
              ))
          .where((e) => e.itemId.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Bu id kaydedilmiş mi?
  static Future<bool> isSaved(String itemId) async {
    final entries = await getSavedEntries();
    return entries.any((e) => e.itemId == itemId);
  }

  /// İçeriği kaydet (kayıt varsa savedAt güncellenmez; yoksa eklenir)
  static Future<void> addSaved(String itemId) async {
    if (itemId.isEmpty) return;
    final entries = await getSavedEntries();
    if (entries.any((e) => e.itemId == itemId)) return;
    final newEntry = SavedEntry(
      itemId: itemId,
      savedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _write([...entries, newEntry]);
  }

  /// Kaydı kaldır
  static Future<void> removeSaved(String itemId) async {
    if (itemId.isEmpty) return;
    final entries = await getSavedEntries();
    final filtered = entries.where((e) => e.itemId != itemId).toList();
    await _write(filtered);
  }

  /// Kaydet / kaldır toggle
  static Future<bool> toggleSaved(String itemId) async {
    final saved = await isSaved(itemId);
    if (saved) {
      await removeSaved(itemId);
      return false;
    } else {
      await addSaved(itemId);
      return true;
    }
  }

  static Future<void> _write(List<SavedEntry> entries) async {
    await _ensureDir();
    final path = await _getPath();
    final file = File(path);
    final encoded = json.encode(entries.map((e) => {'itemId': e.itemId, 'savedAt': e.savedAt}).toList());
    await file.writeAsString(encoded);
  }
}

class SavedEntry {
  final String itemId;
  final String savedAt;

  SavedEntry({required this.itemId, required this.savedAt});
}
