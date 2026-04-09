import 'package:flutter/foundation.dart';

/// Backend API taban adresi.
/// - Yerel Go: `http://localhost:8080` (iOS Simülatör / masaüstü)
/// - Android emülatör → host makine: `--dart-define=API_BASE_URL=http://10.0.2.2:8080`
/// - Docker + nginx (WAN/LAN): port 80 → `--dart-define=API_BASE_URL=http://<LAN_IP>` veya `http://<PUBLIC_IP>`
///   (sonunda `/` koymayın; `/api` uygulama içinde eklenir)
class ApiConfig {
  ApiConfig._();

  /// `API_BASE_URL` boş veya tanımsızsa `http://localhost:8080` kullanılır.
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    var u = fromEnv.trim();
    if (u.isEmpty) {
      u = 'http://localhost:8080';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  static const String apiPrefix = '/api';

  /// Debug konsolda hangi host’a gidildiğini görmek için.
  static void debugLogResolvedUrl() {
    if (kDebugMode) {
      final b = baseUrl;
      final full = '$b$apiPrefix';
      debugPrint('[ApiConfig] baseUrl=$b → API kökü $full');
    }
  }
}
