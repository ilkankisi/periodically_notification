-- Rozet / sosyal puan özeti (Flutter GamificationService ile uyumlu alanlar)
CREATE TABLE IF NOT EXISTS user_gamification (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    social_points INT NOT NULL DEFAULT 0,
    comment_count INT NOT NULL DEFAULT 0,
    max_streak_recorded INT NOT NULL DEFAULT 0,
    unlocked_badges JSONB NOT NULL DEFAULT '[]'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_gamification_updated ON user_gamification (updated_at);
