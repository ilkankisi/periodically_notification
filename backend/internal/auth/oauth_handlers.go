package auth

import (
	"log"
	"net/http"
	"strings"

	"periodically/backend/pkg/jwt"
	"periodically/backend/pkg/oauth"

	"github.com/gin-gonic/gin"
)

// OAuthGoogleRequest Google Sign-In id_token.
type OAuthGoogleRequest struct {
	IDToken string `json:"idToken" binding:"required"`
}

// OAuthAppleRequest Apple identityToken + ilk girişte isim (opsiyonel).
type OAuthAppleRequest struct {
	IdentityToken string `json:"identityToken" binding:"required"`
	Email         string `json:"email"`
	FullName      string `json:"fullName"`
}

// OAuthGoogle POST /api/auth/oauth/google
func (h *Handler) OAuthGoogle(c *gin.Context) {
	if len(h.GoogleOAuthAudiences) == 0 {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Google OAuth yapılandırılmamış"})
		return
	}
	var req OAuthGoogleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "idToken gerekli"})
		return
	}
	sub, email, name, picture, err := oauth.ValidateGoogleIDToken(c.Request.Context(), req.IDToken, h.GoogleOAuthAudiences)
	if err != nil {
		log.Printf("OAuthGoogle validate: %v", err)
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Geçersiz Google token"})
		return
	}
	user, err := h.Repo.UpsertGoogleUser(c.Request.Context(), sub, email, name, picture)
	if err != nil {
		log.Printf("OAuthGoogle upsert: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Kullanıcı oluşturulamadı"})
		return
	}
	token, err := jwt.GenerateToken(h.JWTSecret, user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Token oluşturulamadı"})
		return
	}
	c.JSON(http.StatusOK, AuthResponse{Token: token, User: toUserResponse(user)})
}

// OAuthApple POST /api/auth/oauth/apple
func (h *Handler) OAuthApple(c *gin.Context) {
	if len(h.AppleOAuthAudiences) == 0 {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Apple OAuth yapılandırılmamış"})
		return
	}
	var req OAuthAppleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "identityToken gerekli"})
		return
	}
	sub, emailFromToken, err := oauth.ValidateAppleIdentityToken(c.Request.Context(), req.IdentityToken, h.AppleOAuthAudiences)
	if err != nil {
		log.Printf("OAuthApple validate: %v", err)
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Geçersiz Apple token"})
		return
	}
	email := strings.TrimSpace(req.Email)
	if email == "" {
		email = emailFromToken
	}
	display := strings.TrimSpace(req.FullName)
	user, err := h.Repo.UpsertAppleUser(c.Request.Context(), sub, email, display)
	if err != nil {
		log.Printf("OAuthApple upsert: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Kullanıcı oluşturulamadı"})
		return
	}
	token, err := jwt.GenerateToken(h.JWTSecret, user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Token oluşturulamadı"})
		return
	}
	c.JSON(http.StatusOK, AuthResponse{Token: token, User: toUserResponse(user)})
}
