# Giriş (Apple & Google) Kurulum Rehberi

Bu rehber, Apple ve Google ile giriş özelliğinin çalışması için gerekli yapılandırmaları açıklar.

## 1. Firebase Console

1. [Firebase Console](https://console.firebase.google.com/) → Projeniz → **Authentication**
2. **Sign-in method** sekmesinde:
   - **Google**: Etkinleştirin, e-posta ve proje adını kaydedin
   - **Apple**: Etkinleştirin

## 2. Apple Developer Portal (Sign in with Apple)

1. [Apple Developer](https://developer.apple.com/account/) → **Certificates, Identifiers & Profiles** → **Identifiers**
2. Uygulama Bundle ID'nizi seçin (`com.siyazilim.periodicallynotification`)
3. **Sign in with Apple** özelliğini işaretleyin ve kaydedin
4. Xcode'da: Proje → **Signing & Capabilities** → **+ Capability** → **Sign in with Apple** ekleyin (entitlements dosyası zaten güncellendi)

## 3. Google Sign In - iOS

Google Sign In için `GIDClientID` ve URL scheme (`CFBundleURLTypes`) `Info.plist` içinde tanımlanmalıdır. Bu ayarlar yapılmazsa **"No active configuration. Make sure GIDClientID is set in Info.plist"** hatası alırsınız.

### Yöntem A: Firebase'den Güncel GoogleService-Info.plist İndir (Önerilen)

1. [Firebase Console](https://console.firebase.google.com/) → Projeniz → **Authentication** → **Sign-in method** → **Google** → Etkinleştirin (henüz etkin değilse)
2. **Proje Ayarları** (dişli ikonu) → **Genel** → **Uygulamalar** bölümünde iOS uygulamanızı seçin
3. **GoogleService-Info.plist** dosyasını indirin ve `ios/` klasöründeki mevcut dosyanın üzerine kopyalayın
4. İndirilen dosyada **CLIENT_ID** ve **REVERSED_CLIENT_ID** anahtarları olmalı. Yoksa Yöntem B'ye geçin
5. `ios/Runner/Info.plist` dosyasında `GIDClientID` ve `REVERSED_CLIENT_ID` placeholder'larını bu değerlerle değiştirin:
   - `IOS_CLIENT_ID` → GoogleService-Info.plist'teki `CLIENT_ID` değeri
   - `REVERSED_CLIENT_ID` → GoogleService-Info.plist'teki `REVERSED_CLIENT_ID` değeri

### Yöntem B: Google Cloud Console'dan Manuel Oluşturma

1. [Google Cloud Console](https://console.cloud.google.com/) → **APIs & Services** → **Credentials**
2. **+ CREATE CREDENTIALS** → **OAuth client ID**
3. Application type: **iOS**, Bundle ID: `com.siyazilim.periodicallynotification`
4. **Client ID**'yi kopyalayın (örn: `596975805185-xxxxxxxx.apps.googleusercontent.com`)
5. **Reversed Client ID** oluşturun: `596975805185-xxxxxxxx.apps.googleusercontent.com` → `com.googleusercontent.apps.596975805185-xxxxxxxx`
6. `ios/Runner/Info.plist` içinde:
   - `GIDClientID` anahtarının değerini Client ID ile değiştirin
   - `CFBundleURLSchemes` içindeki string'i Reversed Client ID ile değiştirin

## 4. Google Sign In - Android

1. Firebase Console'da Android uygulaması ekli olmalı (SHA-1 fingerprint ile)
2. `google-services.json` dosyası `android/app/` içinde olmalı
3. Google Sign In genelde ek yapılandırma gerektirmez

## 5. Sorun Giderme: "No active configuration. Make sure GIDClientID is set in Info.plist"

Bu hata, Google Sign In SDK'nın `GIDClientID` ve URL scheme değerlerini bulamadığı anlamına gelir. Çözüm:

1. `ios/Runner/Info.plist` dosyasında `GIDClientID` ve `CFBundleURLTypes` → `CFBundleURLSchemes` değerlerinin **placeholder değil**, gerçek değerlerle doldurulduğundan emin olun
2. Yukarıdaki **Bölüm 3** adımlarını takip ederek Firebase veya Google Cloud Console'dan değerleri alın ve yapıştırın
3. Uygulamayı **temiz build** ile yeniden çalıştırın: `flutter clean && flutter pub get`, ardından Xcode'dan Run

## 6. Test

- **Profil** sekmesinde "Giriş Yap" butonuna tıklayın
- Apple ile Giriş Yap (iOS'ta)
- Google ile Giriş Yap
- Giriş sonrası profil bilgileriniz ve "Çıkış Yap" görünmeli
