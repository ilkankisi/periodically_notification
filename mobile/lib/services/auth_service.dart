import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'backend_service.dart';
import 'push_notification_service.dart';

/// Oturum: Go OAuth + JWT (Firebase Auth yok).
class AuthSession {
  AuthSession({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;

  factory AuthSession.fromJson(Map<String, dynamic> m) => AuthSession(
        id: m['id'] as String? ?? '',
        email: m['email'] as String? ?? '',
        displayName: m['displayName'] as String? ?? '',
        photoUrl: m['photoUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
      };
}

/// Apple ve Google ile giriş → Go `/api/auth/oauth/*` → JWT.
class AuthService {
  static const _keySession = 'auth_session_user';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId: const String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
      defaultValue: '',
    ),
  );

  static final StreamController<void> _authState = StreamController<void>.broadcast();
  static AuthSession? _session;

  static Stream<void> get authStateChanges => _authState.stream;

  static AuthSession? get session => _session;

  static bool get isLoggedIn => BackendService.client.hasToken && _session != null;

  static String? get displayName => _session?.displayName;

  static String? get email => _session?.email;

  static String? get photoUrl => _session?.photoUrl;

  /// Backend kullanıcı UUID (yorumlar / engelleme).
  static String? get backendUserId => _session?.id;

  static Future<void> loadCachedSession() async {
    if (!BackendService.client.hasToken) {
      _session = null;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySession);
    if (raw == null || raw.isEmpty) {
      _session = null;
      await BackendService.clearToken();
      return;
    }
    try {
      _session = AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      _session = null;
      await BackendService.clearToken();
    }
  }

  static Future<void> _saveSession(Map<String, dynamic> userJson, String token) async {
    await BackendService.persistJwt(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySession, jsonEncode(userJson));
    _session = AuthSession.fromJson(userJson);
    _authState.add(null);
  }

  /// true: başarılı, false: kullanıcı iptal.
  static Future<bool> signInWithApple() async {
    if (!await SignInWithApple.isAvailable()) {
      throw Exception('Apple ile giriş bu cihazda desteklenmiyor.');
    }
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final identityToken = credential.identityToken?.trim();
    if (identityToken == null || identityToken.isEmpty) {
      throw Exception('Apple token alınamadı.');
    }
    String? fullName;
    final gn = credential.givenName;
    final fn = credential.familyName;
    if ((gn != null && gn.isNotEmpty) || (fn != null && fn.isNotEmpty)) {
      fullName = '${gn ?? ''} ${fn ?? ''}'.trim();
    }
    final data = await BackendService.client.oauthApple(
      identityToken: identityToken,
      email: credential.email,
      fullName: (fullName != null && fullName.isNotEmpty) ? fullName : null,
    );
    if (data == null) throw Exception('Sunucu girişi başarısız.');
    final token = data['token'] as String?;
    final user = data['user'] as Map<String, dynamic>?;
    if (token == null || user == null) throw Exception('Geçersiz sunucu yanıtı.');
    await _saveSession(user, token);
    return true;
  }

  /// true: başarılı, false: kullanıcı iptal.
  static Future<bool> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false;
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        await _googleSignIn.signOut();
        throw Exception(
          'Google idToken yok. Android için --dart-define=GOOGLE_SERVER_CLIENT_ID=... (Web client ID) ekleyin.',
        );
      }
      final data = await BackendService.client.oauthGoogle(idToken: idToken);
      final token = data['token'] as String?;
      final user = data['user'] as Map<String, dynamic>?;
      if (token == null || user == null) {
        await _googleSignIn.signOut();
        throw Exception('Geçersiz sunucu yanıtı.');
      }
      await _saveSession(user, token);
      return true;
    } on PlatformException catch (e) {
      final m = e.message ?? '';
      // DEVELOPER_ERROR: genelde OAuth Android istemcisinde SHA-1 / paket adı eksik (emülatör ≠ telefon imzası).
      if (m.contains('ApiException: 10') ||
          m.contains('DEVELOPER_ERROR') ||
          RegExp(r'ApiException:\s*10\b').hasMatch(m)) {
        throw Exception(
          'Google Android yapılandırması (SHA-1): Google Cloud Console’da bu uygulama için '
          'OAuth 2.0 “Android” istemcisinde paket adı `com.siyazilim.periodicallynotification` '
          've geliştirme için `debug.keystore` SHA-1 parmak izi tanımlı olmalı. '
          'Telefon ve emülatör farklı imza kullanabilir; ikisini de ekleyin.',
        );
      }
      rethrow;
    }
  }

  static Future<void> signOut() async {
    await PushNotificationService.disassociateCurrentUserIfPossible();
    await _googleSignIn.signOut();
    await BackendService.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySession);
    _session = null;
    _authState.add(null);
  }

  /// Sunucuda hesabı kapatır (soft delete), ardından oturumu temizler.
  static Future<bool> deleteAccountOnServer() async {
    if (!isLoggedIn) return false;
    final ok = await BackendService.client.deleteAccount();
    if (ok) {
      await signOut();
    }
    return ok;
  }
}
