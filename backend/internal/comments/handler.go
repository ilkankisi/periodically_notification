package comments

import (
	"context"
	"database/sql"
	"log"
	"net/http"
	"strings"

	"periodically/backend/internal/appnotifs"
	"periodically/backend/internal/auth"
	"periodically/backend/internal/gamification"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	Repo      *Repository
	Gamify    *gamification.Repository
	AppNotifs *appnotifs.Repository
}

func (h *Handler) List(c *gin.Context) {
	itemID := strings.TrimSpace(c.Query("itemId"))
	if itemID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "itemId gerekli"})
		return
	}
	var viewer *string
	if v, ok := c.Get(auth.UserIDKey); ok {
		if s, ok := v.(string); ok && s != "" {
			viewer = &s
		}
	}
	list, err := h.Repo.ListByItem(c.Request.Context(), itemID, viewer)
	if err != nil {
		log.Printf("comments list: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Yorumlar yüklenemedi"})
		return
	}
	if list == nil {
		list = []Comment{}
	}
	c.JSON(http.StatusOK, gin.H{"comments": list})
}

func (h *Handler) Create(c *gin.Context) {
	userID, _ := c.Get(auth.UserIDKey)
	uid := userID.(string)

	var req CreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz istek"})
		return
	}
	req.ItemID = strings.TrimSpace(req.ItemID)
	req.Text = strings.TrimSpace(req.Text)
	if req.ItemID == "" || req.Text == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "itemId ve text gerekli"})
		return
	}
	var parentPtr *string
	if req.ParentCommentID != nil {
		p := strings.TrimSpace(*req.ParentCommentID)
		if p != "" {
			parentPtr = &p
		}
	}

	if h.Gamify == nil {
		if parentPtr != nil {
			pItem, err := h.Repo.ParentExternalID(c.Request.Context(), *parentPtr)
			if err == sql.ErrNoRows {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz parent yorum"})
				return
			}
			if err != nil {
				log.Printf("parent lookup: %v", err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Yorum gönderilemedi"})
				return
			}
			if pItem != req.ItemID {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz parent yorum"})
				return
			}
		}
		comment, err := h.Repo.Create(c.Request.Context(), req.ItemID, uid, req.Text, parentPtr)
		if err != nil {
			log.Printf("comment create: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Yorum gönderilemedi"})
			return
		}
		if comment == nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz yorum"})
			return
		}
		h.notifyCommentReplyIfNeeded(c.Request.Context(), parentPtr, uid, comment.DisplayName, req.ItemID, comment.ID)
		c.JSON(http.StatusCreated, comment)
		return
	}

	tx, err := h.Repo.BeginTxx(c.Request.Context())
	if err != nil {
		log.Printf("comment tx: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Yorum gönderilemedi"})
		return
	}
	defer tx.Rollback()

	if parentPtr != nil {
		pItem, err := h.Repo.ParentExternalIDTx(c.Request.Context(), tx, *parentPtr)
		if err == sql.ErrNoRows || pItem != req.ItemID {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz parent yorum"})
			return
		}
		if err != nil {
			log.Printf("parent lookup: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Yorum gönderilemedi"})
			return
		}
	}

	isReply := parentPtr != nil
	var hadOthers bool
	if !isReply {
		var e error
		hadOthers, e = h.Gamify.HadOtherAuthorsOnItem(c.Request.Context(), tx, req.ItemID, uid)
		if e != nil {
			log.Printf("had others: %v", e)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Yorum gönderilemedi"})
			return
		}
	}

	comment, err := h.Repo.CreateTx(c.Request.Context(), tx, req.ItemID, uid, req.Text, parentPtr)
	if err != nil {
		log.Printf("comment create: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Yorum gönderilemedi"})
		return
	}
	if comment == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz yorum"})
		return
	}

	newBadges, pointsAwarded, gState, err := h.Gamify.RecordCommentPostedTx(c.Request.Context(), tx, uid, hadOthers, isReply)
	if err != nil {
		log.Printf("gamification comment: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Yorum gönderilemedi"})
		return
	}

	if err := tx.Commit(); err != nil {
		log.Printf("comment commit: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Yorum gönderilemedi"})
		return
	}

	h.notifyCommentReplyIfNeeded(c.Request.Context(), parentPtr, uid, comment.DisplayName, req.ItemID, comment.ID)

	c.JSON(http.StatusCreated, gin.H{
		"comment": comment,
		"gamification": gin.H{
			"newBadges":         newBadges,
			"pointsAwarded":     pointsAwarded,
			"socialPoints":      gState.SocialPoints,
			"commentCount":      gState.CommentCount,
			"maxStreakRecorded": gState.MaxStreakRecorded,
			"unlocked":          gState.Unlocked,
		},
	})
}

// PostReaction POST /api/v1/comments/:id/reaction
func (h *Handler) PostReaction(c *gin.Context) {
	userID, _ := c.Get(auth.UserIDKey)
	uid := userID.(string)
	commentID := strings.TrimSpace(c.Param("id"))
	if commentID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "id gerekli"})
		return
	}
	var req ReactionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz istek"})
		return
	}
	if req.Value != 1 && req.Value != -1 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "value 1 veya -1 olmalı"})
		return
	}
	if h.Gamify == nil {
		c.JSON(http.StatusNotImplemented, gin.H{"error": "Tepki servisi kapalı"})
		return
	}

	tx, err := h.Repo.BeginTxx(c.Request.Context())
	if err != nil {
		log.Printf("reaction tx: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "İşlem yapılamadı"})
		return
	}
	defer tx.Rollback()

	out, err := h.Repo.ApplyReactionTx(c.Request.Context(), tx, commentID, uid, req.Value)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "Yorum bulunamadı"})
		return
	}
	if err != nil {
		log.Printf("reaction apply: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "İşlem yapılamadı"})
		return
	}
	points := gamification.ReactionPointsEarned(out.Prev, out.Now, req.Value)
	if points > 0 {
		if err := h.Gamify.AddSocialPointsTx(c.Request.Context(), tx, uid, points); err != nil {
			log.Printf("reaction points: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "İşlem yapılamadı"})
			return
		}
	}
	if err := tx.Commit(); err != nil {
		log.Printf("reaction commit: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "İşlem yapılamadı"})
		return
	}

	likes, dislikes, err := h.Repo.ReactionCounts(c.Request.Context(), commentID)
	if err != nil {
		log.Printf("reaction counts: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "İşlem yapılamadı"})
		return
	}
	st, err := h.Gamify.GetState(c.Request.Context(), uid)
	if err != nil {
		log.Printf("reaction state: %v", err)
		c.JSON(http.StatusOK, gin.H{
			"likeCount":    likes,
			"dislikeCount": dislikes,
			"myReaction":   out.Now,
			"pointsAwarded": points,
		})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"likeCount":     likes,
		"dislikeCount":  dislikes,
		"myReaction":    out.Now,
		"pointsAwarded": points,
		"gamification": gin.H{
			"socialPoints":      st.SocialPoints,
			"commentCount":      st.CommentCount,
			"maxStreakRecorded": st.MaxStreakRecorded,
			"unlocked":          st.Unlocked,
		},
	})
}

func (h *Handler) notifyCommentReplyIfNeeded(ctx context.Context, parentID *string, replierID, replierName, itemID, replyCommentID string) {
	if parentID == nil || *parentID == "" || h.AppNotifs == nil {
		return
	}
	if err := h.AppNotifs.InsertCommentReply(ctx, *parentID, replierID, replierName, itemID, replyCommentID); err != nil {
		log.Printf("in-app notify comment reply: %v", err)
	}
}
