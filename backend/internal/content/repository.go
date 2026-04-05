// internal/content/repository.go
//
// NEDEN REPOSITORY?
// Veritabanı erişimini handler'lardan ayırırız (separation of concerns).
// Handler sadece "bana tüm item'ları getir" der; nasıl çekildiği repository'de.
// Test'te mock repository kullanabiliriz.

package content

import (
	"context"
	"database/sql"
	"errors"

	"github.com/jmoiron/sqlx"
)

// İş mantığı hataları (HTTP eşlemesi için).
var (
	ErrDailyStateMissing = errors.New("daily_state eksik; migration çalıştırın")
	ErrDailyItemsEmpty   = errors.New("daily_items boş")
)

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

// ListAll tüm daily_items'ı order'a göre sıralı döner.
// NEDEN context?: Request iptal edilirse (client bağlantı kesti) query de iptal edilebilir.
func (r *Repository) ListAll(ctx context.Context) ([]DailyItem, error) {
	var items []DailyItem
	query := `SELECT id, "order", title, body, image_url, source_page_url, sent_at, created_at, updated_at
		FROM daily_items ORDER BY "order" ASC`
	err := r.db.SelectContext(ctx, &items, query)
	return items, err
}

// GetByID tek bir item döner. Yoksa nil, nil (API'de 404 dönülecek).
func (r *Repository) GetByID(ctx context.Context, id string) (*DailyItem, error) {
	var item DailyItem
	query := `SELECT id, "order", title, body, image_url, source_page_url, sent_at, created_at, updated_at
		FROM daily_items WHERE id = $1`
	err := r.db.GetContext(ctx, &item, query, id)
	if err != nil {
		// sql.ErrNoRows = bulunamadı
		return nil, err
	}
	return &item, nil
}

const dailySelectCols = `id, "order", title, body, image_url, source_page_url, sent_at, created_at, updated_at`

// AdvanceAndPickForSend bir sonraki günlük içeriği seçer, sent_at + daily_state günceller (transaction).
// Cloud Functions sendDailyWidgetContent ile aynı kural: next_order eşleşmezse en küçük order’a sarar.
func (r *Repository) AdvanceAndPickForSend(ctx context.Context) (*DailyItem, error) {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback() }()

	var nextOrder int
	err = tx.GetContext(ctx, &nextOrder, `SELECT COALESCE(next_order, 1) FROM daily_state WHERE id = 1 FOR UPDATE`)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrDailyStateMissing
	}
	if err != nil {
		return nil, err
	}

	var item DailyItem
	q := `SELECT ` + dailySelectCols + ` FROM daily_items WHERE "order" = $1 LIMIT 1 FOR UPDATE`
	err = tx.GetContext(ctx, &item, q, nextOrder)
	var newNext int
	switch {
	case err == nil:
		newNext = nextOrder + 1
	case errors.Is(err, sql.ErrNoRows):
		q2 := `SELECT ` + dailySelectCols + ` FROM daily_items ORDER BY "order" ASC LIMIT 1 FOR UPDATE`
		err = tx.GetContext(ctx, &item, q2)
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrDailyItemsEmpty
		}
		if err != nil {
			return nil, err
		}
		newNext = item.Order + 1
	default:
		return nil, err
	}

	_, err = tx.ExecContext(ctx, `UPDATE daily_items SET sent_at = NOW(), updated_at = NOW() WHERE id = $1`, item.ID)
	if err != nil {
		return nil, err
	}
	_, err = tx.ExecContext(ctx, `
		UPDATE daily_state SET next_order = $1, last_sent_at = NOW(), last_sent_item_id = $2, updated_at = NOW() WHERE id = 1
	`, newNext, item.ID)
	if err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return &item, nil
}
