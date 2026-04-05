import 'package:flutter/material.dart';

import '../models/gamification_badge.dart';
import '../services/auth_service.dart';
import '../services/gamification_service.dart';
import '../widgets/app_top_bar.dart';
import 'login_page.dart';

class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  Future<_BadgeViewModel>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    GamificationService.onStateChanged.addListener(_onGamificationChanged);
  }

  @override
  void dispose() {
    GamificationService.onStateChanged.removeListener(_onGamificationChanged);
    super.dispose();
  }

  void _onGamificationChanged() {
    if (mounted) setState(() => _future = _load());
  }

  Future<_BadgeViewModel> _load() async {
    if (!AuthService.isLoggedIn) {
      return _BadgeViewModel(points: 0, unlocked: {}, commentCount: 0);
    }
    await GamificationService.syncFromBackend();
    final snap = await GamificationService.readSnapshot();
    return _BadgeViewModel(
      points: snap.socialPoints,
      unlocked: snap.unlocked,
      commentCount: snap.commentCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: const AppTopBar(title: 'Rozetler', showBackButton: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Rozetler ve puanlar için giriş yap.',
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
                    if (mounted) setState(() => _future = _load());
                  },
                  child: const Text('Giriş Yap'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: const AppTopBar(title: 'Rozetler ve Puan', showBackButton: true),
      body: FutureBuilder<_BadgeViewModel>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2094F3)));
          }
          final vm = snap.data!;
          final earned = GamificationBadgeDef.catalog.where((b) => vm.unlocked.contains(b.id)).length;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
            },
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
                      const Text('Sosyal puan', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(
                        '${vm.points}',
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Yorum: +${GamificationService.pointsPerComment} puan; başkalarının da yorumladığı gönderiye +${GamificationService.pointsThreadBonus} ek.',
                        style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 12, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kazanılan rozet: $earned / ${GamificationBadgeDef.catalog.length} • Toplam yorum: ${vm.commentCount}',
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tüm rozetler',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ...GamificationBadgeDef.catalog.map((b) {
                  final on = vm.unlocked.contains(b.id);
                  return _badgeTile(b, on);
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _badgeTile(GamificationBadgeDef b, bool unlocked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: unlocked ? const Color(0xFF22C55E).withValues(alpha: 0.5) : const Color(0xFF374151)),
      ),
      child: Row(
        children: [
          Text(b.emoji, style: TextStyle(fontSize: 32, color: unlocked ? null : const Color(0xFF6B7280))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.title,
                        style: TextStyle(
                          color: unlocked ? Colors.white : const Color(0xFF6B7280),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (unlocked)
                      const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 20)
                    else
                      const Icon(Icons.lock_outline, color: Color(0xFF6B7280), size: 20),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  b.description,
                  style: TextStyle(
                    color: unlocked ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeViewModel {
  final int points;
  final Set<String> unlocked;
  final int commentCount;

  _BadgeViewModel({
    required this.points,
    required this.unlocked,
    required this.commentCount,
  });
}
