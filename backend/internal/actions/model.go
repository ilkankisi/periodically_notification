package actions

import "time"

type Action struct {
	ID             string    `db:"id" json:"id"`
	UserID         string    `db:"user_id" json:"userId"`
	QuoteID        string    `db:"quote_id" json:"quoteId"`
	QuoteExternalID string   `json:"quoteId"` // response'ta client'a external_id döner
	LocalDate      string    `db:"local_date" json:"localDate"`
	Note           string    `db:"note" json:"note"`
	CreatedAt      time.Time `db:"created_at" json:"createdAt"`
}

type CreateRequest struct {
	QuoteID   string `json:"quoteId" binding:"required"`
	LocalDate string `json:"localDate" binding:"required"`
	Note      string `json:"note" binding:"required"`
}
