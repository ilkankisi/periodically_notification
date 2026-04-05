package actions

import (
	"context"
	"database/sql"
	"time"

	"github.com/jmoiron/sqlx"
)

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

// EnsureQuote external_id ile quote var mı kontrol eder, yoksa oluşturur, UUID döner.
func (r *Repository) EnsureQuote(ctx context.Context, externalID string) (string, error) {
	_, err := r.db.ExecContext(ctx, `INSERT INTO quotes (external_id) VALUES ($1) ON CONFLICT (external_id) DO NOTHING`, externalID)
	if err != nil {
		return "", err
	}
	var id string
	err = r.db.GetContext(ctx, &id, `SELECT id::text FROM quotes WHERE external_id = $1`, externalID)
	return id, err
}

// Create aksiyon ekler. Idempotency key varsa önce kontrol; aynı key + farklı payload = conflict.
func (r *Repository) Create(ctx context.Context, userID, quoteUUID, quoteExternalID, localDate, note, idempotencyKey string) (*Action, bool, error) {
	if idempotencyKey != "" {
		var existing Action
		var extID string
		err := r.db.QueryRowContext(ctx, `SELECT a.id::text, a.user_id::text, a.quote_id::text, q.external_id, a.local_date::text, a.note, a.created_at
			FROM actions a JOIN quotes q ON a.quote_id = q.id WHERE a.idempotency_key = $1`, idempotencyKey).Scan(
			&existing.ID, &existing.UserID, &existing.QuoteID, &extID, &existing.LocalDate, &existing.Note, &existing.CreatedAt)
		if err == nil {
			existing.QuoteExternalID = extID
			if existing.UserID == userID && extID == quoteExternalID && existing.LocalDate == localDate && existing.Note == note {
				return &existing, true, nil
			}
			return nil, false, nil
		}
		if err != sql.ErrNoRows {
			return nil, false, err
		}
	}
	var a Action
	query := `INSERT INTO actions (user_id, quote_id, local_date, note, idempotency_key) VALUES ($1, $2, $3, $4, NULLIF($5,''))
		RETURNING id::text, user_id::text, quote_id::text, local_date::text, note, created_at`
	err := r.db.QueryRowContext(ctx, query, userID, quoteUUID, localDate, note, idempotencyKey).Scan(
		&a.ID, &a.UserID, &a.QuoteID, &a.LocalDate, &a.Note, &a.CreatedAt)
	if err != nil {
		return nil, false, err
	}
	a.QuoteExternalID = quoteExternalID
	return &a, true, nil
}

// ListDaily kullanıcının belirli günün aksiyonlarını döner.
func (r *Repository) ListDaily(ctx context.Context, userID, date string) ([]Action, error) {
	var list []Action
	query := `SELECT a.id::text, a.user_id::text, a.quote_id::text, q.external_id as quote_external_id, a.local_date::text, a.note, a.created_at
		FROM actions a JOIN quotes q ON a.quote_id = q.id
		WHERE a.user_id = $1 AND a.local_date = $2 ORDER BY a.created_at DESC`
	rows, err := r.db.QueryContext(ctx, query, userID, date)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var a Action
		var extID string
		if err := rows.Scan(&a.ID, &a.UserID, &a.QuoteID, &extID, &a.LocalDate, &a.Note, &a.CreatedAt); err != nil {
			return nil, err
		}
		a.QuoteExternalID = extID
		list = append(list, a)
	}
	return list, rows.Err()
}

// GetLatestForUserQuote kullanıcı + içerik (daily_items UUID / external_id) için en son aksiyon.
func (r *Repository) GetLatestForUserQuote(ctx context.Context, userID, externalQuoteID string) (*Action, error) {
	var a Action
	var extID string
	err := r.db.QueryRowContext(ctx, `
		SELECT a.id::text, a.user_id::text, a.quote_id::text, q.external_id, a.local_date::text, a.note, a.created_at
		FROM actions a JOIN quotes q ON a.quote_id = q.id
		WHERE a.user_id = $1::uuid AND q.external_id = $2
		ORDER BY a.created_at DESC
		LIMIT 1`,
		userID, externalQuoteID,
	).Scan(&a.ID, &a.UserID, &a.QuoteID, &extID, &a.LocalDate, &a.Note, &a.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	a.QuoteExternalID = extID
	return &a, nil
}

// UserActionListItem Flutter GET /v1/actions/me yanıtı için (note + başlık).
type UserActionListItem struct {
	ID              string    `db:"id" json:"id"`
	QuoteExternalID string    `db:"quote_external_id" json:"quoteId"`
	QuoteTitle      string    `db:"quote_title" json:"quoteTitle"`
	LocalDate       string    `db:"local_date" json:"localDate"`
	Note            string    `db:"note" json:"note"`
	CreatedAt       time.Time `db:"created_at" json:"createdAt"`
}

// ListAllForUser kullanıcının tüm aksiyonlarını döner (Aksiyonlar ekranı + streak client).
func (r *Repository) ListAllForUser(ctx context.Context, userID string) ([]UserActionListItem, error) {
	var list []UserActionListItem
	query := `
		SELECT a.id::text AS id,
		       q.external_id AS quote_external_id,
		       COALESCE(di.title, '') AS quote_title,
		       a.local_date::text AS local_date,
		       a.note,
		       a.created_at
		FROM actions a
		JOIN quotes q ON a.quote_id = q.id
		LEFT JOIN daily_items di ON di.id::text = q.external_id
		WHERE a.user_id = $1::uuid
		ORDER BY a.created_at DESC`
	err := r.db.SelectContext(ctx, &list, query, userID)
	return list, err
}

// GetUserActionDates kullanıcının aksiyonlu günlerini döner (streak için).
func (r *Repository) GetUserActionDates(ctx context.Context, userID string, limit int) ([]string, error) {
	var dates []string
	query := `SELECT DISTINCT local_date::text FROM actions WHERE user_id = $1 ORDER BY local_date DESC LIMIT $2`
	err := r.db.SelectContext(ctx, &dates, query, userID, limit)
	return dates, err
}

// UpdateStreakCache user_day_cache ve streak_cache günceller.
func (r *Repository) UpdateStreakCache(ctx context.Context, userID, localDate string) error {
	_, err := r.db.ExecContext(ctx, `INSERT INTO user_day_cache (user_id, local_date, action_count) VALUES ($1, $2, 1)
		ON CONFLICT (user_id, local_date) DO UPDATE SET action_count = user_day_cache.action_count + 1`, userID, localDate)
	if err != nil {
		return err
	}
	dates, err := r.GetUserActionDates(ctx, userID, 365)
	if err != nil {
		return err
	}
	current, best := computeStreak(dates)
	_, err = r.db.ExecContext(ctx, `INSERT INTO streak_cache (user_id, current, best, last_date, updated_at) VALUES ($1, $2, $3, $4, NOW())
		ON CONFLICT (user_id) DO UPDATE SET current = $2, best = GREATEST(streak_cache.best, $3), last_date = $4, updated_at = NOW()`,
		userID, current, best, localDate)
	return err
}

func computeStreak(dates []string) (current, best int) {
	if len(dates) == 0 {
		return 0, 0
	}
	today := time.Now().Format("2006-01-02")
	parse := func(s string) time.Time {
		t, _ := time.Parse("2006-01-02", s)
		return t
	}
	var run int
	for i := range dates {
		if i == 0 {
			run = 1
			continue
		}
		if parse(dates[i-1]).Sub(parse(dates[i])).Hours()/24 == 1 {
			run++
		} else {
			if run > best {
				best = run
			}
			run = 1
		}
	}
	if run > best {
		best = run
	}
	current = run
	yesterday := time.Now().AddDate(0, 0, -1).Format("2006-01-02")
	if len(dates) > 0 && dates[0] != today && dates[0] != yesterday {
		current = 0
	}
	return current, best
}

