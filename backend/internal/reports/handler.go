package reports

import (
	"log"
	"net/http"

	"periodically/backend/internal/auth"

	"github.com/gin-gonic/gin"
	"github.com/jmoiron/sqlx"
)

type Handler struct {
	db *sqlx.DB
}

// CreateRequest yorum raporlama.
type CreateRequest struct {
	CommentID string `json:"commentId" binding:"required"`
	QuoteID   string `json:"quoteId" binding:"required"`
	Reason    string `json:"reason" binding:"required"`
	Details   string `json:"details"`
}

func NewHandler(db *sqlx.DB) *Handler {
	return &Handler{db: db}
}

// Create rapor oluşturur.
func (h *Handler) Create(c *gin.Context) {
	userID, _ := c.Get(auth.UserIDKey)
	reporterID := userID.(string)

	var req CreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz istek"})
		return
	}
	validReasons := map[string]bool{"spam": true, "abuse": true, "inappropriate": true, "other": true}
	if !validReasons[req.Reason] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz reason"})
		return
	}

	_, err := h.db.Exec(`INSERT INTO reports (reporter_id, comment_id, quote_id, reason, details) VALUES ($1, $2, $3, $4, $5)`,
		reporterID, req.CommentID, req.QuoteID, req.Reason, req.Details)
	if err != nil {
		log.Printf("Report create: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Rapor oluşturulamadı"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"message": "Rapor alındı"})
}
