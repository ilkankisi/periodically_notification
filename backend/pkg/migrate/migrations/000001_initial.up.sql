-- pkg/migrate/migrations/000001_initial.up.sql
-- Migration'lar embed ile binary'ye gömülür, bu yüzden pkg/migrate içinde.

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

CREATE TABLE IF NOT EXISTS daily_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "order" INT NOT NULL UNIQUE,
    title VARCHAR(500) NOT NULL,
    body TEXT NOT NULL,
    image_url TEXT,
    source_page_url TEXT,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_daily_items_order ON daily_items("order");

CREATE TABLE IF NOT EXISTS daily_state (
    id INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    next_order INT NOT NULL DEFAULT 1,
    last_sent_at TIMESTAMPTZ,
    last_sent_item_id UUID REFERENCES daily_items(id),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO daily_state (id, next_order) VALUES (1, 1)
ON CONFLICT (id) DO NOTHING;
