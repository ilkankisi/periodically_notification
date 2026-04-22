import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/motivation.dart';
import '../widgets/motivation_cached_image.dart';
import '../services/motivation_service.dart';
import '../services/saved_items_service.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/notification_badge_controller.dart';
import '../services/onboarding_service.dart';
import '../widgets/saved_full_tour_coach.dart';
import 'badges_page.dart';
import 'notifications_page.dart';
import 'zincir_page.dart';
import 'content_detail_page.dart';

/// Kaydedilenler: Figma boş (60-498) / dolu (60-555) ile uyumlu koyu tema.
class SavedPage extends StatefulWidget {
  const SavedPage({super.key, this.showBottomBar = true, this.onTabTap});

  final bool showBottomBar;
  final ValueChanged<int>? onTabTap;

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  int _filterIndex = 0;

  final GlobalKey _firstSavedRowTourKey = GlobalKey();
  int? _fullTourPhaseCache;
  bool _savedListCoachScheduled = false;

  /// Figma 60-555: HEPSİ / MAKALELER / GÖRSELLER
  static const _filters = ['HEPSİ', 'MAKALELER', 'GÖRSELLER'];

  List<SavedEntry> _entries = [];
  Map<String, Motivation> _itemsById = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _refreshFullTourPhase() async {
    await OnboardingService.ensureFullTourMigrated();
    final p = await OnboardingService.getGlobalTourStep();
    if (!mounted) return;
    setState(() => _fullTourPhaseCache = p);
    await _maybeSavedListCoach();
  }

  Future<void> _maybeSavedListCoach() async {
    if (_savedListCoachScheduled) return;
    if (_fullTourPhaseCache != OnboardingService.ftSavedList) return;
    if (_visibleEntries.isEmpty) return;
    _savedListCoachScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      if (_firstSavedRowTourKey.currentContext == null) return;
      SavedListFullTourCoach.show(
        context: context,
        firstRowKey: _firstSavedRowTourKey,
      );
    });
  }

  Future<void> _onSavedPullRefresh() async {
    await _load();
    await OnboardingService.onPostBadgesSavedPullRefreshCompleted();
    if (!mounted) return;
    final p = await OnboardingService.getGlobalTourStep();
    setState(() => _fullTourPhaseCache = p);
  }

  Future<void> _load() async {
    final entries = await SavedItemsService.getSavedEntries();
    entries.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final all = await MotivationService.loadAll();
    final byId = {for (var m in all) m.id: m};
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _itemsById = byId;
      _loading = false;
    });
    await _refreshFullTourPhase();
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
    await NotificationBadgeController.instance.refresh();
  }

  void _openChain() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ZincirPage()),
    );
  }

  /// Figma 60-498 boş / 60-555 dolu: başlık; dolu iken alt açıklama metni.
  Widget _buildSavedHeader() {
    final badge = NotificationBadgeController.instance;
    final showSubtitle = !_loading && _entries.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Text(
                  'Kaydedilenler',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTopBar.centeredTitleStyle(),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Aksiyon zinciri',
                        icon: const Icon(
                          Icons.link_rounded,
                          color: Color(0xFFBFC7D5),
                          size: 22,
                        ),
                        onPressed: _openChain,
                      ),
                      AnimatedBuilder(
                        animation: badge,
                        builder: (context, _) {
                          final count = badge.unreadCount;
                          final showBadge = count > 0;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                tooltip: 'Bildirimler',
                                icon: const Icon(
                                  Icons.notifications_none_rounded,
                                  color: Color(0xFFBFC7D5),
                                  size: 24,
                                ),
                                onPressed: _openNotifications,
                              ),
                              if (showBadge)
                                Positioned(
                                  right: 10,
                                  top: 10,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Center(
                                      child: Text(
                                        count > 9 ? '9+' : count.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showSubtitle) ...[
            const SizedBox(height: 10),
            Text(
              'Küratörlüğünü yaptığınız, ilham veren ve gelecekte tekrar göz atmak istediğiniz tüm içerikler burada.',
              style: GoogleFonts.notoSans(
                color: const Color(0xFF9CA3AF),
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  bool _hasHeroImage(Motivation m) {
    final b64 = m.imageBase64?.trim();
    if (b64 != null && b64.isNotEmpty) return true;
    final u = m.displayImageUrl?.trim();
    return u != null && u.isNotEmpty;
  }

  List<SavedEntry> get _visibleEntries {
    if (_filterIndex == 0) return _entries;
    return _entries.where((e) {
      final m = _itemsById[e.itemId];
      if (m == null) return false;
      final img = _hasHeroImage(m);
      if (_filterIndex == 1) return !img;
      if (_filterIndex == 2) return img;
      return true;
    }).toList();
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < _filters.length; i++)
            GestureDetector(
              onTap: () => setState(() => _filterIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _filterIndex == i
                      ? const Color(0xFF0095FF)
                      : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _filterIndex == i
                        ? const Color(0xFF0095FF)
                        : const Color(0xFF404040),
                    width: 1,
                  ),
                ),
                child: Text(
                  _filters[i],
                  style: GoogleFonts.notoSans(
                    color: _filterIndex == i
                        ? Colors.white
                        : const Color(0xFF9CA3AF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Figma 60-498: boş durum — glow’lu yer imi, sol hizalı metin, Keşfet CTA.
  Widget _buildEmptyStateContent() {
    const accent = Color(0xFF0095FF);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 72,
                      spreadRadius: 12,
                    ),
                  ],
                ),
              ),
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF2C2C2E)),
                ),
                child: const Icon(
                  Icons.bookmark_border_rounded,
                  color: accent,
                  size: 52,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        Text(
          'Henüz bir şey kaydetmedin.',
          textAlign: TextAlign.left,
          style: GoogleFonts.newsreader(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Keşfet sayfasından ilgini çeken içerikleri buraya ekleyebilirsin.',
          textAlign: TextAlign.left,
          style: GoogleFonts.notoSans(
            color: const Color(0xFF9CA3AF),
            fontSize: 15,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 40),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onTabTap?.call(1),
            borderRadius: BorderRadius.circular(999),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF0095FF), Color(0xFF0078D4)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x400095FF),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text(
                    "KEŞFET'YE GİT",
                    style: GoogleFonts.notoSans(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 48),
        Center(
          child: Text(
            'Curate.',
            style: GoogleFonts.newsreader(
              fontSize: 56,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyScrollable() {
    return RefreshIndicator(
      color: const Color(0xFF0095FF),
      backgroundColor: const Color(0xFF1F1F1F),
      onRefresh: _onSavedPullRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: _buildEmptyStateContent(),
              ),
            ),
          );
        },
      ),
    );
  }

  String _categoryUpper(Motivation m) {
    final c = m.category?.trim();
    if (c == null || c.isEmpty) return 'İÇERİK';
    return c.toUpperCase();
  }

  Widget _savedCardHeroImage(Motivation item) {
    if (item.imageBase64 != null && item.imageBase64!.trim().isNotEmpty) {
      return Image.memory(
        base64Decode(item.imageBase64!),
        fit: BoxFit.cover,
        width: double.infinity,
      );
    }
    if (item.displayImageUrl != null &&
        item.displayImageUrl!.trim().isNotEmpty) {
      return MotivationCachedImage(
        imageUrl: item.displayImageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: const Color(0xFF27272A),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF0095FF),
            ),
          ),
        ),
        error: (_, __, ___) => _savedCardImagePlaceholder(),
      );
    }
    return _savedCardImagePlaceholder();
  }

  Widget _savedCardImagePlaceholder() {
    return Container(
      color: const Color(0xFF1C1C1E),
      alignment: Alignment.center,
      child: const Icon(
        Icons.article_outlined,
        color: Color(0xFF6B7280),
        size: 48,
      ),
    );
  }

  /// Figma 60-555: üstte geniş görsel, kategori + yer imi, başlık, isteğe bağlı özet.
  Widget _buildSavedRow({required Motivation item, GlobalKey? tourRowKey}) {
    const accent = Color(0xFF0095FF);
    final snippet = item.body.trim();
    final showSnippet = snippet.length > 48;

    final row = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final ftpBefore = await OnboardingService.getGlobalTourStep();
          if (ftpBefore == OnboardingService.ftSavedList) {
            await OnboardingService.onSavedItemOpened();
          }
          if (!mounted) return;
          final r = await Navigator.push<String?>(
            context,
            MaterialPageRoute<String?>(
              builder: (context) => ContentDetailPage(
                item: item,
                onboardingFullTourSavedFlow:
                    ftpBefore == OnboardingService.ftSavedList,
              ),
            ),
          );
          await _load();
          if (!mounted) return;
          if (r == 'full_tour_badges') {
            await Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const BadgesPage(firstLaunchPreview: false),
              ),
            );
            if (!mounted) return;
            await OnboardingService.setGlobalTourStep(
              OnboardingService.ftPostBadgesExploreTab,
            );
            await _refreshFullTourPhase();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2C2C2E)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: _savedCardHeroImage(item),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            _categoryUpper(item),
                            style: GoogleFonts.notoSans(
                              color: const Color(0xFF9CA3AF),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bookmark_rounded,
                              color: accent,
                              size: 22,
                            ),
                            const SizedBox(width: 2),
                            Tooltip(
                              message: 'Kaydı kaldır',
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () async {
                                  await SavedItemsService.removeSaved(item.id);
                                  _load();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    color: const Color(0xFF6B7280),
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      item.title,
                      style: GoogleFonts.newsreader(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    if (showSnippet) ...[
                      const SizedBox(height: 8),
                      Text(
                        snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSans(
                          color: const Color(0xFF9CA3AF),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (tourRowKey != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: KeyedSubtree(key: tourRowKey, child: row),
      );
    }
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: row);
  }

  Widget _buildFilledList() {
    final visible = _visibleEntries;
    if (visible.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
        children: [
          Center(
            child: Text(
              'Bu filtrede kayıt yok.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                color: const Color(0xFFBFC7D5),
                fontSize: 15,
              ),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF0095FF),
      backgroundColor: const Color(0xFF1F1F1F),
      onRefresh: _onSavedPullRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final entry = visible[index];
          final item = _itemsById[entry.itemId];
          if (item == null) return const SizedBox.shrink();
          final tourKey =
              index == 0 && _fullTourPhaseCache == OnboardingService.ftSavedList
              ? _firstSavedRowTourKey
              : null;
          return _buildSavedRow(item: item, tourRowKey: tourKey);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSavedHeader(),
            if (!_loading && _entries.isNotEmpty) _buildFilterChips(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0095FF),
                      ),
                    )
                  : _entries.isEmpty
                  ? _buildEmptyScrollable()
                  : _buildFilledList(),
            ),
            if (widget.showBottomBar)
              BottomNavBar(activeIndex: 2, onTabTap: widget.onTabTap),
          ],
        ),
      ),
    );
  }
}
