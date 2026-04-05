# Test Planı - Günlük İçerik Bildirim Sistemi

## 🎯 Test Hedefleri

1. Firestore'dan içerik seçimi ve gönderimi
2. FCM topic bildirimleri
3. iOS ve Android widget güncellemeleri
4. End-to-end akış doğrulaması

---

## 📋 Test Senaryoları

### Senaryo 1: İlk Kurulum ve Veri Hazırlama

**Adımlar:**
1. Firebase Console > Firestore'a gidin
2. `daily_items` koleksiyonunu oluşturun
3. 3 örnek içerik ekleyin:
   ```json
   {
     "order": 1,
     "title": "Test İçeriği 1",
     "body": "Bu birinci test içeriğidir.",
     "sent": false
   }
   {
     "order": 2,
     "title": "Test İçeriği 2",
     "body": "Bu ikinci test içeriğidir.",
     "sent": false
   }
   {
     "order": 3,
     "title": "Test İçeriği 3",
     "body": "Bu üçüncü test içeriğidir.",
     "sent": false
   }
   ```
4. `daily_state/current` dokümanını oluşturun:
   ```json
   {
     "nextOrder": 1,
     "lastSentAt": null,
     "lastSentItemId": null
   }
   ```

**Beklenen Sonuç:**
- ✅ Veriler başarıyla oluşturuldu
- ✅ `daily_state/current` dokümanı mevcut

---

### Senaryo 2: Manuel İçerik Gönderimi (Cloud Function)

**Adımlar:**
1. Firebase Console > Functions > `manualSendDailyContent` fonksiyonunu seçin
2. **Testing** sekmesine gidin
3. Fonksiyonu çağırın (parametre gerekmez)

**Beklenen Sonuç:**
- ✅ Function başarıyla çalıştı
- ✅ `daily_items` koleksiyonunda order=1 olan içerik `sent: true` oldu
- ✅ `daily_state/current.nextOrder` = 2 oldu
- ✅ `daily_state/current.lastSentAt` timestamp içeriyor
- ✅ Function log'larında "Visible notification sent successfully" mesajı var

**Kontrol Listesi:**
- [ ] Firestore'da ilk içerik `sent: true` oldu mu?
- [ ] `daily_state/current.nextOrder` = 2 oldu mu?
- [ ] Function log'larında hata var mı?

---

### Senaryo 3: FCM Bildirim Alımı (Flutter)

**Önkoşul:** Senaryo 2 tamamlanmış olmalı

**Adımlar:**
1. Flutter uygulamasını çalıştırın: `flutter run`
2. Uygulama açıldığında log'ları kontrol edin
3. Bildirim izni isteği geldi mi? (İzin verin)
4. FCM token alındı mı? (Log'larda görünmeli)
5. Topic'e subscribe olundu mu? (`daily_widget_all`)

**Beklenen Sonuç:**
- ✅ Bildirim izni verildi
- ✅ FCM token alındı (log'larda görünüyor)
- ✅ Topic'e subscribe olundu (log'larda "Subscribed to topic: daily_widget_all")
- ✅ Uygulama ana ekranda "Waiting for daily content..." veya "Widget is active" gösteriyor

**Kontrol Listesi:**
- [ ] FCM token log'da görünüyor mu?
- [ ] Topic subscribe mesajı log'da var mı?
- [ ] Uygulama hatasız çalışıyor mu?

---

### Senaryo 4: Bildirim Geldiğinde Widget Güncelleme

**Önkoşul:** Senaryo 2 ve 3 tamamlanmış olmalı

**Adımlar:**
1. Uygulamayı açık tutun (foreground)
2. `manualSendDailyContent()` fonksiyonunu tekrar çağırın (ikinci içerik gönderilecek)
3. Bildirim geldiğinde:
   - Bildirim görünüyor mu?
   - Widget güncellendi mi? (Uygulama içinde kontrol edin)

**Beklenen Sonuç:**
- ✅ Bildirim geldi (görünür notification)
- ✅ Uygulama içinde widget verisi güncellendi
- ✅ Log'larda "Home widget updated successfully" mesajı var

**Kontrol Listesi:**
- [ ] Bildirim geldi mi?
- [ ] Uygulama içinde "Last update" zamanı güncellendi mi?
- [ ] Log'larda widget update mesajı var mı?

---

### Senaryo 5: iOS Widget Testi

**Önkoşul:** iOS cihaz veya simülatör, widget extension build edilmiş

**Adımlar:**
1. iOS cihaz/simülatörde uygulamayı çalıştırın
2. Ana ekrana gidin
3. Widget ekleme moduna girin (ekrana uzun basın)
4. **+** butonuna tıklayın
5. "DailyWidget" veya "Günlük İçerik" widget'ını bulun
6. Widget'ı ekleyin
7. `manualSendDailyContent()` fonksiyonunu çağırın
8. Widget'ın güncellenip güncellenmediğini kontrol edin

**Beklenen Sonuç:**
- ✅ Widget ana ekranda görünüyor
- ✅ Widget'ta "Günün İçeriği" başlığı var
- ✅ Bildirim geldikten sonra widget içeriği güncellendi
- ✅ "Son güncelleme" zamanı gösteriliyor

**Kontrol Listesi:**
- [ ] Widget eklenebildi mi?
- [ ] Widget'ta içerik görünüyor mu?
- [ ] Bildirim sonrası widget güncellendi mi?
- [ ] App Group ID doğru mu? (Xcode'da kontrol edin)

---

### Senaryo 6: Android Widget Testi

**Önkoşul:** Android cihaz veya emülatör

**Adımlar:**
1. Android cihaz/emülatörde uygulamayı çalıştırın
2. Ana ekrana gidin
3. Widget ekleme moduna girin (ekrana uzun basın)
4. "Widgets" veya "Widgets" sekmesine gidin
5. "DailyWidget" veya "Günlük İçerik" widget'ını bulun
6. Widget'ı ana ekrana sürükleyin
7. `manualSendDailyContent()` fonksiyonunu çağırın
8. Widget'ın güncellenip güncellenmediğini kontrol edin

**Beklenen Sonuç:**
- ✅ Widget ana ekranda görünüyor
- ✅ Widget'ta "Günün İçeriği" başlığı var
- ✅ Bildirim geldikten sonra widget içeriği güncellendi
- ✅ "Son güncelleme" zamanı gösteriliyor

**Kontrol Listesi:**
- [ ] Widget eklenebildi mi?
- [ ] Widget'ta içerik görünüyor mu?
- [ ] Bildirim sonrası widget güncellendi mi?
- [ ] SharedPreferences'de veri var mı? (Android Studio > Device File Explorer)

---

### Senaryo 7: Background/Terminated State Testi

**Adımlar:**
1. Uygulamayı açın ve topic'e subscribe olun
2. Uygulamayı background'a alın (home tuşuna basın)
3. `manualSendDailyContent()` fonksiyonunu çağırın
4. Bildirim geldiğinde:
   - Bildirim görünüyor mu?
   - Bildirime dokununca uygulama açılıyor mu?
   - Widget güncellendi mi?

**Beklenen Sonuç:**
- ✅ Background'da bildirim geldi
- ✅ Bildirime dokununca uygulama açıldı
- ✅ Widget verisi güncellendi

**Kontrol Listesi:**
- [ ] Background'da bildirim geldi mi?
- [ ] Bildirime dokununca uygulama açıldı mı?
- [ ] Widget güncellendi mi?

---

### Senaryo 8: Scheduled Function Testi (Gerçek Zaman)

**Not:** Bu test için scheduled function'ın çalışma saatini beklemek veya manuel olarak tetiklemek gerekir.

**Adımlar:**
1. Firestore'da 3 içerik olduğundan emin olun (order: 1, 2, 3, sent: false)
2. `daily_state/current.nextOrder` = 1 olduğundan emin olun
3. Scheduled function'ın çalışma saatini bekleyin veya Firebase Console'dan manuel tetikleyin
4. Function log'larını kontrol edin
5. Bildirim geldi mi?
6. Widget güncellendi mi?

**Beklenen Sonuç:**
- ✅ Scheduled function belirlenen saatte çalıştı
- ✅ İçerik gönderildi
- ✅ Bildirim geldi
- ✅ Widget güncellendi

**Kontrol Listesi:**
- [ ] Function log'larında başarı mesajı var mı?
- [ ] Bildirim geldi mi?
- [ ] Widget güncellendi mi?
- [ ] `daily_state/current.nextOrder` artırıldı mı?

---

### Senaryo 9: Hata Senaryoları

#### 9.1: İçerik Bulunamadı

**Adımlar:**
1. `daily_state/current.nextOrder` = 999 yapın (olmayan bir order)
2. `manualSendDailyContent()` fonksiyonunu çağırın

**Beklenen Sonuç:**
- ✅ Function log'larında "No unsent item found" uyarısı var
- ✅ Hata döndü ama uygulama çökmüyor

#### 9.2: State Dokümanı Yok

**Adımlar:**
1. `daily_state/current` dokümanını silin
2. `manualSendDailyContent()` fonksiyonunu çağırın

**Beklenen Sonuç:**
- ✅ Function log'larında "State document not found" hatası var
- ✅ Function hata döndü

---

## 📊 Test Sonuçları Tablosu

| Senaryo | Durum | Notlar |
|---------|-------|--------|
| Senaryo 1: Veri Hazırlama | ⬜ | |
| Senaryo 2: Manuel Gönderim | ⬜ | |
| Senaryo 3: FCM Alımı | ⬜ | |
| Senaryo 4: Widget Güncelleme | ⬜ | |
| Senaryo 5: iOS Widget | ⬜ | |
| Senaryo 6: Android Widget | ⬜ | |
| Senaryo 7: Background Test | ⬜ | |
| Senaryo 8: Scheduled Function | ⬜ | |
| Senaryo 9: Hata Senaryoları | ⬜ | |

---

## 🔍 Debug İpuçları

### Flutter Log'ları

```bash
flutter run -v
```

Önemli log mesajları:
- `FCM Token: ...`
- `Subscribed to topic: daily_widget_all`
- `Foreground message received: ...`
- `Home widget updated successfully`

### Firebase Function Log'ları

Firebase Console > Functions > Logs

Önemli log mesajları:
- `Daily widget content scheduler triggered`
- `Found item: ...`
- `Visible notification sent successfully`

### iOS Widget Debug

Xcode'da widget extension'ı run edin ve log'ları kontrol edin.

### Android Widget Debug

Android Studio > Logcat'te `DailyWidgetProvider` filtreleyin.

---

## ✅ Başarı Kriterleri

Tüm test senaryoları başarıyla tamamlandığında:
- ✅ Firestore'dan içerik seçimi çalışıyor
- ✅ FCM bildirimleri geliyor
- ✅ iOS widget güncelleniyor
- ✅ Android widget güncelleniyor
- ✅ Background/terminated state'te çalışıyor
- ✅ Scheduled function zamanında çalışıyor


