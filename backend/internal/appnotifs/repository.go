package appnotifs

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"

	"periodically/backend/internal/dailysend"
	"periodically/backend/internal/push"

	"github.com/jmoiron/sqlx"
)

type Repository struct {
	db     *sqlx.DB
	apns   *dailysend.APNSSender
	tokens *push.Repository
}

func NewRepository(db *sqlx.DB, apns *dailysend.APNSSender, tokens *push.Repository) *Repository {
	return &Repository{db: db, apns: apns, tokens: tokens}
}

// Row API listesi için.
type Row struct {
	ID        string    `db:"id" json:"id"`
	Title     string    `db:"title" json:"title"`
	Body      string    `db:"body" json:"body"`
	Type      string    `db:"type" json:"type"`
	Read      bool      `db:"read" json:"read"`
	CreatedAt time.Time `db:"created_at" json:"createdAt"`
}

// InsertCommentReply yorum yanıtında üst yorum sahibine bildirim ekler (kendine değil).
func (r *Repository) InsertCommentReply(ctx context.Context, parentCommentID, replierUserID, replierDisplayName, itemExternalID, replyCommentID string) error {
	var recipient string
	err := r.db.QueryRowContext(ctx, `
		SELECT user_id::text FROM comments WHERE id = $1::uuid`, parentCommentID).Scan(&recipient)
	if err != nil {
		return err
	}
	if recipient == "" || recipient == replierUserID {
		return nil
	}
	dn := strings.TrimSpace(replierDisplayName)
	if dn == "" {
		dn = "Bir kullanıcı"
	}
	title := "Yeni yanıt"
	body := fmt.Sprintf("%s yorumunuza yanıt yazdı.", dn)
	payload, err := json.Marshal(map[string]string{
		"itemId":          itemExternalID,
		"parentCommentId": parentCommentID,
		"replyCommentId":  replyCommentID,
	})
	if err != nil {
		return err
	}
	_, err = r.db.ExecContext(ctx, `
		INSERT INTO in_app_notifications (user_id, title, body, type, payload)
		VALUES ($1::uuid, $2, $3, 'COMMENT_REPLY', $4::jsonb)`,
		recipient, title, body, string(payload))
	if err != nil {
		return err
	}
	go r.sendCommentReplyAPNS(recipient, title, body, itemExternalID, parentCommentID, replyCommentID)
	return nil
}

func (r *Repository) sendCommentReplyAPNS(recipientUserID, title, body, itemID, parentCID, replyCID string) {
	if r.apns == nil || r.tokens == nil {
		return
	}
	ctx := context.Background()
	tokList, err := r.tokens.ListTokensForUser(ctx, recipientUserID)
	if err != nil {
		log.Printf("apns reply tokens user=%s: %v", recipientUserID, err)
		return
	}
	if len(tokList) == 0 {
		return
	}
	sent, err := r.apns.SendCommentReplyToDevices(ctx, tokList, title, body, itemID, parentCID, replyCID)
	if err != nil && sent == 0 {
		log.Printf("apns reply user=%s: %v", recipientUserID, err)
		return
	}
	if err != nil {
		log.Printf("apns reply partial user=%s sent=%d warn=%v", recipientUserID, sent, err)
	}
}

func (r *Repository) ListForUser(ctx context.Context, userID string, limit int) ([]Row, error) {
	if limit <= 0 || limit > 200 {
		limit = 100
	}
	var rows []Row
	err := r.db.SelectContext(ctx, &rows, `
		SELECT id::text AS id, title, body, type, read, created_at
		FROM in_app_notifications
		WHERE user_id = $1::uuid
		ORDER BY created_at DESC
		LIMIT $2`, userID, limit)
	return rows, err
}

func (r *Repository) MarkAllRead(ctx context.Context, userID string) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE in_app_notifications SET read = true WHERE user_id = $1::uuid AND read = false`, userID)
	return err
}
