// pkg/jwt/jwt.go
//
// JWT token oluşturma ve doğrulama.
// NEDEN ayrı paket?: Auth handler'lardan bağımsız; başka yerlerde de kullanılabilir.

package jwt

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Claims JWT içindeki veriler. "sub" = subject = user ID.
// NEDEN sub?: JWT standart claim; çoğu kütüphane bunu kullanır.
type Claims struct {
	Subject string `json:"sub"`
	jwt.RegisteredClaims
}

const defaultExpiration = 7 * 24 * time.Hour // 7 gün

// GenerateToken userID için JWT oluşturur.
func GenerateToken(secret string, userID string) (string, error) {
	claims := Claims{
		Subject: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(defaultExpiration)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "periodically-backend",
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

// ParseToken token string'den userID döner. Geçersizse hata.
func ParseToken(secret string, tokenString string) (string, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("beklenmeyen imza yöntemi")
		}
		return []byte(secret), nil
	})
	if err != nil {
		return "", err
	}
	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return "", fmt.Errorf("geçersiz token")
	}
	return claims.Subject, nil
}
