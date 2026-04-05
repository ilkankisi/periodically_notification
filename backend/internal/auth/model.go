// internal/auth/model.go
//
// User: JWT auth için. password_hash API'de asla dönmez.
// NEDEN?: Güvenlik - hash bile olsa istemciye gönderilmez.

package auth

import "time"

// User veritabanı modeli.
type User struct {
	ID           string     `db:"id" json:"id"`
	FirebaseUID  *string    `db:"firebase_uid" json:"-"`
	GoogleSub    *string    `db:"google_sub" json:"-"`
	AppleSub     *string    `db:"apple_sub" json:"-"`
	Email        string     `db:"email" json:"email"`
	PasswordHash *string    `db:"password_hash" json:"-"`
	DisplayName  *string    `db:"display_name" json:"-"`
	PhotoURL     *string    `db:"photo_url" json:"-"`
	CreatedAt    time.Time  `db:"created_at" json:"createdAt"`
	UpdatedAt    time.Time  `db:"updated_at" json:"updatedAt"`
	DeletedAt    *time.Time `db:"deleted_at" json:"-"`
}

// UserResponse API'de dönen kullanıcı.
type UserResponse struct {
	ID          string    `json:"id"`
	Email       string    `json:"email"`
	DisplayName string    `json:"displayName,omitempty"`
	PhotoURL    string    `json:"photoUrl,omitempty"`
	CreatedAt   time.Time `json:"createdAt"`
}
