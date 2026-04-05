// pkg/migrate/migrate.go
//
// NEDEN BASİT MIGRATION RUNNER?
// golang-migrate kullanabilirdik ama bağımlılık az olsun diye basit tutuyoruz.
// Sadece .up.sql dosyalarını sırayla çalıştırır. Prod'da migrate CLI da kullanılabilir.

package migrate

import (
	"embed"
	"fmt"
	"log"
	"sort"

	"github.com/jmoiron/sqlx"
)

// migrations klasörünü embed ediyoruz - binary ile birlikte gider.
// NEDEN embed?: Migrations binary'nin içinde; ayrı dosya taşımaya gerek yok.
//
//go:embed migrations/*.sql
var migrationsFS embed.FS

// Up tüm migration'ları çalıştırır.
func Up(db *sqlx.DB) error {
	entries, err := migrationsFS.ReadDir("migrations")
	if err != nil {
		return err
	}

	// Sadece .up.sql dosyalarını al ve sırala
	var ups []string
	for _, e := range entries {
		if !e.IsDir() && len(e.Name()) > 8 && e.Name()[len(e.Name())-7:] == ".up.sql" {
			ups = append(ups, e.Name())
		}
	}
	sort.Strings(ups)

	for _, name := range ups {
		log.Printf("Migration çalıştırılıyor: %s", name)
		body, err := migrationsFS.ReadFile("migrations/" + name)
		if err != nil {
			return fmt.Errorf("%s okunamadı: %w", name, err)
		}
		if _, err := db.Exec(string(body)); err != nil {
			return fmt.Errorf("%s hatası: %w", name, err)
		}
	}

	return nil
}
