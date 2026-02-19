# iOS Home Widget Kurulum Rehberi

Widget "Günün İçeriği" ve "İçerik yükleniyor..." gösteriyorsa, App Group erişimi sorunludur. Aşağıdaki adımları **sırayla** uygulayın.

## 1. Xcode'da App Group Kontrolü

### Runner (Ana Uygulama)
1. Xcode'da projeyi açın: `ios/Runner.xcodeproj`
2. Sol panelden **Runner** target'ını seçin
3. **Signing & Capabilities** sekmesine gidin
4. **App Groups** capability'si ekli mi kontrol edin
5. Yoksa **+ Capability** → **App Groups** ekleyin
6. `group.com.siyazilim.periodicallynotification` listelenmeli

### DailyWidgetExtension
1. Sol panelden **DailyWidgetExtension** target'ını seçin
2. **Signing & Capabilities** sekmesine gidin
3. **App Groups** capability'si ekli mi kontrol edin
4. Yoksa **+ Capability** → **App Groups** ekleyin
5. **Aynı** grup eklenmeli: `group.com.siyazilim.periodicallynotification`

## 2. Apple Developer Portal

1. [developer.apple.com](https://developer.apple.com) → **Certificates, Identifiers & Profiles**
2. **Identifiers** → **App IDs** bölümüne gidin

### Ana uygulama App ID
- `com.siyazilim.periodicallynotification` bulun
- **Edit** → **App Groups** kısmına bakın
- `group.com.siyazilim.periodicallynotification` işaretli olmalı
- Değilse işaretleyip kaydedin

### Widget extension App ID
- `com.siyazilim.periodicallynotification.DailyWidget` bulun
- **Edit** → **App Groups** kısmına bakın
- **Aynı** grup işaretli olmalı: `group.com.siyazilim.periodicallynotification`
- Değilse işaretleyip kaydedin

### App Group oluşturma (yoksa)
- **Identifiers** → **App Groups** → **+** ile yeni ekle
- Identifier: `group.com.siyazilim.periodicallynotification`
- Description: `Periodically Notification Shared`

## 3. Provisioning Profilleri Yenile

Developer Portal'da App ID'leri güncelledikten sonra:

1. **Profiles** bölümüne gidin
2. Runner ve DailyWidgetExtension için kullanılan profilleri bulun
3. **Edit** → **Regenerate** ile yenileyin
4. Yeni profilleri indirin (Xcode genelde otomatik çeker)

## 4. Temiz Build

```bash
cd ios
rm -rf build
xcodebuild clean
cd ..
flutter clean
flutter pub get
flutter run
```

## 5. Gerçek Cihazda Test

**Önemli:** Simülatörde widget extension ile App Group bazen farklı container kullanır. Mutlaka **gerçek iPhone** ile deneyin.

## 6. Widget'ı Yeniden Ekleme

1. Ana ekranda widget'a uzun basın → **Widget'ı Kaldır**
2. Uygulamayı tamamen kapatın (arka plandan silin)
3. Uygulamayı yeniden açın
4. Bir bildirim tetikleyin (veya "Test Gönder" ile)
5. Ana ekrana widget'ı tekrar ekleyin

## Entitlements Dosyaları

- **Runner**: `ios/Runner/Runner.entitlements` (aps-environment + App Groups)
- **Widget Extension**: `ios/DailyWidget/DailyWidget.entitlements` (sadece App Groups)

Her iki dosyada da `group.com.siyazilim.periodicallynotification` olmalı.
