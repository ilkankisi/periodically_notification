import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/gamification_badge.dart';
import '../services/auth_service.dart';
import '../services/gamification_service.dart';
import '../widgets/app_top_bar.dart';
import 'login_page.dart';

/// Rozetler ve sosyal puan — Figma 60-1499.
class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  Future<_BadgeViewModel>? _future;
  final ScrollController _scrollController = ScrollController();

  static const Color _bg = Color(0xFF000000);
  static const Color _accent = Color(0xFF0095FF);
  static const Color _card = Color(0xFF1C1C1E);
  static const Color _muted = Color(0xFF8E8E93);
  static const Color _border = Color(0xFF2C2C2E);

  @override
  void initState() {
    super.initState();
    _future = _load();
    GamificationService.onStateChanged.addListener(_onGamificationChanged);
  }

  @override
  void dispose() {
    GamificationService.onStateChanged.removeListener(_onGamificationChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onGamificationChanged() {
    if (mounted) setState(() => _future = _load());
  }

  Future<_BadgeViewModel> _load() async {
    if (!AuthService.isLoggedIn) {
      return _BadgeViewModel(points: 0, unlocked: {});
    }
    await GamificationService.syncFromBackend();
    final snap = await GamificationService.readSnapshot();
    return _BadgeViewModel(
      points: snap.socialPoints,
      unlocked: snap.unlocked,
    );
  }

  Future<void> _onRefresh() async {
    final f = _load();
    setState(() => _future = f);
    await f;
  }

  void _scrollToCollection() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  /// Sağ üst seviye etiketi (puana göre).
  String _tierLabel(int points) {
    if (points >= 1200) return 'Elite';
    if (points >= 600) return 'Premium';
    if (points >= 200) return 'Aktif';
    return 'Başlangıç';
  }

  PreferredSizeWidget _buildAppBar(int points) {
    return AppBar(
      backgroundColor: _bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Text(
        'Rozetler ve Puan',
        style: AppTopBar.centeredTitleStyle(),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            child: Text(
              _tierLabel(points),
              style: GoogleFonts.notoSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(0),
        body: _buildLoginRequired(context),
      );
    }

    return FutureBuilder<_BadgeViewModel>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Scaffold(
            backgroundColor: _bg,
            appBar: _buildAppBar(0),
            body: const Center(
              child: CircularProgressIndicator(color: _accent),
            ),
          );
        }
        final vm = snapshot.data ?? _BadgeViewModel(points: 0, unlocked: {});
        final earned = GamificationBadgeDef.catalog.where((b) => vm.unlocked.contains(b.id)).length;
        final total = GamificationBadgeDef.catalog.length;
        final progress = total > 0 ? earned / total : 0.0;

        return Scaffold(
          backgroundColor: _bg,
          appBar: _buildAppBar(vm.points),
          body: RefreshIndicator(
            onRefresh: _onRefresh,
            color: _accent,
            edgeOffset: 12,
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              children: [
                _buildPointsHero(
                  points: vm.points,
                  earned: earned,
                  total: total,
                  progress: progress,
                ),
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Koleksiyon',
                      style: GoogleFonts.newsreader(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _scrollToCollection,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'TÜMÜNÜ GÖR',
                        style: GoogleFonts.notoSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: _muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...GamificationBadgeDef.catalog.map((b) {
                  final on = vm.unlocked.contains(b.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BadgeTileFigma(badge: b, unlocked: on),
                  );
                }),
                const SizedBox(height: 8),
                _buildInfoFooter(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPointsHero({
    required int points,
    required int earned,
    required int total,
    required double progress,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: -20,
          top: -24,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.22),
                  blurRadius: 64,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MEVCUT DURUM',
                style: GoogleFonts.notoSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$points',
                    style: GoogleFonts.newsreader(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SP',
                    style: GoogleFonts.newsreader(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Sosyal Puanınız',
                style: GoogleFonts.notoSans(
                  fontSize: 13,
                  color: _muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121214),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.emoji_events_rounded, color: _accent, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ROZET DURUMU',
                            style: GoogleFonts.notoSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: _muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$earned / $total Kazanıldı',
                            style: GoogleFonts.notoSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: const Color(0xFF3A3A3C),
                  valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _muted.withValues(alpha: 0.5)),
            ),
            child: Icon(Icons.info_outline_rounded, size: 16, color: _muted.withValues(alpha: 0.9)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Puanların ve rozetlerin her ayın başında global sıralamada yerini belirler. Daha fazla kazanmak için aktif kal!',
              style: GoogleFonts.notoSans(
                fontSize: 13,
                height: 1.45,
                color: const Color(0xFFAEAEB2),
              ),
            ),
          ),
        ],
      ),
    );
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
                color: _accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x14FFFFFF)),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: _accent,
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Rozetler ve puanlar için giriş yap',
              textAlign: TextAlign.center,
              style: GoogleFonts.newsreader(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Yorumların ve rozet ilerlemen hesabına bağlanır; giriş yaptıktan sonra burada görünür.',
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
                  if (mounted) setState(() => _future = _load());
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
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
}

class _BadgeTileFigma extends StatelessWidget {
  const _BadgeTileFigma({
    required this.badge,
    required this.unlocked,
  });

  final GamificationBadgeDef badge;
  final bool unlocked;

  static const Color _accent = Color(0xFF0095FF);
  static const Color _card = Color(0xFF1C1C1E);
  static const Color _border = Color(0xFF2C2C2E);

  IconData _iconForId(String id) {
    switch (id) {
      case 'streak_7':
        return Icons.auto_awesome_rounded;
      case 'streak_30':
        return Icons.nights_stay_rounded;
      case 'streak_365':
        return Icons.emoji_events_rounded;
      case 'social_first':
        return Icons.chat_bubble_rounded;
      case 'social_10':
        return Icons.forum_rounded;
      case 'social_50':
        return Icons.star_rounded;
      case 'social_thread':
        return Icons.handshake_rounded;
      default:
        return Icons.military_tech_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _iconForId(badge.id);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: unlocked ? _accent.withValues(alpha: 0.35) : _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: unlocked
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Açık',
                      style: GoogleFonts.notoSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _accent,
                        letterSpacing: 0.3,
                      ),
                    ),
                  )
                : Icon(Icons.lock_outline_rounded, color: Colors.white.withValues(alpha: 0.35), size: 20),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: unlocked
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0095FF), Color(0xFF005A99)],
                        )
                      : null,
                  color: unlocked ? null : const Color(0xFF2C2C2E),
                  border: Border.all(color: unlocked ? Colors.transparent : _border),
                ),
                child: Icon(
                  icon,
                  color: unlocked ? Colors.white : const Color(0xFF6B7280),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge.title,
                      style: GoogleFonts.newsreader(
                        color: unlocked ? Colors.white : const Color(0xFF6B7280),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      badge.description,
                      style: GoogleFonts.notoSans(
                        color: unlocked ? const Color(0xFFAEAEB2) : const Color(0xFF4B5563),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeViewModel {
  final int points;
  final Set<String> unlocked;

  _BadgeViewModel({
    required this.points,
    required this.unlocked,
  });
}
