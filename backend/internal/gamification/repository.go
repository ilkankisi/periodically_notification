package gamification

import (
	"context"
	"database/sql"
	"encoding/json"
	"sort"
	"strings"
	"time"

	"github.com/jmoiron/sqlx"
)

// State API + Postgres satırı özeti.
type State struct {
	SocialPoints      int      `json:"socialPoints"`
	CommentCount      int      `json:"commentCount"`
	MaxStreakRecorded int      `json:"maxStreakRecorded"`
	Unlocked          []string `json:"unlocked"`
}

// Repository user_gamification + streak hesabı.
type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

// Sosyal puan sabitleri (tepkiler ve yorumlar).
const (
	PointsCommentTopLevel = 5
	PointsCommentThread   = 3
	PointsCommentReply    = 5
	PointsReactionLike    = 2
	PointsReactionDislike = 1
)

// HadOtherAuthorsOnItem bu içerikte (yeni yorumdan önce) başka kullanıcının yorumu var mı?
func (r *Repository) HadOtherAuthorsOnItem(ctx context.Context, ext sqlx.ExtContext, itemExternalID, userID string) (bool, error) {
	var n int
	err := sqlx.GetContext(ctx, ext, &n, `
		SELECT COUNT(*)::int FROM comments
		WHERE item_external_id = $1 AND user_id <> $2::uuid`,
		itemExternalID, userID)
	if err != nil {
		return false, err
	}
	return n > 0, nil
}

func parseUnlockedList(raw []byte) map[string]bool {
	out := map[string]bool{}
	if len(raw) == 0 {
		return out
	}
	var list []string
	if json.Unmarshal(raw, &list) != nil {
		return out
	}
	for _, id := range list {
		id = strings.TrimSpace(id)
		if id != "" {
			out[id] = true
		}
	}
	return out
}

func unlockedMapToSortedJSON(m map[string]bool) ([]byte, error) {
	list := make([]string, 0, len(m))
	for id := range m {
		list = append(list, id)
	}
	sort.Strings(list)
	return json.Marshal(list)
}

// AddSocialPointsTx yalnızca sosyal puan ekler (ör. tepki verme).
func (r *Repository) AddSocialPointsTx(ctx context.Context, tx *sqlx.Tx, userID string, delta int) error {
	if delta == 0 {
		return nil
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO user_gamification (user_id) VALUES ($1::uuid) ON CONFLICT (user_id) DO NOTHING`, userID); err != nil {
		return err
	}
	_, err := tx.ExecContext(ctx, `
		UPDATE user_gamification SET social_points = social_points + $2, updated_at = NOW()
		WHERE user_id = $1::uuid`, userID, delta)
	return err
}

// RecordCommentPostedTx yorum kaydı ile aynı transaction içinde puan + sosyal rozetleri günceller.
// hadOthersOnItem: üst seviye yorumda başka yazar vardı (thread bonusu).
// isReply: parent_comment_id dolu (yanıt bonusu).
func (r *Repository) RecordCommentPostedTx(ctx context.Context, tx *sqlx.Tx, userID string, hadOthersOnItem, isReply bool) (newBadges []string, pointsAwarded int, st *State, err error) {
	_, err = tx.ExecContext(ctx, `INSERT INTO user_gamification (user_id) VALUES ($1::uuid) ON CONFLICT (user_id) DO NOTHING`, userID)
	if err != nil {
		return nil, 0, nil, err
	}
	pointsAwarded = PointsCommentTopLevel
	if isReply {
		pointsAwarded += PointsCommentReply
	} else if hadOthersOnItem {
		pointsAwarded += PointsCommentThread
	}
	var social, cc, maxS int
	var raw []byte
	err = tx.QueryRowContext(ctx, `
		SELECT social_points, comment_count, max_streak_recorded, unlocked_badges
		FROM user_gamification WHERE user_id = $1::uuid FOR UPDATE`, userID).Scan(&social, &cc, &maxS, &raw)
	if err != nil {
		return nil, 0, nil, err
	}
	unlocked := parseUnlockedList(raw)
	newCC := cc + 1
	newSocial := social + pointsAwarded
	newly := make([]string, 0, 4)
	add := func(id string, cond bool) {
		if cond && !unlocked[id] {
			unlocked[id] = true
			newly = append(newly, id)
		}
	}
	add("social_first", newCC >= 1)
	add("social_10", newCC >= 10)
	add("social_50", newCC >= 50)
	add("social_thread", hadOthersOnItem || isReply)
	outJSON, err := unlockedMapToSortedJSON(unlocked)
	if err != nil {
		return nil, 0, nil, err
	}
	_, err = tx.ExecContext(ctx, `
		UPDATE user_gamification SET
			social_points = $2,
			comment_count = $3,
			unlocked_badges = $4::jsonb,
			updated_at = NOW()
		WHERE user_id = $1::uuid`,
		userID, newSocial, newCC, string(outJSON))
	if err != nil {
		return nil, 0, nil, err
	}
	var unlockedList []string
	_ = json.Unmarshal(outJSON, &unlockedList)
	st = &State{
		SocialPoints:      newSocial,
		CommentCount:      newCC,
		MaxStreakRecorded: maxS,
		Unlocked:          unlockedList,
	}
	return newly, pointsAwarded, st, nil
}

// GetState kayıtlı oyun durumunu döner; satır yoksa sıfır değerler.
func (r *Repository) GetState(ctx context.Context, userID string) (*State, error) {
	var social, cc, maxS int
	var raw []byte
	err := r.db.QueryRowContext(ctx, `
		SELECT social_points, comment_count, max_streak_recorded, unlocked_badges
		FROM user_gamification WHERE user_id = $1::uuid`, userID).Scan(&social, &cc, &maxS, &raw)
	if err == sql.ErrNoRows {
		return &State{Unlocked: []string{}}, nil
	}
	if err != nil {
		return nil, err
	}
	var unlockedList []string
	if len(raw) > 0 {
		_ = json.Unmarshal(raw, &unlockedList)
	}
	if unlockedList == nil {
		unlockedList = []string{}
	}
	return &State{
		SocialPoints:      social,
		CommentCount:      cc,
		MaxStreakRecorded: maxS,
		Unlocked:          unlockedList,
	}, nil
}

func maxConsecutiveStreakDays(dates []string) int {
	if len(dates) == 0 {
		return 0
	}
	parsed := make([]time.Time, 0, len(dates))
	for _, s := range dates {
		s = strings.TrimSpace(s)
		if s == "" {
			continue
		}
		if len(s) >= 10 {
			s = s[:10]
		}
		t, err := time.ParseInLocation("2006-01-02", s, time.UTC)
		if err != nil {
			continue
		}
		parsed = append(parsed, t)
	}
	if len(parsed) == 0 {
		return 0
	}
	sort.Slice(parsed, func(i, j int) bool { return parsed[i].Before(parsed[j]) })
	if len(parsed) == 1 {
		return 1
	}
	best := 1
	run := 1
	for i := 1; i < len(parsed); i++ {
		delta := int(parsed[i].Sub(parsed[i-1]).Hours() / 24)
		if delta == 1 {
			run++
			if run > best {
				best = run
			}
		} else if delta > 1 {
			run = 1
		}
	}
	return best
}

// SyncSocialAggregatesFromComments yorum sayısı ve sosyal rozetleri comments tablosu ile hizalar (geri doldurma / tutarlılık).
func (r *Repository) SyncSocialAggregatesFromComments(ctx context.Context, userID string) error {
	var cnt int
	if err := r.db.GetContext(ctx, &cnt, `SELECT COUNT(*)::int FROM comments WHERE user_id = $1::uuid`, userID); err != nil {
		return err
	}
	if _, err := r.db.ExecContext(ctx, `INSERT INTO user_gamification (user_id) VALUES ($1::uuid) ON CONFLICT (user_id) DO NOTHING`, userID); err != nil {
		return err
	}
	var sp, oldCC int
	var raw []byte
	err := r.db.QueryRowContext(ctx, `
		SELECT social_points, comment_count, unlocked_badges
		FROM user_gamification WHERE user_id = $1::uuid`, userID).Scan(&sp, &oldCC, &raw)
	if err != nil {
		return err
	}
	unlocked := parseUnlockedList(raw)
	newPoints := cnt * 5
	if sp > newPoints {
		newPoints = sp
	}
	if cnt >= 1 {
		unlocked["social_first"] = true
	}
	if cnt >= 10 {
		unlocked["social_10"] = true
	}
	if cnt >= 50 {
		unlocked["social_50"] = true
	}
	outJSON, err := unlockedMapToSortedJSON(unlocked)
	if err != nil {
		return err
	}
	_, err = r.db.ExecContext(ctx, `
		UPDATE user_gamification SET
			comment_count = $2,
			social_points = $3,
			unlocked_badges = $4::jsonb,
			updated_at = NOW()
		WHERE user_id = $1::uuid`,
		userID, cnt, newPoints, string(outJSON))
	return err
}

// SyncStreakFromActions actions tablosundan ardışık gün sayısını hesaplar, streak rozetlerini ve max_streak_recorded günceller.
func (r *Repository) SyncStreakFromActions(ctx context.Context, userID string) ([]string, error) {
	_, err := r.db.ExecContext(ctx, `INSERT INTO user_gamification (user_id) VALUES ($1::uuid) ON CONFLICT (user_id) DO NOTHING`, userID)
	if err != nil {
		return nil, err
	}
	var dates []string
	err = r.db.SelectContext(ctx, &dates, `
		SELECT DISTINCT local_date::text FROM actions WHERE user_id = $1::uuid ORDER BY local_date ASC`, userID)
	if err != nil {
		return nil, err
	}
	maxRun := maxConsecutiveStreakDays(dates)
	var raw []byte
	var maxRecorded int
	err = r.db.QueryRowContext(ctx, `
		SELECT COALESCE(unlocked_badges, '[]'::jsonb), max_streak_recorded
		FROM user_gamification WHERE user_id = $1::uuid`, userID).Scan(&raw, &maxRecorded)
	if err != nil {
		return nil, err
	}
	unlocked := parseUnlockedList(raw)
	newly := make([]string, 0, 3)
	add := func(id string, cond bool) {
		if cond && !unlocked[id] {
			unlocked[id] = true
			newly = append(newly, id)
		}
	}
	add("streak_7", maxRun >= 7)
	add("streak_30", maxRun >= 30)
	add("streak_365", maxRun >= 365)
	newMax := maxRecorded
	if maxRun > newMax {
		newMax = maxRun
	}
	outJSON, err := unlockedMapToSortedJSON(unlocked)
	if err != nil {
		return nil, err
	}
	_, err = r.db.ExecContext(ctx, `
		UPDATE user_gamification SET
			max_streak_recorded = $2,
			unlocked_badges = $3::jsonb,
			updated_at = NOW()
		WHERE user_id = $1::uuid`,
		userID, newMax, string(outJSON))
	return newly, err
}
