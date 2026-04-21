import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// İlk açılış değer önerisi (App Store 4.2 — ürünün ne olduğu).
class OnboardingService {
  OnboardingService._();

  static const _key = 'value_prop_onboarding_v1_done';
  static const _keyFirstMissionCoach = 'first_mission_coach_v1_done';
  static const _keyCommentPointsSpotlight = 'comment_points_spotlight_v1_done';
  static const _keyV1ChainPhase = 'onboarding_v1_chain_phase';
  static const _keyFullTourV2Phase = 'onboarding_full_tour_v2_phase';

  /// 0..22 ham adım; eski [0..7] compact v2 ile çakışmayı önlemek için ayrı anahtar.
  static const _keyFullTourV4Step = 'onboarding_full_tour_v4_step';

  /// Eski v1: İlk görev → günlük aksiyon → kart → yorum → puan → rozetler zinciri.
  /// [v1ChainDone] tamamlandı (veya eski kullanıcı migrasyonu).
  static const int v1NeedMissionCoach = 0;
  static const int v1NeedDailyAction = 1;
  static const int v1NeedMainCardCoach = 2;
  static const int v1NeedComposerCoach = 3;
  static const int v1NeedFirstComment = 4;
  static const int v1NeedBadgesPreview = 5;
  static const int v1ChainDone = 6;

  /// 22 adımlı global spotlight turu (0..21), tamamlanmış durum = 22.
  static const int tourStep00LoginIntro = 0;
  static const int tourStep01LoginApple = 1;
  static const int tourStep02LoginGoogle = 2;
  static const int tourStep03LoginSuccess = 3;
  static const int tourStep04HomeCardIntro = 4;
  static const int tourStep05HomeDailyAction = 5;
  static const int tourStep06HomeBadgesIntro = 6;
  static const int tourStep07HomeToExplore = 7;
  static const int tourStep08ExploreIntro = 8;
  static const int tourStep09ExploreSearch = 9;
  static const int tourStep10ExploreSaveIntro = 10;
  static const int tourStep11ExploreSaveAction = 11;
  static const int tourStep12ExploreToSaved = 12;
  static const int tourStep13SavedIntro = 13;
  static const int tourStep14SavedFirstItem = 14;
  static const int tourStep15SavedOpenDetail = 15;
  static const int tourStep16DetailHeroIntro = 16;
  static const int tourStep17DetailCommentComposer = 17;
  static const int tourStep18DetailSendComment = 18;
  static const int tourStep19DetailPointsSpotlight = 19;
  static const int tourStep20BadgesAfterComment = 20;
  static const int tourStep21FinalInfo = 21;
  static const int tourDone = 22;

  /// Eski isimler — ekran kodlarını kademeli migrate etmek için alias.
  static const int ftNeedLogin = tourStep00LoginIntro;
  static const int ftNeedHomeAction = tourStep05HomeDailyAction;
  static const int ftExploreIntro = tourStep08ExploreIntro;
  static const int ftExploreSave = tourStep10ExploreSaveIntro;
  static const int ftSavedList = tourStep14SavedFirstItem;
  static const int ftSavedComment = tourStep17DetailCommentComposer;
  static const int ftBadgesAfterTourComment = tourStep20BadgesAfterComment;
  static const int ftFullTourDone = tourDone;

  // --- Geliştirici: eski ilk görev spotlight’ı tekrar denemek ---
  static const bool kDebugRepeatFirstMissionCoach = false;

  /// Tur bitince prefs sıfırlanıp yeniden başlatılır (geliştirme).
  /// Test bittiğinde false yap.
  static bool kDebugRepeatFullTour = true;

  /// 22 adım için okunabilir envanter (debug/log amacıyla).
  static const List<(int step, String id)> fullTourStepInventory = [
    (tourStep00LoginIntro, 'login_intro'),
    (tourStep01LoginApple, 'login_apple'),
    (tourStep02LoginGoogle, 'login_google'),
    (tourStep03LoginSuccess, 'login_success'),
    (tourStep04HomeCardIntro, 'home_card_intro'),
    (tourStep05HomeDailyAction, 'home_daily_action'),
    (tourStep06HomeBadgesIntro, 'home_badges_intro'),
    (tourStep07HomeToExplore, 'home_to_explore'),
    (tourStep08ExploreIntro, 'explore_intro'),
    (tourStep09ExploreSearch, 'explore_search'),
    (tourStep10ExploreSaveIntro, 'explore_save_intro'),
    (tourStep11ExploreSaveAction, 'explore_save_action'),
    (tourStep12ExploreToSaved, 'explore_to_saved'),
    (tourStep13SavedIntro, 'saved_intro'),
    (tourStep14SavedFirstItem, 'saved_first_item'),
    (tourStep15SavedOpenDetail, 'saved_open_detail'),
    (tourStep16DetailHeroIntro, 'detail_hero_intro'),
    (tourStep17DetailCommentComposer, 'detail_comment_composer'),
    (tourStep18DetailSendComment, 'detail_send_comment'),
    (tourStep19DetailPointsSpotlight, 'detail_points_spotlight'),
    (tourStep20BadgesAfterComment, 'badges_after_comment'),
    (tourStep21FinalInfo, 'final_info'),
  ];

  static VoidCallback? _debugOnFirstMissionCoachCycleDone;

  /// Alt sekme değiştirmek için [main.dart] içindeki kabuk kaydeder.
  static void Function(int tabIndex)? _requestTab;

  static void setDebugFirstMissionCoachCycleListener(
    VoidCallback? onCycleDone,
  ) {
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
    if (p.containsKey(_keyFullTourV4Step)) {
      return;
    }

    if (p.containsKey(_keyFullTourV2Phase)) {
      final raw = p.getInt(_keyFullTourV2Phase) ?? 0;
      final migrated = _migrateLegacyCompactOrKeepFull(raw);
      await p.setInt(_keyFullTourV4Step, migrated);
      return;
    }

    final v1Stored = p.getInt(_keyV1ChainPhase);
    final v1Done = v1Stored != null && v1Stored >= v1ChainDone;
    if (v1Done) {
      await p.setInt(_keyFullTourV4Step, ftFullTourDone);
      return;
    }

    await p.setInt(_keyFullTourV4Step, ftNeedHomeAction);
  }

  /// Eski tek-bayt v2 (0..7) → 22 adım. 8..22 ise zaten geniş adım kabul edilir.
  static int _migrateLegacyCompactOrKeepFull(int raw) {
    if (raw < 0) return ftNeedHomeAction;
    if (raw > ftFullTourDone) return ftFullTourDone;
    if (raw > 7) {
      return raw;
    }
    switch (raw) {
      case 0:
        return ftNeedHomeAction;
      case 1:
        return ftNeedHomeAction;
      case 2:
        return ftExploreIntro;
      case 3:
        return ftExploreSave;
      case 4:
        return ftSavedList;
      case 5:
        return ftSavedComment;
      case 6:
        return ftBadgesAfterTourComment;
      case 7:
        return ftFullTourDone;
      default:
        return ftNeedHomeAction;
    }
  }

  static int _debugLoopStartStep() {
    return ftNeedLogin;
  }

  static Future<void> _applyDebugLoopIfNeeded(
    SharedPreferences p,
    int step,
  ) async {
    if (!kDebugRepeatFullTour) return;
    if (step < ftFullTourDone) return;
    await p.setInt(_keyFullTourV4Step, _debugLoopStartStep());
  }

  static Future<int> getGlobalTourStep() async {
    await ensureFullTourMigrated();
    final p = await SharedPreferences.getInstance();
    final step = p.getInt(_keyFullTourV4Step) ?? ftNeedHomeAction;
    var out = step.clamp(0, ftFullTourDone);
    // Uygulama yeniden açıldığında da debug döngüsü tetiklensin.
    if (kDebugRepeatFullTour && out >= ftFullTourDone) {
      final restartStep = _debugLoopStartStep();
      await p.setInt(_keyFullTourV4Step, restartStep);
      return restartStep;
    }
    return out;
  }

  static Future<void> setGlobalTourStep(int step) async {
    await ensureFullTourMigrated();
    final p = await SharedPreferences.getInstance();
    final clamped = step.clamp(0, ftFullTourDone);
    await p.setInt(_keyFullTourV4Step, clamped);
    if (clamped >= ftFullTourDone) {
      await _markLegacyV1DoneForMigration(p);
    }
    await _applyDebugLoopIfNeeded(p, clamped);
  }

  static Future<void> advanceGlobalTourStep({
    int by = 1,
    int? expectedCurrent,
  }) async {
    final current = await getGlobalTourStep();
    if (expectedCurrent != null && current != expectedCurrent) return;
    await setGlobalTourStep(current + by);
  }

  static Future<int> getFullTourPhase() async {
    return getGlobalTourStep();
  }

  static Future<void> setFullTourPhase(int phase) async {
    await setGlobalTourStep(phase);
  }

  static Future<void> _markLegacyV1DoneForMigration(SharedPreferences p) async {
    await p.setBool(_keyFirstMissionCoach, true);
    await p.setInt(_keyV1ChainPhase, v1ChainDone);
    await p.setBool(_keyCommentPointsSpotlight, true);
  }

  static Future<void> resetFullTourForDebug() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyFullTourV4Step, _debugLoopStartStep());
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
