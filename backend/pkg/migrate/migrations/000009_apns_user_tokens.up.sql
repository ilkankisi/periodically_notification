-- APNs cihaz jetonunu giriş yapmış kullanıcıya bağla (hedefli push için)
ALTER TABLE apns_device_tokens
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_apns_device_tokens_user ON apns_device_tokens (user_id)
    WHERE user_id IS NOT NULL;
