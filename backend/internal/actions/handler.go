package actions

import (
	"log"
	"net/http"

	"periodically/backend/internal/auth"
	"periodically/backend/internal/gamification"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	Repo   *Repository
	Gamify *gamification.Repository
}

// Create aksiyon ekler. Idempotency-Key header, consent body'de (X-Consent-Sync: true).
func (h *Handler) Create(c *gin.Context) {
	userID, _ := c.Get(auth.UserIDKey)
	uid := userID.(string)

	consent := c.GetHeader("X-Consent-Sync") == "true"
	if !consent {
		c.JSON(http.StatusOK, gin.H{"message": "Sync declined, action not sent"})
		return
	}

	var req CreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz istek", "details": err.Error()})
		return
	}

	quoteUUID, err := h.Repo.EnsureQuote(c.Request.Context(), req.QuoteID)
	if err != nil {
		log.Printf("EnsureQuote: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Veritabanı hatası"})
		return
	}

	idempotencyKey := c.GetHeader("Idempotency-Key")
	action, ok, err := h.Repo.Create(c.Request.Context(), uid, quoteUUID, req.QuoteID, req.LocalDate, req.Note, idempotencyKey)
	if err != nil {
		log.Printf("Create action: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Aksiyon eklenemedi"})
		return
	}
	if !ok {
		c.JSON(http.StatusConflict, gin.H{"error": "Aynı idempotency key ile farklı veri gönderildi"})
		return
	}

	if err := h.Repo.UpdateStreakCache(c.Request.Context(), uid, req.LocalDate); err != nil {
		log.Printf("UpdateStreakCache: %v", err)
	}

	if h.Gamify != nil {
		if _, err := h.Gamify.SyncStreakFromActions(c.Request.Context(), uid); err != nil {
			log.Printf("SyncStreakFromActions: %v", err)
		}
	}

	c.JSON(http.StatusCreated, action)
}

// ListMine GET /api/v1/actions/me — kullanıcının tüm aksiyonları (note dahil).
func (h *Handler) ListMine(c *gin.Context) {
	userID, _ := c.Get(auth.UserIDKey)
	uid := userID.(string)
	list, err := h.Repo.ListAllForUser(c.Request.Context(), uid)
	if err != nil {
		log.Printf("ListAllForUser: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Veritabanı hatası"})
		return
	}
	if list == nil {
		list = []UserActionListItem{}
	}
	c.JSON(http.StatusOK, gin.H{"actions": list})
}

// Daily günlük aksiyon listesi. ?date=YYYY-MM-DD
func (h *Handler) Daily(c *gin.Context) {
	userID, _ := c.Get(auth.UserIDKey)
	uid := userID.(string)
	date := c.DefaultQuery("date", "")
	if date == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "date parametresi gerekli (YYYY-MM-DD)"})
		return
	}
	list, err := h.Repo.ListDaily(c.Request.Context(), uid, date)
	if err != nil {
		log.Printf("ListDaily: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Veritabanı hatası"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"actions": list})
}

// ForQuote GET /api/v1/actions/for-quote?quoteId= — bu içerik için kullanıcının son aksiyonu (detay sayfası).
func (h *Handler) ForQuote(c *gin.Context) {
	userID, _ := c.Get(auth.UserIDKey)
	uid := userID.(string)
	q := c.Query("quoteId")
	if q == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "quoteId gerekli"})
		return
	}
	a, err := h.Repo.GetLatestForUserQuote(c.Request.Context(), uid, q)
	if err != nil {
		log.Printf("GetLatestForUserQuote: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Veritabanı hatası"})
		return
	}
	if a == nil {
		c.JSON(http.StatusOK, gin.H{"action": nil})
		return
	}
	c.JSON(http.StatusOK, gin.H{"action": gin.H{
		"id":        a.ID,
		"note":      a.Note,
		"localDate": a.LocalDate,
		"createdAt": a.CreatedAt.UTC().Format("2006-01-02T15:04:05.999Z07:00"),
		"quoteId":   a.QuoteExternalID,
	}})
}

// Progress streak + last7Days.
func (h *Handler) Progress(c *gin.Context) {
	userID, _ := c.Get(auth.UserIDKey)
	uid := userID.(string)
	dates, err := h.Repo.GetUserActionDates(c.Request.Context(), uid, 30)
	if err != nil {
		log.Printf("GetUserActionDates: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Veritabanı hatası"})
		return
	}
	current, best := computeStreak(dates)
	last7 := make([]map[string]interface{}, 0)
	if len(dates) > 0 {
		for i := 0; i < 7 && i < len(dates); i++ {
			last7 = append(last7, map[string]interface{}{"date": dates[i], "count": 1})
		}
	}
	c.JSON(http.StatusOK, gin.H{
		"currentStreak": current,
		"bestStreak":    best,
		"last7Days":     last7,
	})
}
