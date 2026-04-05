-- scripts/seed.sql
-- NEDEN?
-- Geliştirme/test için örnek veri. PostgreSQL'e bağlanıp bu dosyayı çalıştırabilirsin:
--   psql -h localhost -U app -d periodically -f scripts/seed.sql

INSERT INTO daily_items ("order", title, body, image_url)
VALUES 
  (1, 'Başlamak için mükemmel olman gerekmez', 'Başlamak seni geliştirir.', NULL),
  (2, 'Küçük bir adım, yerinde saymaktan daha güçlüdür', 'Her gün küçük ilerlemeler yap.', NULL),
  (3, 'Bugün attığın adım, yarının yönünü belirler', 'Bugün yapacakların yarını şekillendirir.', NULL)
ON CONFLICT ("order") DO NOTHING;

-- Kontrol için:
-- SELECT * FROM daily_items;
