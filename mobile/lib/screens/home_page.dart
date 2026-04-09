import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/notification_badge_controller.dart';
import '../models/motivation.dart';
import '../widgets/motivation_cached_image.dart';
import '../services/content_sync_service.dart';
import '../services/push_notification_service.dart';
import '../services/motivation_service.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import 'all_content_list_page.dart';
import 'content_detail_page.dart';
import 'notifications_page.dart';
import 'zincir_page.dart';
import '../widgets/add_action_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.showBottomBar = true,
    this.onTabTap,
  });

  /// false ise alt navigasyon bar gösterilmez (MainShell kullanıyorsa).
  final bool showBottomBar;
  final ValueChanged<int>? onTabTap;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<Motivation> items = [];
  bool loading = true;
  bool _hasDeliveredContent = true; // Bildirimle gelen içerik var mı?

  StreamSubscription<void>? _contentUpdateSub;

  Widget _homeImagePlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: const Color(0xFF27272A),
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined, color: Color(0xFF52525B), size: 40),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _contentUpdateSub = PushNotificationService.onContentUpdated.stream.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    });
  }

  @override
  void dispose() {
    _contentUpdateSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    await ContentSyncService.syncFromBackend();
    // Anasayfada önce bildirimle (FCM) gelen içerikler
    final delivered = await MotivationService.loadDeliveredOnly();
    if (delivered.isNotEmpty) {
      setState(() {
        items = delivered;
        _hasDeliveredContent = true;
        loading = false;
      });
    } else {
      // Bildirim gelmemişse: Keşfet'ten ilk 5 içeriği "Bugünün Önerisi" olarak göster
      final all = await MotivationService.loadAll();
      setState(() {
        items = all.take(5).toList();
        _hasDeliveredContent = false;
        loading = false;
      });
    }
    // Widget'ı güncelle - FCM arka planda geldiyse resim burada indirilir
    PushNotificationService.refreshWidgetFromCache();
  }

  /// Bildirimle gelen içerik mi yoksa öneri mi? (öneri = delivered boşken gösterilen)
  bool get _isSuggestedContent => items.isNotEmpty && !_hasDeliveredContent;

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

  /// Figma 60-336: ortada «Günün İçeriği», sağda bildirim.
  Widget _buildEmptyHomeAppBar() {
    final badge = NotificationBadgeController.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 4, 8),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Text(
              'Günün İçeriği',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTopBar.centeredTitleStyle(),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: badge,
                builder: (context, _) {
                  final count = badge.unreadCount;
                  final showBadge = count > 0;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: 'Bildirimler',
                        icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFFE8E8E8), size: 26),
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
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Center(
                              child: Text(
                                count > 9 ? '9+' : count.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Figma 60-404: ortada «Günün İçeriği», sağda zincir + bildirim.
  Widget _buildDailyHeader() {
    final badge = NotificationBadgeController.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 4, 8),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Text(
              'Günün İçeriği',
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
                    icon: const Icon(Icons.link_rounded, color: Color(0xFFE8E8E8), size: 24),
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
                            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFFE8E8E8), size: 26),
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
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Center(
                                  child: Text(
                                    count > 9 ? '9+' : count.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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

  Widget _buildEmptyOrLoadingBody() {
    return RefreshIndicator(
      color: const Color(0xFF0095FF),
      backgroundColor: const Color(0xFF1F1F1F),
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: loading ? _buildFigmaLoadingEmptyBody() : _buildFigmaNoDataBody(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFigmaLoadingEmptyBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFigmaMainWaitingCard(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0D2847),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x330095FF),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: Color(0xFFA1C9FF),
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'İçerik yükleniyor',
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  color: const Color(0xFFF5F5F5),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bugünün içeriği hazırlanıyor. Birkaç saniye içinde burada olacak.',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSans(
                  color: const Color(0xFF9CA3AF),
                  fontSize: 14,
                  height: 1.55,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _buildFigmaHabitSectionHeader(),
        const SizedBox(height: 12),
        _buildFigmaHabitWaitingCard(),
        const SizedBox(height: 28),
        _buildFigmaPatienceQuote(),
      ],
    );
  }

  /// Figma 60-336 — veri yokken anasayfa.
  Widget _buildFigmaNoDataBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFigmaMainWaitingCard(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0D2847),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x400095FF),
                      blurRadius: 28,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFFA1C9FF), size: 22),
                    SizedBox(width: 2),
                    Icon(Icons.auto_awesome, color: Color(0xFF7EB6FF), size: 16),
                    SizedBox(width: 2),
                    Icon(Icons.auto_awesome, color: Color(0xFF5DA3FF), size: 14),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Güne başlamak için bekliyoruz.',
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  color: const Color(0xFFF5F5F5),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Küratörlerimiz bugün için en özel içerikleri hazırlıyor. Çok yakında burada olacak.',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSans(
                  color: const Color(0xFF9CA3AF),
                  fontSize: 14,
                  height: 1.55,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _buildFigmaHabitSectionHeader(),
        const SizedBox(height: 12),
        _buildFigmaHabitWaitingCard(),
        const SizedBox(height: 28),
        _buildFigmaPatienceQuote(),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _load,
            child: Text(
              'Yenile',
              style: GoogleFonts.notoSans(
                color: const Color(0xFFA1C9FF),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFigmaMainWaitingCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2A2A2E),
              Color(0xFF1E1E22),
              Color(0xFF161618),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x50000000),
              blurRadius: 32,
              offset: Offset(0, 16),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _HomeEmptyWavePainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFigmaHabitSectionHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            'Bugünkü Alışkanlığın',
            style: GoogleFonts.newsreader(
              color: const Color(0xFFE2E2E2),
              fontSize: 22,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'HAZIRLANIYOR',
            style: GoogleFonts.notoSans(
              color: const Color(0xFFA1C9FF),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFigmaHabitWaitingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFBFC7D5), size: 26),
          ),
          const SizedBox(height: 18),
          Text(
            'Henüz bugünün içeriği hazır değil.',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(
              color: const Color(0xFFE5E7EB),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Zihnini dinlendir, yeni hedeflerin yolda.',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(
              color: const Color(0xFF9CA3AF),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          _buildFigmaSkeletonBar(width: double.infinity),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: _buildFigmaSkeletonBar(width: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildFigmaSkeletonBar({required double width}) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFF2F2F2F),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _buildFigmaPatienceQuote() {
    return Text(
      'Sabır, en yüksek erdemdir.',
      textAlign: TextAlign.center,
      style: GoogleFonts.newsreader(
        fontStyle: FontStyle.italic,
        fontSize: 17,
        height: 1.4,
        color: const Color(0xFF9CA3AF),
        fontWeight: FontWeight.w400,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latest = items.isNotEmpty ? items.first : null;
    final hasPreviousDays = items.length > 1;
    final showEmptyLayout = loading || items.isEmpty;

    if (showEmptyLayout) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildEmptyHomeAppBar(),
              Expanded(child: _buildEmptyOrLoadingBody()),
              if (widget.showBottomBar) BottomNavBar(activeIndex: 0, onTabTap: widget.onTabTap),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDailyHeader(),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF0095FF),
                backgroundColor: const Color(0xFF1F1F1F),
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMainCard(latest!, isSuggested: _isSuggestedContent),
                      const SizedBox(height: 16),
                      _buildZincirPillButton(),
                      const SizedBox(height: 28),
                      _buildHabitSection(items.first),
                      if (hasPreviousDays) ...[
                        const SizedBox(height: 32),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isSuggestedContent ? 'Daha fazla içerik' : 'Önceki Günler',
                                    style: GoogleFonts.newsreader(
                                      color: const Color(0xFFE2E2E2),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                    ),
                                  ),
                                  if (!_isSuggestedContent) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Geçmişteki yolculuğuna göz at',
                                      style: GoogleFonts.notoSans(
                                        color: const Color(0xFF9CA3AF),
                                        fontSize: 13,
                                        height: 1.4,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AllContentListPage(),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFA1C9FF),
                                padding: const EdgeInsets.only(left: 8, top: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'TÜMÜNÜ GÖR →',
                                style: GoogleFonts.notoSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.9,
                                  color: const Color(0xFFA1C9FF),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: items.length - 1,
                            separatorBuilder: (_, __) => const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              final item = items[index + 1];
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ContentDetailPage(item: item),
                                  ),
                                ),
                                child: _smallCard(item),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (widget.showBottomBar) BottomNavBar(activeIndex: 0, onTabTap: widget.onTabTap),
          ],
        ),
      ),
    );
  }

  /// Figma 60-404: koyu pill, hero kartının hemen altında.
  Widget _buildZincirPillButton() {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _openChain,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.link_rounded, color: Color(0xFFA1C9FF), size: 22),
                const SizedBox(width: 10),
                Text(
                  'Zincir ve rozetlerini gör',
                  style: GoogleFonts.notoSans(
                    color: const Color(0xFFE5E7EB),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ana değer önerisi — Figma 60-404 (mavi daire check + kompakt aksiyon kartı).
  Widget _buildHabitSection(Motivation latest) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0095FF),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x400095FF),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Bugünkü alışkanlığın',
                style: GoogleFonts.newsreader(
                  color: const Color(0xFFE2E2E2),
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Motivasyon tek başına yetmez — ne yaptığını yaz...',
          style: GoogleFonts.notoSans(
            color: const Color(0xFF9CA3AF),
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 18),
        AddActionCard(
          quoteId: latest.id,
          quoteTitle: latest.title,
          onActionSaved: _load,
          titleText: 'BUGÜN BU SÖZLE NE YAPTIN?',
          hintText: 'Düşüncelerini ve eylemlerini buraya not et...',
          showDescription: false,
        ),
      ],
    );
  }

  /// Figma 60-404: tam genişlik hero, görsel üzerinde rozet + italik başlık.
  static const double _homeHeroImageHeight = 300;

  Widget _buildMainCard(Motivation latest, {bool isSuggested = false}) {
    final badge = isSuggested ? 'BUGÜNÜN ÖNERİSİ' : 'GÜNÜN İLHAMI';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ContentDetailPage(item: latest),
        ),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x50000000),
              blurRadius: 32,
              offset: Offset(0, 16),
              spreadRadius: -8,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.loose,
          children: [
            SizedBox(
              height: _homeHeroImageHeight,
              width: double.infinity,
              child: latest.imageBase64 != null
                  ? Image.memory(
                      base64Decode(latest.imageBase64!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: _homeHeroImageHeight,
                    )
                  : (latest.displayImageUrl != null && latest.displayImageUrl!.isNotEmpty
                      ? MotivationCachedImage(
                          imageUrl: latest.displayImageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: _homeHeroImageHeight,
                          placeholder: (c, u) => Container(color: const Color(0xFF27272A)),
                          error: (c, u, e) => _homeImagePlaceholder(_homeHeroImageHeight),
                        )
                      : _homeImagePlaceholder(_homeHeroImageHeight)),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 96,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 200,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.88),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xB3000000),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF0095FF).withValues(alpha: 0.4)),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.notoSans(
                    color: const Color(0xFFA1C9FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.85,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Text(
                latest.title,
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.newsreader(
                  color: const Color(0xFFF5F5F5),
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  height: 1.2,
                  letterSpacing: -0.3,
                  shadows: const [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 12,
                      color: Color(0x99000000),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallCard(Motivation m) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 16,
            offset: Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 100,
            width: double.infinity,
            child: m.imageBase64 != null
                ? Image.memory(
                    base64Decode(m.imageBase64!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 100,
                  )
                : (m.displayImageUrl != null && m.displayImageUrl!.isNotEmpty
                    ? MotivationCachedImage(
                        imageUrl: m.displayImageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 100,
                        placeholder: (c, u) => Container(color: const Color(0xFF27272A)),
                        error: (c, u, e) => _homeImagePlaceholder(100),
                      )
                    : _homeImagePlaceholder(100)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDateDayMonthUpper(m.sentAt ?? ''),
                  style: GoogleFonts.notoSans(
                    color: const Color(0xFFA1C9FF),
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  m.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.newsreader(
                    color: const Color(0xFFE2E2E2),
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Figma önceki günler kartları: «18 MART»
  String _formatDateDayMonthUpper(String? sentAt) {
    if (sentAt == null || sentAt.isEmpty) return '—';
    try {
      final parsed = DateTime.tryParse(sentAt);
      if (parsed != null) {
        const months = [
          'OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN',
          'TEMMUZ', 'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK',
        ];
        return '${parsed.day} ${months[parsed.month - 1]}';
      }
    } catch (_) {}
    return sentAt;
  }
}

/// Figma 60-336 ana kart arka planı — hafif dalga / derinlik.
class _HomeEmptyWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Path()
      ..moveTo(0, size.height * 0.4)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.26,
        size.width * 0.52,
        size.height * 0.42,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.58,
        size.width,
        size.height * 0.32,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(p1, Paint()..color = const Color(0x0AFFFFFF));

    final p2 = Path()
      ..moveTo(0, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.52,
        size.width * 0.48,
        size.height * 0.68,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.78,
        size.width,
        size.height * 0.55,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(p2, Paint()..color = const Color(0x061A2840));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

