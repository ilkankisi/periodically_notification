// Yerel klasördeki görselleri MinIO'ya yükler; motivations.json + isteğe bağlı PostgreSQL image_url günceller.
//
//   export MINIO_ENDPOINT=localhost:9000 MINIO_ACCESS_KEY=minioadmin MINIO_SECRET_KEY=minioadmin
//   go run scripts/upload-local-images.go -local /path/to/gorseller
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"

	"periodically/backend/pkg/storage"
)

func main() {
	localRoot := flag.String("local", "", "görsel kök dizin (zorunlu)")
	jsonPath := flag.String("json", "../mobile/assets/data/motivations.json", "motivations.json")
	writeJSON := flag.Bool("write-json", true, "JSON'daki imageUrl güncelle")
	updateDB := flag.Bool("update-db", true, "daily_items.image_url güncelle")
	flag.Parse()

	if strings.TrimSpace(*localRoot) == "" {
		log.Fatal("-local zorunlu")
	}

	data, err := os.ReadFile(*jsonPath)
	if err != nil {
		log.Fatalf("json okuma: %v", err)
	}
	var items []map[string]interface{}
	if err := json.Unmarshal(data, &items); err != nil {
		log.Fatalf("json parse: %v", err)
	}

	ctx := context.Background()
	cli, err := storage.New(
		getEnv("MINIO_ENDPOINT", "localhost:9000"),
		getEnv("MINIO_ACCESS_KEY", "minioadmin"),
		getEnv("MINIO_SECRET_KEY", "minioadmin"),
		getEnv("MINIO_BUCKET", "motivationpictures"),
		getEnv("MINIO_PUBLIC_URL", "http://localhost:9000"),
		getEnvBool("MINIO_USE_SSL", false),
	)
	if err != nil {
		log.Fatalf("minio: %v", err)
	}

	var db *sqlx.DB
	if *updateDB {
		dsn := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
			getEnv("DB_HOST", "localhost"), getEnvInt("DB_PORT", 5432),
			getEnv("DB_USER", "app"), getEnv("DB_PASSWORD", "secret"),
			getEnv("DB_NAME", "periodically"), getEnv("DB_SSLMODE", "disable"))
		db, err = sqlx.Connect("postgres", dsn)
		if err != nil {
			log.Fatalf("db: %v", err)
		}
		defer db.Close()
	}

	for _, item := range items {
		df, _ := item["downloadedFile"].(string)
		df = strings.TrimSpace(df)
		if df == "" {
			continue
		}
		localFile := filepath.Join(*localRoot, filepath.FromSlash(df))
		if _, err := os.Stat(localFile); err != nil {
			log.Printf("atlandı (dosya yok): %s", localFile)
			continue
		}
		objKey := filepath.ToSlash(df)
		if err := cli.PutLocalFile(ctx, localFile, objKey); err != nil {
			log.Printf("upload %s: %v", objKey, err)
			continue
		}
		pub := cli.ObjectPublicURL(objKey)
		item["imageUrl"] = pub

		if db != nil {
			var order int
			switch v := item["order"].(type) {
			case float64:
				order = int(v)
			case int:
				order = v
			default:
				order = 0
			}
			if order > 0 {
				if _, err := db.ExecContext(ctx, `UPDATE daily_items SET image_url = $1 WHERE "order" = $2`, pub, order); err != nil {
					log.Printf("db order %d: %v", order, err)
				}
			}
		}
		log.Printf("OK %s → %s", objKey, pub)
	}

	if *writeJSON {
		out, err := json.MarshalIndent(items, "", "  ")
		if err != nil {
			log.Fatalf("json marshal: %v", err)
		}
		if err := os.WriteFile(*jsonPath, out, 0o644); err != nil {
			log.Fatalf("json yazma: %v", err)
		}
		log.Printf("güncellendi: %s", *jsonPath)
	}
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

func getEnvBool(k string, d bool) bool {
	if v := os.Getenv(k); v != "" {
		return v == "1" || v == "true"
	}
	return d
}
