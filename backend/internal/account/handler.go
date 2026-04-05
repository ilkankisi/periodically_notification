package account

import (
	"net/http"

	"periodically/backend/internal/auth"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	AuthRepo *auth.Repository
}

func NewHandler(authRepo *auth.Repository) *Handler {
	return &Handler{AuthRepo: authRepo}
}

// Delete hesabı soft delete yapar.
func (h *Handler) Delete(c *gin.Context) {
	userID, _ := c.Get(auth.UserIDKey)
	uid := userID.(string)

	if err := h.AuthRepo.SoftDelete(c.Request.Context(), uid); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Hesap silinemedi"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Hesap silindi"})
}
