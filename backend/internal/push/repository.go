package push

import (
	"context"

	"github.com/jmoiron/sqlx"
)

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

// Upsert misafir: yalnızca jeton kaydı; mevcut user_id silinmez.
func (r *Repository) Upsert(ctx context.Context, deviceToken string) error {
	return r.UpsertForUser(ctx, nil, deviceToken)
}

// UpsertForUser userID nil ise yalnızca ziyaretçi kaydı (user_id korunur). Dolu ise cihaz bu kullanıcıya bağlanır.
func (r *Repository) UpsertForUser(ctx context.Context, userID *string, deviceToken string) error {
	var uid interface{}
	if userID != nil && *userID != "" {
		uid = *userID
	} else {
		uid = nil
	}
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO apns_device_tokens (device_token, user_id, last_seen_at)
		VALUES ($1, $2, NOW())
		ON CONFLICT (device_token) DO UPDATE SET
			user_id = CASE
				WHEN EXCLUDED.user_id IS NOT NULL THEN EXCLUDED.user_id
				ELSE apns_device_tokens.user_id
			END,
			last_seen_at = NOW()`,
		deviceToken, uid)
	return err
}

// DisassociateUser bu jetonda kullanıcı bağlantısını kaldırır (yalnızca eşleşen kullanıcı).
func (r *Repository) DisassociateUser(ctx context.Context, userID, deviceToken string) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE apns_device_tokens
		SET user_id = NULL
		WHERE device_token = $1 AND user_id = $2::uuid`,
		deviceToken, userID)
	return err
}

func (r *Repository) ListAll(ctx context.Context) ([]string, error) {
	var tokens []string
	err := r.db.SelectContext(ctx, &tokens, `SELECT device_token FROM apns_device_tokens ORDER BY last_seen_at DESC`)
	return tokens, err
}

// ListTokensForUser hedefli APNs için bu kullanıcının jetonları.
func (r *Repository) ListTokensForUser(ctx context.Context, userID string) ([]string, error) {
	var tokens []string
	err := r.db.SelectContext(ctx, &tokens, `
		SELECT device_token FROM apns_device_tokens
		WHERE user_id = $1::uuid
		ORDER BY last_seen_at DESC`, userID)
	return tokens, err
}
