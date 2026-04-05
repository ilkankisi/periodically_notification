// internal/auth/handler.go
//
// Register: email + şifre ile kayıt, JWT döner.
// Login: email + şifre ile giriş, JWT döner.
// NEDEN bcrypt?: Şifreleri düz metin saklamayız. bcrypt güvenli hash algoritması.

package auth

import (
	"log"
	"net/http"
	"strings"

	"periodically/backend/pkg/firebase"
	"periodically/backend/pkg/jwt"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

type Handler struct {
	Repo                 *Repository
	JWTSecret            string
	GoogleOAuthAudiences []string
	AppleOAuthAudiences  []string
}

// TokenRequest Firebase ID token ile JWT almak için.
type TokenRequest struct {
	IdToken string `json:"idToken" binding:"required"`
}

// RegisterRequest API istek gövdesi.
type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
}

// LoginRequest aynı yapı.
type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

// AuthResponse token + user döner.
type AuthResponse struct {
	Token string       `json:"token"`
	User  UserResponse `json:"user"`
}

// Register yeni kullanıcı oluşturur.
func (h *Handler) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz istek", "details": err.Error()})
		return
	}
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))

	// Email zaten var mı?
	_, err := h.Repo.FindByEmail(c.Request.Context(), req.Email)
	if err == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "Bu email zaten kayıtlı"})
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Şifre işlenemedi"})
		return
	}

	user, err := h.Repo.Create(c.Request.Context(), req.Email, string(hash))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Kayıt oluşturulamadı"})
		return
	}

	token, err := generateAndReturnToken(h.JWTSecret, user, c)
	if err != nil {
		return
	}
	c.JSON(http.StatusCreated, AuthResponse{
		Token: token,
		User:  toUserResponse(user),
	})
}

// Token Firebase ID token verify eder, JWT döner. Kullanıcı yoksa oluşturur.
func (h *Handler) Token(c *gin.Context) {
	var req TokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "idToken gerekli"})
		return
	}
	uid, email, name, photoURL, err := firebase.VerifyIDToken(c.Request.Context(), req.IdToken)
	if err != nil {
		log.Printf("Firebase verify: %v", err)
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Geçersiz token"})
		return
	}
	user, err := h.Repo.FindByFirebaseUID(c.Request.Context(), uid)
	if err != nil {
		user, err = h.Repo.CreateFromFirebase(c.Request.Context(), uid, email, name, photoURL)
		if err != nil {
			log.Printf("CreateFromFirebase: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Kullanıcı oluşturulamadı"})
			return
		}
	}
	token, err := jwt.GenerateToken(h.JWTSecret, user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Token oluşturulamadı"})
		return
	}
	c.JSON(http.StatusOK, AuthResponse{Token: token, User: toUserResponse(user)})
}

// Me giriş yapmış kullanıcının bilgilerini döner.
// RequireAuth middleware'den sonra çağrılır; user_id context'te olur.
func (h *Handler) Me(c *gin.Context) {
	userID, exists := c.Get(UserIDKey)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Giriş yapmanız gerekiyor"})
		return
	}
	user, err := h.Repo.GetByID(c.Request.Context(), userID.(string))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Kullanıcı bulunamadı"})
		return
	}
	c.JSON(http.StatusOK, toUserResponse(user))
}

// Login mevcut kullanıcıyla giriş (email/password).
func (h *Handler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Geçersiz istek", "details": err.Error()})
		return
	}
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))

	user, err := h.Repo.FindByEmail(c.Request.Context(), req.Email)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Email veya şifre hatalı"})
		return
	}

	if user.PasswordHash == nil || *user.PasswordHash == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Bu hesap Apple veya Google ile giriş yapıyor"})
		return
	}
	if err := bcrypt.CompareHashAndPassword([]byte(*user.PasswordHash), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Email veya şifre hatalı"})
		return
	}

	token, err := generateAndReturnToken(h.JWTSecret, user, c)
	if err != nil {
		return
	}
	c.JSON(http.StatusOK, AuthResponse{
		Token: token,
		User:  toUserResponse(user),
	})
}

func generateAndReturnToken(secret string, user *User, c *gin.Context) (string, error) {
	token, err := jwt.GenerateToken(secret, user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Token oluşturulamadı"})
		return "", err
	}
	return token, nil
}

func toUserResponse(u *User) UserResponse {
	r := UserResponse{ID: u.ID, Email: u.Email, CreatedAt: u.CreatedAt}
	if u.DisplayName != nil {
		r.DisplayName = *u.DisplayName
	}
	if u.PhotoURL != nil {
		r.PhotoURL = *u.PhotoURL
	}
	return r
}
