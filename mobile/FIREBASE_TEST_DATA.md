# Firebase Test Verisi Hazırlama Rehberi

## 🎯 "Test Send" Butonunun Çalışması İçin Gerekli Veriler

### 1. `daily_state/current` Dokümanı

**Yol:** Firestore > `daily_state` koleksiyonu > `current` dokümanı

**Alanlar:**
```json
{
  "nextOrder": 1,
  "lastSentAt": null,
  "lastSentItemId": null
}
```

**Nasıl Oluşturulur:**
1. Firebase Console > Firestore Database'e git
2. `daily_state` koleksiyonunu oluştur (yoksa)
3. `current` dokümanını oluştur
4. Alanları ekle:
   - `nextOrder` → **Number** → `1`
   - `lastSentAt` → **Timestamp** → Boş bırak (null)
   - `lastSentItemId` → **String** → Boş bırak (null)

---

### 2. `daily_items` Koleksiyonu

**Yol:** Firestore > `daily_items` koleksiyonu

**En Az 1 İçerik Olmalı:**
```json
{
  "order": 1,
  "title": "Test İçeriği 1",
  "body": "Bu birinci test içeriğidir.",
  "sent": false
}
```

**Nasıl Oluşturulur:**
1. Firebase Console > Firestore Database'e git
2. `daily_items` koleksiyonunu oluştur (yoksa)
3. Yeni doküman ekle (ID otomatik oluşabilir)
4. Alanları ekle:
   - `order` → **Number** → `1` (daily_state/current.nextOrder ile eşleşmeli)
   - `title` → **String** → `"Test İçeriği 1"`
   - `body` → **String** → `"Bu birinci test içeriğidir."`
   - `sent` → **Boolean** → `false`

---

## ✅ Test Senaryosu

### İlk Test İçin:

1. **daily_state/current:**
   ```
   nextOrder: 1
   ```

2. **daily_items (en az 1 doküman):**
   ```
   order: 1
   title: "Test İçeriği 1"
   body: "Bu birinci test içeriğidir."
   sent: false
   ```

3. **Flutter uygulamasında "Test Send" butonuna bas**

4. **Beklenen Sonuç:**
   - ✅ `daily_items` koleksiyonunda `order: 1` olan içerik `sent: true` olur
   - ✅ `daily_state/current.nextOrder` = `2` olur
   - ✅ `daily_state/current.lastSentAt` timestamp ile doldurulur
   - ✅ `daily_state/current.lastSentItemId` gönderilen item'ın ID'si ile doldurulur
   - ✅ FCM bildirimi gönderilir

---

### İkinci Test İçin:

1. **daily_items'e yeni içerik ekle:**
   ```
   order: 2
   title: "Test İçeriği 2"
   body: "Bu ikinci test içeriğidir."
   sent: false
   ```

2. **Tekrar "Test Send" butonuna bas**

3. **Beklenen Sonuç:**
   - ✅ `order: 2` olan içerik gönderilir
   - ✅ `nextOrder` = `3` olur

---

## 🔍 Sorun Giderme

### "No unsent item found with order X" Hatası

**Sebep:** `daily_items` koleksiyonunda `order == nextOrder` ve `sent == false` olan bir item yok.

**Çözüm:**
1. `daily_state/current.nextOrder` değerini kontrol et (örn: `1`)
2. `daily_items` koleksiyonunda `order: 1` ve `sent: false` olan bir item olduğundan emin ol
3. Yoksa yeni item ekle veya `nextOrder` değerini değiştir

---

### "State document not found" Hatası

**Sebep:** `daily_state/current` dokümanı yok.

**Çözüm:**
1. Firebase Console > Firestore > `daily_state` koleksiyonunu oluştur
2. `current` dokümanını oluştur
3. `nextOrder: 1` alanını ekle

---

### Tüm İçerikler Gönderildi (sent: true)

**Çözüm:**
1. `daily_items` koleksiyonundaki tüm item'ların `sent` değerini `false` yap
2. Veya yeni item'lar ekle (`order` değerlerini sırayla artırarak)

---

## 📝 Hızlı Test İçin Örnek Veriler

### 3 İçerik Hazırla:

**daily_items:**
1. `order: 1`, `title: "İçerik 1"`, `body: "Birinci içerik"`, `sent: false`
2. `order: 2`, `title: "İçerik 2"`, `body: "İkinci içerik"`, `sent: false`
3. `order: 3`, `title: "İçerik 3"`, `body: "Üçüncü içerik"`, `sent: false`

**daily_state/current:**
- `nextOrder: 1`

Bu şekilde 3 kez "Test Send" butonuna basabilirsin!
