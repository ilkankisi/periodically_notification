package comments

import "time"

// Comment DB satırı / API.
type Comment struct {
	ID               string    `db:"id" json:"id"`
	ItemExternalID   string    `db:"item_external_id" json:"itemId"`
	UserID           string    `db:"user_id" json:"userId"`
	ParentID         *string   `db:"parent_comment_id" json:"parentId,omitempty"`
	Text             string    `db:"text" json:"text"`
	CreatedAt        time.Time `db:"created_at" json:"createdAt"`
	DisplayName      string    `db:"display_name" json:"userDisplayName"`
	PhotoURL         *string   `db:"photo_url" json:"userPhotoUrl,omitempty"`
	LikeCount        int       `db:"like_count" json:"likeCount"`
	DislikeCount     int       `db:"dislike_count" json:"dislikeCount"`
	MyReaction       *int      `db:"my_reaction" json:"myReaction,omitempty"`
}

// CreateRequest POST gövdesi.
type CreateRequest struct {
	ItemID          string  `json:"itemId" binding:"required"`
	Text            string  `json:"text" binding:"required"`
	ParentCommentID *string `json:"parentId"`
}

// ReactionRequest POST /v1/comments/:id/reaction
type ReactionRequest struct {
	Value int `json:"value"`
}
