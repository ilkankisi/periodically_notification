# Uzaktan backend (Docker + nginx + WAN)

> Flutter **`mobile/`**, Go API **`backend/`** — komutları **git reporoot** (`periodically_notification`) dizininden çalıştırın. Bu akış, API’yi **nginx 80** üzerinden dış ağdan erişilebilir kılar (`go run` yerine tam Docker stack).

**Sadece kurum/ofis Wi‑Fi’nde test:** adım adım **`OFIS_CALISTIRMA.md`**.

## 1. APNs + admin (sunucudan önce, aynı terminal)

`docker-compose up` **çalıştırmadan önce** aynı terminalde — böylece `api` konteynerına ortam değişkeni olarak geçer. **`APNS_KEY_PATH`’i burada export etmeyin** (Docker’da host yolu konteyneri bozar; `.p8` bağlama adımları aşağıda).

```bash
export APNS_KEY_ID=6UK7V7Z75K
export APNS_TEAM_ID=7U43YTY35S
export APNS_TOPIC=com.siyazilim.periodicallynotification
export APNS_PRODUCTION=false
export ADMIN_SECRET=214a5258fed487583e4156f749060226fac982b35711c8f34ed09ad32069a53c
```

`APNS_PRODUCTION=false` — Xcode debug → false; TestFlight/App Store → true.  
`ADMIN_SECRET` — `POST /api/admin/daily-send` için.

**Docker ve APNs:** Konteyner içinde Mac’teki `/Users/.../AuthKey.p8` yolu yoktur. Host’taki dosyayı **bind mount** ile konteynıra verirsiniz; uygulama ise **konteyner içi** sabit bir yolu okur (ör. `/run/secrets/apns.p8`).

1. `backend` klasöründe örnek dosyayı kopyalayın:  
   `cp docker-compose.override.example.yml docker-compose.override.yml`
2. `docker-compose.override.yml` içinde `volumes` satırının **sol** tarafını kendi `.p8` dosyanızın **tam host yolu** ile değiştirin (ör. `/Users/consultechs/.../AuthKey_GN4CR3AB3W.p8`). Sağ taraf `/run/secrets/apns.p8` kalsın.
3. Aynı dosyada `APNS_KEY_PATH: /run/secrets/apns.p8` zaten örnekte var — böylece `export APNS_KEY_PATH=/Users/...` **kullanmayın**; konteyner hep iç yolu görür.
4. `docker compose up` çalıştırdığınızda Compose, `docker-compose.yml` + `docker-compose.override.yml` dosyalarını otomatik birleştirir.

`go run ./cmd/server` ile yerelde çalışırken eskisi gibi host’taki mutlak yolu `export APNS_KEY_PATH=...` ile vermeye devam edebilirsiniz (`YEREL_CALISTIRMA.md`).

## 2. `MINIO_PUBLIC_URL` (compose’tan önce)

API’nin döndürdüğü `image_url` gibi adresler dışarıdan açılabilir olmalı. Bölüm 1 ile **aynı shell’de** (public adresi biliyorsanız):

```bash
export MINIO_PUBLIC_URL=http://31.145.138.158:9000 
```

Public IP örneği: `curl -s ifconfig.me`

İsteğe bağlı: `JWT_SECRET`, OAuth / Firebase — `backend/docker-compose.yml` ve `backend/.env.example` içindeki isimlerle shell’den `export` veya `backend/.env`.

## 3. Docker (altyapı + API + nginx)

```bash
colima start
cd backend
docker-compose up -d --build
```

> Bu makinede `docker compose` hata verirse `docker-compose` kullanın.

Kontrol (nginx → Go):

```bash
curl -s http://127.0.0.1/api/health
```

Export’ları değiştirdiyseniz konteynerı yeniden oluşturun: `docker-compose up -d --build` (veya `docker-compose up -d --force-recreate`).

## 4. İki ortam: evde sürekli + kurum içinden test

Aynı repoyu **evde** dışarıdan erişilebilir tutup **işyerinde** sadece kurum ağından test etmek için ortam bazlı adres kullanın (kodu iki kez yazmaya gerek yok; sadece `export` + Flutter `API_BASE_URL` değişir).

### Ev (hedef: sürekli çalışma, port yönlendirme sende)

1. Mac + Docker stack **ev Wi‑Fi’sinde** çalışsın.
2. Modemde **port yönlendirme**: dış **TCP 80 → Mac’in LAN IP’si:80**, görseller için **TCP 9000 → aynı LAN IP:9000** (MinIO).
3. `docker-compose up` **öncesi** aynı shell’de (evdeki kamu IP ile):

   ```bash
   export MINIO_PUBLIC_URL=http://<EV_KAMU_IP>:9000
   ```

   `<EV_KAMU_IP>`: evdeki Mac’ten `curl -s ifconfig.me` (CGNAT yoksa router WAN ile aynı olmalı).

4. Telefon / dış ağ testi: `http://<EV_KAMU_IP>/api/health` ve Flutter:

   ```bash
   cd mobile
   flutter run --dart-define=API_BASE_URL=http://<EV_KAMU_IP>
   ```

### Kurum (ör. ARDGRUP — sadece aynı kurumsal Wi‑Fi’den test)

Kurum firewall’u dışarıdan doğrudan Mac’e izin vermeyebilir; **ofis içi test** için telefon ile Mac **aynı Wi‑Fi**’de olsun.

**Tüm adımlar (LAN IP, `MINIO_PUBLIC_URL`, compose, Flutter, sorun giderme):** **`OFIS_CALISTIRMA.md`**.

Kısa özet: `ipconfig getifaddr en0` → `export MINIO_PUBLIC_URL=http://<LAN_IP>:9000` (§1 export’larıyla aynı shell) → `docker-compose up -d --build` → `http://<LAN_IP>/api/health` ve `flutter run --dart-define=API_BASE_URL=http://<LAN_IP>`.

**Özet**

| Nerede | `MINIO_PUBLIC_URL` tabanı | `API_BASE_URL` (Flutter) |
|--------|----------------------------|---------------------------|
| Ev (WAN) | `http://<ev kamu IP>:9000` | `http://<ev kamu IP>` |
| Kurum (LAN) | `http://<Mac LAN IP>:9000` | `http://<Mac LAN IP>` |

Export’ları veya LAN IP’yi değiştirdiyseniz API konteynerını yenileyin: `docker-compose up -d --force-recreate`.

## 5. Dışarıdan erişilebilir adresler (WAN)

- **API (HTTP):** `http://<PUBLIC_IP>/` — nginx **80** portu, path’ler `/api/...` ile aynı.
- **MinIO (görseller):** hostta **9000** açık; mobil/curl’ün gördüğü görsel URL’leri için taban adres gerekir.

Router’da (ev/ofis) **port yönlendirme** örneği:

| Dış port | Hedef (Mac LAN IP) | Servis |
|----------|--------------------|--------|
| 80 | `<Mac-LAN-IP>:80` | nginx → API |
| 9000 | `<Mac-LAN-IP>:9000` | MinIO |

Mac LAN IP (Wi‑Fi genelde `en0`):

```bash
ifconfig | grep "inet " | grep -v 127.0.0.1

   curl -s ifconfig.me
# boşsa: ipconfig getifaddr en1
```

**CGNAT:** ISP gerçek public IP vermiyorsa port açmak işe yaramaz; Cloudflare Tunnel, ngrok, Tailscale Funnel vb. düşünün.

## 6. Push tetik (token kaydı uygulamadan)

Bölüm 1’deki `export`’ları **aynı oturumda** kullandıysanız `ADMIN_SECRET` sunucuyla eşleşir. Yeni terminaldeyseniz tekrar `export ADMIN_SECRET=...` yapın veya header’a sunucudakiyle **aynı** değeri yazın (WAN üzerinden):

```bash
curl -sS -X POST "http://<PUBLIC_IP>/api/admin/daily-send" \
  -H "X-Admin-Secret: 214a5258fed487583e4156f749060226fac982b35711c8f34ed09ad32069a53c"
```

## 7. Telefon / farklı ağ (Flutter)

Aynı Wi‑Fi şartı yok; **public** taban kullanın (nginx 80 ise port yazmayabilirsiniz):

```bash
cd mobile
flutter run --release --dart-define=API_BASE_URL=http://<PUBLIC_IP>
```

MinIO görselleri için bölüm 2’deki `MINIO_PUBLIC_URL` adımını doğru verdiğinizden emin olun.

## 8. Port çakışması

Makinede **80** doluysa `backend/docker-compose.yml` içinde nginx için örneğin `"8080:80"` kullanıp dışarıdan `http://<PUBLIC_IP>:8080` ile erişin.

## Not

- Üretimde güçlü `JWT_SECRET` / `ADMIN_SECRET`; internete HTTP ile açmak risklidir — mümkünse HTTPS (ters proxy + sertifika).
- `.p8` ve servis hesabı JSON dosyalarını Git’e eklemeyin.
- `APNS_KEY_PATH` mutlak yol ve **dosya** (.p8); klasör değil.
