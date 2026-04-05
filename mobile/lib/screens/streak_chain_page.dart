import 'package:flutter/material.dart';

import '../models/action_entry.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../services/gamification_service.dart';
import '../widgets/app_top_bar.dart';
import 'login_page.dart';

class StreakChainPage extends StatefulWidget {
  const StreakChainPage({super.key});

  @override
  State<StreakChainPage> createState() => _StreakChainPageState();
}

class _StreakChainPageState extends State<StreakChainPage> {
  late Future<List<ActionEntry>> _future;
  /// Görüntülenen ay (gün = 1)
  late DateTime _visibleMonth;

  static const _green = Color(0xFF22C55E);
  static const _red = Color(0xFFEF4444);
  static const _greyFuture = Color(0xFF374151);
  static const _greyMuted = Color(0xFF2D3748);

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
        backgroundColor: const Color(0xFF121212),
        appBar: const AppTopBar(title: 'Günlük Zincir', showBackButton: true),
        body: _buildLoginRequired(context),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: const AppTopBar(title: 'Günlük Zincir', showBackButton: true),
      body: FutureBuilder<List<ActionEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2094F3)),
            );
          }
          final actions = snapshot.data ?? const [];
          final actionDates = _toDateSet(actions);
          final sortedDays = _sortedActionDays(actionDates);
          final streak = _currentStreak(actionDates);
          final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
          final visibleMonthStart =
              DateTime(_visibleMonth.year, _visibleMonth.month, 1);
          final thisMonthStart = DateTime(today.year, today.month, 1);
          final canGoNext = visibleMonthStart.isBefore(thisMonthStart);

          return RefreshIndicator(
            onRefresh: _reload,
            color: Colors.white,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF374151)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mevcut Zincirin',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$streak gün',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Yeşil: o gün aksiyon var. Kırmızı: iki aksiyon günü arasında kırılan (boş) gün.',
                        style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    IconButton(
                      onPressed: _prevMonth,
                      icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                    ),
                    Expanded(
                      child: Text(
                        _monthTitle(_visibleMonth),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: canGoNext ? _nextMonth : null,
                      icon: Icon(
                        Icons.chevron_right,
                        color: canGoNext ? Colors.white : const Color(0xFF4B5563),
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildWeekdayHeader(),
                const SizedBox(height: 8),
                _buildMonthGrid(
                  visibleMonth: _visibleMonth,
                  today: today,
                  actionDates: actionDates,
                  sortedActionDays: sortedDays,
                ),
                const SizedBox(height: 16),
                _buildLegend(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Açıklama',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _legendRow(_green, 'Aksiyon var — zincir o gün devam etti veya o gün başladı.'),
        const SizedBox(height: 6),
        _legendRow(_red, 'Aksiyon yok — önce ve sonra aksiyon olan iki gün arasında kırık gün.'),
        const SizedBox(height: 6),
        _legendRow(_greyFuture, 'Gelecek günler veya henüz zincire dahil olmayan boş günler.'),
      ],
    );
  }

  Widget _legendRow(Color c, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(top: 3, right: 10),
          decoration: BoxDecoration(shape: BoxShape.circle, color: c),
        ),
        Expanded(
          child: Text(text, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, height: 1.35)),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader() {
    const labels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return Row(
      children: [
        for (final l in labels)
          Expanded(
            child: Text(
              l,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w600),
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
    // Pazartesi = 1 (Dart). Sol sütun Pazartesi.
    final startOffset = first.weekday - 1;
    final totalCells = startOffset + lastDay;
    final rowCount = (totalCells / 7).ceil();
    final slotCount = rowCount * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
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
    final isToday = d.year == today.year && d.month == today.month && d.day == today.day;

    Color circleColor;
    if (hasAction) {
      circleColor = _green;
    } else if (isFuture) {
      circleColor = _greyFuture;
    } else if (_isBrokenGapDay(d, sortedActionDays)) {
      circleColor = _red;
    } else {
      circleColor = _greyMuted;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: circleColor,
            border: isToday ? Border.all(color: const Color(0xFF2094F3), width: 2) : null,
          ),
          child: Center(
            child: Text(
              '${d.day}',
              style: TextStyle(
                color: hasAction || (!isFuture && circleColor == _red) ? Colors.white : const Color(0xFF9CA3AF),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Geçmişte, aksiyon yok; ama tam öncesinde ve tam sonrasında aksiyon günü var → zincir kırığı (kırmızı).
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Zincirini görmek için giriş yapmalısın.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFE5E7EB), fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
                if (mounted) _reload();
              },
              child: const Text('Giriş Yap'),
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
