import '../utils/media_url.dart';

class Motivation {
  final String id;
  final String title;
  final String body;
  final String? sentAt;
  final int? order;
  final String? imageBase64; // base64 encoded image string
  final String? imageUrl; // storage URL
  final String? category; // Teknoloji, Sanat, Tarih, Bilim - Keşfet filtrelemesi için

  Motivation({
    required this.id,
    required this.title,
    required this.body,
    this.sentAt,
    this.order,
    this.imageBase64,
    this.imageUrl,
    this.category,
  });

  static String? _trimUrl(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory Motivation.fromMap(Map<String, dynamic> m) => Motivation(
        id: m['id']?.toString() ?? m['docId']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: m['title'] ?? '',
        body: m['body'] ?? '',
        sentAt: m['sentAt']?.toString(),
        order: m['order'] is int ? m['order'] : (m['order'] != null ? int.tryParse(m['order'].toString()) : null),
        imageBase64: m['image'],
        imageUrl: _trimUrl(
              m['imageUrl'] ??
                  (m['image'] is String && (m['image'] as String).trim().startsWith('http')
                      ? m['image']
                      : null),
            ),
        category: m['category']?.toString(),
      );

  /// Go `GET /api/daily-items` satırı (camelCase JSON).
  factory Motivation.fromApiDailyItem(Map<String, dynamic> m) {
    final sentRaw = m['sentAt'];
    String? sentAt;
    if (sentRaw != null) {
      sentAt = sentRaw is String ? sentRaw : sentRaw.toString();
    }
    final orderRaw = m['order'];
    int? order;
    if (orderRaw is int) {
      order = orderRaw;
    } else if (orderRaw != null) {
      order = int.tryParse(orderRaw.toString());
    }
    final img = m['imageUrl'];
    final imageUrl =
        img is String && img.trim().isNotEmpty ? img.trim() : null;
    return Motivation(
      id: m['id']?.toString() ?? '',
      title: m['title']?.toString() ?? '',
      body: m['body']?.toString() ?? '',
      sentAt: sentAt,
      order: order,
      imageUrl: imageUrl,
      category: m['category']?.toString(),
    );
  }

  /// Ağdan yüklenecek görsel URL'i; `MediaUrl.resolveForDevice` loopback adresleri düzeltir.
  String? get displayImageUrl => MediaUrl.resolveForDevice(imageUrl);

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'sentAt': sentAt,
        'order': order,
        'image': imageBase64,
        'imageUrl': imageUrl,
        'category': category,
      };
}
