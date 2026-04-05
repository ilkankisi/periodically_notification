class NotificationEntry {
  final String id;
  final String title;
  final String body;
  final String createdAt;
  final bool read;
  final String type;

  NotificationEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    required this.type,
  });

  NotificationEntry copyWith({
    bool? read,
  }) {
    return NotificationEntry(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      read: read ?? this.read,
      type: type,
    );
  }

  factory NotificationEntry.fromMap(Map<String, dynamic> map) {
    return NotificationEntry(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      createdAt: map['createdAt']?.toString() ?? '',
      read: map['read'] == true,
      type: map['type']?.toString() ?? '',
    );
  }

  /// Go `GET /v1/notifications` satırı (`createdAt` ISO-8601).
  factory NotificationEntry.fromServerJson(Map<String, dynamic> map) {
    var created = map['createdAt']?.toString() ?? '';
    if (created.isEmpty && map['created_at'] != null) {
      created = map['created_at'].toString();
    }
    if (created.isNotEmpty) {
      final d = DateTime.tryParse(created);
      if (d != null) created = d.toUtc().toIso8601String();
    }
    return NotificationEntry(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      createdAt: created,
      read: map['read'] == true,
      type: map['type']?.toString() ?? 'COMMENT_REPLY',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'createdAt': createdAt,
      'read': read,
      'type': type,
    };
  }
}

