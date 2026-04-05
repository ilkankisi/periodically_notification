# Başka bir yapay zekâya verilecek danışma / onay promptu

Bu dosyayı **olduğu gibi** veya kendi notlarınla birlikte hedef modele yapıştırabilirsin. Aşağıdaki **“Başka modele yapıştır”** bölümü tek parça prompttur.

---

## Ürünün özü (insan okuması için)

**DAHA**, insanlara **günlük motivasyon** sunmayı hedefleyen bir uygulama. Motivasyon metinleri ve görselleri **tetikleyici**; kullanıcılar içerikleri **okuyor, kaydediyor, keşfediyor**. Aynı içerikler etrafında **yorum yazarak sosyalleşiyor** (topluluk / UGC katmanı). Bunun ötesinde **“bugün bu sözle ne yaptın?”** tarzı **günlük eylem kaydı**, **seri (streak) / zincir** ekranları ve **rozet + sosyal puan** (ör. yorum ve etkileşimlere bağlı puanlama) ile kullanıcılar **ilerleme hissi ve hafif rekabet / meydan okuma** (kendine veya topluluk dinamiklerine karşı) yaşasın diye tasarlanmıştır. **Ana ekran widget’ı** ve **zamanlı bildirimler** ile günlük geri dönüş desteklenir; **Apple/Google ile giriş** isteğe bağlıdır (buluta bağlı özellikler için).

*Kodda ayrıca:* kullanıcıların kendi motivasyonlarını ekleme akışı (`add_my_motivation_page`), bildirim merkezi/ayarları, profil ve hesap bilgisi ekranları bulunur. **Gerçek zamanlı küresel skor tablosu** iddiası dokümante değil; rekabet dilini listing ve Review Notes’ta **AB** uyumlu ve abartısız kurmak önemli (özellikle 4.2 ve “misleading” riski).

---

## Sana özel: App Store inceleme dönüşü (buraya ekle)

> **Aşağıya Apple App Store Connect’ten gelen son red / çözüm metnini veya e-posta özetini aynen yapıştır.** Prompt içinde özetlediğim strateji (`docs/IMPLEMENTATION_PLAN_4.2.md`) genel olarak **Guideline 4.2 (Minimum Functionality)** etrafında; senin **gerçek red gerekçen** çıktıyı netleştirir.

```
[Buraya App Store Review’dan gelen metni yapıştır — örn. 4.2.x, 2.1, 5.1.x vb.]

```

---

## Başka modele yapıştır — tam prompt

Sen deneyimli bir **mobil ürün + App Store uyum (Human Interface + App Review Guidelines)** danışmanısın. Aşağıdaki projeyi **üçüncü taraf gözüyle** değerlendir: eksikleri, riskleri, App Store yeniden gönderiminde dikkat çekecek noktaları ve metin (listing / Review Notes) önerilerini net liste halinde ver.

### 0) Ürünün amacı ve değer önerisi (iş / kullanıcı dili)

- **Temel amaç:** Kullanıcılara **düzenli motivasyon** vermek; onları günlük olarak **harekete geçmeye ve alışkanlık kazanmaya** teşvik etmek.
- **Sosyalleşme:** Motivasyon içerikleri altında **yorum yaparak** diğer kullanıcılarla etkileşim; paylaşım ve tartışma ile **topluluk hissi**.
- **Oyunsallaştırma / “yarış” boyutu:** **Günlük eylem kayıtları**, **seri (streak) ve zincir** görünümleri, **rozetler** ve **sosyal puan** (ör. yorum katılımına bağlı) ile kullanıcıların **ilerlemeyi görünür kılması** ve **kendini / grubu motive etme** dinamiği — bu, “birbirleriyle yarışma” iddiasını **Apple açısından ölçülü anlat** (yanıltıcı “sıralama garantisi” yokmuş gibi iddia etme); teknik gerçeği kod envanterine göre doğrula.
- **Tamamlayıcı özellikler (repo iddiası):** İçerik **keşfet / kaydet**, **widget**, **push (iOS APNs)**, **bildirim ayarları**, **kendi motivasyonunu ekleme**, isteğe bağlı **hesap (Apple/Google)** ile senkron ve profil.

### 1) Proje özeti (teknik)

- **Ürün:** Flutter uygulaması (marka/ekran adı **DAHA**; repo adı `periodically_notification`). Yukarıdaki amaçla: motivasyon + yorum + alışkanlık/oyunlaştırma katmanları.
- **Önceki mimari:** Firebase (Firestore, Functions, FCM vb.) bu repoda **kaldırılmış**; `firebase.json`, `firestore.rules`, `lib/services/firebase_service.dart` silinmiş / kullanılmıyor.
- **Güncel mimari:**
  - **Backend:** Ayrı proje **`~/Desktop/backendGo`** — Go + **PostgreSQL**, REST API. İçerik kaynağı API ve/veya `assets/data/motivations.json` + cache servisleri.
  - **Push (iOS):** **Doğrudan APNs** (sunucu tarafında APNs anahtarı; istemcide Firebase Cloud Messaging yok). Android tarafında uzak push stratejisi README’ye göre sınırlı / widget odaklı olabilir.
  - **Widget:** iOS + Android ana ekran widget’ı (`home_widget`, App Group, `DailyWidget` benzeri yapı).
  - **Kimlik doğrulama:** **Apple** ve **Google** ile giriş; token/oturum **`BackendService` / `AuthService`** üzerinden Go API (`/api/auth/oauth/*` vb.). `AUTH_SETUP.md` içinde hâlâ Firebase Console adımları geçebilir (OAuth sağlayıcı yapılandırması için); uygulamanın veri katmanı Firestore değil.
- **Dokümantasyon (repoda):** `README.md`, `docs/FLUTTER_BACKEND_INTEGRATION.md`, `docs/IMPLEMENTATION_PLAN_4.2.md` (Apple **4.2** ve UGC **1.2** odaklı uzun plan), `docs/IMPLEMENTATION_CHECKLIST.md` (kısmi maddeler **eski kalmış olabilir** — kodla çapraz kontrol şart), `docs/YEREL_CALISTIRMA.md`, `AUTH_SETUP.md`.

### 2) Uygulama tarafında bugüne kadar var olduğu bilinen özellikler (envanter)

Aşağısı repo yapısı ve dosya adlarından çıkarılmıştır; **sen bunu “iddia” olarak doğrula** ve eksik/yanlış varsayım varsa işaretle.

**Ekranlar (`lib/screens/`):** `home_page`, `explore_page`, `saved_page`, `profile_page`, `content_detail_page`, `all_content_list_page`, `login_page`, `account_info_page`, `notifications_page`, `actions_chain_page`, `streak_chain_page`, `zincir_page`, `badges_page`, `add_my_motivation_page`.

**Servisler (`lib/services/`):** `api_config`, `auth_service`, `backend_service`, `backend_api_client`, `comment_service`, `content_sync_service`, `gamification_service`, `local_notification_service`, `motivation_service`, `motivation_cache_service`, `notification_*` (badge, settings, store), `push_notification_service`, `user_motivation_service`. (Profil ile ilgili `profile_service` import’ları mevcut.)

**Modeller / widget’lar:** `motivation`, `action_entry`, `comment`, `notification_entry`, `gamification_badge`; `add_action_card` (**“Bugün bu sözle ne yaptın?”** ve opt-in senkronizasyonla ilgili), `app_top_bar`, `motivation_cached_image` vb.

**Varlıklar:** `assets/data/motivations.json`.

**Platform:** iOS `Podfile`/`Runner` güncellemeleri; Android `build.gradle` değişiklikleri; widget provider’lar README’de özetlenmiş.

### 3) App Store inceleme bağlamı (özetimiz — bunu eleştir)

- Beklenen veya yaşanan sorun çerçevesi: **[Guideline 4.2 — Minimum Functionality](https://developer.apple.com/app-store/review/guidelines/#minimum-functionality)** — “sadece birkaç ekran / web sitesi benzeri” algısı, **yeterince native ve tekrar kullanılabilir fayda** sunmama.
- **Strateji (plan belgesi):** Motivasyon sözü **tetikleyici**; asıl ürün değeri **günlük eylem / alışkanlık kaydı**, **streak / ilerleme**, isteğe bağlı **hesaplı senkron**, **UGC (yorum)** ile moderasyon/raporlama ihtiyacı, **iPad’de boş ekranların** çok “basit” görünmemesi.
- **Operasyonel:** Review Notes’ta **demo hesap**, “7 adımlı test” benzeri reviewer talimatları, **destek iletişim** URL’si ve uygulama içi “Bize ulaşın” tutarlılığı plan/checklist’te vurgulanmış (gerçek uygulama durumu senin analizine kalmış).
- Kullanıcı **yukarıdaki kutuya** Apple’dan gelen **kesin red metnini** yapıştıracak; sen özeti, **hangi guideline maddelerine tek tek cevap verildiğini** ve **hâlâ açık kalan gap’leri** red metniyle eşleştir.

### 4) Senden istediğim çıktı formatı

1. **Executive summary** (5–8 cümle): Bu uygulama App Store’a “hazır mı, değilse neden?”
2. **Guideline haritası:** 4.2, 1.2 (UGC), 5.1.x (gizlilik/onam), hesap silme (Apple hesap silme politikası), Sign in with Apple — her biri için **Durum: Yeşil / Sarı / Kırmızı** + gerekçe.
3. **Ürün hikâyesi (listing):** Kısa **subtitle / açıklama / What’s New** önerisi; 4.2’ye göre “asıl fayda” cümlesi net olsun.
4. **Review Notes taslakları:** İngilizce kısa paragraf + madde madım reviewer adımları (giriş gerektirmeyen akış, girişli akış, widget, bildirim).
5. **Teknik / UX gap listesi:** Checklist’te ⬜ olan veya kodda görünmeyen (ör. rate limiting, tam moderasyon paneli, lokalizasyon) maddeleri **önceliklendir** (P0 / P1 / P2).
6. **Tutarsızlıklar:** Örn. dokümantasyonda Firebase anlatımı vs. kodda Firestore yok; `IMPLEMENTATION_CHECKLIST.md` ile gerçek kod uyumu.
7. **Sonuç:** “Onaylarım / Onaylamam” — net cümle + bir sonraki sprint için **en fazla 5 maddelik** aksiyon listesi.

Kısa, denetçi dili kullan; spekülasyon yapıyorsan bunu açıkça etiketle. Türkçe veya İngilizce cevap verebilirsin; tercih: **Türkçe** (teknik terimleri İngilizce bırakabilirsin).

---

## Bu dosyayı kullanırken senin yapacakların

1. Üstteki **App Store metni kutusunu** doldur.
2. Gerekirse **backendGo** README’sinden API listesini veya canlı **base URL** politikasını tek cümle ekle (prompta yapıştır).
3. İstersen şu cümleyi de ekle: *“Checklist eski olabilir; kod ve `README.md` önceliklidir.”*
4. Modele verdiğin cevabı alınca, `docs/IMPLEMENTATION_CHECKLIST.md` ve Review Notes’u **gerçek durumla** güncellemek iyi olur.

---

*Oluşturulma amacı: İkinci bir modele “sunum + denetim” yaptırmak; çıktıyı uygulamaya yansıtmak kullanıcı sorumluluğundadır.*
