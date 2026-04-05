# Flutter ↔ Go Backend Entegrasyonu

**Amaç:** Flutter uygulamasının Go backend API'lerine bağlanması, opt-in sync, offline→online senkron.

---

## 1. API Base URL

```dart
// lib/services/api_config.dart
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  static const String apiPrefix = '/api';
}
```

**Production:** `https://api.yourapp.com` (env ile)

---

## 2. API Client (http paketi)

```dart
// lib/services/backend_api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'api_config.dart';

class BackendApiClient {
  final String baseUrl;
  String? _jwtToken;

  BackendApiClient({String? baseUrl})
      : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  String get _apiBase => '$baseUrl${ApiConfig.apiPrefix}';

  void setToken(String? token) => _jwtToken = token;

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

  /// Firebase ID token → Backend JWT exchange
  Future<Map<String, dynamic>?> exchangeFirebaseToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final idToken = await user.getIdToken();
    if (idToken == null) return null;

    final r = await http.post(
      Uri.parse('$_apiBase/auth/token'),
      headers: _headers(withAuth: false),
      body: jsonEncode({'idToken': idToken}),
    );
    if (r.statusCode != 200) return null;
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    _jwtToken = data['token'] as String?;
    return data;
  }

  /// POST /v1/actions
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
    if (r.statusCode == 409) return null; // idempotency conflict
    return null;
  }

  /// GET /v1/actions/daily?date=YYYY-MM-DD
  Future<List<dynamic>> getDailyActions(String date) async {
    final r = await http.get(
      Uri.parse('$_apiBase/v1/actions/daily?date=$date'),
      headers: _headers(),
    );
    if (r.statusCode != 200) return [];
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return (data['actions'] as List?) ?? [];
  }

  /// GET /v1/progress
  Future<Map<String, dynamic>?> getProgress() async {
    final r = await http.get(
      Uri.parse('$_apiBase/v1/progress'),
      headers: _headers(),
    );
    if (r.statusCode != 200) return null;
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// POST /v1/reports
  Future<bool> postReport({
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

  /// POST /v1/blocks (blockedId = Firebase UID veya backend UUID)
  Future<bool> blockUser(String blockedId) async {
    final r = await http.post(
      Uri.parse('$_apiBase/v1/blocks'),
      headers: _headers(),
      body: jsonEncode({'blockedId': blockedId}),
    );
    return r.statusCode == 201;
  }

  /// DELETE /v1/blocks/:userId
  Future<bool> unblockUser(String userId) async {
    final r = await http.delete(
      Uri.parse('$_apiBase/v1/blocks/$userId'),
      headers: _headers(),
    );
    return r.statusCode == 200;
  }

  /// DELETE /v1/account
  Future<bool> deleteAccount() async {
    final r = await http.delete(
      Uri.parse('$_apiBase/v1/account'),
      headers: _headers(),
    );
    return r.statusCode == 200;
  }
}
```

---

## 3. Auth Token Akışı

```dart
// Giriş sonrası (Apple/Google)
Future<void> onSignIn() async {
  final api = BackendApiClient();
  final data = await api.exchangeFirebaseToken();
  if (data != null) {
    // Token sakla (SharedPreferences veya secure storage)
    await prefs.setString('backend_jwt', data['token'] as String);
    // Artık tüm API çağrıları bu token ile yapılır
  }
}

// Uygulama başlangıcında
Future<void> initApi() async {
  final token = prefs.getString('backend_jwt');
  if (token != null) {
    api.setToken(token);
    // Opsiyonel: token süresi dolmuş olabilir, exchangeFirebaseToken ile yenile
  }
}
```

---

## 4. Opt-in Sonrası Action Gönderme Akışı

```
1. Kullanıcı söze dokunur → ContentDetailPage açılır
2. "Bugün bu sözle ne yaptın?" kartı görünür
3. Kullanıcı aksiyon yazar, "Aksiyon Ekle" basar
4. Opt-in dialog: "Aksiyonlarınız sunucuya senkron edilsin mi? Evet / Hayır"
5. Hayır → Sadece lokal storage'a kaydet (guest mode)
6. Evet → 
   a. Giriş yoksa → Firebase ile giriş yönlendir
   b. Giriş varsa → POST /v1/actions (Idempotency-Key, X-Consent-Sync: true)
```

**Idempotency Key:** `quoteId_localDate_timestamp` veya `uuid` (aynı key ile tekrar istek = 409, duplicate yok)

```dart
String generateIdempotencyKey(String quoteId, String localDate) {
  return '${quoteId}_${localDate}_${DateTime.now().millisecondsSinceEpoch}';
}
```

---

## 5. Offline → Online Sync Mantığı

**Basit yaklaşım:**

1. **Lokal queue:** SharedPreferences veya SQLite'da `pending_actions` listesi
2. **Aksiyon eklenince:** Önce lokale yaz, sonra (online ise) backend'e gönder
3. **Online olunca:** `Connectivity` veya `http` retry ile pending listesini sırayla gönder
4. **Idempotency:** Her pending item için aynı key kullan (ilk oluşturulduğunda üretilen)

```dart
// Basit sync servisi
class ActionSyncService {
  final BackendApiClient _api;
  final SharedPreferences _prefs;
  static const _key = 'pending_actions';

  Future<void> addPending(ActionItem a) async {
    final list = _loadPending();
    list.add({
      'quoteId': a.quoteId,
      'localDate': a.localDate,
      'note': a.note,
      'idempotencyKey': a.idempotencyKey,
    });
    await _prefs.setString(_key, jsonEncode(list));
  }

  Future<void> syncPending() async {
    if (!await _ensureToken()) return;
    final list = List<dynamic>.from(_loadPending());
    final toRemove = <int>[];
    for (var i = 0; i < list.length; i++) {
      final item = list[i] as Map<String, dynamic>;
      final ok = await _api.postAction(
        quoteId: item['quoteId'] as String,
        localDate: item['localDate'] as String,
        note: item['note'] as String?,
        idempotencyKey: item['idempotencyKey'] as String,
      );
      if (ok != null) toRemove.add(i);
    }
    toRemove.sort((a, b) => b.compareTo(a)); // yüksekten düşüğe
    for (final i in toRemove) list.removeAt(i);
    await _prefs.setString(_key, jsonEncode(list));
  }

  List<dynamic> _loadPending() {
    final s = _prefs.getString(_key);
    if (s == null) return [];
    return List<dynamic>.from(jsonDecode(s));
  }

  Future<bool> _ensureToken() async {
    final data = await _api.exchangeFirebaseToken();
    return data != null;
  }
}
```

**Ne zaman sync?** App resume, connectivity change, veya periyodik (ör. her 30 sn).

---

## 6. Backend Endpoint Özeti

| Method | Path | Auth | Body/Query |
|--------|------|------|------------|
| POST | /api/auth/token | No | `{idToken}` |
| POST | /api/v1/actions | Yes | quoteId, localDate, note + Idempotency-Key, X-Consent-Sync |
| GET | /api/v1/actions/daily | Yes | ?date=YYYY-MM-DD |
| GET | /api/v1/progress | Yes | - |
| POST | /api/v1/reports | Yes | commentId, quoteId, reason, details |
| POST | /api/v1/blocks | Yes | blockedId (Firebase UID) |
| DELETE | /api/v1/blocks/:userId | Yes | - |
| DELETE | /api/v1/account | Yes | - |

---

## 7. 3 Günlük Öncelik Sırası

### Gün 1
1. **Backend:** `backendGo` projesinde (`~/Desktop/backendGo`) Docker + `go run ./cmd/server` ile test
2. **Flutter:** `BackendApiClient` + `exchangeFirebaseToken` ekle
3. **Flutter:** Giriş sonrası token exchange, token saklama
4. **Flutter:** POST /v1/actions (opt-in Evet seçildiğinde)

### Gün 2
5. **Flutter:** AddActionCard + Opt-in dialog (ContentDetailPage)
6. **Flutter:** Lokal aksiyon storage (guest mode)
7. **Flutter:** DailyActionsPage (GET /v1/actions/daily)
8. **Flutter:** ProgressStreakPage (GET /v1/progress)

### Gün 3
9. **Flutter:** Pending actions queue + offline sync
10. **Flutter:** Raporla/Engelle (POST /v1/reports, POST/DELETE /v1/blocks)
11. **Flutter:** Hesap silme (DELETE /v1/account)
12. **Test:** End-to-end, offline→online, Apple review senaryoları
