# Periodically — DAHA (Flutter)

Günlük motivasyon içeriğini **Go + PostgreSQL** API’sinden ve (iOS’ta) **APNs** ile alan; ana ekran widget’ı olan Flutter uygulaması.

Bu repoda **Firestore, Cloud Functions, `firebase.json` veya security rules dosyaları yok.** Veri ve zamanlanmış gönderim **`~/Desktop/backendGo`** üzerindedir.

## Özellikler

- Go REST API: içerik listesi, OAuth, yorumlar, senkron
- iOS: doğrudan APNs (Firebase Messaging yok)
- Android: uzak push yok (widget/asset ile çalışmaya devam eder)
- iOS + Android home screen widget

## Gereksinimler

- Flutter SDK 3.8.1+
- **Backend:** [backendGo](../backendGo) — PostgreSQL, MinIO, ortam değişkenleri (`backendGo/README.md`)
- iOS: Xcode, Push capability, APNs anahtarı (sunucu tarafında)
- iOS 14+ / Android API 23+ (widget hedeflerine göre)

## Hızlı başlangıç

```bash
# Backend’i çalıştırın (ayrı repo/klasör)
cd ~/Desktop/backendGo && go run ./cmd/server

# Uygulama — API adresi
cd periodically_notification
flutter pub get
flutter run --dart-define=API_BASE_URL=http://SUNUCU:8080
```

Günlük push tetikleme (örnek):

```bash
curl -X POST "http://SUNUCU:8080/api/admin/daily-send" \
  -H "X-Admin-Secret: $ADMIN_SECRET"
```

İçerik / JSON / MinIO betikleri: **`backendGo/README.md`** → *Veri ve görsel araçları (CLI)*.

### iOS widget

1. `ios/Runner.xcworkspace`
2. App Group: `group.com.siyazilim.periodicallynotification`
3. `ios/DailyWidget/` extension

### Android widget

- `android/app/src/main/kotlin/.../widget/DailyWidgetProvider.kt`
- Layout: `android/app/src/main/res/layout/daily_widget.xml`

## Dokümantasyon

- [backendGo/README.md](../backendGo/README.md) — API, APNs, migration, CLI
- [docs/FLUTTER_BACKEND_INTEGRATION.md](docs/FLUTTER_BACKEND_INTEGRATION.md)
- [SETUP_GUIDE.md](SETUP_GUIDE.md) — **kısmen güncellenmemiş geçmiş adımlar içerebilir;** kaynak olarak backendGo README önceliklidir.
- [TEST_PLAN.md](TEST_PLAN.md), [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)

## Mimari (özet)

1. **PostgreSQL** `daily_items` + `daily_state` — tek kaynak içerik
2. **`POST /api/admin/daily-send`** — sıradaki içerik + kayıtlı APNs jetonlarına bildirim
3. **Flutter** — mesajı işler, `home_widget` + yerel cache günceller
4. **Widget** — paylaşılan veriyi okur

## Sorun giderme

- **Widget güncellenmiyor:** iOS App Group, ana uygulama + extension aynı grup; widget’ı kaldırıp yeniden ekleyin.
- **Bildirim (iOS):** APNs .p8, `APNS_TOPIC` = bundle id, cihazda bildirim izni; sunucuda `apns_device_tokens` dolu mu kontrol edin.
- **İçerik boş:** `GET /api/daily-items` ve `motivations.json` / import script’leri (`backendGo`).

## Lisans

Özel proje.
