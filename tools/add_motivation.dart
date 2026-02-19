import 'dart:convert';
import 'dart:io';

// Usage:
// dart run tools/add_motivation.dart '{"id":"1","title":"Başlık","body":"İçerik","order":1,"sentAt":"15/01/2024 09:00","image":"<base64>"}'

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Lütfen eklenecek JSON objesini argüman olarak verin.');
    exit(1);
  }

  final input = args[0];
  final file = File('assets/data/motivation.json');

  Map<String, dynamic> newObj;
  try {
    newObj = json.decode(input) as Map<String, dynamic>;
  } catch (e) {
    print('Geçersiz JSON: $e');
    exit(1);
  }

  // remove 'sent' key if present (we no longer store it)
  newObj.remove('sent');

  // If user passed an 'image' value that is a URL (starts with http), move it to imageUrl
  if (newObj.containsKey('image') && newObj['image'] is String) {
    final img = newObj['image'] as String;
    if (img.startsWith('http://') || img.startsWith('https://')) {
      newObj['imageUrl'] = img;
      newObj.remove('image');
    }
  }

  // If user passed 'imageUrl' explicitly, ensure it's a string
  if (newObj.containsKey('imageUrl') && newObj['imageUrl'] is! String) {
    newObj.remove('imageUrl');
  }

  List<dynamic> list = [];
  if (await file.exists()) {
    final content = await file.readAsString();
    if (content.trim().isNotEmpty) {
      try {
        final decoded = json.decode(content);
        if (decoded is List) list = decoded;
      } catch (e) {
        print('Mevcut dosya okunamadı, yeni liste oluşturuluyor.');
      }
    }
  }

  list.add(newObj);

  await file.create(recursive: true);
  await file.writeAsString(JsonEncoder.withIndent('  ').convert(list));
  print('Yeni öğe eklendi ve assets/data/motivation.json güncellendi.');
}
