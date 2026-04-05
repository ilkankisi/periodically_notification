// internal/auth/repository.go
//
// User CRUD - sadece auth için gerekli olanlar.
// Create: register, FindByEmail: login, GetByID: /api/me

package auth

import (
	"context"
	"database/sql"
	"errors"
	"strings"

	"github.com/jmoiron/sqlx"
)

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

// Create yeni kullanıcı kaydeder (email/password).
func (r *Repository) Create(ctx context.Context, email, passwordHash string) (*User, error) {
	var user User
	query := `INSERT INTO users (email, password_hash) VALUES ($1, $2)
		RETURNING id::text, email, created_at, updated_at`
	err := r.db.QueryRowContext(ctx, query, email, passwordHash).Scan(&user.ID, &user.Email, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// FindByFirebaseUID Firebase UID ile kullanıcı arar. Silinmemiş.
func (r *Repository) FindByFirebaseUID(ctx context.Context, uid string) (*User, error) {
	var user User
	query := `SELECT id::text, firebase_uid, google_sub, apple_sub, email, display_name, photo_url, created_at, updated_at
		FROM users WHERE firebase_uid = $1 AND deleted_at IS NULL`
	err := r.db.GetContext(ctx, &user, query, uid)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// FindByGoogleSub Google "sub" ile kullanıcı arar.
func (r *Repository) FindByGoogleSub(ctx context.Context, sub string) (*User, error) {
	var user User
	q := `SELECT id::text, firebase_uid, google_sub, apple_sub, email, display_name, photo_url, created_at, updated_at
		FROM users WHERE google_sub = $1 AND deleted_at IS NULL`
	err := r.db.GetContext(ctx, &user, q, sub)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// FindByAppleSub Apple "sub" ile kullanıcı arar.
func (r *Repository) FindByAppleSub(ctx context.Context, sub string) (*User, error) {
	var user User
	q := `SELECT id::text, firebase_uid, google_sub, apple_sub, email, display_name, photo_url, created_at, updated_at
		FROM users WHERE apple_sub = $1 AND deleted_at IS NULL`
	err := r.db.GetContext(ctx, &user, q, sub)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// CreateFromFirebase Firebase ile ilk girişte kullanıcı oluşturur.
func (r *Repository) CreateFromFirebase(ctx context.Context, firebaseUID, email, displayName, photoURL string) (*User, error) {
	var user User
	query := `INSERT INTO users (firebase_uid, email, display_name, photo_url) VALUES ($1, $2, $3, $4)
		RETURNING id::text, firebase_uid, email, display_name, photo_url, created_at, updated_at`
	err := r.db.QueryRowContext(ctx, query, firebaseUID, email, displayName, photoURL).Scan(
		&user.ID, &user.FirebaseUID, &user.Email, &user.DisplayName, &user.PhotoURL, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// FindByEmail email ile kullanıcı arar. Yoksa sql.ErrNoRows.
func (r *Repository) FindByEmail(ctx context.Context, email string) (*User, error) {
	var user User
	query := `SELECT id::text, email, password_hash, firebase_uid, google_sub, apple_sub, display_name, photo_url, created_at, updated_at
		FROM users WHERE email = $1 AND deleted_at IS NULL`
	err := r.db.GetContext(ctx, &user, query, email)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// GetByID ID ile kullanıcı getirir. Silinmiş kullanıcıları döndürmez.
func (r *Repository) GetByID(ctx context.Context, id string) (*User, error) {
	var user User
	query := `SELECT id::text, firebase_uid, google_sub, apple_sub, email, display_name, photo_url, created_at, updated_at
		FROM users WHERE id = $1 AND deleted_at IS NULL`
	err := r.db.GetContext(ctx, &user, query, id)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, err
		}
		return nil, err
	}
	return &user, nil
}

// UpsertGoogleUser google_sub ile bulur veya email ile bağlar veya yeni kayıt açar.
func (r *Repository) UpsertGoogleUser(ctx context.Context, googleSub, email, displayName, photoURL string) (*User, error) {
	email = strings.TrimSpace(strings.ToLower(email))
	u, err := r.FindByGoogleSub(ctx, googleSub)
	if err == nil {
		_ = r.patchProfile(ctx, u.ID, displayName, photoURL)
		return r.GetByID(ctx, u.ID)
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return nil, err
	}
	if email != "" {
		u, err = r.FindByEmail(ctx, email)
		if err == nil {
			_, err = r.db.ExecContext(ctx, `
				UPDATE users SET google_sub = $2,
					display_name = COALESCE(NULLIF($3, ''), display_name),
					photo_url = COALESCE(NULLIF($4, ''), photo_url),
					updated_at = NOW()
				WHERE id = $1::uuid AND deleted_at IS NULL`,
				u.ID, googleSub, displayName, photoURL)
			if err != nil {
				return nil, err
			}
			return r.GetByID(ctx, u.ID)
		}
		if !errors.Is(err, sql.ErrNoRows) {
			return nil, err
		}
	}
	if email == "" {
		email = "google." + googleSub + "@signin.local"
	}
	var user User
	err = r.db.QueryRowContext(ctx, `
		INSERT INTO users (email, google_sub, display_name, photo_url) VALUES ($1, $2, $3, $4)
		RETURNING id::text, firebase_uid, google_sub, apple_sub, email, display_name, photo_url, created_at, updated_at`,
		email, googleSub, strOrNil(displayName), strOrNil(photoURL)).Scan(
		&user.ID, &user.FirebaseUID, &user.GoogleSub, &user.AppleSub, &user.Email, &user.DisplayName, &user.PhotoURL, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// UpsertAppleUser apple_sub ile bulur veya email ile bağlar veya yeni kayıt açar.
func (r *Repository) UpsertAppleUser(ctx context.Context, appleSub, email, displayName string) (*User, error) {
	email = strings.TrimSpace(strings.ToLower(email))
	u, err := r.FindByAppleSub(ctx, appleSub)
	if err == nil {
		_ = r.patchProfile(ctx, u.ID, displayName, "")
		return r.GetByID(ctx, u.ID)
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return nil, err
	}
	if email != "" {
		u, err = r.FindByEmail(ctx, email)
		if err == nil {
			_, err = r.db.ExecContext(ctx, `
				UPDATE users SET apple_sub = $2,
					display_name = COALESCE(NULLIF($3, ''), display_name),
					updated_at = NOW()
				WHERE id = $1::uuid AND deleted_at IS NULL`,
				u.ID, appleSub, displayName)
			if err != nil {
				return nil, err
			}
			return r.GetByID(ctx, u.ID)
		}
		if !errors.Is(err, sql.ErrNoRows) {
			return nil, err
		}
	}
	if email == "" {
		email = "apple." + strings.ReplaceAll(appleSub, ".", "_") + "@signin.local"
	}
	var user User
	err = r.db.QueryRowContext(ctx, `
		INSERT INTO users (email, apple_sub, display_name) VALUES ($1, $2, $3)
		RETURNING id::text, firebase_uid, google_sub, apple_sub, email, display_name, photo_url, created_at, updated_at`,
		email, appleSub, strOrNil(displayName)).Scan(
		&user.ID, &user.FirebaseUID, &user.GoogleSub, &user.AppleSub, &user.Email, &user.DisplayName, &user.PhotoURL, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *Repository) patchProfile(ctx context.Context, userID, displayName, photoURL string) error {
	if displayName == "" && photoURL == "" {
		return nil
	}
	_, err := r.db.ExecContext(ctx, `
		UPDATE users SET
			display_name = COALESCE(NULLIF($2, ''), display_name),
			photo_url = COALESCE(NULLIF($3, ''), photo_url),
			updated_at = NOW()
		WHERE id = $1::uuid AND deleted_at IS NULL`,
		userID, displayName, photoURL)
	return err
}

func strOrNil(s string) interface{} {
	if strings.TrimSpace(s) == "" {
		return nil
	}
	return s
}

// SoftDelete hesabı soft delete yapar.
func (r *Repository) SoftDelete(ctx context.Context, userID string) error {
	_, err := r.db.ExecContext(ctx, `UPDATE users SET deleted_at = NOW() WHERE id = $1`, userID)
	return err
}
