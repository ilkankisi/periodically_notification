ALTER TABLE users ADD COLUMN IF NOT EXISTS google_sub VARCHAR(255) UNIQUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS apple_sub VARCHAR(255) UNIQUE;
CREATE INDEX IF NOT EXISTS idx_users_google_sub ON users(google_sub) WHERE google_sub IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_apple_sub ON users(apple_sub) WHERE apple_sub IS NOT NULL;
