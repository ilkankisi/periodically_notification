package blocks

import (
	"context"
	"log"
	"net/http"
	"regexp"

	"periodically/backend/internal/auth"

	"github.com/gin-gonic/gin"
	"github.com/jmoiron/sqlx"
)

var uuidRegex = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

type Handler struct {
	db        *sqlx.DB
	authRepo  *auth.Repository
}

func NewHandler(db *sqlx.DB, authRepo *auth.Repository) *Handler {
	return &Handler{db: db, authRepo: authRepo}
}

// resolveBlockedID Firebase UID veya backend UUID kabul eder, backend UUID döner.
func (h *Handler) resolveBlockedID(ctx context.Context, blockedID string) (string, error) {
	if uuidRegex.MatchString(blockedID) {
		return blockedID, nil
	}
	user, err := h.authRepo.FindByFirebaseUID(ctx, blockedID)
	if err != nil {
		return "", err
	}
	return user.ID, nil
}

// Create kullanıcı engeller. blockedId: Firebase UID veya backend UUID.
func (h *Handler) Create(c *gin.Context) {
	userID, _ := c.Get(auth.UserIDKey)
	blockerID := userID.(string)

	var req struct {
		BlockedID string `json:"blockedId" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "blockedId gerekli"})
		return
	}
	blockedUUID, err := h.resolveBlockedID(c.Request.Context(), req.BlockedID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Kullanıcı bulunamadı"})
		return
	}
	if blockedUUID == blockerID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Kendinizi engelleyemezsiniz"})
		return
	}

	_, err = h.db.Exec(`INSERT INTO blocks (blocker_id, blocked_id) VALUES ($1, $2) ON CONFLICT (blocker_id, blocked_id) DO NOTHING`,
		blockerID, blockedUUID)
	if err != nil {
		log.Printf("Block create: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Engelleme başarısız"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"message": "Kullanıcı engellendi"})
}

// Delete engeli kaldırır. userId: Firebase UID veya backend UUID.
func (h *Handler) Delete(c *gin.Context) {
	userID, _ := c.Get(auth.UserIDKey)
	blockerID := userID.(string)
	blockedParam := c.Param("userId")
	if blockedParam == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "userId gerekli"})
		return
	}
	blockedUUID, err := h.resolveBlockedID(c.Request.Context(), blockedParam)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Kullanıcı bulunamadı"})
		return
	}

	_, err = h.db.Exec(`DELETE FROM blocks WHERE blocker_id = $1 AND blocked_id = $2`, blockerID, blockedUUID)
	if err != nil {
		log.Printf("Block delete: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Engel kaldırılamadı"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Engel kaldırıldı"})
}
