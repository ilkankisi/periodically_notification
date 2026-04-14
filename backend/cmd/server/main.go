// cmd/server/main.go
//
// NEDEN BURADA?
// Go projelerinde "cmd/" klasörü uygulama giriş noktalarını içerir.
// Monolit yapıda tek binary olduğumuz için tek main.go var.
// İleride mikroservise geçince cmd/worker, cmd/scheduler ekleyebiliriz.

package main

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	"periodically/backend/internal/actions"
	"periodically/backend/internal/auth"
	"periodically/backend/internal/content"
	"periodically/backend/internal/appnotifs"
	"periodically/backend/internal/dailysend"
	"periodically/backend/internal/gamification"
	"periodically/backend/internal/push"
	"periodically/backend/internal/server"
	"periodically/backend/internal/storage"
	"periodically/backend/pkg/config"
	"periodically/backend/pkg/firebase"
	"periodically/backend/pkg/migrate"
	"periodically/backend/pkg/postgres"
	miniostorage "periodically/backend/pkg/storage"

	"github.com/gin-gonic/gin"
)

// ginLogFormatter — nginx arkasında gerçek istemci IP’si için ClientIP() + X-Forwarded-For satırda.
func ginLogFormatter(param gin.LogFormatterParams) string {
	suffix := ""
	if xff := param.Request.Header.Get("X-Forwarded-For"); xff != "" {
		suffix = fmt.Sprintf(" | X-Forwarded-For: %s", xff)
	}
	return fmt.Sprintf("[GIN] %v | %3d | %13v | %15s | %-7s %s%s\n",
		param.TimeStamp.Format("2006/01/02 - 15:04:05"),
		param.StatusCode,
		param.Latency,
		param.ClientIP,
		param.Method,
		param.Path,
		suffix,
	)
}

func main() {
	// 1. Config yükle (env değişkenleri)
	cfg := config.Load()

	// 2. PostgreSQL bağlantısı
	// NEDEN erken bağlantı?: Uygulama başlamadan DB hazır olmalı. Migrations da bu bağlantı ile çalışır.
	pg, err := postgres.New(
		cfg.DBHost, cfg.DBPort, cfg.DBUser, cfg.DBPassword, cfg.DBName, cfg.DBSSLMode,
	)
	if err != nil {
		log.Fatalf("PostgreSQL: %v", err)
	}
	defer pg.Close()

	// 3. Migration'ları çalıştır
	if err := migrate.Up(pg.DB); err != nil {
		log.Fatalf("Migration: %v", err)
	}

	// 4. Opsiyonel Firebase Admin Auth (sadece POST /api/auth/token — FIREBASE_AUTH_CREDENTIALS_PATH)
	if err := firebase.Init(context.Background(), cfg.FirebaseProjectID, cfg.FirebaseAuthCredentialsPath); err != nil {
		log.Printf("Firebase Auth init: %v", err)
	}
	// 5. Repository ve servisleri oluştur
	contentRepo := content.NewRepository(pg.DB)
	authRepo := auth.NewRepository(pg.DB)
	actionsRepo := actions.NewRepository(pg.DB)
	gamificationRepo := gamification.NewRepository(pg.DB)

	minioClient, err := miniostorage.New(
		cfg.MinIOEndpoint, cfg.MinIOAccessKey, cfg.MinIOSecretKey,
		cfg.MinIOBucket, cfg.MinIOPublicURL, cfg.MinIOUseSSL,
	)
	if err != nil {
		log.Fatalf("MinIO: %v", err)
	}
	storageHandler := &storage.Handler{Storage: minioClient}

	// 5. Gin router (max 5MB multipart - görsel yükleme için)
	r := gin.New()
	proxies := config.SplitComma(cfg.TrustedProxies)
	if err := r.SetTrustedProxies(proxies); err != nil {
		log.Fatalf("TRUSTED_PROXIES: %v", err)
	}
	log.Printf("Gin trusted proxies: %v", proxies)
	r.Use(gin.LoggerWithFormatter(ginLogFormatter))
	r.Use(gin.Recovery())
	r.MaxMultipartMemory = 5 << 20

	// CORS
	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization, Idempotency-Key, X-Consent-Sync, X-Admin-Secret")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	pushRepo := push.NewRepository(pg.DB)
	apnsHandler := &push.Handler{Repo: pushRepo}

	var apnsSender *dailysend.APNSSender
	if cfg.APNSKeyPath != "" && cfg.APNSKeyID != "" && cfg.APNSTeamID != "" && cfg.APNSTopic != "" {
		s, err := dailysend.NewAPNSSender(cfg.APNSKeyPath, cfg.APNSKeyID, cfg.APNSTeamID, cfg.APNSTopic, cfg.APNSUseProduction)
		if err != nil {
			log.Printf("APNS: %v", err)
		} else {
			apnsSender = s
			log.Println("APNS gönderici hazır")
		}
	} else {
		log.Println("APNS yapılandırılmadı (APNS_KEY_PATH, APNS_KEY_ID, APNS_TEAM_ID, APNS_TOPIC)")
	}

	appNotifsRepo := appnotifs.NewRepository(pg.DB, apnsSender, pushRepo)

	dailySend := &dailysend.Handler{
		Repo:        contentRepo,
		PushRepo:    pushRepo,
		APNS:        apnsSender,
		AdminSecret: cfg.AdminSecret,
	}

	// 6. Route'ları kur
	server.Setup(r, contentRepo, authRepo, actionsRepo, gamificationRepo, appNotifsRepo, storageHandler, pg.DB, cfg.JWTSecret,
		config.SplitComma(cfg.GoogleOAuthClientIDs), config.SplitComma(cfg.AppleClientIDs), apnsHandler, dailySend)

	if s := strings.TrimSpace(cfg.DailySendBroadcastInterval); s != "" {
		if apnsSender == nil {
			log.Printf("DAILY_SEND_BROADCAST_INTERVAL=%s yok sayıldı (APNS yapılandırılmadı)", s)
		} else {
			d, err := time.ParseDuration(s)
			if err != nil {
				log.Printf("DAILY_SEND_BROADCAST_INTERVAL geçersiz (%s): %v", s, err)
			} else {
				log.Printf("APNs yayın testi aktif: her %v (daily_state değişmez). Kapatmak için env kaldırın.", d)
				go func() {
					ticker := time.NewTicker(d)
					defer ticker.Stop()
					for range ticker.C {
						ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
						res, err := dailySend.RunBroadcastPing(ctx)
						cancel()
						if err != nil {
							log.Printf("dailysend broadcast: %v", err)
							continue
						}
						log.Printf("dailysend broadcast: %+v", res)
					}
				}()
			}
		}
	}

	// 7. Sunucuyu başlat
	addr := fmt.Sprintf(":%d", cfg.Port)
	if err := r.Run(addr); err != nil {
		log.Fatalf("Server: %v", err)
	}
}
