package push

import (
	"net/http"
	"strings"

	"periodically/backend/internal/auth"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	Repo *Repository
}

type apnsTokenRequest struct {
	DeviceToken string `json:"deviceToken" binding:"required"`
}

// PostApnsToken POST /api/push/apns-token — misafir: günlük yayın için jeton (user_id korunur).
func (h *Handler) PostApnsToken(c *gin.Context) {
	var req apnsTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "deviceToken gerekli"})
		return
	}
	tok := strings.TrimSpace(req.DeviceToken)
	if len(tok) < 32 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "geçersiz deviceToken"})
		return
	}
	if err := h.Repo.Upsert(c.Request.Context(), tok); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "kayıt başarısız"})
		return
	}
	c.Status(http.StatusNoContent)
}

// PostApnsTokenForUser POST /api/v1/push/apns-token — JWT ile kullanıcıya bağlar (hedefli push).
func (h *Handler) PostApnsTokenForUser(c *gin.Context) {
	userID, _ := c.Get(auth.UserIDKey)
	uid := userID.(string)

	var req apnsTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "deviceToken gerekli"})
		return
	}
	tok := strings.TrimSpace(req.DeviceToken)
	if len(tok) < 32 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "geçersiz deviceToken"})
		return
	}
	if err := h.Repo.UpsertForUser(c.Request.Context(), &uid, tok); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "kayıt başarısız"})
		return
	}
	c.Status(http.StatusNoContent)
}

// PostApnsTokenDisassociate POST /api/v1/push/apns-token/disassociate — çıkışta user_id kaldırır.
func (h *Handler) PostApnsTokenDisassociate(c *gin.Context) {
	userID, _ := c.Get(auth.UserIDKey)
	uid := userID.(string)

	var req apnsTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "deviceToken gerekli"})
		return
	}
	tok := strings.TrimSpace(req.DeviceToken)
	if len(tok) < 32 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "geçersiz deviceToken"})
		return
	}
	if err := h.Repo.DisassociateUser(c.Request.Context(), uid, tok); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "işlem başarısız"})
		return
	}
	c.Status(http.StatusNoContent)
}
