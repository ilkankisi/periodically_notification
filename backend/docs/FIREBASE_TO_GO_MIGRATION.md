# Firebase → Go Tam Geçiş Planı

**Hedef:** Firebase’i kapatmadan önce şu an Firebase’de yaptığınız her şeyi Go + Postgres (ve bildirim için ayrı kanal) ile karşılamak.

---

## 1. Bugün Firebase’de Ne Var? (Envanter)

| Alan | Şu an (Flutter / Firebase) | Go + Postgres hedefi |
|------|----------------------------|-------------------------|
| **Giriş** | `firebase_auth` (Apple, Google) | `POST /api/auth/oauth/google`, `POST /api/auth/oauth/apple` → JWT; `users` tablosunda `google_sub` / `apple_sub` |
| **Kullanıcı / profil** | Auth + yerel `ProfileService` | `GET/PATCH /api/me`, Postgres `users` |
| **İçerik listesi** | Asset JSON + `MotivationCacheService` + Firestore (`FirebaseService`) | `GET /api/daily-items` (mevcut) + isteğe bağlı `GET /api/v1/feed` (sayfalı); cache sadece istemci |
| **Yorumlar (UGC)** | `CommentService` → Firestore `daily_items/{id}/comments` | `GET/POST /api/v1/comments?itemId=` → Postgres `comments` |
| **Aksiyon / streak / rapor / engel** | Kısmen Go | Zaten Go (`/api/v1/actions`, …) |
| **Depolama (görsel)** | Muhtemelen Firebase Storage / mevcut akış | MinIO + mevcut `POST /api/storage/upload` |
| **Sunucu işleri** | `cloud_functions` (`manualSendDailyContent` vb.) | Go: cron veya admin endpoint + aynı iş mantığı |
| **Push** | FCM + topic, mesajda içerik | **Aşama 1:** Go, FCM HTTP v1 ile gönderir (servis hesabı JSON, Firebase projesi sadece FCM için). **Aşama 2:** iOS’ta doğrudan APNs; Android’de FCM veya alternatif. Firebase **Console’u** kapatabilirsiniz; FCM tamamen kesmek Android’i zorlar. |

---

## 2. Önerilen Sıra (Hepsini Go’da Yapmak)

### Faz 0 — Hazırlık
- [ ] Firestore koleksiyonlarını ve Function isimlerini listeleyin (tek sayfa doküman).
- [ ] `users` için harici kimlik: `google_sub`, `apple_sub` (Firebase `firebase_uid` geçiş döneminde durabilir).
- [ ] Tek ortam: `docker compose` + `go run ./cmd/server` + tek Postgres.

### Faz 1 — UGC: Yorumlar (Firestore → Postgres)
- [ ] Migration: `comments` tablosu.
- [ ] Go: `GET/POST /api/v1/comments` (JWT zorunlu).
- [ ] Flutter: `CommentService` önce Go’yu çağırsın; Firestore’u feature flag ile kapatın.
- [ ] Tek seferlik script: Firestore yorumlarını Postgres’e import.

### Faz 2 — Kimlik: Apple + Google OAuth (Go JWT) ✅ uygulandı
- [x] Go: `POST /api/auth/oauth/google`, `POST /api/auth/oauth/apple` — JWT + Postgres `google_sub` / `apple_sub`.
- [x] Flutter: `firebase_auth` kaldırıldı; `google_sign_in` + `sign_in_with_apple` → Go.
- [ ] İsteğe bağlı: `POST /api/auth/token` (Firebase) kaldırma — tam Firebase kapatmadan önce.

### Faz 3 — İçerik: Tek kaynak Go API ✅
- [x] `ContentSyncService` + `GET /api/daily-items` → yerel cache; uygulama açılışı, Anasayfa/Keşfet yenilemede senkron.
- [x] FCM `DAILY_WIDGET`: tam metin `GET /api/daily-items/:id` ile; Firestore `daily_items` okuması kaldırıldı.
- [x] `cloud_firestore` bağımlılığı Flutter’dan kaldırıldı (diğer Firebase paketleri kalabilir).

### Faz 4 — Cloud Functions → Go
- [ ] `manualSendDailyContent` vb. fonksiyonların yaptığı işi Go handler veya zamanlanmış job yapar.
- [ ] `cloud_functions` bağımlılığı Flutter’dan silinir.

### Faz 5 — Bildirim (özel durum)
- [ ] Go: “günlük içerik gönder” job → FCM HTTP v1 **veya** APNs (iOS).
- [ ] Cihaz token’larını Postgres’te saklayın (`device_tokens`: platform, token, user_id).
- [ ] FCM’yi tamamen bırakmak istenirse: iOS APNs zorunlu; Android için ayrı strateji.

### Faz 6 — Firebase projesini kapatma
- [ ] İstemcide `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions` kaldırıldı mı?
- [ ] Push kararı uygulandı mı?
- [ ] Son veri doğrulama + yedek.

---

## 3. Bu Repoda Başlanan İş (Faz 1)

- `pkg/migrate/migrations/000003_comments.up.sql` — `comments` tablosu.
- `internal/comments` — `GET /api/v1/comments?itemId=`, `POST /api/v1/comments` (JWT).
- Flutter: `ApiConfig.useGoComments` — `--dart-define=USE_GO_COMMENTS=true` ile Go’ya geçiş (varsayılan `false`, Firestore).
- Sonraki büyük kod adımı: **Faz 2 OAuth** (Firebase token endpoint’i devreden çıkarılır).

---

## 4. Özet

- **Evet:** Giriş, profil, içerik, yorumlar, sunucu işleri ve bildirim mantığı Go tarafında toplanacak şekilde planlandı.
- **Bildirim:** “Firebase’siz” ile “FCM’siz” farklı; Android için genelde FCM veya eşdeğeri kalır. İsterseniz önce FCM’yi **sadece Go’nun tetiklediği** servis olarak kullanıp Console’daki diğer kullanımı kademeli kapatırsınız.
