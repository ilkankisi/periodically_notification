import '../models/comment.dart';
import 'backend_service.dart';
import 'gamification_service.dart';

/// Yorum + (varsa) sunucu gamification yanıtı.
class CommentPostResult {
  final Comment comment;
  final List<String> newBadgeIds;
  final int pointsAwarded;

  const CommentPostResult({
    required this.comment,
    this.newBadgeIds = const [],
    this.pointsAwarded = 0,
  });
}

/// Yorumlar yalnızca Go Postgres API (Faz 2).
class CommentService {
  static Stream<List<Comment>> streamComments(String itemId) {
    return _goCommentStream(itemId);
  }

  static Stream<List<Comment>> _goCommentStream(String itemId) async* {
    yield await _loadCommentsFromGo(itemId);
    yield* Stream.periodic(const Duration(seconds: 8), (_) => itemId).asyncMap(_loadCommentsFromGo);
  }

  static Future<List<Comment>> _loadCommentsFromGo(String itemId) async {
    final raw = await BackendService.client.getComments(itemId);
    return raw.map(Comment.fromBackendJson).toList();
  }

  /// [hadOtherAuthorsOnThread]: Eski backend (düz yorum JSON) için yerel rozet hesabında kullanılır.
  static Future<CommentPostResult?> postComment(
    String itemId,
    String text, {
    required bool hadOtherAuthorsOnThread,
    String? parentCommentId,
  }) async {
    final t = text.trim();
    if (t.isEmpty) return null;
    final ok = await BackendService.ensureToken();
    if (!ok) return null;
    final data = await BackendService.client.createComment(
      itemId,
      t,
      parentCommentId: parentCommentId,
    );
    if (data == null) return null;

    Map<String, dynamic> commentMap;
    Map<String, dynamic>? gamificationMap;
    if (data['comment'] is Map) {
      commentMap = Map<String, dynamic>.from(data['comment'] as Map);
      if (data['gamification'] is Map) {
        gamificationMap = Map<String, dynamic>.from(data['gamification'] as Map);
      }
    } else {
      commentMap = data;
    }

    final comment = Comment.fromBackendJson(commentMap);

    if (gamificationMap != null) {
      await GamificationService.persistServerGamificationFromMap(gamificationMap);
      final newBadges = (gamificationMap['newBadges'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final pts = (gamificationMap['pointsAwarded'] as num?)?.toInt() ?? 0;
      return CommentPostResult(
        comment: comment,
        newBadgeIds: newBadges,
        pointsAwarded: pts,
      );
    }

    final isReply = parentCommentId != null && parentCommentId.isNotEmpty;
    final newBadges = await GamificationService.recordCommentPosted(
      hadOtherAuthorsOnThread: hadOtherAuthorsOnThread,
      isReply: isReply,
    );
    final pts = GamificationService.pointsPerComment +
        (isReply ? GamificationService.pointsReplyBonus : 0) +
        (!isReply && hadOtherAuthorsOnThread ? GamificationService.pointsThreadBonus : 0);
    return CommentPostResult(
      comment: comment,
      newBadgeIds: newBadges,
      pointsAwarded: pts,
    );
  }

  /// Beğeni (1) / beğenmeme (-1). Yanıtta `gamification` varsa önbellek güncellenir.
  static Future<Map<String, dynamic>?> reactToComment(String commentId, int value) async {
    final ok = await BackendService.ensureToken();
    if (!ok) return null;
    final data = await BackendService.client.postCommentReaction(commentId, value);
    if (data != null) {
      await GamificationService.applyReactionServerSummary(data);
    }
    return data;
  }
}
