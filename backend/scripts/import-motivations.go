// scripts/import-motivations.go
//
// motivations.json → PostgreSQL daily_items. MinIO imageUrl veya JSON'daki imageUrl.
// Kullanım: cd backend && go run scripts/import-motivations.go
// Tam yenileme: go run scripts/import-motivations.go -replace
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/url"
	"os"
	"strings"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
)

type Motivation struct {
	ID             string `json:"id"`
	Title          string `json:"title"`
	Body           string `json:"body"`
	Order          int    `json:"order"`
	SentAt         string `json:"sentAt"`
	ImageURL       string `json:"imageUrl"`
	SourcePageURL  string `json:"sourcePageUrl"`
	DownloadedFile string `json:"downloadedFile"`
}

func main() {
	jsonPath := flag.String("json", "../mobile/assets/data/motivations.json", "motivations.json yolu")
	minioBase := flag.String("minio", "http://localhost:9000", "MinIO base URL (imageUrl boşsa)")
	bucket := flag.String("bucket", "motivationpictures", "MinIO bucket adı")
	flat := flag.Bool("flat", false, "downloadedFile'da yalnızca dosya adı kullan")
	replace := flag.Bool("replace", false, "true: daily_items sil + daily_state next_order=1")
	flag.Parse()

	data, err := os.ReadFile(*jsonPath)
	if err != nil {
		log.Fatalf("JSON okunamadı: %v", err)
	}

	var items []Motivation
	if err := json.Unmarshal(data, &items); err != nil {
		log.Fatalf("JSON parse: %v", err)
	}
	log.Printf("%d item bulundu", len(items))

	dsn := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		getEnv("DB_HOST", "localhost"), getEnvInt("DB_PORT", 5432),
		getEnv("DB_USER", "app"), getEnv("DB_PASSWORD", "secret"),
		getEnv("DB_NAME", "periodically"), getEnv("DB_SSLMODE", "disable"))
	db, err := sqlx.Connect("postgres", dsn)
	if err != nil {
		log.Fatalf("DB: %v", err)
	}
	defer db.Close()

	if *replace {
		if _, err := db.Exec(`UPDATE daily_state SET last_sent_item_id = NULL, next_order = 1, last_sent_at = NULL WHERE id = 1`); err != nil {
			log.Fatalf("daily_state güncelleme: %v", err)
		}
		if _, err := db.Exec(`DELETE FROM daily_items`); err != nil {
			log.Fatalf("daily_items silme: %v", err)
		}
		log.Println("daily_items temizlendi; daily_state next_order=1")
	}

	for _, m := range items {
		imageURL := strings.TrimSpace(m.ImageURL)
		if imageURL == "" {
			objName := m.DownloadedFile
			if *flat {
				if idx := lastSlash(objName); idx >= 0 {
					objName = objName[idx+1:]
				}
			}
			imageURL = buildMinIOURL(*minioBase, *bucket, objName)
		}

		var sentAt interface{}
		if strings.TrimSpace(m.SentAt) != "" {
			sentAt = strings.TrimSpace(m.SentAt)
		} else {
			sentAt = nil
		}

		_, err := db.Exec(`INSERT INTO daily_items ("order", title, body, image_url, source_page_url, sent_at)
			VALUES ($1, $2, $3, $4, $5, $6)
			ON CONFLICT ("order") DO UPDATE SET title=$2, body=$3, image_url=$4, source_page_url=$5, sent_at=COALESCE(EXCLUDED.sent_at, daily_items.sent_at)`,
			m.Order, m.Title, m.Body, nullIfEmpty(imageURL), nullIfEmpty(strings.TrimSpace(m.SourcePageURL)), sentAt)
		if err != nil {
			log.Printf("Order %d hata: %v", m.Order, err)
			continue
		}
		preview := m.Title
		if len(preview) > 40 {
			preview = preview[:40] + "..."
		}
		log.Printf("Order %d: %s → %s", m.Order, preview, imageURL)
	}
	log.Println("Import tamamlandı.")
}

func nullIfEmpty(s string) interface{} {
	if strings.TrimSpace(s) == "" {
		return nil
	}
	return s
}

func buildMinIOURL(base, bucket, objectName string) string {
	var parts []string
	for _, p := range splitPath(objectName) {
		parts = append(parts, url.PathEscape(p))
	}
	encoded := ""
	for i, p := range parts {
		if i > 0 {
			encoded += "/"
		}
		encoded += p
	}
	return strings.TrimSuffix(base, "/") + "/" + bucket + "/" + encoded
}

func lastSlash(s string) int {
	for i := len(s) - 1; i >= 0; i-- {
		if s[i] == '/' {
			return i
		}
	}
	return -1
}

func splitPath(s string) []string {
	var out []string
	cur := ""
	for _, r := range s {
		if r == '/' {
			if cur != "" {
				out = append(out, cur)
				cur = ""
			}
		} else {
			cur += string(r)
		}
	}
	if cur != "" {
		out = append(out, cur)
	}
	return out
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
