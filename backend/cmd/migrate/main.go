// Sadece migration çalıştırır. Postgres bağlantısı gerekir.
package main

import (
	"log"

	"periodically/backend/pkg/config"
	"periodically/backend/pkg/migrate"
	"periodically/backend/pkg/postgres"
)

func main() {
	cfg := config.Load()
	pg, err := postgres.New(
		cfg.DBHost, cfg.DBPort, cfg.DBUser, cfg.DBPassword, cfg.DBName, cfg.DBSSLMode,
	)
	if err != nil {
		log.Fatalf("PostgreSQL: %v", err)
	}
	defer pg.Close()

	if err := migrate.Up(pg.DB); err != nil {
		log.Fatalf("Migration: %v", err)
	}
	log.Println("Migration tamamlandı.")
}
