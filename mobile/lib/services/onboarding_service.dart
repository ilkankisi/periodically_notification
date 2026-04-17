import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// İlk açılış değer önerisi (App Store 4.2 — ürünün ne olduğu).
class OnboardingService {
  OnboardingService._();

  static const _key = 'value_prop_onboarding_v1_done';
  static const _keyFirstMissionCoach = 'first_mission_coach_v1_done';
  static const _keyCommentPointsSpotlight = 'comment_points_spotlight_v1_done';
  static const _keyV1ChainPhase = 'onboarding_v1_chain_phase';
  static const _keyFullTourV2Phase = 'onboarding_full_tour_v2_phase';

  /// Eski v1: İlk görev → günlük aksiyon → kart → yorum → puan → rozetler zinciri.
  /// [v1ChainDone] tamamlandı (veya eski kullanıcı migrasyonu).
  static const int v1NeedMissionCoach = 0;
  static const int v1NeedDailyAction = 1;
  static const int v1NeedMainCardCoach = 2;
  static const int v1NeedComposerCoach = 3;
  static const int v1NeedFirstComment = 4;
  static const int v1NeedBadgesPreview = 5;
  static const int v1ChainDone = 6;

  /// Genişletilmiş tur v2 (plan: giriş → aksiyon → rozet → Keşfet → kaydet → Kaydedilenler → yorum → rozet).
  static const int ftNeedLogin = 0;
  static const int ftNeedHomeAction = 1;
  static const int ftExploreIntro = 2;
  static const int ftExploreSave = 3;
  static const int ftSavedList = 4;
  static const int ftSavedComment = 5;
  static const int ftBadgesAfterTourComment = 6;
  static const int ftFullTourDone = 7;

  // --- Geliştirici: eski ilk görev spotlight’ı tekrar denemek ---
  static const bool kDebugRepeatFirstMissionCoach = false;

  /// Tur bitince prefs sıfırlanıp yeniden başlatılır (geliştirme).
  static const bool kDebugRepeatFullTour = false;

  static VoidCallback? _debugOnFirstMissionCoachCycleDone;

  /// Alt sekme değiştirmek için [main.dart] içindeki kabuk kaydeder.
  static void Function(int tabIndex)? _requestTab;

  static void setDebugFirstMissionCoachCycleListener(VoidCallback? onCycleDone) {
    _debugOnFirstMissionCoachCycleDone = onCycleDone;
  }

  static void registerTabRequestHandler(void Function(int tabIndex)? handler) {
    _requestTab = handler;
  }

  static void requestTab(int index) {
    _requestTab?.call(index);
  }

  static Future<bool> isCompleted() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_key) ?? false;
  }

  static Future<void> markCompleted() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, true);
  }

  // --- Full tour v2 ---

  static Future<void> ensureFullTourMigrated() async {
    final p = await SharedPreferences.getInstance();
    if (p.containsKey(_keyFullTourV2Phase)) return;

    final v1Stored = p.getInt(_keyV1ChainPhase);
    final v1Done = v1Stored != null && v1Stored >= v1ChainDone;
    if (v1Done) {
      await p.setInt(_keyFullTourV2Phase, ftFullTourDone);
      return;
    }

    if (AuthService.isLoggedIn) {
      await p.setInt(_keyFullTourV2Phase, ftNeedHomeAction);
    } else {
      await p.setInt(_keyFullTourV2Phase, ftNeedLogin);
    }
  }

  static Future<int> getFullTourPhase() async {
    await ensureFullTourMigrated();
    final p = await SharedPreferences.getInstance();
    return p.getInt(_keyFullTourV2Phase) ?? ftNeedLogin;
  }

  static Future<void> setFullTourPhase(int phase) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyFullTourV2Phase, phase);
    if (phase >= ftFullTourDone) {
      await _markLegacyV1DoneForMigration(p);
    }
  }

  static Future<void> _markLegacyV1DoneForMigration(SharedPreferences p) async {
    await p.setBool(_keyFirstMissionCoach, true);
    await p.setInt(_keyV1ChainPhase, v1ChainDone);
    await p.setBool(_keyCommentPointsSpotlight, true);
  }

  static Future<void> resetFullTourForDebug() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyFullTourV2Phase);
    await ensureFullTourMigrated();
  }

  /// Legacy v1 coach’ları (ilk görev / ana kart / eski detay zinciri) full tur bitene kadar kapalı.
  static Future<bool> isFullTourBlockingLegacyV1() async {
    final ph = await getFullTourPhase();
    return ph < ftFullTourDone;
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
    if (await isFullTourBlockingLegacyV1()) return false;
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

  /// İlk yorum sonrası puan spotlight (eski v1 faz 4 + gamification) veya full tur faz 5.
  static Future<bool> shouldShowOnboardingCommentPointsSpotlight() async {
    final ftp = await getFullTourPhase();
    if (ftp == ftSavedComment) return true;
    final phase = await getOnboardingV1Phase();
    return phase == v1NeedFirstComment;
  }

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
