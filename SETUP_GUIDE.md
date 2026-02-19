# Kurulum ve Yapılandırma Rehberi

Bu dokümantasyon, günlük içerik bildirim sistemi ve widget'ların kurulumu için adım adım talimatlar içerir.

## 📋 İçindekiler

1. [Firebase Kurulumu](#firebase-kurulumu)
2. [Flutter Bağımlılıkları](#flutter-bağımlılıkları)
3. [iOS Yapılandırması](#ios-yapılandırması)
4. [Android Yapılandırması](#android-yapılandırması)
5. [Firestore Veri Modeli](#firestore-veri-modeli)
6. [Test Planı](#test-planı)

---

## 🔥 Firebase Kurulumu

### 1. Firebase Projesi Oluşturma

1. [Firebase Console](https://console.firebase.google.com/)'a gidin
2. Yeni proje oluşturun veya mevcut projeyi seçin
3. Projeye Flutter uygulaması ekleyin:
   - iOS: Bundle ID: `com.siyazilim.periodicallynotification`
   - Android: Package name: `com.siyazilim.periodicallynotification`

### 2. Firebase Dosyalarını İndirme

**iOS:**
- `GoogleService-Info.plist` dosyasını indirin
- `ios/Runner/` klasörüne kopyalayın

**Android:**
- `google-services.json` dosyasını indirin
- `android/app/` klasörüne kopyalayın

### 3. Cloud Functions Kurulumu

```bash
cd functions
npm install
```

### 4. Cloud Functions Deployment

```bash
# Firebase CLI'yi yükleyin (eğer yoksa)
npm install -g firebase-tools

# Firebase'e giriş yapın
firebase login

# Projeyi başlatın
firebase init

# Functions'ı deploy edin
firebase deploy --only functions
```

### 5. Firestore Index Oluşturma

Firebase Console > Firestore > Indexes bölümüne gidin ve `firestore.indexes.json` dosyasındaki index'i oluşturun.

### 6. FCM Topic Oluşturma

Firebase Console > Cloud Messaging bölümünde topic oluşturmanıza gerek yok, kod otomatik oluşturacak. Ancak test için manuel topic oluşturabilirsiniz: `daily_widget_all`

---

## 📦 Flutter Bağımlılıkları

```bash
flutter pub get
```

Bağımlılıklar:
- `firebase_core: ^3.6.0`
- `firebase_messaging: ^15.1.3`
- `cloud_firestore: ^5.4.4`
- `home_widget: ^0.5.1`
- `shared_preferences: ^2.3.2`

---

## 🍎 iOS Yapılandırması

### 1. App Group Ayarları

1. Xcode'da projeyi açın: `ios/Runner.xcworkspace`
2. Runner target'ını seçin
3. **Signing & Capabilities** sekmesine gidin
4. **+ Capability** butonuna tıklayın
5. **App Groups** ekleyin
6. App Group ID: `group.com.siyazilim.periodicallynotification`
7. Bu ID'yi hem Runner hem de DailyWidget extension için ekleyin

### 2. Widget Extension Oluşturma

1. Xcode'da **File > New > Target** seçin
2. **Widget Extension** seçin
3. Product Name: `DailyWidget`
4. Language: **Swift**
5. Include Configuration Intent: **Hayır**
6. **Finish** butonuna tıklayın

### 3. Widget Extension Dosyalarını Kopyalama

Oluşturduğumuz dosyaları widget extension'a kopyalayın:
- `ios/DailyWidget/DailyWidget.swift` → Widget extension klasörüne
- `ios/DailyWidget/DailyWidgetBundle.swift` → Widget extension klasörüne

### 4. Widget Extension App Group Ayarları

1. DailyWidget target'ını seçin
2. **Signing & Capabilities** sekmesine gidin
3. **App Groups** ekleyin
4. Aynı App Group ID'yi ekleyin: `group.com.siyazilim.periodicallynotification`

### 5. APNs (Apple Push Notification Service) Yapılandırması

1. [Apple Developer Portal](https://developer.apple.com/account/)'a gidin
2. **Certificates, Identifiers & Profiles** bölümüne gidin
3. **Identifiers** > **App IDs** > Runner uygulamanızı seçin
4. **Push Notifications** özelliğini etkinleştirin
5. **Certificates** bölümünden APNs sertifikası oluşturun
6. Firebase Console > Project Settings > Cloud Messaging > iOS'e sertifikayı yükleyin

### 6. Info.plist Güncellemeleri

`ios/Runner/Info.plist` dosyasına ekleyin:

```xml
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

### 7. Podfile Güncellemesi

`ios/Podfile` dosyasının en üstüne ekleyin:

```ruby
platform :ios, '14.0'
```

Sonra:

```bash
cd ios
pod install
```

---

## 🤖 Android Yapılandırması

### 1. google-services.json Kontrolü

`android/app/google-services.json` dosyasının mevcut olduğundan emin olun.

### 2. build.gradle Güncellemeleri

`android/build.gradle` dosyasına ekleyin:

```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

`android/app/build.gradle` dosyasının en altına ekleyin:

```gradle
apply plugin: 'com.google.gms.google-services'
```

### 3. minSdkVersion Kontrolü

`android/app/build.gradle.kts` dosyasında minimum SDK 21 olmalı:

```kotlin
minSdk = 21  // veya flutter.minSdkVersion (eğer 21+ ise)
```

### 4. Notification Channel

Notification channel otomatik olarak `MainActivity.kt` içinde oluşturuluyor. Ek bir işlem gerekmez.

### 5. FCM Server Key

Firebase Console > Project Settings > Cloud Messaging > Server key'i not edin (Cloud Functions için gerekli değil, topic kullanıyoruz).

---

## 🗄️ Firestore Veri Modeli

### 1. İlk Veri Yapısını Oluşturma

Firebase Console > Firestore Database bölümüne gidin ve şu koleksiyonları oluşturun:

#### `daily_items` Collection

```javascript
// Örnek doküman
{
  order: 1,
  title: "Bugünün İçeriği",
  body: "Bu günlük içerik metnidir. Kullanıcılar bu içeriği widget'ta görecek.",
  sent: false,
  sentAt: null
}
```

#### `daily_state/current` Document

```javascript
{
  nextOrder: 1,
  lastSentAt: null,
  lastSentItemId: null
}
```

### 2. Örnek Veri Ekleme

Firebase Console'dan veya Cloud Functions ile:

```javascript
// daily_items koleksiyonuna 3 örnek içerik ekleyin
db.collection('daily_items').add({
  order: 1,
  title: "İlk Günlük İçerik",
  body: "Bu ilk günlük içerik metnidir.",
  sent: false
});

db.collection('daily_items').add({
  order: 2,
  title: "İkinci Günlük İçerik",
  body: "Bu ikinci günlük içerik metnidir.",
  sent: false
});

db.collection('daily_items').add({
  order: 3,
  title: "Üçüncü Günlük İçerik",
  body: "Bu üçüncü günlük içerik metnidir.",
  sent: false
});
```

### 3. Firestore Rules

`firestore.rules` dosyası zaten hazır. Deploy edin:

```bash
firebase deploy --only firestore:rules
```

---

## 🧪 Test Planı

### 1. Manuel Test (Cloud Function)

Firebase Console > Functions bölümünden `manualSendDailyContent` fonksiyonunu çağırın veya:

```bash
# Firebase CLI ile
firebase functions:shell
> manualSendDailyContent()
```

### 2. Flutter Uygulaması Testi

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android
```

**Kontrol Listesi:**
- [ ] Uygulama açıldığında FCM token alınıyor mu?
- [ ] Topic'e subscribe olunuyor mu? (`daily_widget_all`)
- [ ] Bildirim geldiğinde widget güncelleniyor mu?
- [ ] Bildirime dokununca uygulama açılıyor mu?

### 3. Widget Testi

**iOS:**
1. Uygulamayı çalıştırın
2. Ana ekrana gidin
3. Widget ekleme moduna girin (uzun basın)
4. DailyWidget'ı ekleyin
5. Bildirim gönderin ve widget'ın güncellenip güncellenmediğini kontrol edin

**Android:**
1. Uygulamayı çalıştırın
2. Ana ekrana gidin
3. Widget ekleme moduna girin (uzun basın)
4. DailyWidget'ı ekleyin
5. Bildirim gönderin ve widget'ın güncellenip güncellenmediğini kontrol edin

### 4. Scheduled Function Testi

Scheduled function'ı test etmek için:

1. Firebase Console > Functions > `sendDailyWidgetContent` fonksiyonunu seçin
2. **Testing** sekmesine gidin
3. Manuel olarak tetikleyin veya gerçek zamanı bekleyin

**Not:** Scheduled function'ın çalışması için:
- Cron: `0 9 * * *` (Her gün 09:00 UTC = 12:00 Europe/Istanbul)
- Timezone: `Europe/Istanbul`

### 5. End-to-End Test Senaryosu

1. **Firestore'a 3 içerik ekleyin:**
   - order: 1, sent: false
   - order: 2, sent: false
   - order: 3, sent: false

2. **daily_state/current'ı ayarlayın:**
   - nextOrder: 1

3. **Manuel gönderim yapın:**
   - `manualSendDailyContent()` fonksiyonunu çağırın

4. **Kontrol edin:**
   - [ ] İlk içerik gönderildi mi?
   - [ ] daily_state/current.nextOrder = 2 oldu mu?
   - [ ] daily_items/.../sent = true oldu mu?
   - [ ] Bildirim geldi mi?
   - [ ] Widget güncellendi mi?

5. **İkinci gönderim:**
   - Tekrar `manualSendDailyContent()` çağırın
   - İkinci içerik gönderilmeli

---

## 🔧 Sorun Giderme

### iOS Widget Güncellenmiyor

1. App Group ID'lerin eşleştiğinden emin olun
2. Widget extension'ın App Group capability'si olduğunu kontrol edin
3. Xcode'da widget'ı yeniden build edin

### Android Widget Güncellenmiyor

1. SharedPreferences key'lerinin doğru olduğundan emin olun
2. Widget provider'ın manifest'te kayıtlı olduğunu kontrol edin
3. Uygulamayı yeniden başlatın

### FCM Bildirimleri Gelmiyor

1. FCM token'ın alındığını kontrol edin (log'larda)
2. Topic'e subscribe olunduğunu kontrol edin
3. APNs sertifikasının Firebase'e yüklendiğini kontrol edin (iOS)
4. `google-services.json` dosyasının doğru olduğunu kontrol edin (Android)

### Cloud Function Çalışmıyor

1. Firebase Console > Functions > Logs bölümünden hataları kontrol edin
2. Firestore index'lerinin oluşturulduğunu kontrol edin
3. FCM topic'in mevcut olduğunu kontrol edin

---

## 📝 Notlar

- **Dil Desteği:** İleride `daily_widget_tr` ve `daily_widget_en` topic'leri oluşturulabilir
- **Saat Ayarı:** Scheduled function'ın saatini değiştirmek için `functions/index.js` dosyasındaki cron ifadesini güncelleyin
- **Widget Tasarımı:** iOS ve Android widget tasarımlarını `ios/DailyWidget/DailyWidget.swift` ve `android/app/src/main/res/layout/daily_widget.xml` dosyalarından özelleştirebilirsiniz

---

## 🚀 Deployment

### Production Deployment

1. **Firebase Functions:**
   ```bash
   firebase deploy --only functions
   ```

2. **Firestore Rules:**
   ```bash
   firebase deploy --only firestore:rules
   ```

3. **Flutter App:**
   ```bash
   # iOS
   flutter build ios --release
   
   # Android
   flutter build apk --release
   # veya
   flutter build appbundle --release
   ```

---

## 📞 Destek

Sorun yaşarsanız:
1. Log'ları kontrol edin
2. Firebase Console'dan function log'larını inceleyin
3. Flutter debug console'u kontrol edin


