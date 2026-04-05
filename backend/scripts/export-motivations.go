// PostgreSQL daily_items → motivations.json (Flutter asset formatına yakın).
//
// Kullanım: cd backend && go run scripts/export-motivations.go -out ../mobile/assets/data/motivations.json
package main

import (
	"database/sql"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
)

type row struct {
	ID              string         `db:"id"`
	Order           int            `db:"order"`
	Title           string         `db:"title"`
	Body            string         `db:"body"`
	ImageURL        sql.NullString `db:"image_url"`
	SourcePageURL   sql.NullString `db:"source_page_url"`
	SentAt          sql.NullTime   `db:"sent_at"`
}

type outItem struct {
	ID              string  `json:"id"`
	Title           string  `json:"title"`
	Body            string  `json:"body"`
	Order           int     `json:"order"`
	SentAt          *string `json:"sentAt,omitempty"`
	Image           *string `json:"image"`
	ImageURL        *string `json:"imageUrl,omitempty"`
	SourcePageURL   *string `json:"sourcePageUrl,omitempty"`
	DownloadedFile  string  `json:"downloadedFile,omitempty"`
}

func main() {
	outPath := flag.String("out", "../mobile/assets/data/motivations.json", "çıktı JSON yolu")
	flag.Parse()

	dsn := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		getEnv("DB_HOST", "localhost"), getEnvInt("DB_PORT", 5432),
		getEnv("DB_USER", "app"), getEnv("DB_PASSWORD", "secret"),
		getEnv("DB_NAME", "periodically"), getEnv("DB_SSLMODE", "disable"))
	db, err := sqlx.Connect("postgres", dsn)
	if err != nil {
		log.Fatalf("DB: %v", err)
	}
	defer db.Close()

	var rows []row
	q := `SELECT id::text, "order", title, body, image_url, source_page_url, sent_at
		FROM daily_items ORDER BY "order" ASC`
	if err := db.Select(&rows, q); err != nil {
		log.Fatalf("query: %v", err)
	}

	out := make([]outItem, 0, len(rows))
	for _, r := range rows {
		it := outItem{
			ID:    r.ID,
			Title: r.Title,
			Body:  r.Body,
			Order: r.Order,
		}
		if r.SentAt.Valid {
			s := r.SentAt.Time.UTC().Format(time.RFC3339Nano)
			it.SentAt = &s
		}
		it.Image = nil
		if r.ImageURL.Valid && r.ImageURL.String != "" {
			u := r.ImageURL.String
			it.ImageURL = &u
		}
		if r.SourcePageURL.Valid && r.SourcePageURL.String != "" {
			u := r.SourcePageURL.String
			it.SourcePageURL = &u
		}
		out = append(out, it)
	}

	data, err := json.MarshalIndent(out, "", "  ")
	if err != nil {
		log.Fatalf("json: %v", err)
	}
	if err := os.WriteFile(*outPath, data, 0o644); err != nil {
		log.Fatalf("yazma: %v", err)
	}
	log.Printf("%d satır → %s", len(out), *outPath)
}

func getEnv(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

func getEnvInt(k string, d int) int {
	if v := os.Getenv(k); v != "" {
		var i int
		if _, err := fmt.Sscanf(v, "%d", &i); err == nil {
			return i
		}
	}
	return d
}
