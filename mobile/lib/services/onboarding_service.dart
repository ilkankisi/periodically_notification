import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// İlk açılış değer önerisi (App Store 4.2 — ürünün ne olduğu).
class OnboardingService {
  OnboardingService._();

  static const _key = 'value_prop_onboarding_v1_done';
  static const _keyFirstMissionCoach = 'first_mission_coach_v1_done';
  static const _keyCommentPointsSpotlight = 'comment_points_spotlight_v1_done';
  static const _keyV1ChainPhase = 'onboarding_v1_chain_phase';

  /// İlk görev → günlük aksiyon → kart → yorum → puan → rozetler zinciri.
  /// [v1ChainDone] tamamlandı (veya eski kullanıcı migrasyonu).
  static const int v1NeedMissionCoach = 0;
  static const int v1NeedDailyAction = 1;
  static const int v1NeedMainCardCoach = 2;
  static const int v1NeedComposerCoach = 3;
  static const int v1NeedFirstComment = 4;
  static const int v1NeedBadgesPreview = 5;
  static const int v1ChainDone = 6;

  // --- Geliştirici: ilk görev spotlight’ı tekrar tekrar denemek ---
  static const bool kDebugRepeatFirstMissionCoach = false;

  static VoidCallback? _debugOnFirstMissionCoachCycleDone;

  static void setDebugFirstMissionCoachCycleListener(VoidCallback? onCycleDone) {
    _debugOnFirstMissionCoachCycleDone = onCycleDone;
  }

  static Future<bool> isCompleted() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_key) ?? false;
  }

  static Future<void> markCompleted() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, true);
  }

  static Future<int> getOnboardingV1Phase() async {
    final p = await SharedPreferences.getInstance();
    if (p.containsKey(_keyV1ChainPhase)) {
      return p.getInt(_keyV1ChainPhase)!;
    }
    final fmDone = p.getBool(_keyFirstMissionCoach) ?? false;
    if (fmDone) {
      await p.setInt(_keyV1ChainPhase, v1ChainDone);
      return v1ChainDone;
    }
    return v1NeedMissionCoach;
  }

  static Future<void> setOnboardingV1Phase(int phase) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyV1ChainPhase, phase);
  }

  /// Ana sayfadaki 2 adımlı spotlight (aksiyon + zincir) — faz 0 iken.
  static Future<bool> shouldShowFirstMissionCoach() async {
    if (kDebugRepeatFirstMissionCoach) return true;
    final phase = await getOnboardingV1Phase();
    return phase == v1NeedMissionCoach;
  }

  static Future<void> markFirstMissionCoachCompleted() async {
    if (kDebugRepeatFirstMissionCoach) {
      _debugOnFirstMissionCoachCycleDone?.call();
      return;
    }
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyFirstMissionCoach, true);
    await p.setInt(_keyV1ChainPhase, v1NeedDailyAction);
  }

  /// İlk yorum sonrası puan spotlight (faz 4 + gamification).
  static Future<bool> shouldShowOnboardingCommentPointsSpotlight() async {
    final phase = await getOnboardingV1Phase();
    return phase == v1NeedFirstComment;
  }

  /// Eski anahtar ile uyumluluk; zincir dışı ilk yorum SnackBar için kullanılmaz.
  static Future<bool> shouldShowCommentPointsSpotlight() async {
    return shouldShowOnboardingCommentPointsSpotlight();
  }

  static Future<void> markCommentPointsSpotlightCompleted() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyCommentPointsSpotlight, true);
    await p.setInt(_keyV1ChainPhase, v1NeedBadgesPreview);
  }

  static Future<void> markV1BadgesPreviewCompleted() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyV1ChainPhase, v1ChainDone);
  }
}
