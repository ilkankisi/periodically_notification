# Periodically Notification - Günlük İçerik Bildirim Sistemi

Firestore'da elle girilen günlük içerikleri, her gün belirli saatte (Europe/Istanbul) tüm kullanıcılara ulaştıran ve iOS + Android home screen widget'lerinde gösteren Flutter uygulaması.

## 🎯 Özellikler

- ✅ **Scheduled Cloud Functions**: Her gün belirli saatte otomatik içerik gönderimi
- ✅ **FCM Topic Notifications**: Tüm kullanıcılara görünür bildirimler
- ✅ **iOS WidgetKit**: Home screen widget desteği
- ✅ **Android Widget**: Home screen widget desteği
- ✅ **Firestore Integration**: İçerik yönetimi ve queue sistemi
- ✅ **Guaranteed Delivery**: Görünür bildirimlerle kesin ulaşma garantisi

## 📋 Gereksinimler

- Flutter SDK 3.8.1+
- Firebase Projesi
- iOS 14.0+ (Widget için)
- Android API 21+ (Widget için)
- Node.js 20+ (Cloud Functions için)

## 🚀 Hızlı Başlangıç

### 1. Firebase Kurulumu

1. [Firebase Console](https://console.firebase.google.com/)'da proje oluşturun
2. iOS ve Android uygulamalarını ekleyin
3. `GoogleService-Info.plist` (iOS) ve `google-services.json` (Android) dosyalarını indirin
4. Dosyaları projeye ekleyin:
   - `ios/Runner/GoogleService-Info.plist`
   - `android/app/google-services.json`

### 2. Flutter Bağımlılıkları

```bash
flutter pub get
```

### 3. Cloud Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

### 4. Firestore Veri Modeli

Firebase Console > Firestore'da şu yapıyı oluşturun:

**`daily_items` Collection:**
```json
{
  "order": 1,
  "title": "Günün İçeriği",
  "body": "İçerik metni burada...",
  "sent": false,
  "sentAt": null
}
```

**`daily_state/current` Document:**
```json
{
  "nextOrder": 1,
  "lastSentAt": null,
  "lastSentItemId": null
}
```

### 5. iOS Widget Extension

1. Xcode'da `ios/Runner.xcworkspace` açın
2. File > New > Target > Widget Extension
3. Product Name: `DailyWidget`
4. `ios/DailyWidget/` klasöründeki Swift dosyalarını extension'a kopyalayın
5. App Group ayarlarını yapın: `group.com.siyazilim.periodicallynotification`

### 6. Çalıştırma

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android
```

## 📚 Dokümantasyon

- **[SETUP_GUIDE.md](SETUP_GUIDE.md)**: Detaylı kurulum rehberi
- **[TEST_PLAN.md](TEST_PLAN.md)**: Test senaryoları ve kontrol listesi

## 🏗️ Mimari

### Veri Akışı

1. **Firestore**: Elle girilen günlük içerikler (`daily_items`)
2. **Cloud Function**: Scheduled function her gün saat 09:00 (Europe/Istanbul) çalışır
3. **FCM Topic**: `daily_widget_all` topic'ine bildirim gönderilir
4. **Flutter App**: FCM mesajını alır, `home_widget` ile shared storage'a yazar
5. **Widget**: Shared storage'dan veriyi okur ve gösterir

### Güvenilirlik

- **Kesin ulaşma**: Görünür FCM bildirimleri (notification payload)
- **Best-effort**: Widget otomatik güncellemesi (data-only payload)
- **Fallback**: Bildirime dokununca uygulama açılır ve widget güncellenir

## 🔧 Yapılandırma

### Scheduled Function Saati

`functions/index.js` dosyasında:

```javascript
schedule: "0 9 * * *", // 9:00 AM UTC = 12:00 PM Europe/Istanbul
timeZone: "Europe/Istanbul",
```

### FCM Topic

Varsayılan topic: `daily_widget_all`

İleride dil desteği için:
- `daily_widget_tr`
- `daily_widget_en`

## 📱 Widget Özelleştirme

### iOS Widget

`ios/DailyWidget/DailyWidget.swift` dosyasını düzenleyin.

### Android Widget

- Layout: `android/app/src/main/res/layout/daily_widget.xml`
- Provider: `android/app/src/main/kotlin/.../widget/DailyWidgetProvider.kt`

## 🧪 Test

Detaylı test planı için [TEST_PLAN.md](TEST_PLAN.md) dosyasına bakın.

Manuel test için:

```bash
# Firebase Console > Functions > manualSendDailyContent
# veya Firebase CLI:
firebase functions:shell
> manualSendDailyContent()
```

## 📝 Notlar

- Widget güncellemeleri iOS ve Android tarafından garanti edilmez
- Bu yüzden görünür bildirimler zorunludur
- Widget güncellemesi best-effort olarak çalışır
- Bildirime dokununca uygulama açılır ve widget kesin güncellenir

## 🐛 Sorun Giderme

### Widget Güncellenmiyor

1. App Group ID'lerin eşleştiğinden emin olun (iOS)
2. SharedPreferences key'lerinin doğru olduğunu kontrol edin (Android)
3. Widget'ı yeniden ekleyin

### Bildirimler Gelmiyor

1. FCM token'ın alındığını kontrol edin
2. Topic'e subscribe olunduğunu kontrol edin
3. APNs sertifikasının yüklendiğini kontrol edin (iOS)

### Cloud Function Çalışmıyor

1. Firebase Console > Functions > Logs
2. Firestore index'lerinin oluşturulduğunu kontrol edin
3. Cron ifadesinin doğru olduğunu kontrol edin

## 📄 Lisans

Bu proje özel bir projedir.

## 👥 Katkıda Bulunanlar

- Geliştirici: [Sizin Adınız]

---

**Not**: Bu proje production'a geçmeden önce güvenlik ayarlarını (Firestore rules, authentication) gözden geçirin.
