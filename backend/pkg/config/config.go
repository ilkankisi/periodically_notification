// pkg/config/config.go
//
// NEDEN AYRI CONFIG PAKETİ?
// Tüm ortam değişkenlerini tek yerden okuruz. Test'te mock, prod'da gerçek env.
// go get github.com/caarlos0/env gibi paketler de kullanılabilir; şimdilik basit.

package config

import (
	"os"
	"strconv"
	"strings"
)

type Config struct {
	DBHost     string
	DBPort     int
	DBUser     string
	DBPassword string
	DBName     string
	DBSSLMode  string

	RabbitMQURL string

	MinIOEndpoint  string
	MinIOAccessKey string
	MinIOSecretKey string
	MinIOBucket    string
	MinIOUseSSL    bool
	MinIOPublicURL string // Görüntüleme URL'i (prod'da CDN vb.)

	JWTSecret         string
	Port              int
	FirebaseProjectID           string // POST /api/auth/token (opsiyonel; boşsa Auth yok)
	FirebaseAuthCredentialsPath string // Service account JSON yolu — sadece Auth için (FIREBASE_AUTH_CREDENTIALS_PATH)
	AdminSecret string // POST /api/admin/daily-send — X-Admin-Secret

	// APNs (iOS doğrudan push; .p8 Apple Developer)
	APNSKeyPath      string // APNS_KEY_PATH — AuthKey_xxx.p8 dosya yolu
	APNSKeyID        string // APNS_KEY_ID
	APNSTeamID       string // APNS_TEAM_ID
	APNSTopic        string // APNS_TOPIC — iOS bundle id (örn. com.siyazilim.periodicallynotification)
	APNSUseProduction bool // APNS_PRODUCTION=true → api.push.apple.com

	// OAuth (Faz 2): virgülle ayrılmış client id / bundle id listesi
	GoogleOAuthClientIDs string
	AppleClientIDs       string

	// TrustedProxies — virgülle ayrılmış CIDR veya IP; Gin ClientIP() için (nginx arkasında gerçek IP).
	// Boşsa varsayılan: loopback + RFC1918 + Docker köprü (172.16/12).
	TrustedProxies string
}

// Load ortam değişkenlerinden config yükler.
// NEDEN env?: 12-Factor App - config kodda değil, ortamda. .env dosyası genelde docker/env tarafından set edilir.
func Load() *Config {
	return &Config{
		DBHost:     getEnv("DB_HOST", "localhost"),
		DBPort:     getEnvInt("DB_PORT", 5432),
		DBUser:     getEnv("DB_USER", "app"),
		DBPassword: getEnv("DB_PASSWORD", "secret"),
		DBName:     getEnv("DB_NAME", "periodically"),
		DBSSLMode:  getEnv("DB_SSLMODE", "disable"),

		RabbitMQURL: getEnv("RABBITMQ_URL", "amqp://guest:guest@localhost:5672/"),

		MinIOEndpoint:  getEnv("MINIO_ENDPOINT", "localhost:9000"),
		MinIOAccessKey: getEnv("MINIO_ACCESS_KEY", "minioadmin"),
		MinIOSecretKey: getEnv("MINIO_SECRET_KEY", "minioadmin"),
		MinIOBucket:    getEnv("MINIO_BUCKET", "motivationpictures"),
		MinIOUseSSL:    getEnvBool("MINIO_USE_SSL", false),
		MinIOPublicURL: getEnv("MINIO_PUBLIC_URL", "http://localhost:9000"),

		JWTSecret:         getEnv("JWT_SECRET", "dev-secret-change-in-production"),
		Port:              getEnvInt("PORT", 8080),
		FirebaseProjectID:           getEnv("FIREBASE_PROJECT_ID", ""),
		FirebaseAuthCredentialsPath: getEnv("FIREBASE_AUTH_CREDENTIALS_PATH", ""),
		AdminSecret: getEnv("ADMIN_SECRET", ""),

		APNSKeyPath:        getEnv("APNS_KEY_PATH", ""),
		APNSKeyID:          getEnv("APNS_KEY_ID", ""),
		APNSTeamID:         getEnv("APNS_TEAM_ID", ""),
		APNSTopic:          getEnv("APNS_TOPIC", ""),
		APNSUseProduction:  getEnvBool("APNS_PRODUCTION", false),

		// iOS/Android/Web OAuth client ID'leri (virgülle); token `aud` buradakilerden biri olmalı.
		GoogleOAuthClientIDs: getEnv("GOOGLE_OAUTH_CLIENT_IDS", "571904521245-2pulfplhun0hen46ppc28vd63g00ngep.apps.googleusercontent.com"),
		AppleClientIDs:       getEnv("APPLE_CLIENT_IDS", "com.siyazilim.periodicallynotification"),

		TrustedProxies: getEnv("TRUSTED_PROXIES", "127.0.0.1,172.16.0.0/12,192.168.0.0/16,10.0.0.0/8"),
	}
}

// SplitComma boş olmayan virgülle ayrılmış parçalar.
func SplitComma(s string) []string {
	parts := strings.Split(s, ",")
	var out []string
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

func getEnv(key, defaultVal string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return defaultVal
}

func getEnvBool(key string, defaultVal bool) bool {
	if v := os.Getenv(key); v != "" {
		return v == "true" || v == "1"
	}
	return defaultVal
}

func getEnvInt(key string, defaultVal int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return defaultVal
}
