package gamification

import (
	"log"
	"net/http"

	"periodically/backend/internal/auth"

	"github.com/gin-gonic/gin"
)

// Handler GET /api/v1/gamification
type Handler struct {
	Repo *Repository
}

func (h *Handler) GetMe(c *gin.Context) {
	v, ok := c.Get(auth.UserIDKey)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Giriş gerekli"})
		return
	}
	uid, ok := v.(string)
	if !ok || uid == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Giriş gerekli"})
		return
	}
	if err := h.Repo.SyncSocialAggregatesFromComments(c.Request.Context(), uid); err != nil {
		log.Printf("gamification SyncSocialAggregatesFromComments: %v", err)
	}
	if _, err := h.Repo.SyncStreakFromActions(c.Request.Context(), uid); err != nil {
		log.Printf("gamification SyncStreakFromActions: %v", err)
	}
	state, err := h.Repo.GetState(c.Request.Context(), uid)
	if err != nil {
		log.Printf("gamification GetState: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Veritabanı hatası"})
		return
	}
	c.JSON(http.StatusOK, state)
}
