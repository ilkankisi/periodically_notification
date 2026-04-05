# Backend Kurulumu - Adım Adım Açıklama

Bu dosya, yaptığımız her adımın **neden** yapıldığını açıklar.

---

## Adım 1: Proje İskeleti

### Ne yaptık?
- `go.mod` - Go modül tanımı
- `cmd/server/main.go` - Uygulama giriş noktası
- `internal/server/` - HTTP handler'lar

### Neden?
- **cmd/**: Go projelerinde çalıştırılabilir binary'ler burada. `cmd/server` = tek monolit uygulama.
- **internal/**: Bu paketlere sadece bu proje içinden erişilebilir. Dış projeler import edemez (encapsulation).
- **go.mod**: Bağımlılık yönetimi. `go mod tidy` ile indirilen paketler burada listelenir.

---

## Adım 2: Docker Compose

### Ne yaptık?
- `docker-compose.yml` ile PostgreSQL, RabbitMQ, MinIO servisleri

### Neden?
- **PostgreSQL**: Firestore yerine ilişkisel veritabanı. `daily_items`, `users` tabloları.
- **RabbitMQ**: Cron 2:40'ta "günlük içerik gönder" mesajı atacak. Worker bu mesajı alıp FCM gönderecek. Async, servisler birbirinden bağımsız.
- **MinIO**: Firebase Storage yerine S3-uyumlu object storage. Görseller burada tutulacak.
- **healthcheck**: Uygulama başlamadan önce PostgreSQL hazır olsun diye Docker healthcheck kullanıyoruz.

---

## Adım 3: Migrations ve Veritabanı Bağlantısı

### Ne yaptık?
- `pkg/migrate/migrations/000001_initial.up.sql` - Tablo tanımları
- `pkg/postgres/postgres.go` - sqlx ile bağlantı
- `pkg/config/config.go` - Ortam değişkenleri
- `embed` ile migration'lar binary'ye gömüldü

### Neden?
- **Migration**: Şema kodla yönetilir. Takımda herkes aynı tabloya sahip olur. `migrate up` = tablolar oluşur.
- **sqlx**: `database/sql` üzerine. Struct'lara otomatik map, daha az boilerplate. `SelectContext` ile `[]DailyItem` döner.
- **Config env'den**: 12-Factor App - şifreler, host'lar kodda değil ortamda. `.env` veya Docker env ile set edilir.
- **embed**: Migration dosyaları binary'nin içinde; ayrı dosya taşımaya gerek yok.

---

## Adım 4: Content API (daily_items)

### Ne yaptık?
- `internal/content/model.go` - DailyItem struct
- `internal/content/repository.go` - ListAll, GetByID
- `internal/server/server.go` - ContentHandlers (ListDailyItems, GetDailyItem)
- `internal/server/routes.go` - Route tanımları

### Neden?
- **Repository pattern**: Handler veritabanına direkt erişmez. "Bana tüm item'ları getir" der, repository nasıl çektiğini bilir. Test'te mock repository kullanabiliriz.
- **ContentHandlers struct**: Tüm handler'lar aynı repository'yi paylaşır. Dependency injection - main'de gerçek repo verilir.
- **Context**: `c.Request.Context()` - HTTP isteği iptal edilirse (client çıktı) veritabanı sorgusu da iptal edilebilir.

---

## Çalıştırma Sırası

1. `docker compose up -d` → Altyapı hazır
2. `go mod tidy` → Bağımlılıklar indirilir
3. `go run ./cmd/server` → Migration çalışır, tablolar oluşur, API 8080'de dinler
4. (Opsiyonel) `psql ... -f scripts/seed.sql` → Örnek 3 item eklenir

---

## JWT Auth (yapıldı)

- **POST /api/auth/register**: email + password (min 6 karakter) → JWT + user
- **POST /api/auth/login**: email + password → JWT + user
- **GET /api/me**: `Authorization: Bearer <token>` zorunlu → user bilgisi
- **bcrypt** ile şifre hash
- **RequireAuth** middleware: token yoksa/geçersizse 401

---

## MinIO (yapıldı)

- **pkg/storage/minio.go**: MinIO client, Upload, bucket oluşturma, public policy
- **POST /api/storage/upload**: JWT zorunlu, multipart "file", max 5MB, .jpg/.png/.gif/.webp
- Dönen URL: `http://localhost:9000/motivations/uuid.jpg` (public erişim)

---

## Sonraki Adımlar (henüz yapılmadı)

- RabbitMQ consumer (FCM gönderici)
- Scheduler (cron 2:40)
- Flutter uygulamasının API'ye bağlanması
