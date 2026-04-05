package dailysend

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"periodically/backend/internal/content"

	"github.com/sideshow/apns2"
	"github.com/sideshow/apns2/token"
)

// APNSSender Apple Push Notification service (HTTP/2, .p8 anahtar).
type APNSSender struct {
	client *apns2.Client
	topic  string
}

func NewAPNSSender(p8Path, keyID, teamID, topic string, production bool) (*APNSSender, error) {
	if p8Path == "" || keyID == "" || teamID == "" || topic == "" {
		return nil, fmt.Errorf("APNS yapılandırması eksik (APNS_KEY_PATH, APNS_KEY_ID, APNS_TEAM_ID, APNS_TOPIC)")
	}
	authKey, err := token.AuthKeyFromFile(p8Path)
	if err != nil {
		return nil, err
	}
	tok := &token.Token{
		AuthKey: authKey,
		KeyID:   keyID,
		TeamID:  teamID,
	}
	client := apns2.NewTokenClient(tok)
	if production {
		client = client.Production()
	} else {
		client = client.Development()
	}
	return &APNSSender{client: client, topic: topic}, nil
}

func apnsDailyPayload(item *content.DailyItem) ([]byte, error) {
	img := ""
	if item.ImageURL != nil {
		img = *item.ImageURL
	}
	updated := time.Now().UTC().Format(time.RFC3339Nano)
	apsBody := item.Title
	if apsBody == "" {
		apsBody = "Yeni içerik hazır"
	}
	payload := map[string]interface{}{
		"aps": map[string]interface{}{
			"alert": map[string]string{
				"title": "Günün İçeriği",
				"body":  apsBody,
			},
			"sound":             "default",
			"content-available": 1,
		},
		"type":      "DAILY_WIDGET",
		"order":     strconv.Itoa(item.Order),
		"itemId":    item.ID,
		"title":     item.Title,
		"body":      item.Body,
		"updatedAt": updated,
		"imageUrl":  img,
	}
	return json.Marshal(payload)
}

// SendDailyToDevices her jetona aynı günlük bildirimi gönderir.
func (s *APNSSender) SendDailyToDevices(ctx context.Context, item *content.DailyItem, deviceTokens []string) (success int, lastErr error) {
	_ = ctx
	if len(deviceTokens) == 0 {
		return 0, nil
	}
	payloadBytes, err := apnsDailyPayload(item)
	if err != nil {
		return 0, err
	}
	for _, tok := range deviceTokens {
		n := &apns2.Notification{
			DeviceToken: tok,
			Topic:       s.topic,
			Payload:     payloadBytes,
			PushType:    apns2.PushTypeAlert,
		}
		res, err := s.client.Push(n)
		if err != nil {
			lastErr = err
			continue
		}
		if !res.Sent() {
			lastErr = fmt.Errorf("apns: %s (%d)", res.Reason, res.StatusCode)
			continue
		}
		success++
	}
	return success, lastErr
}

// SendCommentReplyToDevices yorum yanıtı — yalnızca ilgili kullanıcının cihazlarına.
func (s *APNSSender) SendCommentReplyToDevices(ctx context.Context, deviceTokens []string, title, body, itemID, parentCommentID, replyCommentID string) (success int, lastErr error) {
	_ = ctx
	if len(deviceTokens) == 0 {
		return 0, nil
	}
	t := strings.TrimSpace(title)
	if t == "" {
		t = "Yeni yanıt"
	}
	b := strings.TrimSpace(body)
	if b == "" {
		b = "Yorumunuza yanıt var."
	}
	payload := map[string]interface{}{
		"aps": map[string]interface{}{
			"alert": map[string]string{
				"title": t,
				"body":  b,
			},
			"sound": "default",
		},
		"type":              "COMMENT_REPLY",
		"itemId":            itemID,
		"parentCommentId":   parentCommentID,
		"replyCommentId":    replyCommentID,
	}
	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return 0, err
	}
	for _, tok := range deviceTokens {
		n := &apns2.Notification{
			DeviceToken: tok,
			Topic:       s.topic,
			Payload:     payloadBytes,
			PushType:    apns2.PushTypeAlert,
		}
		res, err := s.client.Push(n)
		if err != nil {
			lastErr = err
			continue
		}
		if !res.Sent() {
			lastErr = fmt.Errorf("apns: %s (%d)", res.Reason, res.StatusCode)
			continue
		}
		success++
	}
	return success, lastErr
}
