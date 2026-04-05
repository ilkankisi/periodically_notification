-- users: Firebase + soft delete
ALTER TABLE users ADD COLUMN IF NOT EXISTS firebase_uid VARCHAR(128) UNIQUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS display_name VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_firebase_uid ON users(firebase_uid) WHERE firebase_uid IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_deleted ON users(deleted_at) WHERE deleted_at IS NULL;

-- quotes: Firestore mirror (external_id = Firestore doc id)
CREATE TABLE IF NOT EXISTS quotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    external_id VARCHAR(64) UNIQUE NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_quotes_external_id ON quotes(external_id);

-- actions
CREATE TABLE IF NOT EXISTS actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    quote_id UUID NOT NULL REFERENCES quotes(id),
    local_date DATE NOT NULL,
    note TEXT NOT NULL,
    idempotency_key VARCHAR(64),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_actions_user_date ON actions(user_id, local_date DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_actions_idempotency ON actions(idempotency_key) WHERE idempotency_key IS NOT NULL;

-- user_day_cache (streak)
CREATE TABLE IF NOT EXISTS user_day_cache (
    user_id UUID NOT NULL REFERENCES users(id),
    local_date DATE NOT NULL,
    action_count INT NOT NULL DEFAULT 1,
    PRIMARY KEY (user_id, local_date)
);

-- streak_cache
CREATE TABLE IF NOT EXISTS streak_cache (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    current INT NOT NULL DEFAULT 0,
    best INT NOT NULL DEFAULT 0,
    last_date DATE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- reports (comment_id = Firestore doc id, string)
CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(id),
    comment_id VARCHAR(128) NOT NULL,
    quote_id VARCHAR(128) NOT NULL,
    reason VARCHAR(50) NOT NULL,
    details TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_reports_comment ON reports(comment_id);

-- blocks
CREATE TABLE IF NOT EXISTS blocks (
    blocker_id UUID NOT NULL REFERENCES users(id),
    blocked_id UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (blocker_id, blocked_id)
);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON blocks(blocked_id);
