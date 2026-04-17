# Periodically Backend

Go + Gin ile günlük motivasyon bildirimi backend'i. PostgreSQL, RabbitMQ, MinIO kullanır.

## Kurulum

### 1. Go kurulumu

Go yüklü değilse: https://go.dev/doc/install

### 2. Proje bağımlılıkları

```bash
cd backend
go mod tidy
```

### 3. Docker ile altyapıyı başlat

```bash
docker compose up -d
```

Bu komut PostgreSQL (5432), RabbitMQ (5672, web UI: 15672), MinIO (9000, console: 9001), API ve nginx başlatır.

WAN erişimi ve `MINIO_PUBLIC_URL`: [docs/DOCKER_DESKTOP_WINDOWS_WAN.md](../docs/DOCKER_DESKTOP_WINDOWS_WAN.md).

### 4. Örnek veri ekle (isteğe bağlı)

```bash
psql -h localhost -U app -d periodically -f scripts/seed.sql
# Şifre: secret
```

### 5. Migration (opsiyonel - server başlarken otomatik çalışır)

```bash
go run ./cmd/migrate
```

### 6. OAuth (Apple / Google — varsayılan giriş)

```bash
export GOOGLE_OAUTH_CLIENT_IDS=xxx.apps.googleusercontent.com
export APPLE_CLIENT_IDS=com.sirket.uygulama
```

Boş bırakılırsa `pkg/config` içindeki örnek değerler kullanılır; **production’da env zorunlu.**

### 7. Firebase Auth (opsiyonel — yalnızca `POST /api/auth/token`)

Uygulama yalnızca sunucu + Google/Apple OAuth ile çalışıyorsa bu değişkenleri boş bırakın. Geçiş endpoint’i gerekiyorsa:

```bash
export FIREBASE_PROJECT_ID=periodically-notification
export FIREBASE_AUTH_CREDENTIALS_PATH=/path/to/service-account.json
```

### 8. APNs (iOS push) + admin tetikleyici

```bash
export ADMIN_SECRET=uzun-rastgele-gizli

# Apple Push (.p8 anahtar)
export APNS_KEY_PATH=/path/to/AuthKey_XXXXX.p8
export APNS_KEY_ID=XXXXXXXXXX
export APNS_TEAM_ID=XXXXXXXXXX
export APNS_TOPIC=com.siyazilim.periodicallynotification
# Yayın: APNS_PRODUCTION=true   Geliştirme: false (sandbox)
```

Cihaz uygulama açıldığında `POST /api/push/apns-token` ile jeton kaydeder; `POST /api/admin/daily-send` tüm kayıtlı jetonlara günlük içeriği gönderir.

### 9. Uygulamayı çalıştır

```bash
go run ./cmd/server
```

Sunucu `http://localhost:8080` üzerinde çalışır.

## API Endpoints

| Method | Endpoint | Auth | Açıklama |
|--------|----------|------|----------|
| GET | /api/health | - | Sağlık kontrolü |
| GET | /api/daily-items | - | Tüm günlük içerikler |
| GET | /api/daily-items/:id | - | Tek içerik |
| POST | /api/push/apns-token | - | iOS APNs cihaz jetonu kaydı |
| POST | /api/admin/daily-send | X-Admin-Secret | Günlük içerik + APNs (yapılandırılmışsa) |
| POST | /api/auth/register | - | Kayıt (email, password) |
| POST | /api/auth/login | - | Giriş (email, password) |
| POST | /api/auth/oauth/google | - | Google id_token → JWT |
| POST | /api/auth/oauth/apple | - | Apple identity_token → JWT |
| POST | /api/auth/token | - | (Geçiş) Firebase ID token → JWT |
| GET | /api/me | JWT | Giriş yapmış kullanıcı bilgisi |
| POST | /api/storage/upload | JWT | Görsel yükleme (multipart/form-data, field: file) |
| POST | /api/v1/actions | JWT | Aksiyon ekle (Idempotency-Key, X-Consent-Sync) |
| GET | /api/v1/actions/daily | JWT | Günlük aksiyonlar (?date=YYYY-MM-DD) |
| GET | /api/v1/progress | JWT | Streak + last7Days |
| POST | /api/v1/reports | JWT | Rapor |
| POST | /api/v1/blocks | JWT | Engelle |
| DELETE | /api/v1/blocks/:userId | JWT | Engeli kaldır |
| DELETE | /api/v1/account | JWT | Hesap sil (soft delete) |
| GET | /api/v1/comments?itemId= | - | Yorum listesi |
| POST | /api/v1/comments | JWT | Yorum ekle |

### Storage upload test (curl)

```bash
# Önce login/register ile token al
TOKEN="..." # veya register/login response'tan

# Görsel yükle
curl -X POST http://localhost:8080/api/storage/upload \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/path/to/image.jpg"
# Response: {"url":"http://127.0.0.1/minio/motivations/uuid.jpg",...}  (Docker’da nginx /minio/ vekili; MINIO_PUBLIC_URL buna göre)
```

**Not:** Docker + nginx kullanırken `MINIO_PUBLIC_URL` tabanı `http://<erişilebilir_IP>/minio` olmalı (doğrudan `:9000` mobil operatörlerde sorun çıkarabilir). Yerel `go run` ile doğrudan MinIO’ya bağlanıyorsanız `http://localhost:9000` kullanılabilir.

## Veri ve görsel araçları (CLI)

Firestore / Node script’lerinin yerine; `backend` kökünden `DB_*` ve `MINIO_*` env ile çalıştırın.

| Amaç | Komut |
|------|--------|
| `motivations.json` → Postgres `daily_items` | `go run scripts/import-motivations.go` |
| Tüm `daily_items` sil + `next_order` sıfırla ve içe aktar | `go run scripts/import-motivations.go -replace` |
| Postgres → `mobile/assets/.../motivations.json` | `go run scripts/export-motivations.go -out ../mobile/assets/data/motivations.json` |
| Yerel dosyaları MinIO’ya yükle, JSON + DB `image_url` | `go run scripts/upload-local-images.go -local /path/to/gorsel_klasoru` |

`upload-local-images.go`: `-write-json=false` veya `-update-db=false` ile sadece yükleme / sadece JSON güncelleme yapılabilir.

### Günlük gönderim (cron örneği)

```bash
curl -sS -X POST "https://api.example.com/api/admin/daily-send" \
  -H "X-Admin-Secret: $ADMIN_SECRET"
```

### Auth test (curl)

```bash
# Kayıt
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"123456"}'

# Giriş
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"123456"}'

# Me (token ile)
curl http://localhost:8080/api/me \
  -H "Authorization: Bearer <TOKEN>"
```

## Proje Yapısı

```
cmd/server/main.go     → Uygulama giriş noktası
internal/server/       → HTTP handler'lar, route'lar
internal/content/      → Domain model, repository (veritabanı erişimi)
pkg/config/            → Ortam değişkenleri
pkg/postgres/          → DB bağlantısı
pkg/migrate/           → SQL migration'lar (embed)
```
