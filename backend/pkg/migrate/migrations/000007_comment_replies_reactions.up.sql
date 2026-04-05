-- Yoruma yanıt (thread)
ALTER TABLE comments
    ADD COLUMN IF NOT EXISTS parent_comment_id UUID REFERENCES comments (id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_comments_parent ON comments (parent_comment_id);

-- Beğeni (+1) / beğenmeme (-1); kullanıcı başına yorumda tek satır
CREATE TABLE IF NOT EXISTS comment_reactions (
    comment_id UUID NOT NULL REFERENCES comments (id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    value SMALLINT NOT NULL CHECK (value IN (-1, 1)),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (comment_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_comment_reactions_user ON comment_reactions (user_id);
