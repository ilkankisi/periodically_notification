# Yerel backend + iOS (hızlı)

> Flutter **`mobile/`**, Go API **`backend/`** — komutları **git reporoot** (`periodically_notification`) dizininden çalıştırın.

## 1. Docker

```bash
colima start
cd backend
docker-compose up -d
```

> Bu makinede `docker compose` hata verirse `docker-compose` kullan.

## 2. APNs + admin (sunucudan önce, aynı terminal)

```bash
export APNS_KEY_PATH=/Users/ilkankisi/Desktop/pushnotificationSeltification/AuthKey_6UK7V7Z75K.p8
export APNS_KEY_ID=6UK7V7Z75K
export APNS_TEAM_ID=7U43YTY35S
export APNS_TOPIC=com.siyazilim.periodicallynotification
export APNS_PRODUCTION=false   
export ADMIN_SECRET=214a5258fed487583e4156f749060226fac982b35711c8f34ed09ad32069a53c  
```


'export APNS_PRODUCTION=false   # Xcode debug → false; TestFlight/App Store → true'
'export ADMIN_SECRET=214a5258fed487583e4156f749060226fac982b35711c8f34ed09ad32069a53c   # daily-send için'

## 3. Sunucu

```bash
cd backend
go run ./cmd/server
```

Kontrol: `curl -s http://localhost:8080/api/health`

## 4. Fiziksel iPhone (API localhost olmaz)

Mac LAN IP (Wi‑Fi genelde `en0`):

```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
# boşsa: ipconfig getifaddr en1
```

Telefon aynı Wi‑Fi’de olmalı. Flutter:

```bash
cd mobile
flutter run --release --dart-define=API_BASE_URL=http://192.168.1.115:8080
```

## 5. Push tetik (token kaydı uygulamadan)

## 2’deki export’ları **aynı terminalde** `export` ettiysen `$ADMIN_SECRET` çalışır. Yeni terminal açtıysan ya tekrar `export ADMIN_SECRET=...` yap ya da header’a **sunucudakiyle aynı** değeri yaz:

```bash
curl -sS -X POST "http://localhost:8080/api/admin/daily-send" \
  -H "X-Admin-Secret: 214a5258fed487583e4156f749060226fac982b35711c8f34ed09ad32069a53c"
```

## Not

- `.p8` dosyasını Git’e ekleme.
- `APNS_KEY_PATH` mutlak yol ve **dosya** (.p8); klasör değil.
