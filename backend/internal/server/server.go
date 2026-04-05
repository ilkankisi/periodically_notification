// internal/server/server.go
//
// NEDEN internal/?
// Go'da "internal" klasörü özel: Bu paketi SADECE bu modül içinden import edebilirsin.
// Dış projeler "periodically/backend/internal/server" import edemez - encapsulation.

package server

import (
	"database/sql"
	"net/http"

	"periodically/backend/internal/content"

	"github.com/gin-gonic/gin"
)

// ContentHandlers content API handler'ları. Hepsi aynı repository'yi kullanır.
// NEDEN struct?: Dependency injection - test'te mock repo verebiliriz.
type ContentHandlers struct {
	Repo *content.Repository
}

// ListDailyItems tüm günlük içerikleri döner.
func (h *ContentHandlers) ListDailyItems(c *gin.Context) {
	items, err := h.Repo.ListAll(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Veritabanı hatası"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"items": items})
}

// GetDailyItem tek bir item döner. Yoksa 404.
func (h *ContentHandlers) GetDailyItem(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "id gerekli"})
		return
	}
	item, err := h.Repo.GetByID(c.Request.Context(), id)
	if err != nil {
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "İçerik bulunamadı"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Veritabanı hatası"})
		return
	}
	c.JSON(http.StatusOK, item)
}
