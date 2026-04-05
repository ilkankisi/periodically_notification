package gamification

// ReactionPointsEarned tepki ekleme/güncelleme sonrası verilecek puan (kaldırma = 0).
func ReactionPointsEarned(prev *int, now *int, submittedValue int) int {
	if now == nil {
		return 0
	}
	if prev == nil {
		if submittedValue == 1 {
			return PointsReactionLike
		}
		return PointsReactionDislike
	}
	if *prev != submittedValue {
		if submittedValue == 1 {
			return PointsReactionLike
		}
		return PointsReactionDislike
	}
	return 0
}
