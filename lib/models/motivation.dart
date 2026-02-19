class Motivation {
  final String id;
  final String title;
  final String body; // corresponds to firebase 'body'
  final String? sentAt; // corresponds to firebase 'sentAt' string
  final int? order; // corresponds to firebase 'order'
  final String? imageBase64; // base64 encoded image string
  final String? imageUrl; // storage URL

  Motivation({
    required this.id,
    required this.title,
    required this.body,
    this.sentAt,
    this.order,
    this.imageBase64,
    this.imageUrl,
  });

  factory Motivation.fromMap(Map<String, dynamic> m) => Motivation(
        id: m['id']?.toString() ?? m['docId']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: m['title'] ?? '',
        body: m['body'] ?? '',
        sentAt: m['sentAt']?.toString(),
        order: m['order'] is int ? m['order'] : (m['order'] != null ? int.tryParse(m['order'].toString()) : null),
        imageBase64: m['image'],
        imageUrl: m['imageUrl'] ?? (m['image'] is String && (m['image'] as String).startsWith('http') ? m['image'] : null),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'sentAt': sentAt,
        'order': order,
        'image': imageBase64,
        'imageUrl': imageUrl,
      };
}
