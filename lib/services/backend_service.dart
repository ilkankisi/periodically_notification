import 'package:shared_preferences/shared_preferences.dart';

import 'backend_api_client.dart';

/// Backend API client singleton + JWT persistence.
class BackendService {
  static final BackendApiClient _client = BackendApiClient();
  static const _keyJwt = 'backend_jwt';

  static BackendApiClient get client => _client;

  static Future<void> persistJwt(String token) async {
    _client.setToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyJwt, token);
  }

  static Future<void> loadStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyJwt);
    if (token != null) _client.setToken(token);
  }

  static Future<void> clearToken() async {
    _client.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyJwt);
  }

  static Future<bool> ensureToken() async => _client.hasToken;
}
