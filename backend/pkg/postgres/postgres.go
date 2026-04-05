// pkg/postgres/postgres.go
//
// NEDEN sqlx?
// database/sql yerine sqlx: Struct'lara otomatik map, named query, daha az boilerplate.
// Alternatif: GORM (ORM, daha ağır) - biz lightweight tercih ettik.

package postgres

import (
	"fmt"
	"log"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq" // PostgreSQL driver - blank import ile register edilir
)

// Conn veritabanı bağlantısı. Uygulama boyunca tek instance kullanacağız.
// NEDEN pointer?: Bağlantı paylaşılır; kopyalamak istemeyiz.
type Conn struct {
	DB *sqlx.DB
}

// New bağlantı kurar ve ping atar.
// DSN formatı: postgres://user:pass@host:port/dbname?sslmode=disable
func New(host string, port int, user, password, dbname, sslmode string) (*Conn, error) {
	dsn := fmt.Sprintf(
		"host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		host, port, user, password, dbname, sslmode,
	)

	db, err := sqlx.Connect("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("postgres bağlantı hatası: %w", err)
	}

	// Connection pool ayarları
	// NEDEN?: Varsayılan 0 = sınırsız. MaxOpenConns ile aşırı bağlantıyı önleriz.
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)

	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("postgres ping hatası: %w", err)
	}

	log.Println("PostgreSQL bağlantısı başarılı")
	return &Conn{DB: db}, nil
}

// Close bağlantıyı kapatır (graceful shutdown için).
func (c *Conn) Close() error {
	return c.DB.Close()
}
