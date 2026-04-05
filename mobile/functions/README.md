# Firebase Cloud Functions / Firestore (kaldırıldı)

- Günlük bildirim ve veri işleri **`~/Desktop/backendGo`** ile yapılır.
- Bu repoda **`firebase.json`**, **`firestore.rules`**, **`firestore.indexes.json`** ve **`.firebaserc` yok**; `firebase deploy` ile Firestore/Functions kullanılmaz.
- İçerik: Postgres + `go run scripts/import-motivations.go` / `export-motivations.go`; görseller: MinIO + `upload-local-images.go`. Ayrıntı: `backendGo/README.md`.

Güvenlik: Eski `*-firebase-adminsdk-*.json` dosyalarını repoda tutmayın.
