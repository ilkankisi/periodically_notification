// internal/auth/middleware.go
//
// RequireAuth: Token ZORUNLU. Yoksa veya geçersizse 401.
// Kullanım: GET /api/me gibi sadece giriş yapmış kullanıcıların erişebildiği route'larda.
//
// OptionalAuth (opsiyonel): Token varsa user_id set eder, yoksa devam eder.
// Kullanım: Örn. daily-items'da token varsa kişiselleştirme yapılabilir, yoksa genel liste.

package auth

import (
	"net/http"
	"strings"

	"periodically/backend/pkg/jwt"

	"github.com/gin-gonic/gin"
)

const UserIDKey = "user_id"

// RequireAuth JWT zorunlu. Authorization: Bearer <token>
func RequireAuth(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		tokenStr := extractToken(c)
		if tokenStr == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Giriş yapmanız gerekiyor"})
			c.Abort()
			return
		}
		userID, err := jwt.ParseToken(secret, tokenStr)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Geçersiz veya süresi dolmuş token"})
			c.Abort()
			return
		}
		c.Set(UserIDKey, userID)
		c.Next()
	}
}

// OptionalAuth token varsa user_id set eder, yoksa devam (guest).
func OptionalAuth(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		tokenStr := extractToken(c)
		if tokenStr == "" {
			c.Next()
			return
		}
		userID, err := jwt.ParseToken(secret, tokenStr)
		if err != nil {
			c.Next()
			return
		}
		c.Set(UserIDKey, userID)
		c.Next()
	}
}

func extractToken(c *gin.Context) string {
	auth := c.GetHeader("Authorization")
	if auth == "" {
		return ""
	}
	parts := strings.SplitN(auth, " ", 2)
	if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
		return ""
	}
	return parts[1]
}
