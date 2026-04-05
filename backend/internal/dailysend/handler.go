package dailysend

import (
	"errors"
	"log"
	"net/http"

	"periodically/backend/internal/content"
	"periodically/backend/internal/push"

	"github.com/gin-gonic/gin"
)

// Handler POST /api/admin/daily-send — manuel / cron tetikleyici.
type Handler struct {
	Repo        *content.Repository
	PushRepo    *push.Repository
	APNS        *APNSSender
	AdminSecret string
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
	sent, err := h.APNS.SendDailyToDevices(c.Request.Context(), item, tokens)
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
