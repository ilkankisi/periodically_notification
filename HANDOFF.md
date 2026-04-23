# Handoff Notes (Full Tour / Spotlight)

Bu dosya, mevcut tur geliştirmesini başka bir Cursor oturumuna taşımak için hazırlanmıştır.

## Proje
- Repo: `c:\PROJECTS\periodically_notification`
- Mobil app: `mobile/`

## Hedef Akış (güncel)
- Tur **Home** ekranından başlar.
- Home:
  1. Intro popup
  2. Ana kart spotlight
  3. Karta dokununca detail’e geçiş
- Detail:
  1. Üst bilgilendirme popup
  2. Metin gövdesine dokunma adımı
  3. Aksiyon kartına scroll + spotlight
  4. Kullanıcı metin yazınca `Aksiyon Ekle` buton spotlight
  5. `Aksiyon Ekle` sonrası geri yönlendirme popup
  6. Geri tuşuyla sonraki adıma geçiş
- Son adımlardan sonra debug loop açıkken tur başa sarar.

## Önemli Değişiklikler

### 1) Onboarding state / event helper
Dosya: `mobile/lib/services/onboarding_service.dart`

- Merkezi helper'lar eklendi:
  - `moveToStepIfCurrent(...)`
  - `onHomeIntroAcknowledged()`
  - `onHomeCardTappedToDetail()`
  - `onDetailReadBodyTapped()`
  - `onDetailActionSaved()`
  - `onDetailBackConfirmedToExplore()`
  - `onExploreSavedFirstItem()`
  - `onSavedItemOpened()`
- Debug flaglar:
  - `kDebugRepeatFullTour = true`
  - `kDebugSingleStepLoop = false` (tek adım kilidi kapalı)
- Debug loop başlangıcı:
  - `_debugLoopStartStep() => tourStep04HomeCardIntro`

### 2) Home akışı
Dosya: `mobile/lib/screens/home_page.dart`

- Home intro popup eklendi (`_showHomeIntroPopup`).
- Sonrasında home kart spotlight gösteriliyor.
- Spotlight’ta karta dokununca:
  - `OnboardingService.onHomeCardTappedToDetail()`
  - Detail sayfasına navigasyon.
- Yanlış step zorlamaları azaltıldı; adım kontrolü event bazlı.

### 3) Detail akışı
Dosya: `mobile/lib/screens/content_detail_page.dart`

- Tour için yeni key/flag/state:
  - `_detailReadBodyKey`
  - `_detailActionCardKey`
  - `_detailActionButtonKey`
  - `_detailBackButtonKey`
  - `_detailReadCoachShown`, `_detailActionCoachShown`, `_detailActionButtonCoachShown`, `_detailBackPopupShown`
- Yeni adım fonksiyonları:
  - `_maybeStartFullTourDetailFlow()`
  - `_showDetailInfoPopup(...)`
  - `_showDetailReadBodyCoach()`
  - `_onDetailReadBodyTapped()`
  - `_maybeShowActionButtonSpotlight(...)`
  - `_onDetailActionSavedForTour()`
  - `_handleBackPressed()`
- Metin gövdesi tıklanabilir hale getirildi (step geçiş için).
- AddActionCard artık key/callback ile buton spotlight tetikliyor.

### 4) AddActionCard davranışı
Dosya: `mobile/lib/widgets/add_action_card.dart`

- Yeni parametreler:
  - `actionButtonKey`
  - `onNoteChanged`
- TextField `onChanged` eklendi.
- `Aksiyon Ekle` butonu `KeyedSubtree` ile hedeflenebilir yapıldı.
- Login değilse `LoginPage` açılırken:
  - `onboardingFullTour: true` veriliyor (login buton spotlight’ı açılsın diye).

### 5) Explore / Saved geçişleri
- `mobile/lib/screens/explore_page.dart`
  - İlk save sonrası: `OnboardingService.onExploreSavedFirstItem()`
- `mobile/lib/screens/saved_page.dart`
  - Saved item açılışında: `OnboardingService.onSavedItemOpened()`

### 6) Home coach metin/etiket
Dosya: `mobile/lib/widgets/full_tour_home_action_coach.dart`
- Step etiketi `Adım 5/22` olarak güncellendi.

## Bilinen Noktalar / Dikkat
- `kDebugRepeatFullTour` açık olduğu için tur tamamlanınca debug başlangıç adımına döner.
- Login’e yönlendirilen senaryoda login spotlight açık ama tur step mantığı ile çakışma olursa event helper koşulları kontrol edilmeli.
- Bazı geçmiş değişiklikler sırasında duplicate todo id’leri oluşmuştu; kod tarafı etkilenmiyor.

## Hızlı Kontrol (QA)
1. App aç -> Home intro popup görünür.
2. Popup kapanır -> Home kart spotlight görünür.
3. Karta dokun -> Detail açılır.
4. Detail popup + metin gövdesi dokunma adımı çalışır.
5. Aksiyon kartına spotlight + yazınca buton spotlight görünür.
6. `Aksiyon Ekle` sonrası geri popup görünür.
7. Geri ok -> bir sonraki adıma geçiş.
8. Tur sonu -> debug loop ile başlangıca dönme.

## Ek Rehber
- Uygulama rehberi dosyası: `FULL_TOUR_SPOTLIGHT_POPUP_GUIDE.md`

