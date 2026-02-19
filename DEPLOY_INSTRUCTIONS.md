# Firebase Deploy ve Migration Talimatları

Bu dosya Firebase ve Veri Akışı Planı uygulaması için adım adım talimatlardır.

## 1. Cloud Functions Deploy

Proje kök dizininde:

```bash
cd functions
npm run deploy
```

veya:

```bash
firebase deploy --only functions
```

## 2. Firestore: `sent` Alanını Kaldırma

Önce `functions` klasöründe Firebase Admin bağlaması için service account gerekir. `firebase-admin` zaten `functions` içinde kurulu.

Migration script'i çalıştırmak için kimlik doğrulama gereklidir. **İki yol:**

**Yol A – Service Account Key (gcloud gerektirmez):**
1. [Firebase Console](https://console.firebase.google.com) > Proje Ayarları > Hizmet Hesapları
2. "Yeni özel anahtar oluştur" (Generate new private key)
3. İndirilen JSON dosyasını güvenli bir yere kaydedin
4. Terminalde:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/indirilen-dosya.json"
   cd functions
   npm run remove-sent
   ```

**Yol B – gcloud kullanarak:**
1. gcloud kurulumu (Homebrew ile):
   ```bash
   brew install --cask gcloud-cli
   ```
2. Google hesabınızla giriş yapın:
   ```bash
   gcloud auth application-default login
   ```
3. Script'i çalıştırın:
   ```bash
   cd functions
   npm run remove-sent
   ```

Alternatif: Firebase Console > Firestore > daily_items > her dokümanı açıp `sent` alanını elle sil.

## 3. Firestore: imageUrl Ekleme

**Script ile (önerilen):**

1. `functions/scripts/image-url-mapping.json` dosyasını düzenleyin: order -> filename eşlemesi (örn. `"1": "IMG_5234.jpg"`).
2. Çalıştırın:
   ```bash
   cd functions
   npm run add-imageurls
   ```

Script, Storage'dan signed URL alıp her daily_items dokümanına yazar.

## 4. Firestore İndex (Gerekirse)

`orderBy("order")` için Firestore hata verirse, Console'daki link ile indeksi oluşturun veya:

```bash
firebase deploy --only firestore:indexes
```

## 5. Test

1. Uygulamayı cihazda/simülatörde çalıştırın: `flutter run`
2. FCM topic'ine (`daily_widget_all`) subscribe olduğunu doğrulayın
3. `manualSendDailyContent` Cloud Function'ı Firebase Console > Functions üzerinden test edin veya bir HTTP client ile çağırın
4. Bildirim geldiğinde anasayfada "Günün İçeriği" kartının güncellendiğini kontrol edin
5. Firestore dokümanlarında `imageUrl` varsa, kartlarda görsellerin cache'lenerek göründüğünü doğrulayın
