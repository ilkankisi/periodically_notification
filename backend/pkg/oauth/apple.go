package oauth

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/MicahParks/keyfunc/v3"
	"github.com/golang-jwt/jwt/v5"
)

const appleIssuer = "https://appleid.apple.com"

var (
	appleJWKS     keyfunc.Keyfunc
	appleJWKSOnce sync.Once
	appleJWKSErr  error
)

func ensureAppleJWKS() error {
	appleJWKSOnce.Do(func() {
		// Uzun ömürlü ctx; JWKS arka planda yenilenir
		appleJWKS, appleJWKSErr = keyfunc.NewDefaultCtx(context.Background(), []string{"https://appleid.apple.com/auth/keys"})
	})
	return appleJWKSErr
}

type appleClaims struct {
	Email string `json:"email"`
	jwt.RegisteredClaims
}

// ValidateAppleIdentityToken Apple identity_token (JWT) doğrular.
func ValidateAppleIdentityToken(ctx context.Context, rawToken string, validAudiences []string) (sub, email string, err error) {
	rawToken = strings.TrimSpace(rawToken)
	if rawToken == "" {
		return "", "", errors.New("boş identity_token")
	}
	if len(validAudiences) == 0 {
		return "", "", errors.New("APPLE_CLIENT_IDS tanımlı değil")
	}
	if err := ensureAppleJWKS(); err != nil {
		return "", "", fmt.Errorf("apple jwks: %w", err)
	}
	kf := appleJWKS.KeyfuncCtx(ctx)
	var claims appleClaims
	// Apple identity_token bazen RS256, bazen ES256 ile imzalanır; JWKS'teki kty ile uyumlu.
	token, err := jwt.ParseWithClaims(rawToken, &claims, kf,
		jwt.WithValidMethods([]string{
			jwt.SigningMethodRS256.Alg(),
			jwt.SigningMethodES256.Alg(),
		}),
		jwt.WithLeeway(2*time.Minute),
		jwt.WithPaddingAllowed(),
	)
	if err != nil {
		return "", "", fmt.Errorf("apple jwt: %w", err)
	}
	if token == nil || !token.Valid {
		return "", "", errors.New("apple jwt: token geçersiz veya süresi dolmuş")
	}
	if !strings.EqualFold(claims.Issuer, appleIssuer) {
		return "", "", errors.New("apple iss uyuşmuyor")
	}
	audList := claims.Audience
	if len(audList) == 0 {
		return "", "", errors.New("apple aud yok")
	}
	ok := false
	for _, want := range validAudiences {
		want = strings.TrimSpace(want)
		if want == "" {
			continue
		}
		if slices.Contains(audList, want) {
			ok = true
			break
		}
	}
	if !ok {
		return "", "", errors.New("apple aud uyuşmuyor")
	}
	if claims.Subject == "" {
		return "", "", errors.New("apple sub yok")
	}
	email = strings.TrimSpace(claims.Email)
	return claims.Subject, email, nil
}
