import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Arama geçmişi: kullanıcının son arama sorguları. {documents}/data/search_history.json
class SearchHistoryService {
  static const String _fileName = 'data/search_history.json';
  static const int _maxItems = 20;

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

  /// Son aramaları döner (en yenisi başta)
  static Future<List<String>> getHistory() async {
    try {
      final path = await _getPath();
      final file = File(path);
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = json.decode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Aramayı geçmişe ekler (boş/duplicate hariç, en başa taşınır)
  static Future<void> addSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final list = await getHistory();
    final filtered = list.where((s) => s.toLowerCase() != q.toLowerCase()).toList();
    final updated = [q, ...filtered].take(_maxItems).toList();
    await _write(updated);
  }

  /// Tek bir aramayı geçmişten siler
  static Future<void> removeSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final list = await getHistory();
    final filtered = list.where((s) => s.toLowerCase() != q.toLowerCase()).toList();
    await _write(filtered);
  }

  /// Geçmişi tamamen siler
  static Future<void> clearHistory() async {
    await _write([]);
  }

  static Future<void> _write(List<String> items) async {
    await _ensureDir();
    final path = await _getPath();
    final file = File(path);
    await file.writeAsString(json.encode(items));
  }
}
