# Periodically Notification — Design System

## Genel Bakış

Bu belge, "Günün İçeriği" mobil uygulamasının **tasarım sistemini**, **renk paletini**, **tipografiyi**, **spacing**'i ve **bileşenleri** detaylı şekilde açıklar. Tasarımcılara ve geliştiricilere visual consistency sağlamak için kullanılır.

---

## 1. Ekran Layoutu (Screen Layout)

### Ana Ekran (Home Screen)

```
┌─────────────────────────────────┐
│ [APP BAR]                       │  Yükseklik: 56dp (default Material)
│ Günün İçeriği                   │  Renkler: Blue background, White text
└─────────────────────────────────┘
│                                 │
│        [CONTENT AREA]           │  Yükseklik: Fill Parent
│                                 │  Background: White
│        ┌─────────────────┐      │
│        │   LOADING       │      │  State 1: İlk yükleme
│        │  (spinner +     │      │
│        │   text)         │      │
│        └─────────────────┘      │
│                                 │
│                - VEYA -         │
│                                 │
│        ┌─────────────────┐      │  State 2: Veriler yüklü
│        │ TITLE           │      │
│        │ Günün İçeriği   │      │
│        │                 │      │
│        │ ┌──────────────┤      │
│        │ │ BODY         │      │  Body container with gray background
│        │ │ Veri...      │      │
│        │ └──────────────┤      │
│        │                 │      │
│        │ Updated: TIME   │      │
│        │                 │      │
│        │ [REFRESH BTN]   │      │
│        │ [TEST NOTIF]    │      │
│        └─────────────────┘      │
│                                 │
└─────────────────────────────────┘
```

---

## 2. Renk Paleti (Color Palette)

### Kullanılan Renkler

| Kullanım Yeri | Renk | Hex Code | Material Dart |
|---|---|---|---|
| App Bar Background | Mavi | #2196F3 | `Colors.blue` |
| App Bar Text | Beyaz | #FFFFFF | `Colors.white` |
| Body Background | Beyaz | #FFFFFF | `Colors.white` |
| Title Text | Koyu Gri | #212121 | `Colors.black87` |
| Body Container BG | Açık Gri | #F5F5F5 | `Colors.grey[100]` |
| Body Text | Gri | #757575 | `Colors.black54` |
| Border (Body) | Çok Açık Gri | #E0E0E0 | `Colors.grey[300]` |
| Timestamp Text | Gri | #9E9E9E | `Colors.grey` |
| Refresh Button | Blue (inherit) | #2196F3 | `ElevatedButton` default |
| Test Notification Button | Turuncu | #FF9800 | `Colors.orange` |

### Renk Kullanımı Prensipleri

- **Primary (Blue):** App bar, action buttons (öncelik düzeyinde)
- **Secondary (Orange):** Test/notification actions (dikkat çekici)
- **Backgrounds:** White (main), Grey 100 (container), White (body)
- **Text:** Black87 (başlıklar), Black54 (body), Grey (meta info)

---

## 3. Tipografi (Typography)

### Text Styles

| Kullanım | Dart Text Style | Font Size | Font Weight | Color | Örnek |
|---|---|---|---|---|---|
| App Bar Title | Material App Bar default | 20sp | W500 | White | "Günün İçeriği" |
| Page Title | `headlineSmall` + bold | 18-20sp | W700 (bold) | Black87 | Widget title |
| Body Text | `bodyMedium` | 14sp | W400 | Black54 | Widget content |
| Meta / Timestamp | `bodySmall` | 12sp | W400 | Grey | "Güncelleme: ..." |
| Loading Text | `bodyLarge` | 16sp | W400 | Default | "Widget verileri yükleniyor..." |
| Button Text | Material Button default | 14sp | W500 | White/inherit | "Verileri Yenile" |

### Font Family

- **Default:** System font (Material Design kullanmıyor custom font)
- Dart `Theme.of(context).textTheme` kullanılıyor — platform default'leri apply ediyor

---

## 4. Spacing & Layout

### Padding (İç boşluk)

| Konum | Değer | Kullanım |
|---|---|---|
| Screen body padding | 16.0 dp | SingleChildScrollView → Padding |
| Container internal padding | 12.0 dp | Body content container |
| Vertical gap (items between) | 16.0 dp | İlk gap (title - body) |
| Secondary gap | 20.0 dp | Body - timestamp, timestamp - buttons |
| Button gap | 12.0 dp | Refresh button - Test button arası |

### Margin (Dış boşluk)

- **App Bar:** Standard (Material default, ~0)
- **Body:** Padding (margin değil, padding kullanılıyor)

### Alignment

- **Body content:** `Column` → `mainAxisAlignment: MainAxisAlignment.center` + `crossAxisAlignment: CrossAxisAlignment.start` (başlık sola hizalı, center yapılmış)
- **Scroll:** `SingleChildScrollView` (dikey scroll, örneğin landscape modda)

---

## 5. Bileşenler (Components)

### 5.1 App Bar

```dart
AppBar(
  title: const Text('Günün İçeriği'),
  backgroundColor: Colors.blue,
)
```

- **Yükseklik:** 56 dp (Material default)
- **Title Text:** Beyaz, 20sp
- **Background:** Blue (`Colors.blue`)
- **Padding:** Material default

### 5.2 Loading State

```dart
Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    const CircularProgressIndicator(),     // Spinner
    const SizedBox(height: 20),             // 20 dp gap
    Text(
      'Widget verileri yükleniyor...',
      style: Theme.of(context).textTheme.bodyLarge,
    ),
  ],
)
```

- **Spinner:** Material default circular progress indicator (blue)
- **Text:** Body large style
- **Alignment:** Center

### 5.3 Content Container (Body Box)

```dart
Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.grey[100],               // Açık gri background
    borderRadius: BorderRadius.circular(8), // 8 dp köşe radius
    border: Border.all(color: Colors.grey[300]!), // Gri border
  ),
  child: Text(widgetBody, ...),
)
```

- **Background:** Grey 100 (light gray)
- **Border Radius:** 8 dp (soft corners)
- **Border:** 1 dp grey border
- **Padding:** 12 dp (internal)

### 5.4 Title Text

```dart
Text(
  widgetTitle,
  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  ),
)
```

- **Style:** Headline small + bold
- **Color:** Black87 (dark text)
- **Ellipsis:** Varsayılan (overflow handling)

### 5.5 Body Text

```dart
Text(
  widgetBody,
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: Colors.black54,
  ),
)
```

- **Style:** Body medium
- **Color:** Black54 (medium gray text)
- **Line Breaking:** Default (wrapping)

### 5.6 Timestamp Text

```dart
if (widgetUpdatedAt.isNotEmpty)
  Text(
    'Güncelleme: $widgetUpdatedAt',
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Colors.grey,
    ),
  )
```

- **Style:** Body small
- **Color:** Grey (lighter)
- **Conditional:** Yalnızca data varsa göster

### 5.7 Buttons

#### Refresh Button

```dart
ElevatedButton(
  onPressed: _loadWidgetData,
  child: const Text('Verileri Yenile'),
)
```

- **Style:** ElevatedButton (Material default blue)
- **Width:** Wrap content (default)
- **Height:** 48 dp (Material button height)
- **Text Color:** White
- **Background:** Blue

#### Test Notification Button

```dart
ElevatedButton.icon(
  onPressed: _sendTestNotification,
  icon: const Icon(Icons.send),
  label: const Text('Test Notification Gönder'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.orange,
  ),
)
```

- **Style:** ElevatedButton.icon
- **Icon:** `Icons.send` (send/arrow icon)
- **Background:** Orange (`Colors.orange`)
- **Text Color:** White (default from orange theme)
- **Icon Position:** Left (default)
- **Button Width:** Wrap content
- **Button Height:** 48 dp

---

## 6. Responsive Design

### Landscape Mode

- `SingleChildScrollView` wrapped → horizontal scroll mümkün
- `Column` yine vertical layout (scroll önerilir wide screens'de)

### Mobile Orientations

- **Portrait (default):** 375-430 dp width (standard)
- **Landscape:** 800+ dp width (scroll enabled via SingleChildScrollView)

### Tablet Support

- Layout fixed column, padding fixed → scalable

---

## 7. Icons

| Icon | Location | Purpose |
|---|---|---|
| `Icons.send` | Test Notification Button | Notification gönderme action |
| (default circle) | Loading spinner | Progress indication |

---

## 8. Spacing Reference (Quick Lookup)

```
16 dp  = Default screen padding
12 dp  = Container internal padding
20 dp  = Major vertical gaps
8 dp   = Border radius
56 dp  = App Bar height
48 dp  = Button height (standard)
```

---

## 9. State-Based Design

### Loading State (isLoading = true)

- **Visible:** Spinner + "Widget verileri yükleniyor..." text
- **Hidden:** Title, body, buttons, timestamp
- **Layout:** Centered column

### Loaded State (isLoading = false)

- **Visible:** Title, body container, timestamp (if not empty), refresh + test buttons
- **Hidden:** Spinner + loading text
- **Layout:** Scrollable column with padding

---

## 10. Color Hex Reference (For Designers)

```json
{
  "primary_blue": "#2196F3",
  "accent_orange": "#FF9800",
  "white": "#FFFFFF",
  "black_87": "#212121",
  "grey_100": "#F5F5F5",
  "grey_300": "#E0E0E0",
  "grey_default": "#9E9E9E",
  "black_54": "#757575"
}
```

---

## 11. How to Recreate This UI

### In Figma / Sketch:

1. **Frame:** Mobile (375x667 or responsive)
2. **App Bar:** Rectangle 375x56, blue fill, white "Günün İçeriği" text
3. **Body Background:** Rectangle 375x611, white fill
4. **Content Group:** Column, 16dp padding, center alignment
5. **Title:** "Günün İçeriği", headlineSmall bold, black87
6. **Body Container:** Rectangle with 8dp radius, grey[100] fill, grey[300] border 1dp, 12dp padding
7. **Timestamp:** "Güncelleme: ...", bodySmall, grey
8. **Buttons:** Two ElevatedButtons (blue + orange), 48dp height, stacked vertical with 12dp gap

### In Code (Flutter):

See [lib/main.dart](lib/main.dart) for exact widget tree and styling.

---

## 12. Accessibility Notes

- **Color Contrast:** Blue on white (WCAG AA compliant)
- **Text Size:** Min 14sp (readable)
- **Button Size:** 48dp (tappable)
- **Icon Size:** Default (24dp, tappable)

---

# Home Screen Widget Design (iOS WidgetKit)

## Widget Özeti

**Adı:** Günlük İçerik Widget  
**Türü:** iOS WidgetKit (Lock Screen & Home Screen)  
**Desteklenen Boyutlar:** Small (2x2) ve Medium (2x4)  
**Refresh Sıklığı:** Her saat (best-effort policy)  
**Veri Kaynağı:** UserDefaults (App Group: `group.com.siyazilim.periodicallynotification`)

---

## Widget Layout

### Small Widget (2x2)

```
┌──────────────┐
│ Günün İçeriği│  Title (headline, bold, white)
│              │
│ Bu bir örnek │  Body (subheadline, light gray)
│ içerik metni │
│ dir. Widget' │  4 satırdan fazlası kesiliyor
│ ta görüntüle │  (lineLimit: 4)
│              │
│       14:30  │  Timestamp (caption2, darker gray)
└──────────────┘

Background: Purple (#6200EE)
Padding: 16 dp (uniform)
Spacing: 8 dp (title-body gap, body-timestamp gap)
```

### Medium Widget (2x4)

- Same layout as Small, but with more horizontal space
- Body text can wrap more naturally
- Content remains vertically centered/top-aligned with spacing

---

## Widget Color Palette

| Element | Renk | Hex Code | SwiftUI (RGB) | Kullanım |
|---|---|---|---|---|
| Background | Mor | #6200EE | `Color(red: 0.38, green: 0.0, blue: 0.93)` | Widget arka planı |
| Title Text | Beyaz | #FFFFFF | `Color(red: 1.0, green: 1.0, blue: 1.0)` | Widget başlığı |
| Body Text | Açık Gri | #E0E0E0 | `Color(red: 0.878, green: 0.878, blue: 0.878)` | Widget içeriği |
| Timestamp Text | Koyu Gri | #B0B0B0 | `Color(red: 0.69, green: 0.69, blue: 0.69)` | "Son güncelleme: ..." |

### Renk Uyumu

- **Purple background** — mor widget, light text kontrastı yüksek (WCAG AAA)
- **White title** — maksimum kontras, okunabilir
- **Light gray body** — title'dan daha hafif, ancak yine okunabilir
- **Darker gray timestamp** — meta info, daha az vurgulanmış

---

## Widget Tipografi (Typography)

| Element | SwiftUI Font | Size | Weight | Color | Örnek |
|---|---|---|---|---|---|
| Title | `.headline` | ~17pt | Bold | White | "Günün İçeriği" |
| Body | `.subheadline` | ~15pt | Regular | Light Gray | Widget content |
| Timestamp | `.caption2` | ~11pt | Regular | Dark Gray | "Son güncelleme: 14/01/2024 09:00" |

---

## Widget Spacing

| Konum | Değer | Kullanım |
|---|---|---|
| Container padding | 16 dp | Widget edges |
| Title-Body gap | 8 dp | Vertical spacing |
| Body-Timestamp gap | 8 dp | Vertical spacing |
| VStack spacing | 0 (custom with padding) | Fine control |

---

## Widget State & Data

### Data Storage

- **UserDefaults Suite:** `group.com.siyazilim.periodicallynotification` (App Group)
- **Keys:**
  - `widget_title` — Widget title (string)
  - `widget_body` — Widget body content (string)
  - `widget_updatedAt` — ISO 8601 timestamp (e.g., "2024-01-15T09:00:00.000Z")

### Placeholder State

Görüntülenecek örnek veriler (widget önizlemesi veya ilk yükleme):

```swift
title: "Günün İçeriği"
body: "Örnek içerik metni burada görünecek..."
updatedAt: nil
```

### Fallback State

Eğer UserDefaults verisi yoksa:

```swift
title: "Günün İçeriği"
body: "İçerik yükleniyor..."
updatedAt: nil
```

### Live State

Notification/background task tarafından güncellenen veriler:

```swift
title: "Günün Özel İçeriği"
body: "Bugünün başlık yazısı ve özet bilgisi..."
updatedAt: "2024-01-15T09:00:00.000Z" (ISO 8601)
```

---

## Widget Refresh Policy

```swift
.after(nextUpdate) // 1 saat sonra yeniden kontrol et
```

- Refresh süresi: **1 saat**
- Policy: **Best-effort** (sistem kaynakları veya battery durumuna bağlı)
- İçerik değişikliğinde **push notification** ile anlık update (recommended)

---

## Widget Text Truncation Rules

| Element | Line Limit | Truncation | Behavior |
|---|---|---|---|
| Title | 2 lines | `lineLimit(2)` | 2 satırdan fazlası kesiliyor |
| Body | 4 lines | `lineLimit(4)` | 4 satırdan fazlası kesiliyor |
| Timestamp | 1 line | (implicit) | Tek satır, tam görüntülenir |

**fixedSize:** Body text yüksekliği dinamik (responsive)

---

## Widget VStack Hierarchy

```
VStack(alignment: .leading, spacing: 0)
│
├─ Text (Title)          // .headline, bold, white
│
├─ Text (Body)           // .subheadline, light gray
│  └─ .padding(.top, 8)  // 8 dp top spacing
│
├─ Spacer(minLength: 0)  // Flexible vertical space
│
└─ HStack (Timestamp)    // Conditional, right-aligned
   └─ .padding(.top, 8)  // 8 dp top spacing
```

**Alignment:** Leading (sola hizalı başlık ve body)  
**Timestamp:** Right-aligned (HStack → Spacer → Text)

---

## Widget Preview (SwiftUI Preview)

```swift
DailyWidgetEntryView(
    entry: DailyWidgetEntry(
        date: Date(),
        title: "Günün İçeriği",
        body: "Bu bir örnek içerik metnidir. Widget'ta görüntülenecek içerik burada yer alacak.",
        updatedAt: "2024-01-15T09:00:00.000Z"
    )
)
.previewContext(WidgetPreviewContext(family: .systemSmall))
```

---

## Date Formatting

**Input Format:** ISO 8601 with fractional seconds  
**Example:** `2024-01-15T09:00:00.000Z`

**Display Format:** `dd/MM/yyyy HH:mm`  
**Display Label:** `"Son güncelleme: 15/01/2024 09:00"`

---

## How to Recreate Widget in Figma

1. **Frame:** 169x169 px (small widget size) or taller for medium
2. **Background:** Purple (#6200EE) rectangle, fill entire frame
3. **Padding:** 16 px uniform inner margin
4. **VStack Group:**
   - **Title:** "Günün İçeriği", Headline, Bold, White, 2 lines max
   - **Spacer:** 8 px gap
   - **Body:** "Örnek metin...", Subheadline, Light Gray, 4 lines max
   - **Spacer (flexible):** Push timestamp down
   - **Timestamp:** "Son güncelleme: ...", Caption2, Dark Gray, right-aligned

---

## Widget Integration Notes

- **Update Trigger:** Firebase Cloud Messaging (push) + hourly refresh
- **Data Sync:** Flutter app → UserDefaults (App Group) → Widget reads
- **Widget Extension:** `DailyWidgetExtension` target in Xcode
- **Entitlements:** App Groups (`group.com.siyazilim.periodicallynotification`)

---

**Widget Code Location:** [ios/DailyWidget/DailyWidget.swift](ios/DailyWidget/DailyWidget.swift)

---

**Last Updated:** 3 Şubat 2026  
**Maintainer:** Design Team / Development Team  
**Format:** Markdown + JSON for tooling
