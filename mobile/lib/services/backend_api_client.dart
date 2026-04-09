import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/motivation.dart';
import 'api_config.dart';
import '../models/action_entry.dart';

/// Go backend API client.
class BackendApiClient {
  final String baseUrl;
  String? _jwtToken;

  BackendApiClient({String? baseUrl})
      : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  String get _apiBase => '$baseUrl${ApiConfig.apiPrefix}';

  static const Duration _httpTimeout = Duration(seconds: 30);

  /// Herkese açık içerik listesi (JWT gerekmez).
  Future<List<Motivation>> fetchDailyItemsMotivations() async {
    final uri = Uri.parse('$_apiBase/daily-items');
    if (kDebugMode) {
      debugPrint('[API] GET $uri');
    }
    try {
      final r = await http
          .get(uri, headers: _headers(withAuth: false))
          .timeout(_httpTimeout);
      if (kDebugMode) {
        debugPrint('[API] daily-items → ${r.statusCode}, ${r.body.length} byte');
      }
      if (r.statusCode != 200) {
        if (kDebugMode && r.body.isNotEmpty) {
          debugPrint('[API] daily-items body: ${r.body.length > 200 ? '${r.body.substring(0, 200)}…' : r.body}');
        }
        return [];
      }
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final list = data['items'] as List? ?? [];
      final out = list
          .map((e) => Motivation.fromApiDailyItem(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (kDebugMode) {
        debugPrint('[API] daily-items parsed ${out.length} kayıt');
      }
      return out;
    } on Object catch (e, st) {
      if (kDebugMode) {
        debugPrint('[API] daily-items hata: $e');
        debugPrint('$st');
      }
      return [];
    }
  }

  /// APNs cihaz jetonunu Go `POST /api/push/apns-token` ile kaydeder.
  Future<bool> registerApnsDeviceToken(String deviceTokenHex) async {
    final r = await http.post(
      Uri.parse('$_apiBase/push/apns-token'),
      headers: _headers(withAuth: false),
      body: jsonEncode({'deviceToken': deviceTokenHex}),
    );
    return r.statusCode == 204 || r.statusCode == 200;
  }

  /// JWT ile APNs jetonunu kullanıcıya bağlar (`POST /api/v1/push/apns-token`).
  Future<bool> registerApnsDeviceTokenForAuthUser(String deviceTokenHex) async {
    final r = await http.post(
      Uri.parse('$_apiBase/v1/push/apns-token'),
      headers: _headers(),
      body: jsonEncode({'deviceToken': deviceTokenHex}),
    );
    return r.statusCode == 204 || r.statusCode == 200;
  }

  /// Çıkışta bu cihaz jetonundan kullanıcı bağını kaldırır.
  Future<bool> disassociateApnsDeviceToken(String deviceTokenHex) async {
    final r = await http.post(
      Uri.parse('$_apiBase/v1/push/apns-token/disassociate'),
      headers: _headers(),
      body: jsonEncode({'deviceToken': deviceTokenHex}),
    );
    return r.statusCode == 204 || r.statusCode == 200;
  }

  /// Tek içerik (`itemId` = backend UUID).
  Future<Map<String, dynamic>?> fetchDailyItemRaw(String id) async {
    final enc = Uri.encodeComponent(id);
    final r = await http.get(
      Uri.parse('$_apiBase/daily-items/$enc'),
      headers: _headers(withAuth: false),
    );
    if (r.statusCode != 200) return null;
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  void setToken(String? token) => _jwtToken = token;

  bool get hasToken => _jwtToken != null && _jwtToken!.isNotEmpty;

  Map<String, String> _headers({bool withAuth = true}) {
    final m = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth && _jwtToken != null) {
      m['Authorization'] = 'Bearer $_jwtToken';
    }
    return m;
  }

  Future<Map<String, dynamic>?> oauthGoogle({required String idToken}) async {
    final r = await http.post(
      Uri.parse('$_apiBase/auth/oauth/google'),
      headers: _headers(withAuth: false),
      body: jsonEncode({'idToken': idToken}),
    );
    if (r.statusCode != 200) return null;
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> oauthApple({
    required String identityToken,
    String? email,
    String? fullName,
  }) async {
    final body = <String, dynamic>{'identityToken': identityToken};
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (fullName != null && fullName.isNotEmpty) body['fullName'] = fullName;
    final r = await http.post(
      Uri.parse('$_apiBase/auth/oauth/apple'),
      headers: _headers(withAuth: false),
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) return null;
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> postAction({
    required String quoteId,
    required String localDate,
    String? note,
    required String idempotencyKey,
  }) async {
    final r = await http.post(
      Uri.parse('$_apiBase/v1/actions'),
      headers: {
        ..._headers(),
        'Idempotency-Key': idempotencyKey,
        'X-Consent-Sync': 'true',
      },
      body: jsonEncode({
        'quoteId': quoteId,
        'localDate': localDate,
        'note': note ?? '',
      }),
    );
    if (r.statusCode == 201) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 409) return null;
    return null;
  }

  Future<List<Map<String, dynamic>>> getComments(String itemId) async {
    final q = Uri.encodeQueryComponent(itemId);
    final r = await http.get(
      Uri.parse('$_apiBase/v1/comments?itemId=$q'),
      headers: _headers(withAuth: hasToken),
    );
    if (r.statusCode != 200) return [];
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final list = data['comments'] as List? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>?> createComment(
    String itemId,
    String text, {
    String? parentCommentId,
  }) async {
    final body = <String, dynamic>{'itemId': itemId, 'text': text};
    if (parentCommentId != null && parentCommentId.isNotEmpty) {
      body['parentId'] = parentCommentId;
    }
    final r = await http.post(
      Uri.parse('$_apiBase/v1/comments'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode == 201) return jsonDecode(r.body) as Map<String, dynamic>;
    return null;
  }

  /// Beğeni (1) veya beğenmeme (-1). Aynı değere tekrar basınca kaldırılır.
  Future<Map<String, dynamic>?> postCommentReaction(String commentId, int value) async {
    final enc = Uri.encodeComponent(commentId);
    final r = await http.post(
      Uri.parse('$_apiBase/v1/comments/$enc/reaction'),
      headers: _headers(),
      body: jsonEncode({'value': value}),
    );
    if (r.statusCode != 200) return null;
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Bu içerik (`quoteId` = daily_item id) için giriş yapmış kullanıcının son aksiyonu; yoksa null.
  Future<Map<String, dynamic>?> getActionForQuote(String quoteId) async {
    final q = Uri.encodeQueryComponent(quoteId);
    final r = await http.get(
      Uri.parse('$_apiBase/v1/actions/for-quote?quoteId=$q'),
      headers: _headers(),
    );
    if (r.statusCode != 200) return null;
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final a = data['action'];
    if (a == null) return null;
    return Map<String, dynamic>.from(a as Map);
  }

  Future<List<dynamic>> getDailyActions(String date) async {
    final r = await http.get(
      Uri.parse('$_apiBase/v1/actions/daily?date=$date'),
      headers: _headers(),
    );
    if (r.statusCode != 200) return [];
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return (data['actions'] as List?) ?? [];
  }

  Future<Map<String, dynamic>?> getProgress() async {
    final r = await http.get(
      Uri.parse('$_apiBase/v1/progress'),
      headers: _headers(),
    );
    if (r.statusCode != 200) return null;
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Uygulama içi bildirimler (ör. yorum yanıtı).
  Future<List<Map<String, dynamic>>> getNotifications() async {
    final r = await http.get(
      Uri.parse('$_apiBase/v1/notifications'),
      headers: _headers(),
    );
    if (r.statusCode != 200) return [];
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final list = data['notifications'] as List? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<bool> postNotificationsReadAll() async {
    final r = await http.post(
      Uri.parse('$_apiBase/v1/notifications/read-all'),
      headers: _headers(),
    );
    return r.statusCode == 204;
  }

  /// Rozetler + puan özeti (PostgreSQL `user_gamification`, streak sunucuda hesaplanır).
  Future<Map<String, dynamic>?> getGamification() async {
    final r = await http.get(
      Uri.parse('$_apiBase/v1/gamification'),
      headers: _headers(),
    );
    if (r.statusCode != 200) return null;
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Kullanıcının bugüne kadar girdiği tüm aksiyonlar (zincir ekranı için).
  Future<List<ActionEntry>> getMyActions() async {
    final r = await http.get(
      Uri.parse('$_apiBase/v1/actions/me'),
      headers: _headers(),
    );
    if (r.statusCode != 200) return [];
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final list = data['actions'] as List? ?? [];
    return list
        .map((e) => ActionEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Apple hesap silme politikası: kalıcı hesap kapatma (sunucu soft delete).
  Future<bool> deleteAccount() async {
    final r = await http.delete(
      Uri.parse('$_apiBase/v1/account'),
      headers: _headers(),
    );
    return r.statusCode == 200;
  }

  /// UGC — yorum raporu (Guideline 1.2).
  Future<bool> createReport({
    required String commentId,
    required String quoteId,
    required String reason,
    String? details,
  }) async {
    final r = await http.post(
      Uri.parse('$_apiBase/v1/reports'),
      headers: _headers(),
      body: jsonEncode({
        'commentId': commentId,
        'quoteId': quoteId,
        'reason': reason,
        'details': details ?? '',
      }),
    );
    return r.statusCode == 201;
  }

  /// Kullanıcı engelle; yorum listesinde gizlenir.
  Future<bool> blockUser(String blockedId) async {
    final r = await http.post(
      Uri.parse('$_apiBase/v1/blocks'),
      headers: _headers(),
      body: jsonEncode({'blockedId': blockedId}),
    );
    return r.statusCode == 201 || r.statusCode == 200;
  }
}
