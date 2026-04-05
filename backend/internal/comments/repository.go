package comments

import (
	"context"
	"database/sql"
	"strings"

	"github.com/jmoiron/sqlx"
)

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

// ListByItem viewerUserID doluysa bu kullanıcının her yorumdaki tepkisi döner.
func (r *Repository) ListByItem(ctx context.Context, itemID string, viewerUserID *string) ([]Comment, error) {
	const q = `
		SELECT c.id::text, c.item_external_id, c.user_id::text, c.parent_comment_id::text, c.text, c.created_at,
			COALESCE(u.display_name, split_part(u.email, '@', 1)) AS display_name,
			u.photo_url,
			(SELECT COUNT(*)::int FROM comment_reactions r WHERE r.comment_id = c.id AND r.value = 1) AS like_count,
			(SELECT COUNT(*)::int FROM comment_reactions r WHERE r.comment_id = c.id AND r.value = -1) AS dislike_count,
			(SELECT r2.value FROM comment_reactions r2
			 WHERE r2.comment_id = c.id AND r2.user_id IS NOT DISTINCT FROM $2::uuid LIMIT 1) AS my_reaction
		FROM comments c
		JOIN users u ON u.id = c.user_id AND u.deleted_at IS NULL
		WHERE c.item_external_id = $1
		AND ($2::uuid IS NULL OR NOT EXISTS (
			SELECT 1 FROM blocks b WHERE b.blocker_id = $2 AND b.blocked_id = c.user_id
		))
		ORDER BY c.created_at ASC`
	var v interface{}
	if viewerUserID != nil && *viewerUserID != "" {
		v = *viewerUserID
	}
	var list []Comment
	err := r.db.SelectContext(ctx, &list, q, itemID, v)
	if err != nil {
		return nil, err
	}
	return list, nil
}

func (r *Repository) BeginTxx(ctx context.Context) (*sqlx.Tx, error) {
	return r.db.BeginTxx(ctx, nil)
}

func (r *Repository) Create(ctx context.Context, itemID, userID, text string, parentID *string) (*Comment, error) {
	return r.createWithExt(ctx, r.db, itemID, userID, text, parentID)
}

// CreateTx transaction içinde yorum ekler.
func (r *Repository) CreateTx(ctx context.Context, tx *sqlx.Tx, itemID, userID, text string, parentID *string) (*Comment, error) {
	return r.createWithExt(ctx, tx, itemID, userID, text, parentID)
}

// ParentExternalID parent yorumun hangi içeriğe ait olduğunu döner (tx dışı).
func (r *Repository) ParentExternalID(ctx context.Context, parentCommentID string) (string, error) {
	var item string
	err := r.db.QueryRowContext(ctx, `
		SELECT item_external_id FROM comments WHERE id = $1::uuid`, parentCommentID).Scan(&item)
	return item, err
}

// ParentExternalIDTx transaction içinde parent doğrulama.
func (r *Repository) ParentExternalIDTx(ctx context.Context, tx *sqlx.Tx, parentCommentID string) (string, error) {
	var item string
	err := tx.QueryRowContext(ctx, `
		SELECT item_external_id FROM comments WHERE id = $1::uuid`, parentCommentID).Scan(&item)
	return item, err
}

type queryRower interface {
	QueryRowxContext(ctx context.Context, query string, args ...interface{}) *sqlx.Row
}

func (r *Repository) createWithExt(ctx context.Context, dbOrTx queryRower, itemID, userID, text string, parentID *string) (*Comment, error) {
	text = strings.TrimSpace(text)
	if text == "" {
		return nil, nil
	}
	var p interface{}
	if parentID != nil && strings.TrimSpace(*parentID) != "" {
		p = strings.TrimSpace(*parentID)
	} else {
		p = nil
	}
	const insertSQL = `
		INSERT INTO comments (item_external_id, user_id, text, parent_comment_id)
		VALUES ($1, $2::uuid, $3, $4::uuid)
		RETURNING id::text, item_external_id, user_id::text, parent_comment_id::text, text, created_at`
	var c Comment
	err := dbOrTx.QueryRowxContext(ctx, insertSQL, itemID, userID, text, p).Scan(
		&c.ID, &c.ItemExternalID, &c.UserID, &c.ParentID, &c.Text, &c.CreatedAt)
	if err != nil {
		return nil, err
	}
	if c.ParentID != nil && *c.ParentID == "" {
		c.ParentID = nil
	}
	c.CreatedAt = c.CreatedAt.UTC()
	const userSQL = `
		SELECT COALESCE(u.display_name, split_part(u.email, '@', 1)), u.photo_url
		FROM users u WHERE u.id = $1::uuid`
	var dn string
	var pu *string
	if err := dbOrTx.QueryRowxContext(ctx, userSQL, userID).Scan(&dn, &pu); err == nil {
		c.DisplayName = dn
		c.PhotoURL = pu
	}
	return &c, nil
}

// ReactionOutcome tepki sonrası kullanıcının yeni durumu (nil = kaldırıldı).
type ReactionOutcome struct {
	Prev *int
	Now  *int
}

// ApplyReactionTx aynı değere basılırsa tepkiyi kaldırır; aksi halde ekler veya günceller.
func (r *Repository) ApplyReactionTx(ctx context.Context, tx *sqlx.Tx, commentID, userID string, value int) (*ReactionOutcome, error) {
	var idCheck string
	err := tx.QueryRowContext(ctx, `SELECT id::text FROM comments WHERE id = $1::uuid`, commentID).Scan(&idCheck)
	if err == sql.ErrNoRows {
		return nil, sql.ErrNoRows
	}
	if err != nil {
		return nil, err
	}
	var prev sql.NullInt32
	err = tx.QueryRowContext(ctx, `
		SELECT value FROM comment_reactions WHERE comment_id = $1::uuid AND user_id = $2::uuid FOR UPDATE`,
		commentID, userID).Scan(&prev)
	has := err == nil
	if err != nil && err != sql.ErrNoRows {
		return nil, err
	}
	out := &ReactionOutcome{}
	if has {
		v := int(prev.Int32)
		out.Prev = &v
	}
	if has && int(prev.Int32) == value {
		if _, err := tx.ExecContext(ctx, `
			DELETE FROM comment_reactions WHERE comment_id = $1::uuid AND user_id = $2::uuid`,
			commentID, userID); err != nil {
			return nil, err
		}
		return out, nil
	}
	if has {
		if _, err := tx.ExecContext(ctx, `
			UPDATE comment_reactions SET value = $3, created_at = NOW()
			WHERE comment_id = $1::uuid AND user_id = $2::uuid`,
			commentID, userID, value); err != nil {
			return nil, err
		}
	} else {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO comment_reactions (comment_id, user_id, value) VALUES ($1::uuid, $2::uuid, $3)`,
			commentID, userID, value); err != nil {
			return nil, err
		}
	}
	out.Now = &value
	return out, nil
}

// ReactionCounts yorum için beğeni / beğenmeme sayıları.
func (r *Repository) ReactionCounts(ctx context.Context, commentID string) (likes, dislikes int, err error) {
	err = r.db.QueryRowContext(ctx, `
		SELECT
			(SELECT COUNT(*)::int FROM comment_reactions r WHERE r.comment_id = $1::uuid AND r.value = 1),
			(SELECT COUNT(*)::int FROM comment_reactions r WHERE r.comment_id = $1::uuid AND r.value = -1)`,
		commentID).Scan(&likes, &dislikes)
	return likes, dislikes, err
}
