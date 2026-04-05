// internal/content/model.go
//
// NEDEN AYRI MODEL DOSYASI?
// Domain entity'leri tek yerde. API request/response'dan farklı olabilir.
// Örn: API'de password_hash dönmeyiz ama DB'de tutarız.

package content

import "time"

// DailyItem günlük motivasyon içeriği.
// Firestore daily_items koleksiyonunun karşılığı.
// ID string: PostgreSQL UUID'leri lib/pq ile string olarak gelir; uyumluluk için string.
type DailyItem struct {
	ID           string     `db:"id" json:"id"`
	Order        int        `db:"order" json:"order"`
	Title        string     `db:"title" json:"title"`
	Body         string     `db:"body" json:"body"`
	ImageURL     *string    `db:"image_url" json:"imageUrl,omitempty"`
	SourcePageURL *string   `db:"source_page_url" json:"sourcePageUrl,omitempty"`
	SentAt       *time.Time `db:"sent_at" json:"sentAt,omitempty"`
	CreatedAt    time.Time  `db:"created_at" json:"createdAt"`
	UpdatedAt    time.Time  `db:"updated_at" json:"updatedAt"`
}
