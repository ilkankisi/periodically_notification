-- Yorumlar: Firestore daily_items/{itemId}/comments yerine Postgres
CREATE TABLE IF NOT EXISTS comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_external_id VARCHAR(128) NOT NULL,
    user_id UUID NOT NULL REFERENCES users(id),
    text TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_comments_item_created ON comments(item_external_id, created_at);
