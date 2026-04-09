import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/action_entry.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../services/gamification_service.dart';
import '../widgets/app_top_bar.dart';
import 'login_page.dart';

/// Günlük zincir ve aksiyon takvimi.
class StreakChainPage extends StatefulWidget {
  const StreakChainPage({super.key});

  @override
  State<StreakChainPage> createState() => _StreakChainPageState();
}

class _StreakChainPageState extends State<StreakChainPage> {
  late Future<List<ActionEntry>> _future;
  /// Görüntülenen ay (gün = 1)
  late DateTime _visibleMonth;

  static const Color _bg = Color(0xFF000000);
  static const Color _accent = Color(0xFF0095FF);
  static const Color _titleBlue = Color(0xFFA1C9FF);
  static const Color _accentSoft = Color(0x1A0095FF);
  static const Color _borderSubtle = Color(0x14FFFFFF);
  static const Color _card = Color(0xFF1C1C1E);
  static const Color _muted = Color(0xFF9CA3AF);

  static const _blueDay = Color(0xFF0095FF);
  static const _red = Color(0xFFD32F2F);
  static const _greyFuture = Color(0xFF6B7280);
  static const _greyMuted = Color(0xFF4B5563);

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _visibleMonth = DateTime(n.year, n.month, 1);
    _future = _loadWithGamification();
  }

  Future<List<ActionEntry>> _load() async {
    if (!AuthService.isLoggedIn) return [];
    final ok = await BackendService.ensureToken();
    if (!ok) return [];
    return BackendService.client.getMyActions();
  }

  Future<List<ActionEntry>> _loadWithGamification() async {
    final list = await _load();
    await GamificationService.syncFromBackend();
    return list;
  }

  Future<void> _reload() async {
    final data = await _load();
    if (!mounted) return;
    await GamificationService.syncFromBackend();
    if (!mounted) return;
    setState(() => _future = Future.value(data));
  }

  void _prevMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    final thisMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    if (next.isAfter(thisMonth)) return;
    setState(() => _visibleMonth = next);
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: _buildFigmaAppBar(),
        body: _buildLoginRequired(context),
      );
    }
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildFigmaAppBar(),
      body: FutureBuilder<List<ActionEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0095FF)),
            );
          }
          final actions = snapshot.data ?? const [];
          final actionDates = _toDateSet(actions);
          final sortedDays = _sortedActionDays(actionDates);
          final streak = _currentStreak(actionDates);
          final bestStreak = _longestStreak(sortedDays);
          final consistency = _consistencyPercentLast30(actionDates);
          final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
          final visibleMonthStart =
              DateTime(_visibleMonth.year, _visibleMonth.month, 1);
          final thisMonthStart = DateTime(today.year, today.month, 1);
          final canGoNext = visibleMonthStart.isBefore(thisMonthStart);

          return RefreshIndicator(
            onRefresh: _reload,
            color: const Color(0xFF0095FF),
            edgeOffset: 12,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              children: [
                _buildStreakHeroFigma(streak),
                const SizedBox(height: 20),
                _buildStatsRow(bestStreak, consistency),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2C2C2E)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _roundNavButton(
                            icon: Icons.chevron_left_rounded,
                            onPressed: _prevMonth,
                            enabled: true,
                          ),
                          Expanded(
                            child: Text(
                              _monthTitle(_visibleMonth),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.newsreader(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          _roundNavButton(
                            icon: Icons.chevron_right_rounded,
                            onPressed: canGoNext ? _nextMonth : null,
                            enabled: canGoNext,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildWeekdayHeader(),
                      const SizedBox(height: 12),
                      _buildMonthGrid(
                        visibleMonth: _visibleMonth,
                        today: today,
                        actionDates: actionDates,
                        sortedActionDays: sortedDays,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildLegendCardFigma(),
                const SizedBox(height: 28),
                _buildQuoteBlock(),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildFigmaAppBar() {
    return AppBar(
      backgroundColor: _bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _titleBlue, size: 20),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Text(
        'İlerleme',
        style: AppTopBar.centeredTitleStyle(color: _titleBlue),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            child: Text(
              'Günlük Zincir',
              style: GoogleFonts.notoSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _roundNavButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool enabled,
  }) {
    return Material(
      color: enabled ? const Color(0xFF2A2A2C) : const Color(0xFF1A1A1C),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: enabled ? _accent : const Color(0xFF4B5563),
          size: 26,
        ),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }

  /// Figma 60-1303: ortada büyük sayı + mavi glow.
  Widget _buildStreakHeroFigma(int streak) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          child: Container(
            width: 220,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.22),
                  blurRadius: 80,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        ),
        Column(
          children: [
            Text(
              '$streak Gün',
              style: GoogleFonts.newsreader(
                fontSize: 44,
                fontWeight: FontWeight.w700,
                height: 1.0,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'ŞU ANKİ SERİN',
              style: GoogleFonts.notoSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: _muted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(int bestStreak, int consistencyPercent) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.workspace_premium_rounded,
            label: 'EN İYİ SERİ',
            value: '$bestStreak Gün',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.show_chart_rounded,
            label: 'İSTİKRAR ORANI',
            value: '%$consistencyPercent',
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.notoSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.newsreader(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendCardFigma() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GÖSTERGE',
            style: GoogleFonts.notoSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: _muted,
            ),
          ),
          const SizedBox(height: 14),
          _legendRow(_blueDay, 'Tamamlanan Günler'),
          const SizedBox(height: 10),
          _legendRow(_red, 'Kaçırılan Günler (Zincir Kırıldı)'),
          const SizedBox(height: 10),
          _legendRow(_greyFuture, 'Gelecek Günler'),
        ],
      ),
    );
  }

  Widget _buildQuoteBlock() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: _accent, width: 3),
        ),
      ),
      child: Text(
        'Büyük başarılar, her gün atılan küçük adımların birikimidir. Zinciri kırma, ritmini koru.',
        style: GoogleFonts.newsreader(
          fontSize: 17,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w500,
          height: 1.45,
          color: const Color(0xFFE5E7EB),
        ),
      ),
    );
  }

  Widget _legendRow(Color c, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 4, right: 10),
          decoration: BoxDecoration(shape: BoxShape.circle, color: c),
        ),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.notoSans(
              color: const Color(0xFF9CA3AF),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader() {
    const labels = ['PZT', 'SAL', 'ÇAR', 'PER', 'CUM', 'CMT', 'PAZ'];
    return Row(
      children: [
        for (final l in labels)
          Expanded(
            child: Text(
              l,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                color: const Color(0xFF6B7280),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMonthGrid({
    required DateTime visibleMonth,
    required DateTime today,
    required Set<String> actionDates,
    required List<DateTime> sortedActionDays,
  }) {
    final first = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final lastDay = DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    final startOffset = first.weekday - 1;
    final totalCells = startOffset + lastDay;
    final rowCount = (totalCells / 7).ceil();
    final slotCount = rowCount * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.92,
      ),
      itemCount: slotCount,
      itemBuilder: (context, index) {
        final dayNumber = index - startOffset + 1;
        if (dayNumber < 1 || dayNumber > lastDay) {
          return const SizedBox.shrink();
        }
        final d = DateTime(visibleMonth.year, visibleMonth.month, dayNumber);
        return _dayCell(
          d: d,
          today: today,
          actionDates: actionDates,
          sortedActionDays: sortedActionDays,
        );
      },
    );
  }

  Widget _dayCell({
    required DateTime d,
    required DateTime today,
    required Set<String> actionDates,
    required List<DateTime> sortedActionDays,
  }) {
    final key = _fmt(d);
    final hasAction = actionDates.contains(key);
    final isFuture = d.isAfter(today);
    final isToday =
        d.year == today.year && d.month == today.month && d.day == today.day;

    // Figma: gelecek günler — daire yok, sadece gri rakam.
    if (isFuture) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${d.day}',
            style: GoogleFonts.newsreader(
              color: _greyFuture,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      );
    }

    final isBroken = _isBrokenGapDay(d, sortedActionDays);

    if (hasAction) {
      return _calendarDayCircle(
        day: d.day,
        fill: _blueDay,
        textColor: Colors.white,
        todayRing: isToday ? Border.all(color: Colors.white, width: 2.5) : null,
      );
    }
    if (isBroken) {
      return _calendarDayCircle(
        day: d.day,
        fill: _red,
        textColor: Colors.white,
        todayRing: isToday ? Border.all(color: Colors.white, width: 2.5) : null,
      );
    }

    // Bugün henüz kayıt yok — mavi ton + kalın beyaz çerçeve (Figma «bugün» vurgusu).
    if (isToday) {
      return _calendarDayCircle(
        day: d.day,
        fill: _accent.withValues(alpha: 0.28),
        textColor: Colors.white,
        todayRing: Border.all(color: Colors.white, width: 2.5),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${d.day}',
          style: GoogleFonts.newsreader(
            color: _greyMuted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _calendarDayCircle({
    required int day,
    required Color fill,
    required Color textColor,
    BoxBorder? todayRing,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: todayRing,
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: GoogleFonts.newsreader(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  bool _isBrokenGapDay(DateTime d, List<DateTime> sortedAsc) {
    final only = DateTime(d.year, d.month, d.day);
    if (sortedAsc.isEmpty) return false;

    DateTime? prev;
    DateTime? next;
    for (final x in sortedAsc) {
      if (x.isBefore(only)) {
        prev = x;
      } else if (x.isAfter(only)) {
        next = x;
        break;
      }
    }
    return prev != null && next != null;
  }

  String _monthTitle(DateTime m) {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    return '${months[m.month - 1]} ${m.year}';
  }

  Widget _buildLoginRequired(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _accentSoft,
                shape: BoxShape.circle,
                border: Border.all(color: _borderSubtle),
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: _accent,
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Zincirini görmek için giriş yap',
              textAlign: TextAlign.center,
              style: GoogleFonts.newsreader(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Günlük serini ve takvimini yalnızca hesabınla görüntüleyebilirsin.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                color: _muted,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () async {
                  await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                  if (mounted) _reload();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0095FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Giriş Yap',
                  style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Set<String> _toDateSet(List<ActionEntry> actions) {
    final set = <String>{};
    for (final e in actions) {
      final raw = e.localDate.trim();
      if (raw.isEmpty) continue;
      final norm = _normalizeDateKey(raw);
      if (norm != null) set.add(norm);
    }
    return set;
  }

  List<DateTime> _sortedActionDays(Set<String> keys) {
    final list = <DateTime>[];
    for (final k in keys) {
      try {
        final p = DateTime.parse(k);
        list.add(DateTime(p.year, p.month, p.day));
      } catch (_) {}
    }
    list.sort();
    return list;
  }

  String? _normalizeDateKey(String raw) {
    try {
      final d = DateTime.parse(raw.split('T').first.trim());
      return _fmt(DateTime(d.year, d.month, d.day));
    } catch (_) {
      return null;
    }
  }

  /// Sıralı aksiyon günlerindeki en uzun ardışık seri (gün sayısı).
  int _longestStreak(List<DateTime> sortedAsc) {
    if (sortedAsc.isEmpty) return 0;
    var best = 1;
    var cur = 1;
    for (var i = 1; i < sortedAsc.length; i++) {
      final gap = sortedAsc[i].difference(sortedAsc[i - 1]).inDays;
      if (gap == 1) {
        cur++;
        if (cur > best) best = cur;
      } else {
        cur = 1;
      }
    }
    return best;
  }

  /// Son 30 takvim gününde aksiyon olan günlerin yüzdesi.
  int _consistencyPercentLast30(Set<String> actionDates) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    var hit = 0;
    for (var i = 0; i < 30; i++) {
      final d = today.subtract(Duration(days: i));
      if (actionDates.contains(_fmt(d))) hit++;
    }
    return ((hit / 30) * 100).round().clamp(0, 100);
  }

  int _currentStreak(Set<String> actionDates) {
    var streak = 0;
    var day = DateTime.now();
    while (true) {
      final key = _fmt(day);
      if (!actionDates.contains(key)) {
        if (streak == 0) {
          final yesterday = _fmt(day.subtract(const Duration(days: 1)));
          if (actionDates.contains(yesterday)) {
            day = day.subtract(const Duration(days: 1));
            continue;
          }
        }
        break;
      }
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String _fmt(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
