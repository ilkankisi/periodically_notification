package appnotifs

import (
	"log"
	"net/http"

	"periodically/backend/internal/auth"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	Repo *Repository
}

func (h *Handler) List(c *gin.Context) {
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
	rows, err := h.Repo.ListForUser(c.Request.Context(), uid, 100)
	if err != nil {
		log.Printf("appnotifs list: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Bildirimler yüklenemedi"})
		return
	}
	if rows == nil {
		rows = []Row{}
	}
	c.JSON(http.StatusOK, gin.H{"notifications": rows})
}

func (h *Handler) MarkAllRead(c *gin.Context) {
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
	if err := h.Repo.MarkAllRead(c.Request.Context(), uid); err != nil {
		log.Printf("appnotifs mark all: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "İşlem başarısız"})
		return
	}
	c.Status(http.StatusNoContent)
}
