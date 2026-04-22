import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../models/motivation.dart';
import '../widgets/motivation_cached_image.dart';
import '../services/content_sync_service.dart';
import '../services/motivation_service.dart';
import '../services/saved_items_service.dart';
import '../services/search_history_service.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/notification_badge_controller.dart';
import '../services/onboarding_service.dart';
import '../widgets/explore_full_tour_coach.dart';
import 'notifications_page.dart';
import 'zincir_page.dart';
import 'content_detail_page.dart';

/// Keşfet sayfası — Figma 60-676: arama, chip filtreler, dikey immersive kart akışı.
class ExplorePage extends StatefulWidget {
  const ExplorePage({
    super.key,
    this.showBottomBar = true,
    this.onTabTap,
    this.shellTabIndex,
  });

  final bool showBottomBar;
  final ValueChanged<int>? onTabTap;
  /// Ana kabukta seçili sekme (0–3); tur adımı önbelleğini Keşfet görünür olunca yenilemek için.
  final int? shellTabIndex;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  int _selectedCategoryIndex = 0;

  final GlobalKey _exploreHeaderKey = GlobalKey();
  final GlobalKey _firstBookmarkKey = GlobalKey();
  final GlobalKey _postTourFirstCardKey = GlobalKey();
  int? _fullTourPhaseCache;
  bool _fullTourIntroScheduled = false;
  bool _postBadgesFirstCardCoachScheduled = false;
  bool _postBadgesExploreIntroDialogShown = false;
  bool _postBadgesExploreFlowBusy = false;
  bool _postBadgesExplorePullEndDialogShown = false;
  bool _postBadgesExplorePullEndDialogInFlight = false;
  final GlobalKey _postBadgesExploreRefreshKey = GlobalKey();

  /// Rozetler sonrası Keşfet adımı: önce bilgi penceresi (mevcut spotlight metinleriyle karıştırılmaz).
  static const String _postBadgesExploreIntroTitle = 'İçeriği aç';
  static const String _postBadgesExploreIntroBody =
      'İlk karttaki içeriğe dokunarak detayı açacaksın; orada turun bir sonraki adımı devam eder.';

  static const String _postBadgesExplorePullEndBody =
      'Listeyi yenilemek için aşağı çek. Tur burada biter.';

  /// ($categoryKey, $uppercaseLabel) — key null = Tümü
  static const List<(String?, String)> _categoryFilters = [
    (null, 'TÜMÜ'),
    ('Teknoloji', 'TEKNOLOJİ'),
    ('Sanat', 'SANAT'),
    ('Tarih', 'TARİH'),
    ('Bilim', 'BİLİM'),
  ];

  List<Motivation> _items = [];
  List<String> _searchHistory = [];
  final Set<String> _savedIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    OnboardingService.registerExploreTourPhaseRefreshHandler(
      _handleExploreTourPhaseRefreshRequest,
    );
    _load();
    unawaited(_refreshFullTourPhase());
  }

  void _handleExploreTourPhaseRefreshRequest() {
    if (mounted) unawaited(_refreshFullTourPhase());
  }

  @override
  void didUpdateWidget(covariant ExplorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final idx = widget.shellTabIndex;
    if (idx != null &&
        idx == 1 &&
        oldWidget.shellTabIndex != idx) {
      unawaited(_refreshFullTourPhase());
    }
  }

  Future<void> _refreshFullTourPhase() async {
    await OnboardingService.ensureFullTourMigrated();
    final p = await OnboardingService.getGlobalTourStep();
    if (!mounted) return;
    setState(() => _fullTourPhaseCache = p);
    unawaited(_maybeRunFullTourCoaches());
    unawaited(_maybePostBadgesExploreIntroDialogThenFirstCardCoach());
    unawaited(_maybeShowPostBadgesExplorePullEndDialog());
  }

  Future<void> _maybeRunFullTourCoaches() async {
    final p =
        _fullTourPhaseCache ?? await OnboardingService.getGlobalTourStep();
    if (p >= OnboardingService.ftPostBadgesExploreTab) return;
    if (p == OnboardingService.ftExploreIntro && !_fullTourIntroScheduled) {
      _fullTourIntroScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        if (_filteredItems.isEmpty) return;
        ExploreIntroFullTourCoach.show(
          context: context,
          headerKey: _exploreHeaderKey,
          onFinished: () async {
            await OnboardingService.setGlobalTourStep(
              OnboardingService.ftExploreSave,
            );
            if (mounted) {
              setState(
                () => _fullTourPhaseCache = OnboardingService.ftExploreSave,
              );
            }
            await Future<void>.delayed(const Duration(milliseconds: 400));
            if (!mounted || _filteredItems.isEmpty) return;
            ExploreSaveFullTourCoach.show(
              context: context,
              bookmarkKey: _firstBookmarkKey,
            );
          },
        );
      });
      return;
    }
    if (p == OnboardingService.ftExploreSave) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!mounted || _filteredItems.isEmpty) return;
        ExploreSaveFullTourCoach.show(
          context: context,
          bookmarkKey: _firstBookmarkKey,
        );
      });
    }
  }

  Future<void> _maybePostBadgesExploreIntroDialogThenFirstCardCoach() async {
    if (!mounted || _postBadgesExploreFlowBusy) return;
    final p = await OnboardingService.getGlobalTourStep();
    if (!mounted || p != OnboardingService.ftPostBadgesExploreFirstCard) {
      return;
    }
    if (_filteredItems.isEmpty) return;
    _postBadgesExploreFlowBusy = true;
    try {
      if (!_postBadgesExploreIntroDialogShown) {
        await Future<void>.delayed(const Duration(milliseconds: 220));
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1F1F1F),
            title: Text(
              _postBadgesExploreIntroTitle,
              style: GoogleFonts.notoSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            content: Text(
              _postBadgesExploreIntroBody,
              style: GoogleFonts.notoSans(
                color: const Color(0xFFB0B0B0),
                fontSize: 15,
                height: 1.45,
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0095FF),
                ),
                child: const Text('Tamam', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (!mounted) return;
        _postBadgesExploreIntroDialogShown = true;
      }
      await _maybePostBadgesFirstCardCoach();
    } finally {
      _postBadgesExploreFlowBusy = false;
    }
  }

  Future<void> _maybePostBadgesFirstCardCoach() async {
    if (!mounted || _postBadgesFirstCardCoachScheduled) return;
    final p = await OnboardingService.getGlobalTourStep();
    if (!mounted || p != OnboardingService.ftPostBadgesExploreFirstCard) return;
    if (_filteredItems.isEmpty) return;
    _postBadgesFirstCardCoachScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (!mounted || _postTourFirstCardKey.currentContext == null) {
        _postBadgesFirstCardCoachScheduled = false;
        return;
      }
      var tapped = false;
      TutorialCoachMark(
        targets: [
          TargetFocus(
            identify: 'post_badges_explore_first_card',
            keyTarget: _postTourFirstCardKey,
            shape: ShapeLightFocus.RRect,
            radius: 16,
            enableTargetTab: true,
            enableOverlayTab: false,
            paddingFocus: 8,
            borderSide: const BorderSide(color: Color(0x400095FF), width: 1.5),
            contents: [
              TargetContent(
                align: ContentAlign.bottom,
                padding: const EdgeInsets.only(bottom: 12, left: 18, right: 18),
                builder: (context, controller) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2C2C2E)),
                  ),
                  child: Text(
                    'Bu kartla başla: karta dokunarak içeriği aç ve sonraki adımda kaydet.',
                    style: GoogleFonts.notoSans(
                      color: const Color(0xFFE2E2E2),
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        colorShadow: Colors.black,
        opacityShadow: 0.78,
        pulseEnable: false,
        alignSkip: Alignment.topRight,
        textSkip: 'Geç',
        onClickTarget: (_) {
          tapped = true;
        },
        onFinish: () {
          _postBadgesFirstCardCoachScheduled = false;
          if (!tapped || !mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _filteredItems.isEmpty) return;
            unawaited(_openFirstCardForPostBadgesTour());
          });
        },
        onSkip: () {
          _postBadgesFirstCardCoachScheduled = false;
          return true;
        },
      ).show(context: context);
    });
  }

  Future<void> _openFirstCardForPostBadgesTour() async {
    final item = _filteredItems.first;
    final moved = await OnboardingService.onPostBadgesExploreFirstCardFinished();
    if (!mounted) return;
    if (moved) {
      setState(
        () => _fullTourPhaseCache =
            OnboardingService.ftPostBadgesDetailSaveCard,
      );
    }
    if (!moved) return;
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ContentDetailPage(item: item),
      ),
    );
  }

  Future<void> _onExploreHeroCardTap(Motivation item) async {
    final ftp = await OnboardingService.getGlobalTourStep();
    if (ftp == OnboardingService.ftPostBadgesExploreFirstCard) {
      final first = _filteredItems.isNotEmpty ? _filteredItems.first : null;
      if (first != null && first.id == item.id) {
        final moved = await OnboardingService.onPostBadgesExploreFirstCardFinished();
        if (!mounted) return;
        if (moved) {
          setState(
            () => _fullTourPhaseCache =
                OnboardingService.ftPostBadgesDetailSaveCard,
          );
        }
      }
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ContentDetailPage(item: item),
      ),
    );
  }

  @override
  void dispose() {
    OnboardingService.registerExploreTourPhaseRefreshHandler(null);
    _searchController.dispose();
    super.dispose();
  }

  List<Motivation> get _filteredItems {
    var result = _items;
    if (_selectedCategoryIndex > 0 &&
        _selectedCategoryIndex < _categoryFilters.length) {
      final key = _categoryFilters[_selectedCategoryIndex].$1;
      if (key != null) {
        result = result.where((m) => (m.category ?? '') == key).toList();
      }
    }
    if (_searchQuery.isEmpty) return result;
    final q = _searchQuery.toLowerCase();
    return result.where((m) {
      final titleMatch = m.title.toLowerCase().contains(q);
      final bodyMatch = m.body.toLowerCase().contains(q);
      final authorMatch = (m.author ?? '').toLowerCase().contains(q);
      return titleMatch || bodyMatch || authorMatch;
    }).toList();
  }

  Future<void> _load() async {
    await ContentSyncService.syncFromBackend();
    final all = await MotivationService.loadAll();
    final entries = await SavedItemsService.getSavedEntries();
    final savedIds = entries.map((e) => e.itemId).toSet();
    final history = await SearchHistoryService.getHistory();
    if (!mounted) return;
    setState(() {
      _items = all;
      _savedIds.clear();
      _savedIds.addAll(savedIds);
      _searchHistory = history;
    });
    await _refreshFullTourPhase();
  }

  Future<void> _onExploreRefreshWithTourHook() async {
    await _load();
    await OnboardingService.onPostBadgesSavedPullRefreshCompleted();
    if (!mounted) return;
    final p = await OnboardingService.getGlobalTourStep();
    setState(() => _fullTourPhaseCache = p);
  }

  Future<void> _maybeShowPostBadgesExplorePullEndDialog() async {
    if (!mounted ||
        _postBadgesExplorePullEndDialogShown ||
        _postBadgesExplorePullEndDialogInFlight) {
      return;
    }
    if (widget.shellTabIndex != null && widget.shellTabIndex != 1) return;
    final p = await OnboardingService.getGlobalTourStep();
    if (!mounted || p != OnboardingService.ftPostBadgesSavedPullRefresh) {
      return;
    }
    _postBadgesExplorePullEndDialogInFlight = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1F1F1F),
          title: Text(
            'Keşfet',
            style: GoogleFonts.notoSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: Text(
            _postBadgesExplorePullEndBody,
            style: GoogleFonts.notoSans(
              color: const Color(0xFFB0B0B0),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0095FF),
              ),
              child: const Text('Tamam', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (mounted) _postBadgesExplorePullEndDialogShown = true;
    } finally {
      _postBadgesExplorePullEndDialogInFlight = false;
    }
  }

  Future<void> _clearSearchHistory() async {
    await SearchHistoryService.clearHistory();
    setState(() => _searchHistory = []);
  }

  Future<void> _addCurrentSearchToHistory() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final q = _searchController.text.trim();
    if (q.isNotEmpty) {
      await SearchHistoryService.addSearch(q);
      final history = await SearchHistoryService.getHistory();
      if (mounted) setState(() => _searchHistory = history);
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsPage()),
    );
    await NotificationBadgeController.instance.refresh();
  }

  void _openChain() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ZincirPage()),
    );
  }

  /// Figma 60-676: ortada «Keşfet», sağda zincir + bildirim (arama alanı aşağıda).
  Widget _buildExploreHeader() {
    final badge = NotificationBadgeController.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 4, 8),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            KeyedSubtree(
              key: _exploreHeaderKey,
              child: Text(
                'Keşfet',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTopBar.centeredTitleStyle(),
              ),
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
                      color: Color(0xFFE8E8E8),
                      size: 24,
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
                              color: Color(0xFFE8E8E8),
                              size: 26,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildExploreHeader(),
            Expanded(
              child: KeyedSubtree(
                key: _postBadgesExploreRefreshKey,
                child: RefreshIndicator(
                color: const Color(0xFF0095FF),
                backgroundColor: const Color(0xFF1F1F1F),
                onRefresh: _onExploreRefreshWithTourHook,
                child: CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSearchBar(),
                            if (_searchHistory.isNotEmpty &&
                                _searchQuery.isEmpty) ...[
                              const SizedBox(height: 16),
                              _buildSearchHistorySection(),
                            ],
                            const SizedBox(height: 18),
                            _buildCategoryChips(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    if (filtered.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          child: _buildEmptySection(
                            _searchQuery.isEmpty
                                ? 'Bu filtrede henüz içerik yok.'
                                : 'Aramanızla eşleşen içerik bulunamadı.',
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final item = filtered[index];
                            final featured = index == 0 && _searchQuery.isEmpty;
                            final tourSave =
                                _fullTourPhaseCache ==
                                OnboardingService.ftExploreSave;
                            final bookmarkKey = (index == 0 && tourSave)
                                ? _firstBookmarkKey
                                : null;
                            final postTourFirst =
                                _fullTourPhaseCache ==
                                    OnboardingService
                                        .ftPostBadgesExploreFirstCard;
                            final postTourCardKey =
                                (index == 0 && _searchQuery.isEmpty && postTourFirst)
                                ? _postTourFirstCardKey
                                : null;
                            Widget card = _buildExploreHeroCard(
                              item,
                              featured: featured,
                              tourBookmarkKey: bookmarkKey,
                              tourFirstCardKey: postTourCardKey,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: card,
                            );
                          }, childCount: filtered.length),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ),
            if (widget.showBottomBar)
              BottomNavBar(activeIndex: 1, onTabTap: widget.onTabTap),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Icon(
              Icons.search_rounded,
              color: Color(0xFF6B7280),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.notoSans(
                color: const Color(0xFFE2E2E2),
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Konu, içerik veya yazar ara...',
                hintStyle: GoogleFonts.notoSans(
                  color: const Color(0xFF6B7280),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onChanged: (_) =>
                  setState(() => _searchQuery = _searchController.text.trim()),
              onSubmitted: (_) => _addCurrentSearchToHistory(),
              onEditingComplete: _addCurrentSearchToHistory,
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.clear_rounded,
                color: Color(0xFFBFC7D5),
                size: 22,
              ),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              padding: const EdgeInsets.only(right: 8),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Son aramalar',
              style: GoogleFonts.notoSans(
                color: const Color(0xFFBFC7D5),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            TextButton(
              onPressed: () async {
                await _clearSearchHistory();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Temizle',
                style: GoogleFonts.notoSans(
                  color: const Color(0xFFA1C9FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _searchHistory.map((query) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: const Color(0xFF404040)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      _searchController.text = query;
                      setState(() => _searchQuery = query);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 14,
                        top: 8,
                        bottom: 8,
                      ),
                      child: Text(
                        query,
                        style: GoogleFonts.notoSans(
                          color: const Color(0xFFE2E2E2),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      await SearchHistoryService.removeSearch(query);
                      final history = await SearchHistoryService.getHistory();
                      if (mounted) setState(() => _searchHistory = history);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 4,
                        right: 10,
                        top: 8,
                        bottom: 8,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: const Color(0xFFBFC7D5).withValues(alpha: 0.8),
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categoryFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final selected = index == _selectedCategoryIndex;
          final label = _categoryFilters[index].$2;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategoryIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF0095FF)
                    : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF0095FF)
                      : const Color(0xFF3D3D3D),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: GoogleFonts.notoSans(
                  color: selected ? Colors.white : const Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Figma 60-676: tam genişlik immersive kart, yer imi sağ üst, kategori + başlık altta.
  Widget _buildExploreHeroCard(
    Motivation item, {
    bool featured = false,
    GlobalKey? tourBookmarkKey,
    GlobalKey? tourFirstCardKey,
  }) {
    final imageUrl = item.displayImageUrl ?? '';
    final saved = _savedIds.contains(item.id);
    final categoryLabel = (item.category ?? 'İçerik').toUpperCase();
    final h = featured ? 300.0 : 268.0;

    final outer = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: h,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => unawaited(_onExploreHeroCardTap(item)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.imageBase64 != null)
                    Image.memory(
                      base64Decode(item.imageBase64!),
                      fit: BoxFit.cover,
                    )
                  else if (imageUrl.isNotEmpty)
                    MotivationCachedImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: const Color(0xFF0E0E0E)),
                      error: (_, __, ___) =>
                          Container(color: const Color(0xFF0E0E0E)),
                    )
                  else
                    Container(color: const Color(0xFF0E0E0E)),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: featured ? 200 : 160,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.5),
                              Colors.black.withValues(alpha: 0.88),
                            ],
                            stops: const [0.0, 0.35, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          categoryLabel,
                          style: GoogleFonts.notoSans(
                            color: const Color(0xFFB8D4FF),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.title,
                          maxLines: featured ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.newsreader(
                            color: Colors.white,
                            fontSize: featured ? 24 : 21,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            shadows: const [
                              Shadow(
                                color: Color(0x99000000),
                                blurRadius: 16,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        if (featured) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Bu hafta editörlerimiz tarafından seçilen içeriklere göz atın.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSans(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _wrapTourKey(
                tourBookmarkKey,
                _buildExploreBookmarkButton(
                  saved: saved,
                  onToggle: () async {
                    final nowSaved = await SavedItemsService.toggleSaved(
                      item.id,
                    );
                    if (!mounted) return;
                    setState(() {
                      if (nowSaved) {
                        _savedIds.add(item.id);
                      } else {
                        _savedIds.remove(item.id);
                      }
                    });
                    final ftp = await OnboardingService.getGlobalTourStep();
                    if (ftp == OnboardingService.ftExploreSave && nowSaved) {
                      final moved = await OnboardingService.onExploreSavedFirstItem();
                      if (!moved) return;
                      if (mounted) {
                        setState(
                          () => _fullTourPhaseCache =
                              OnboardingService.ftSavedList,
                        );
                      }
                      OnboardingService.requestTab(2);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (tourFirstCardKey != null) {
      return KeyedSubtree(key: tourFirstCardKey, child: outer);
    }
    return outer;
  }

  Widget _wrapTourKey(GlobalKey? key, Widget child) {
    if (key != null) return KeyedSubtree(key: key, child: child);
    return child;
  }

  Widget _buildExploreBookmarkButton({
    required bool saved,
    required Future<void> Function() onToggle,
  }) {
    return Material(
      color: const Color(0x99000000),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: saved ? 'Kaydedilenlerden çıkar' : 'Kaydet',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        icon: Icon(
          saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: saved ? const Color(0xFFA1C9FF) : Colors.white,
          size: 22,
        ),
        onPressed: onToggle,
      ),
    );
  }

  Widget _buildEmptySection(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.notoSans(
          color: const Color(0xFFBFC7D5),
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );
  }
}
