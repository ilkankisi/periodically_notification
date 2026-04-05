import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/motivation.dart';

/// Kullanıcının kendi eklediği motivasyon cümleleri - cihazda saklanır.
class UserMotivationService {
  static const String _fileName = 'data/user_motivations.json';
  static const String _idPrefix = 'user_';

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

  /// Tüm kullanıcı motivasyonlarını yükle
  static Future<List<Motivation>> loadAll() async {
    try {
      final path = await _getPath();
      final file = File(path);
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = json.decode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => Motivation.fromMap(Map<String, dynamic>.from(e)))
          .where((m) => m.id.startsWith(_idPrefix))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Yeni motivasyon ekle
  static Future<Motivation> add(String title, String body, {String? category}) async {
    final id = '${_idPrefix}${DateTime.now().millisecondsSinceEpoch}';
    final sentAt = DateTime.now().toUtc().toIso8601String();
    final m = Motivation(
      id: id,
      title: title.trim(),
      body: body.trim(),
      sentAt: sentAt,
      order: 0,
      category: category ?? 'Bilim',
    );
    final list = await loadAll();
    list.insert(0, m);
    await _write(list);
    return m;
  }

  /// Kullanıcı motivasyonunu sil
  static Future<void> remove(String id) async {
    if (!id.startsWith(_idPrefix)) return;
    final list = await loadAll();
    final filtered = list.where((m) => m.id != id).toList();
    await _write(filtered);
  }

  static Future<void> _write(List<Motivation> items) async {
    await _ensureDir();
    final path = await _getPath();
    final file = File(path);
    final encoded = json.encode(items.map((m) => m.toMap()).toList());
    await file.writeAsString(encoded);
  }
}
