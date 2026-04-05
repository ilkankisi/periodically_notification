# Implementation Checklist — Apple 4.2 Uyumlu Uygulama

**Amaç:** Plandaki tüm özellikleri uygulayıp App Store'a gönderime hazır hale getirmek.

---

## 1) Implementation Checklist (Uygulama Kontrol Listesi)

### Backend (Go + Postgres)

| # | Görev | Durum |
|---|-------|-------|
| B1 | Go projesi scaffold (main, router, middleware) | ✅ |
| B2 | Postgres bağlantısı + migration (users, quotes, actions, user_day_cache, streak_cache, reports, blocks) | ✅ |
| B3 | Firebase ID token doğrulama → JWT exchange (POST /api/auth/token) | ✅ |
| B4 | POST /api/v1/actions (Idempotency-Key header, X-Consent-Sync) | ✅ |
| B5 | GET /api/v1/actions/daily (?date=YYYY-MM-DD) | ✅ |
| B6 | GET /api/v1/progress (streak + last7Days) | ✅ |
| B7 | GET/POST /v1/comments (Firestore'da kalıyor) | ⬜ |
| B8 | POST /api/v1/reports (commentId, quoteId, reason, details) | ✅ |
| B9 | POST /api/v1/blocks, DELETE /api/v1/blocks/:userId (Firebase UID destekli) | ✅ |
| B10 | DELETE /api/v1/account (soft delete) | ✅ |
| B11 | quotes tablosu + external_id (Firestore mirror) | ✅ |
| B12 | Rate limiting (429 + Retry-After) | ⬜ |

### Flutter — Core (Guest Mode + Aksiyon)

| # | Görev | Durum |
|---|-------|-------|
| F1 | AddActionCard widget ("Bugün bu sözle ne yaptın?" + input + Aksiyon Ekle) | ⬜ |
| F2 | ContentDetailPage'e AddActionCard ekleme (söze dokunduktan sonra) | ⬜ |
| F3 | Opt-in sync dialog (Evet/Hayır) — söze dokunduğu anda; VoiceOver etiketleri; kontrast ≥4.5:1 | ⬜ |
| F4 | Lokal aksiyon storage (SharedPreferences / JSON) — Guest mode, sunucuya user açılmaz | ⬜ |
| F5 | Offline queue + ActionSyncService (idempotency key header'da) | ⬜ |
| F6 | Lokal streak hesaplama (guest için) | ⬜ |

### Flutter — Ekranlar

| # | Görev | Durum |
|---|-------|-------|
| F7 | DailyActionsPage (Günlük Aksiyonlar) — bugünün listesi; boş state: motive edici CTA | ⬜ |
| F8 | ProgressStreakPage (Current/Best streak + 7/30 gün grid) — boş state: "İlk aksiyonunu ekle" CTA | ⬜ |
| F9 | SupportContactPage ("Bize Ulaşın" — e-posta/form) | ⬜ |
| F10 | LinkedAccountsPage (Bağlı hesaplar — Google unlink, Apple revoke) | ⬜ |
| F11 | Profil'e "Günlük Aksiyonlar", "Progress & Streak", "Destek", "Bağlı hesaplar", "Hesap silme" linkleri | ⬜ |

### Flutter — Yorumlar + UGC

| # | Görev | Durum |
|---|-------|-------|
| F12 | CommentTile'da "Raporla" ve "Engelle" butonları | ⬜ |
| F13 | ReportReasonSheet (spam, abuse, inappropriate, other) | ⬜ |
| F14 | Block sonrası engellenen kullanıcının yorumları gizleme | ⬜ |

### Flutter — Diğer

| # | Görev | Durum |
|---|-------|-------|
| F15 | Hesap silme akışı (Profil → Hesap silme → onay → DELETE /v1/account) | ⬜ |
| F16 | iPad empty-state (Daily, Progress) — motive edici metin/CTA | ⬜ |
| F17 | Lokalizasyon (onay metni, butonlar — tüm desteklenen diller) | ⬜ |

---

## 2) Eksik Flutter UI Özeti

| Ekran/Widget | Durum | Açıklama |
|-------------|-------|----------|
| **AddActionCard** | ❌ Yok | Quote detayda "Bugün bu sözle ne yaptın?" kartı |
| **Opt-in Sync Dialog** | ❌ Yok | Evet/Hayır; söze dokunduğu anda açılmalı |
| **DailyActionsPage** | ❌ Yok | Günlük aksiyon listesi ekranı |
| **ProgressStreakPage** | ❌ Yok | Streak + 7/30 gün grid |
| **SupportContactPage** | ❌ Yok | "Bize Ulaşın" / Destek |
| **LinkedAccountsPage** | ❌ Yok | Bağlı hesaplar (credential revoke) |
| **Raporla/Engelle** | ❌ Yok | Yorum satırında Report + Block UI |
| **ReportReasonSheet** | ❌ Yok | Rapor nedeni seçim bottom sheet |
| **Hesap silme** | ❌ Yok | Profil'de hesap silme akışı |
| **Profil linkleri** | ⚠️ Kısmi | Günlük Aksiyonlar, Progress, Destek, Bağlı hesaplar, Hesap silme eksik |

---

## 3) Backend tek kaynak

REST API **`backendGo`** içinde (ör. `~/Desktop/backendGo`, modül `periodically/backend`). Bu Flutter repodaki yedek Go sunucusu kaldırıldı; uçların güncel listesi için `backendGo/README.md` ve `internal/server/routes.go` kullanılmalı. Flutter tarafında yalnızca `API_BASE_URL` bu sunucuyu göstermeli.

İçerik bildirimi: `POST /api/admin/daily-send` (bkz. `backendGo`, `ADMIN_SECRET`, `FCM_*` env).

---

## 4) Submit-Ready Checklist (Gönderime Hazır)

Aşağıdakilerin **hepsi** evet ise uygulama App Store'a gönderilebilir:

### Ön Koşullar

- [ ] **Lokalizasyon:** Son çeviriler onaylandı mı? (onay metni, Evet/Hayır, tüm UI)
- [ ] **Diyalog Zamanlaması:** Söze dokunduğu anda opt-in diyalog açılıyor mu?
- [ ] **Idempotency:** Aynı anahtarla duplicate kayıt yok mu?
- [ ] **Review Notes:** Talimatlar güncel mi? (7 adım + demo hesap)
- [ ] **Linkler:** "Bize Ulaşın" ve destek URL'leri tutarlı ve çalışıyor mu?
- [ ] **Demo Hesap:** [testhesap@ornek.com / DemoPass2026!] ile tüm akışlar test edildi mi?
- [ ] **Hata Yönetimi:** Backend'de fmt.Errorf / uygun hata dönüşü; uygulama çökmüyor mu?

### 10 Adımlı Test (Her Biri Geçmeli)

1. [ ] Çeviri kontrolü — tüm metinler doğru ve tutarlı
2. [ ] Onay (Evet) — aksiyon sunucuya gönderilip Profil'da listeleniyor
3. [ ] Onay (Hayır) — aksiyonlar telefonda kalıyor, silinmiyor
4. [ ] Yorum ekleme — yorum görünüyor, Raporla/Engelle çalışıyor
5. [ ] Aksiyon senkron — offline→online idempotency, duplicate yok
6. [ ] Boş ekran CTA — iPad'de motive edici mesaj/simge
7. [ ] Offline testleri — uçak modunda aksiyon, online olunca senkron
8. [ ] Ağ kesintisi — uygulama kararlı, retry mekanizması
9. [ ] Apple kimlik kesme — Stop Using sonrası çıkış, tekrar giriş
10. [ ] Destek linkleri — Bize Ulaşın ve Ayarlar→Destek açılıyor

### App Store Connect

- [ ] Demo hesap App Review Notes'a yazıldı
- [ ] 7 adımlı test talimatı (Türkçe) kopyalandı
- [ ] Privacy Policy URL geçerli
- [ ] Support URL geçerli

### Risk–Mitigasyon

- [ ] Lokalizasyon — uzman ekiple son kontrol
- [ ] Destek/Gizlilik — Bize Ulaşın + App Store URL tutarlı
- [ ] Yazılım — hata yönetimi düzgün (panik yok)

---

*Bu belge uygulama tamamlandıkça işaretlenebilir. Revizyon değil, uygulama odaklıdır.*
