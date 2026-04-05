import 'backend_service.dart';

/// Yorum raporlama ve kullanıcı engelleme (App Store 1.2).
class ModerationService {
  ModerationService._();

  static Future<bool> reportComment({
    required String commentId,
    required String quoteId,
    required String reason,
    String? details,
  }) async {
    final ok = await BackendService.ensureToken();
    if (!ok) return false;
    return BackendService.client.createReport(
      commentId: commentId,
      quoteId: quoteId,
      reason: reason,
      details: details,
    );
  }

  static Future<bool> blockUser(String blockedBackendUserId) async {
    final ok = await BackendService.ensureToken();
    if (!ok) return false;
    return BackendService.client.blockUser(blockedBackendUserId);
  }
}
