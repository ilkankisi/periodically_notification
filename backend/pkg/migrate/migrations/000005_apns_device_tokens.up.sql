CREATE TABLE IF NOT EXISTS apns_device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_token VARCHAR(160) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_apns_device_tokens_last_seen ON apns_device_tokens(last_seen_at);
