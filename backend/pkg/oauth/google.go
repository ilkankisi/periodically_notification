package oauth

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"google.golang.org/api/idtoken"
)

// ValidateGoogleIDToken Google id_token doğrular; audiences listesinden biri eşleşmeli.
func ValidateGoogleIDToken(ctx context.Context, rawToken string, audiences []string) (sub, email, name, picture string, err error) {
	if rawToken == "" {
		return "", "", "", "", errors.New("boş id_token")
	}
	if len(audiences) == 0 {
		return "", "", "", "", errors.New("GOOGLE_OAUTH_CLIENT_IDS tanımlı değil")
	}
	var lastErr error
	for _, aud := range audiences {
		aud = strings.TrimSpace(aud)
		if aud == "" {
			continue
		}
		payload, err := idtoken.Validate(ctx, rawToken, aud)
		if err != nil {
			lastErr = err
			continue
		}
		sub = payload.Subject
		if sub == "" {
			continue
		}
		if s, _ := payload.Claims["email"].(string); s != "" {
			email = s
		}
		if s, _ := payload.Claims["name"].(string); s != "" {
			name = s
		}
		if s, _ := payload.Claims["picture"].(string); s != "" {
			picture = s
		}
		return sub, email, name, picture, nil
	}
	if lastErr != nil {
		return "", "", "", "", fmt.Errorf("google token: %w", lastErr)
	}
	return "", "", "", "", errors.New("geçersiz google token")
}
