import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/action_entry.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../widgets/app_top_bar.dart';
import 'actions_chain_page.dart';
import 'streak_chain_page.dart';

/// Zincir hub — sıra: Hero → Kartlar (Aksiyonlar, Günlük zincir) → Bento → Featured (Figma Hub Grid).
class ZincirPage extends StatefulWidget {
  const ZincirPage({super.key});

  @override
  State<ZincirPage> createState() => _ZincirPageState();
}

class _ZincirPageState extends State<ZincirPage> {
  late Future<_HubStats> _statsFuture;

  static const Color _bg = Color(0xFF131313);
  static const Color _textPrimary = Color(0xFFE2E2E2);
  static const Color _muted = Color(0xFFBFC7D5);
  static const Color _accent = Color(0xFFA1C9FF);
  static const Color _blueBar = Color(0xFF0095FF);
  static const Color _bentoBg = Color(0xFF1B1B1B);
  static const Color _card = Color(0xFF1F1F1F);
  static const Color _iconBox = Color(0xFF353535);

  /// İçerik genişliği Figma 342px ile hizalı (geniş ekranda ortalanır).
  static const double _contentWidth = 342;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<_HubStats> _loadStats() async {
    if (!AuthService.isLoggedIn) {
      return const _HubStats(activeStreak: 0, completedActions: 0);
    }
    final ok = await BackendService.ensureToken();
    if (!ok) return const _HubStats(activeStreak: 0, completedActions: 0);
    try {
      final actions = await BackendService.client.getMyActions();
      final dates = _actionDateKeys(actions);
      return _HubStats(
        activeStreak: _currentStreakFromDates(dates),
        completedActions: actions.length,
      );
    } catch (_) {
      return const _HubStats(activeStreak: 0, completedActions: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: const AppTopBar(
        title: 'Zincir',
        showBackButton: true,
        backgroundColor: Color(0xB3131313),
        hubTitleStyle: true,
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<_HubStats>(
          future: _statsFuture,
          builder: (context, snap) {
            final stats = snap.data ?? const _HubStats(activeStreak: 0, completedActions: 0);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 128),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _contentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHero(),
                      const SizedBox(height: 48),
                      // Hub grid sırası: önce kartlar, sonra bento (Figma absolute top sırası).
                      _navCard(
                        context,
                        icon: Icons.format_list_bulleted_rounded,
                        title: 'Aksiyonlar',
                        subtitle: 'Yanıt verdiğin tüm kayıtları görüntüle',
                        decorativeW: 120,
                        decorativeH: 120,
                        decorativeRight: -12,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ActionsPage()),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _navCard(
                        context,
                        icon: Icons.local_fire_department_rounded,
                        title: 'Günlük\nZincir',
                        subtitle: 'Takvim üzerinden seri ve kırıkları incele',
                        decorativeW: 106.67,
                        decorativeH: 126.67,
                        decorativeRight: -5.31,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const StreakChainPage()),
                          );
                        },
                      ),
                      // Bento Mini Stats: üst margin 16px (Figma padding 16 0 0)
                      const SizedBox(height: 16),
                      _buildBentoRow(stats),
                      const SizedBox(height: 48),
                      _buildFeaturedStrip(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Hero: gap 16px başlık ↔ mavi çubuk; başlık 36/45 italic 600 #E2E2E2.
  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kendi zincirini kur, aksiyonlarını takip et ve gelişmini izle.',
          style: GoogleFonts.newsreader(
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
            fontSize: 36,
            height: 45 / 36,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: 48,
          height: 4,
          decoration: BoxDecoration(
            color: _blueBar,
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
      ],
    );
  }

  /// İki sütun ~163px + 16px boşluk (342 toplam).
  Widget _buildBentoRow(_HubStats stats) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _bentoTile(
            label: 'Aktif zincir',
            valueText: '${stats.activeStreak}',
            valueColor: _accent,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _bentoTile(
            label: 'Tamamlanan',
            valueText: '${stats.completedActions}',
            valueColor: _textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _bentoTile({
    required String label,
    required String valueText,
    required Color valueColor,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 108),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _bentoBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 16 / 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w400,
              color: _muted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            valueText,
            style: GoogleFonts.newsreader(
              fontSize: 30,
              height: 36 / 30,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required double decorativeW,
    required double decorativeH,
    required double decorativeRight,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14A1C9FF),
                blurRadius: 40,
                offset: Offset(0, 20),
                spreadRadius: -15,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                right: decorativeRight,
                top: -12,
                child: Container(
                  width: decorativeW,
                  height: decorativeH,
                  decoration: BoxDecoration(
                    color: _textPrimary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _iconBox,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: _accent, size: 26),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.newsreader(
                              color: _textPrimary,
                              fontSize: 24,
                              height: 32 / 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              color: _muted,
                              fontSize: 14,
                              height: 23 / 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: _muted,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Abstract (beyaz %40) + alttan #131313 gradient + italik metin (18/28).
  Widget _buildFeaturedStrip() {
    const h = 192.38;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: h,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: 0.4,
              child: Container(color: Colors.white),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    _bg,
                    _bg.withValues(alpha: 0),
                    _bg.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 24,
              bottom: 24,
              width: 249,
              child: Text(
                'İlerlemeni buradan takip et.',
                style: GoogleFonts.newsreader(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w400,
                  fontSize: 18,
                  height: 28 / 18,
                  color: _textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubStats {
  const _HubStats({
    required this.activeStreak,
    required this.completedActions,
  });

  final int activeStreak;
  final int completedActions;
}

Set<String> _actionDateKeys(List<ActionEntry> actions) {
  final set = <String>{};
  for (final e in actions) {
    final raw = e.localDate.trim();
    if (raw.isEmpty) continue;
    final norm = _normalizeDateKey(raw);
    if (norm != null) set.add(norm);
  }
  return set;
}

String? _normalizeDateKey(String raw) {
  try {
    final d = DateTime.parse(raw.split('T').first.trim());
    return _fmt(DateTime(d.year, d.month, d.day));
  } catch (_) {
    return null;
  }
}

int _currentStreakFromDates(Set<String> actionDates) {
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
