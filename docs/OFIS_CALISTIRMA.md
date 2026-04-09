# Ofiste backend (kurumsal Wi‑Fi + Docker)

> Amaç: Mac ve test telefonu **aynı kurumsal Wi‑Fi** (ör. ARDGRUP) üzerindeyken API + MinIO’ya LAN IP ile erişmek. Dış ağdan kamu IP beklentisi yoktur.

Tam mimari ve ev ortamı: `REMOTE_CALISTIRMA.md`.

## Ön koşullar (bir kez)

1. `backend/docker-compose.override.yml` — `.p8` yolu ve `APNS_KEY_PATH` (örnek: `docker-compose.override.example.yml`).
2. Colima / Docker çalışır durumda.

## Her ofis oturumunda (LAN IP değişebilir)

DHCP ile Mac IP’si gün veya ağ değişiminde farklı olabilir; **compose çalıştırmadan önce** `MINIO_PUBLIC_URL`’ü o anki IP ile verin.

### 1) Mac LAN IP’sini al

**Wi‑Fi ile kablosuz kullanımda** Ethernet takılı olması gerekmez. `en0` / `en1` isimleri “Wi‑Fi mi kablo mu?” demez; model ve macOS sürümüne göre Wi‑Fi bazen `en0`, bazen `en1` olabilir. Önemli olan: **aktif bağlantının olduğu arayüzün IPv4 adresi**.

Önce yaygın olanı dene:

```bash
ipconfig getifaddr en0
```

Boşsa diğerini:

```bash
ipconfig getifaddr en1
```

Hangi donanımın hangi `en*` olduğunu görmek için:

```bash
networksetup -listallhardwareports
```

Wi‑Fi satırındaki **Device** adı (ör. `en0`) ile `ipconfig getifaddr <o isim>` kullanın.

Bu çıktıyı not edin; aşağıda `<LAN_IP>` yerine kullanılacak.

### 2) Aynı terminalde — compose’tan önce

`REMOTE_CALISTIRMA.md` **§1** ile **aynı** `APNS_*` ve `ADMIN_SECRET` export’larını verin (kopyalamak için o bölüme bakın). Ardından **ofis** için:

```bash
export MINIO_PUBLIC_URL=http://<LAN_IP>:9000
```

Örnek (`10.11.10.212` sadece örnek — kendi `ipconfig` çıktınızı yazın):

```bash
export MINIO_PUBLIC_URL=http://10.11.10.212:9000
```

### 3) Stack’i kaldır

```bash
colima start
cd backend
docker-compose up -d --build
```

Export’ları veya `<LAN_IP>`’yi değiştirdiyseniz API’nin yeni env ile gelmesi için:

```bash
docker-compose up -d --force-recreate
```

### 4) Kontrol (Mac’te)

```bash
curl -s http://127.0.0.1/api/health
```

Aynı Wi‑Fi’deki telefon veya başka PC’den (tarayıcı veya curl):

```text
http://<LAN_IP>/api/health
```

### 5) Flutter (fiziksel cihaz, aynı Wi‑Fi)

Repokökünden:

```bash
cd mobile
flutter run --dart-define=API_BASE_URL=http://<LAN_IP>
```

`API_BASE_URL` sonunda **port yazmayın** (nginx 80); sonda **`/`** olmasın.

## Özet tablo (ofis)

| Ne | Değer |
|----|--------|
| `MINIO_PUBLIC_URL` | `http://<LAN_IP>:9000` |
| Flutter `API_BASE_URL` | `http://<LAN_IP>` |
| Test URL | `http://<LAN_IP>/api/health` |

## Sorun giderme

| Belirti | Olası neden |
|---------|-------------|
| Telefondan `<LAN_IP>` açılmıyor | Farklı Wi‑Fi / misafir ağ; kurumsal **aynı SSID** kullanın. |
| `ipconfig getifaddr en0` boş | Aynı Wi‑Fi ile `en1` dene; kablo şart değil — `networksetup -listallhardwareports` ile Wi‑Fi’nin `en*` adını doğrula. |
| `127.0.0.1` çalışır, LAN çalışmaz | macOS Güvenlik Duvarı veya kurum istemci güvenlik duvarı. |
| Görseller bozuk | `MINIO_PUBLIC_URL` hâlâ eski IP; IP değiştiyse export + `force-recreate`. |
| Yerel 80 dolu | `docker-compose.yml` içinde nginx için `"8080:80"` ve URL’lere `:8080` ekleyin (`REMOTE_CALISTIRMA.md` §8). |
| Telefondan health JSON geliyor ama Mac’te “dinleyicide” / logda yok | İstek **API konteynerına** düşer; Mac’te `docker logs -f periodically-api` (veya `periodically-nginx`) ile **istek atmadan hemen önce** akışı açın. Yanlış pencere (Colima dışı, başka terminal) veya sadece eski satırlara bakılıyor olabilir. Safari önbelleği şüphesi: `http://<LAN_IP>/api/health?t=1` deneyin. |
| Go logunda istemci `172.18.x` / `X-Forwarded-For` telefon IP’si değil | Gin artık `TRUSTED_PROXIES` ile vekil başlıklarını kullanır; satırda `X-Forwarded-For: ...` da yazılır. **Docker Desktop / Colima** bazen gerçek istemci IP’sini konteynıra iletmez; nginx de `$remote_addr` olarak köprü IP’si görür — bu durumda hem `ClientIP` hem `X-Forwarded-For` aynı köprü adresi olur. **Linux sunucu** veya kaynak IP’yi koruyan port yönlendirmede gerçek LAN IP’si görünür. |
