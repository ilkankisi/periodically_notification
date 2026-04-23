# Full Tour: Popup + Spotlight + Yönlendirme Rehberi

Bu rehber, akışı **Anasayfa’dan başlatmak** için kısa ve net bir uygulama şablonudur.

## 1) Step yapısını netleştir

`OnboardingService` içinde başlangıcı Home yap:

```dart
static const int stepHomeIntroPopup = 0;
static const int stepHomeCardSpotlight = 1;
static const int stepDetailIntroPopup = 2;
static const int stepDetailReadTap = 3;
static const int stepDetailActionSpotlight = 4;
static const int stepDetailActionSaved = 5;
static const int stepDetailBackPopup = 6;
static const int stepExploreIntro = 7;
static const int stepDone = 99;
```

Fallback/default her yerde `stepHomeIntroPopup` olmalı:

- `ensure...` default set
- `get...` fallback
- debug reset başlangıcı

## 2) Event helper yaz (direkt set dağılmasın)

`OnboardingService`:

```dart
static Future<bool> moveTo({
  required int expected,
  required int next,
}) async {
  final cur = await getGlobalTourStep();
  if (cur != expected) return false;
  await setGlobalTourStep(next);
  return true;
}
```

Sonra ekranlar bunu çağırsın:

- `onHomeIntroDone()` -> `0 -> 1`
- `onHomeCardTapped()` -> `1 -> 2`
- `onDetailIntroDone()` -> `2 -> 3`
- `onDetailReadTapped()` -> `3 -> 4`
- `onDetailActionSaved()` -> `4 -> 6` (veya `5 -> 6`)
- `onDetailBackTapped()` -> `6 -> 7`

## 3) Home’da popup sonra spotlight

`home_page.dart` mantığı:

1. Step `stepHomeIntroPopup` ise dialog aç.
2. Dialog kapanınca `onHomeIntroDone()`.
3. Sonra spotlight’ı sadece step `stepHomeCardSpotlight` ise göster.
4. Spotlight hedefe dokununca detail aç ve `onHomeCardTapped()`.

Örnek:

```dart
if (step == OnboardingService.stepHomeIntroPopup) {
  await showDialog(...); // "Önce karta dokun" popup
  await OnboardingService.onHomeIntroDone();
}

if (step == OnboardingService.stepHomeCardSpotlight) {
  FullTourHomeActionCoach.show(
    context: context,
    targetKey: _homeCardKey,
    onOpenMainHeroFromHighlight: () async {
      await OnboardingService.onHomeCardTapped();
      Navigator.push(...detail...);
    },
  );
}
```

## 4) Detail’de 3 aşama

### A) Detail intro popup
Step `stepDetailIntroPopup` ise popup göster, kapanınca `onDetailIntroDone()`.

### B) Metin gövdesine dokunma
Step `stepDetailReadTap` ise sadece gövde text alanını tıklanabilir yap:

```dart
GestureDetector(
  onTap: () async {
    final ok = await OnboardingService.onDetailReadTapped();
    if (!ok) return;
    // Sonraki spotlight
  },
  child: Text(body),
)
```

### C) Aksiyon kartına indir + spotlight
`Scrollable.ensureVisible(actionCardKey.currentContext!)` ile kaydır, sonra spotlight göster.

## 5) Aksiyon kaydında step ilerlet

`AddActionCard.onActionSaved` içinde:

```dart
await OnboardingService.onDetailActionSaved();
await showDialog(... "geri oka bas");
```

> Kural: kullanıcı gerçekten metin girip kayıt başarılı olunca bu çalışmalı.

## 6) Geri butonuna özel kural

Detail appbar geri butonunda:

```dart
onPressed: () async {
  final moved = await OnboardingService.onDetailBackTapped();
  Navigator.pop(context);
  if (moved) OnboardingService.requestTab(1); // Explore
}
```

## 7) Yarışma (race) engeli

Spotlight scheduler fonksiyonlarında guard kullan:

- `if (_running) return;`
- `try { ... } finally { _running = false; }`

Aynı step için popup/spotlight tekrar tetiklenmesin:

- `_introShown`, `_coachShown` gibi flag’ler kullan.

## 8) Hızlı kontrol listesi

- App açılışı: direkt Home intro popup.
- Popup kapanınca Home kart spotlight.
- Kart tap: Detail intro popup.
- Popup kapanınca gövdeye tap beklenir.
- Gövde tap sonrası aksiyon kartına scroll + spotlight.
- Aksiyon kaydı sonrası geri popup.
- Geri oka basınca Explore adımına geçiş.

---

İstersen bu rehberi bir sonraki adımda doğrudan senin mevcut dosya isimlerine birebir (`onboarding_service.dart`, `home_page.dart`, `content_detail_page.dart`) mapleyip “hangi fonksiyonun içine ne koyacağın” şeklinde satır satır da çıkarırım.
