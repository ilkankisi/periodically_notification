# Go backend’de FCM push (tek kaynak)

Uygulama **`firebase_messaging`** ile topic **`daily_widget_all`** dinliyor. Push’u **Go’dan** göndermek için Firebase Admin SDK (`messaging`) kullanılır; HTTP v1 ile aynı sonuç.

## 1. Bağımlılık

`backendGo/go.mod` içinde:

```text
require firebase.google.com/go/v4 v4.15.0
require google.golang.org/api v0.XXX  // firebase ile uyumlu sürüm (go mod tidy)
```

```bash
go get firebase.google.com/go/v4@latest
go mod tidy
```

## 2. Ortam değişkenleri

| Değişken | Açıklama |
|----------|-----------|
| `GOOGLE_APPLICATION_CREDENTIALS` | Opsiyonel: servis hesabı JSON dosya yolu |
| `FCM_SERVICE_ACCOUNT_PATH` | Tercih: sadece FCM için JSON yolu |
| `FIREBASE_PROJECT_ID` veya `GCP_PROJECT` | Proje ID (`GoogleService-Info.plist` / Firebase konsol) |
| `FCM_TOPIC` | Varsayılan: `daily_widget_all` |

Servis hesabı: Firebase Console → Project settings → Service accounts → Generate new private key (JSON).

## 3. Örnek paket: `internal/fcm`

**`internal/fcm/fcm.go`**

```go
package fcm

import (
	"context"
	"fmt"
	"os"
	"strings"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

type Client struct {
	topic   string
	messaging *messaging.Client
}

func NewClient(ctx context.Context) (*Client, error) {
	projectID := strings.TrimSpace(os.Getenv("FIREBASE_PROJECT_ID"))
	if projectID == "" {
		projectID = strings.TrimSpace(os.Getenv("GCP_PROJECT"))
	}
	if projectID == "" {
		return nil, fmt.Errorf("FIREBASE_PROJECT_ID or GCP_PROJECT required")
	}

	topic := strings.TrimSpace(os.Getenv("FCM_TOPIC"))
	if topic == "" {
		topic = "daily_widget_all"
	}

	var opts []option.ClientOption
	if p := strings.TrimSpace(os.Getenv("FCM_SERVICE_ACCOUNT_PATH")); p != "" {
		opts = append(opts, option.WithCredentialsFile(p))
	}

	app, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: projectID}, opts...)
	if err != nil {
		return nil, err
	}
	mc, err := app.Messaging(ctx)
	if err != nil {
		return nil, err
	}
	return &Client{topic: topic, messaging: mc}, nil
}

func clip(s string, max int) string {
	s = strings.TrimSpace(s)
	if max <= 0 || len(s) <= max {
		return s
	}
	return s[:max] + "…"
}

// DailyWidgetPayload Flutter [FirebaseService._handleMessage] ile uyumlu (data string map).
func (c *Client) SendDailyWidget(ctx context.Context, itemID, title, body, imageURL, updatedRFC3339 string) (string, error) {
	data := map[string]string{
		"type":       "DAILY_WIDGET",
		"itemId":     itemID,
		"title":      title,
		"body":       body,
		"imageUrl":   imageURL,
		"updatedAt":  updatedRFC3339,
	}

	msg := &messaging.Message{
		Topic: c.topic,
		Data:  data,
		Notification: &messaging.Notification{
			Title: clip(title, 80),
			Body:  clip(body, 160),
		},
		Android: &messaging.AndroidConfig{
			Priority: "high",
		},
		APNS: &messaging.APNSConfig{
			Headers: map[string]string{
				"apns-priority": "10",
			},
			Payload: &messaging.APNSPayload{
				Aps: &messaging.Aps{
					ContentAvailable: true,
					Sound:            "default",
				},
			},
		},
	}
	return c.messaging.Send(ctx, msg)
}
```

## 4. `POST /api/admin/daily-send` içinde kullanım

Örnek akış:

1. `X-Admin-Secret` doğrula.
2. Transaction: sıradaki `daily_items` satırını seç / `daily_state` güncelle (mevcut mantığın).
3. `fcmClient.SendDailyWidget(ctx, row.ID.String(), row.Title, row.Body, row.ImageURL, row.SentAt.UTC().Format(time.RFC3339))`
4. Hata olursa log + uygun HTTP kodu (FCM bazen geçici hata döner; retry stratejisi isteğe bağlı).

## 5. Flutter ile uyum

- **`data.type`**: `DAILY_WIDGET` (veya `DAILY_WIDGET_UPDATE`).
- Tüm **`data` değerleri string** olmalı (FCM kuralı).
- **`Notification`** bloğu: tepsi / kilit ekranı metni (Android + iOS).
- **`Android.Priority: high`**: uygulama arka plandayken data iletimi için önemli.
- **`APNS`**: APNs alanlarını boş bırakma; yukarıdaki örnek temel ihtiyacı karşılar.

## 6. Xcode / Apple tarafı

Go kodu **APNs’e doğrudan gitmez**; FCM → APNs köprüsü Firebase projende olmalı:

- Firebase Console’da **iOS uygulaması** + **APNs key** tanımlı.
- Xcode’da **Push Notifications** ve gerekiyorsa **Background Modes → Remote notifications**.

## 7. Test

```bash
# Sunucu FCM_* ve FIREBASE_PROJECT_ID ile çalışırken
curl -sS -X POST "http://127.0.0.1:8080/api/admin/daily-send" \
  -H "X-Admin-Secret: $ADMIN_SECRET"
```

Telefonda uygulama açılıp topic’e subscribe olduktan sonra bildirim düşmeli.

---

**Kaynak kod:** Go API bu monorepoda **`backend/`** altında (modül `periodically/backend`). FCM günlük gönderimi: `internal/dailysend/fcm.go` + `internal/dailysend/handler.go`, route: `POST /api/admin/daily-send`.
