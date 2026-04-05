class Comment {
  final String id;
  final String itemId;
  final String userId;
  final String? parentId;
  final String userDisplayName;
  final String? userPhotoUrl;
  final String text;
  final DateTime createdAt;
  final int likeCount;
  final int dislikeCount;
  /// 1 = beğeni, -1 = beğenmeme; giriş yoksa veya tepki yoksa null.
  final int? myReaction;

  Comment({
    required this.id,
    required this.itemId,
    required this.userId,
    this.parentId,
    required this.userDisplayName,
    this.userPhotoUrl,
    required this.text,
    required this.createdAt,
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.myReaction,
  });

  Comment copyWith({
    int? likeCount,
    int? dislikeCount,
    int? myReaction,
    bool updateMyReaction = false,
  }) {
    return Comment(
      id: id,
      itemId: itemId,
      userId: userId,
      parentId: parentId,
      userDisplayName: userDisplayName,
      userPhotoUrl: userPhotoUrl,
      text: text,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      dislikeCount: dislikeCount ?? this.dislikeCount,
      myReaction: updateMyReaction ? myReaction : this.myReaction,
    );
  }

  /// Go API yanıtı (JSON).
  factory Comment.fromBackendJson(Map<String, dynamic> m) => Comment(
        id: m['id'] as String? ?? '',
        itemId: m['itemId'] as String? ?? '',
        userId: m['userId'] as String? ?? '',
        parentId: _parseOptionalString(m['parentId']),
        userDisplayName: m['userDisplayName'] as String? ?? 'Kullanıcı',
        userPhotoUrl: m['userPhotoUrl'] as String?,
        text: m['text'] as String? ?? '',
        createdAt: _parseDateTime(m['createdAt']),
        likeCount: (m['likeCount'] as num?)?.toInt() ?? 0,
        dislikeCount: (m['dislikeCount'] as num?)?.toInt() ?? 0,
        myReaction: _parseOptionalInt(m['myReaction']),
      );

  Map<String, dynamic> toMap() => {
        'itemId': itemId,
        'userId': userId,
        'parentId': parentId,
        'userDisplayName': userDisplayName,
        'userPhotoUrl': userPhotoUrl,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'likeCount': likeCount,
        'dislikeCount': dislikeCount,
        'myReaction': myReaction,
      };

  static String? _parseOptionalString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _parseOptionalInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static DateTime _parseDateTime(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }
}
