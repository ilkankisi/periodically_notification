package dailysend

import (
	"context"
	"errors"
	"log"
	"net/http"
	"strings"

	"periodically/backend/internal/content"
	"periodically/backend/internal/push"
	"periodically/backend/pkg/mediaurl"

	"github.com/gin-gonic/gin"
)

// Handler POST /api/admin/daily-send — manuel / cron tetikleyici.
type Handler struct {
	Repo         *content.Repository
	PushRepo     *push.Repository
	APNS         *APNSSender
	AdminSecret  string
	APIPublicURL string
	MediaBucket  string
}

func (h *Handler) itemForPush(item *content.DailyItem) *content.DailyItem {
	if item == nil {
		return nil
	}
	out := *item
	if out.ImageURL != nil && strings.TrimSpace(h.APIPublicURL) != "" {
		rw := mediaurl.RewriteMinIOToProxy(h.APIPublicURL, h.MediaBucket, *out.ImageURL)
		out.ImageURL = &rw
	}
	return &out
}

// PostAdminDailySend sıradaki içeriği işaretler ve kayıtlı iOS cihazlarına APNs gönderir.
func (h *Handler) PostAdminDailySend(c *gin.Context) {
	if h.AdminSecret == "" {
		c.JSON(http.StatusServiceUnavailable, gin.H{"success": false, "error": "ADMIN_SECRET tanımlı değil"})
		return
	}
	if c.GetHeader("X-Admin-Secret") != h.AdminSecret {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "error": "yetkisiz"})
		return
	}
	item, err := h.Repo.AdvanceAndPickForSend(c.Request.Context())
	if err != nil {
		status := http.StatusInternalServerError
		if errors.Is(err, content.ErrDailyItemsEmpty) || errors.Is(err, content.ErrDailyStateMissing) {
			status = http.StatusNotFound
		}
		c.JSON(status, gin.H{"success": false, "error": err.Error()})
		return
	}
	resp := gin.H{
		"success": true,
		"itemId":  item.ID,
		"order":   item.Order,
	}
	if h.APNS == nil || h.PushRepo == nil {
		resp["apnsSkipped"] = true
		log.Printf("dailysend: APNs veya push repo yok; sadece DB güncellendi item=%s", item.ID)
		c.JSON(http.StatusOK, resp)
		return
	}
	tokens, err := h.PushRepo.ListAll(c.Request.Context())
	if err != nil {
		log.Printf("dailysend: token listesi: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "token listesi alınamadı"})
		return
	}
	if len(tokens) == 0 {
		resp["apnsSkipped"] = true
		log.Printf("dailysend: kayıtlı APNs token yok item=%s", item.ID)
		c.JSON(http.StatusOK, resp)
		return
	}
	sent, err := h.APNS.SendDailyToDevices(c.Request.Context(), h.itemForPush(item), tokens)
	resp["apnsSent"] = sent
	resp["apnsTargets"] = len(tokens)
	if err != nil && sent == 0 {
		log.Printf("dailysend: APNs hata (DB committed) item=%s err=%v", item.ID, err)
		c.JSON(http.StatusBadGateway, gin.H{"success": false, "error": err.Error(), "itemId": item.ID})
		return
	}
	if err != nil {
		resp["apnsWarning"] = err.Error()
	}
	c.JSON(http.StatusOK, resp)
}

// RunBroadcastPing kayıtlı içeriği tekrar gönderir; daily_state ve sıra ilerlemez (APNs testi).
func (h *Handler) RunBroadcastPing(ctx context.Context) (map[string]interface{}, error) {
	if h.Repo == nil {
		return nil, errors.New("repo yok")
	}
	if h.APNS == nil || h.PushRepo == nil {
		return map[string]interface{}{"apnsSkipped": true, "broadcastOnly": true}, nil
	}
	item, err := h.Repo.GetLastSentOrFirstItem(ctx)
	if err != nil {
		return nil, err
	}
	tokens, err := h.PushRepo.ListAll(ctx)
	if err != nil {
		return nil, err
	}
	if len(tokens) == 0 {
		return map[string]interface{}{
			"success": true, "itemId": item.ID, "apnsSkipped": true, "broadcastOnly": true,
		}, nil
	}
	sent, err := h.APNS.SendDailyToDevices(ctx, h.itemForPush(item), tokens)
	out := map[string]interface{}{
		"success": true, "itemId": item.ID, "order": item.Order,
		"apnsSent": sent, "apnsTargets": len(tokens), "broadcastOnly": true,
	}
	if err != nil && sent == 0 {
		return out, err
	}
	if err != nil {
		out["apnsWarning"] = err.Error()
	}
	return out, nil
}
