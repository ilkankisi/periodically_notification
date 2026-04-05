# periodically_notification

Monorepo: Flutter **`mobile/`**, Go API **`backend/`**, paylaşılan notlar **`docs/`**.

## Flutter

```bash
cd mobile
flutter pub get
flutter run
```

Ayrıntılar: [mobile/README.md](mobile/README.md)

## Backend (Go)

```bash
cd backend
go mod download
docker compose up -d   # isteğe bağlı
go run ./cmd/server
```

Ayrıntılar: [backend/README.md](backend/README.md)
