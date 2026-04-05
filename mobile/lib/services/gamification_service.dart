import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/action_entry.dart';
import 'auth_service.dart';
import 'backend_service.dart';

/// UI için anlık rozet / puan özeti.
class GamificationSnapshot {
  final int socialPoints;
  final int commentCount;
  final int maxStreakRecorded;
  final Set<String> unlocked;

  const GamificationSnapshot({
    required this.socialPoints,
    required this.commentCount,
    required this.maxStreakRecorded,
    required this.unlocked,
  });
}

/// Rozetler + sosyal puan (cihazda, kullanıcı id anahtarına bağlı).
class GamificationService {
  GamificationService._();

  static final ValueNotifier<void> onStateChanged = ValueNotifier<void>(null);

  static const int pointsPerComment = 5;
  static const int pointsThreadBonus = 3;

  static String _prefsKey() {
    final id = AuthService.backendUserId ?? 'guest';
    return 'gamification_state_v1_$id';
  }

  static Future<_GamificationState> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey());
    if (raw == null || raw.isEmpty) return _GamificationState.empty();
    try {
      return _GamificationState.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return _GamificationState.empty();
    }
  }

  static Future<void> _save(_GamificationState s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey(), json.encode(s.toJson()));
    onStateChanged.value = null;
  }

  /// Maksimum ardışık aksiyon günü (tüm geçmiş).
  static int maxConsecutiveStreak(Set<String> dateKeys) {
    if (dateKeys.isEmpty) return 0;
    final days = <DateTime>[];
    for (final k in dateKeys) {
      try {
        final p = DateTime.parse(k.split('T').first.trim());
        days.add(DateTime(p.year, p.month, p.day));
      } catch (_) {}
    }
    if (days.isEmpty) return 0;
    days.sort();
    var best = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      final delta = days[i].difference(days[i - 1]).inDays;
      if (delta == 1) {
        run++;
        if (run > best) best = run;
      } else if (delta > 1) {
        run = 1;
      }
    }
    return best;
  }

  static Set<String> _normalizeActionDates(List<ActionEntry> actions) {
    final set = <String>{};
    for (final e in actions) {
      final raw = e.localDate.trim();
      if (raw.isEmpty) continue;
      try {
        final d = DateTime.parse(raw.split('T').first.trim());
        set.add(
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        );
      } catch (_) {}
    }
    return set;
  }

  /// Aksiyon listesinden zincir rozetlerini güncelle (çevrimdışı / yedek).
  static Future<List<String>> syncStreakFromActions(List<ActionEntry> actions) async {
    if (!AuthService.isLoggedIn) return [];
    final dates = _normalizeActionDates(actions);
    final maxRun = maxConsecutiveStreak(dates);
    final state = await _load();
    final newly = <String>[];

    void unlockIf(String id, bool condition) {
      if (condition && !state.unlocked.contains(id)) {
        state.unlocked.add(id);
        newly.add(id);
      }
    }

    unlockIf('streak_7', maxRun >= 7);
    unlockIf('streak_30', maxRun >= 30);
    unlockIf('streak_365', maxRun >= 365);

    if (maxRun > state.maxStreakRecorded) {
      state.maxStreakRecorded = maxRun;
    }
    await _save(state);
    return newly;
  }

  /// Sunucudaki `user_gamification` + aksiyonlardan hesaplanan streak rozetlerini çeker.
  static Future<void> syncFromBackend() async {
    if (!AuthService.isLoggedIn) return;
    final ok = await BackendService.ensureToken();
    if (!ok) return;
    final m = await BackendService.client.getGamification();
    if (m == null) return;
    await persistServerGamificationFromMap(m);
  }

  static Future<void> persistServerGamificationFromMap(Map<String, dynamic> m) async {
    final unlocked = <String>{};
    for (final e in (m['unlocked'] as List?) ?? []) {
      unlocked.add(e.toString());
    }
    await _save(_GamificationState(
      socialPoints: (m['socialPoints'] as num?)?.toInt() ?? 0,
      commentCount: (m['commentCount'] as num?)?.toInt() ?? 0,
      maxStreakRecorded: (m['maxStreakRecorded'] as num?)?.toInt() ?? 0,
      unlocked: unlocked,
    ));
  }

  /// POST /comments/:id/reaction yanıtındaki `gamification` özetini uygular.
  static Future<void> applyReactionServerSummary(Map<String, dynamic> data) async {
    final g = data['gamification'];
    if (g is Map) {
      await persistServerGamificationFromMap(Map<String, dynamic>.from(g));
    }
  }

  static const int pointsReplyBonus = 5;

  /// Yorum gönderildiğinde puan + sosyal rozetler (yalnızca eski API / çevrimdışı yedek).
  /// [hadOtherAuthorsOnThread]: Üst düzey yorumda başka yazar vardı.
  static Future<List<String>> recordCommentPosted({
    required bool hadOtherAuthorsOnThread,
    bool isReply = false,
  }) async {
    if (!AuthService.isLoggedIn) return [];
    final state = await _load();
    final newly = <String>[];

    state.socialPoints += pointsPerComment;
    if (isReply) {
      state.socialPoints += pointsReplyBonus;
    } else if (hadOtherAuthorsOnThread) {
      state.socialPoints += pointsThreadBonus;
    }
    state.commentCount++;

    void unlock(String id) {
      if (!state.unlocked.contains(id)) {
        state.unlocked.add(id);
        newly.add(id);
      }
    }

    if (state.commentCount >= 1) unlock('social_first');
    if (state.commentCount >= 10) unlock('social_10');
    if (state.commentCount >= 50) unlock('social_50');
    if (hadOtherAuthorsOnThread || isReply) unlock('social_thread');

    await _save(state);
    return newly;
  }

  static Future<GamificationSnapshot> readSnapshot() async {
    final s = await _load();
    return GamificationSnapshot(
      socialPoints: s.socialPoints,
      commentCount: s.commentCount,
      maxStreakRecorded: s.maxStreakRecorded,
      unlocked: Set<String>.from(s.unlocked),
    );
  }

  static Future<int> socialPoints() async => (await _load()).socialPoints;

  static Future<Set<String>> unlockedIds() async => (await _load()).unlocked;
}

class _GamificationState {
  int socialPoints;
  int commentCount;
  int maxStreakRecorded;
  Set<String> unlocked;

  _GamificationState({
    required this.socialPoints,
    required this.commentCount,
    required this.maxStreakRecorded,
    required this.unlocked,
  });

  factory _GamificationState.empty() => _GamificationState(
        socialPoints: 0,
        commentCount: 0,
        maxStreakRecorded: 0,
        unlocked: {},
      );

  factory _GamificationState.fromJson(Map<String, dynamic> m) {
    final u = m['unlocked'];
    final set = <String>{};
    if (u is List) {
      for (final e in u) {
        set.add(e.toString());
      }
    }
    return _GamificationState(
      socialPoints: m['socialPoints'] is int ? m['socialPoints'] as int : int.tryParse(m['socialPoints']?.toString() ?? '') ?? 0,
      commentCount: m['commentCount'] is int ? m['commentCount'] as int : int.tryParse(m['commentCount']?.toString() ?? '') ?? 0,
      maxStreakRecorded:
          m['maxStreakRecorded'] is int ? m['maxStreakRecorded'] as int : int.tryParse(m['maxStreakRecorded']?.toString() ?? '') ?? 0,
      unlocked: set,
    );
  }

  Map<String, dynamic> toJson() => {
        'socialPoints': socialPoints,
        'commentCount': commentCount,
        'maxStreakRecorded': maxStreakRecorded,
        'unlocked': unlocked.toList(),
      };
}
