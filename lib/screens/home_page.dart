import 'dart:async';
import 'dart:convert';
import '../services/notification_badge_controller.dart';
import 'package:flutter/material.dart';
import '../models/motivation.dart';
import '../widgets/motivation_cached_image.dart';
import '../services/content_sync_service.dart';
import '../services/push_notification_service.dart';
import '../services/motivation_service.dart';
import '../widgets/header_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/app_top_bar.dart';
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

  @override
  Widget build(BuildContext context) {
    final latest = items.isNotEmpty ? items.first : null;
    final hasPreviousDays = items.length > 1;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppTopBar(
        title: 'Günün İçeriği',
        onNotificationsTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotificationsPage()),
          );
          await NotificationBadgeController.instance.refresh();
        },
        onChainTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ZincirPage()),
          );
        },
      ),
      body: Column(
        children: [
          const SizedBox(height: 0),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: Colors.white,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      items.isEmpty
                          ? _buildWelcomeCard()
                          : _buildMainCard(latest!, isSuggested: _isSuggestedContent),
                      if (items.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _buildHabitSection(items.first),
                      ],
                      if (hasPreviousDays) ...[
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isSuggestedContent ? 'Daha Fazla İçerik' : 'Önceki Günler',
                              style: const TextStyle(color: Color(0xFFF3F4F6), fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AllContentListPage(),
                                ),
                              ),
                              child: const Text('Tümünü Gör', style: TextStyle(color: Color(0xFF42A5F5))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 197,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: items.length - 1,
                            separatorBuilder: (_, __) => const SizedBox(width: 16),
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
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.showBottomBar)
            BottomNavBar(activeIndex: 0, onTabTap: widget.onTabTap),
        ],
      ),
    );
  }

  /// Veri yokken: hoş geldin mesajı, ana ekranı kaplayan kart
  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        border: Border.all(color: Colors.white),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uygulamamıza hoş geldiniz!',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(
              'DAHA ile motivasyonu günlük eyleme çevirirsin: bugün bir içerikle tetiklenir, '
              'detayda veya burada "Bugün bu sözle ne yaptın?" alanına yazdığın adımların zincirini ve rozetlerini oluşturur. '
              'Şimdilik Keşfet’ten içerik seçebilir veya yarın düzenli bildirimini bekleyebilirsin.',
              style: const TextStyle(color: Color(0xFFE5E7EB), fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => widget.onTabTap?.call(1),
              icon: const Icon(Icons.explore, color: Color(0xFF42A5F5), size: 20),
              label: const Text('Keşfet sayfasına git', style: TextStyle(color: Color(0xFF42A5F5), fontSize: 15)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF42A5F5),
                side: const BorderSide(color: Color(0xFF42A5F5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ana değer önerisi: günlük eylem kaydı (App Store 4.2).
  Widget _buildHabitSection(Motivation latest) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.task_alt, color: Color(0xFF2094F3), size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Bugünkü alışkanlığın',
                style: TextStyle(
                  color: Color(0xFFF3F4F6),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Motivasyon tek başına yetmez — ne yaptığını yaz, zincirini koru. Bu alan uygulamanın asıl günlük takip akışıdır.',
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        AddActionCard(
          quoteId: latest.id,
          quoteTitle: latest.title,
          onActionSaved: _load,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (context) => const ZincirPage()),
            );
          },
          icon: const Icon(Icons.link, color: Color(0xFF42A5F5), size: 20),
          label: const Text(
            'Zincir ve rozetlerini gör',
            style: TextStyle(color: Color(0xFF42A5F5), fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF42A5F5),
            side: const BorderSide(color: Color(0xFF42A5F5)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ],
    );
  }

  /// Bugünün içeriği kartı (en az 1 bildirim gelmiş) veya öneri
  Widget _buildMainCard(Motivation latest, {bool isSuggested = false}) {
    final badge = isSuggested ? 'Bugünün Önerisi' : 'Bugünün Öne Çıkanı';
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
          color: const Color(0xFF1F1F1F),
          border: Border.all(color: Colors.white),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 224,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF27272A),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(27)),
                    child: latest.imageBase64 != null
                        ? Image.memory(base64Decode(latest.imageBase64!), fit: BoxFit.fitHeight, width: double.infinity, height: 224)
                        : (latest.displayImageUrl != null && latest.displayImageUrl!.isNotEmpty
                            ? MotivationCachedImage(
                                imageUrl: latest.displayImageUrl!,
                                fit: BoxFit.fitHeight,
                                width: double.infinity,
                                height: 224,
                                placeholder: (c, u) => Container(color: const Color(0xFF27272A)),
                                error: (c, u, e) => _homeImagePlaceholder(224),
                              )
                            : _homeImagePlaceholder(224)),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(latest.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 240,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(12)),
                    child: SingleChildScrollView(
                      child: Text(
                        latest.body,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.schedule, color: Color(0xFF6B7280), size: 14),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(latest.sentAt ?? ''),
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
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
      decoration: BoxDecoration(color: const Color(0xFF1F1F1F), border: Border.all(color: Colors.white), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 96,
            width: double.infinity,
            decoration: const BoxDecoration(color: Color(0xFF27272A), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: m.imageBase64 != null
                  ? Image.memory(base64Decode(m.imageBase64!), fit: BoxFit.fitHeight, width: double.infinity, height: 96)
                  : (m.displayImageUrl != null && m.displayImageUrl!.isNotEmpty
                      ? MotivationCachedImage(
                          imageUrl: m.displayImageUrl!,
                          fit: BoxFit.fitHeight,
                          width: double.infinity,
                          height: 96,
                          placeholder: (c, u) => Container(color: const Color(0xFF27272A)),
                          error: (c, u, e) => _homeImagePlaceholder(96),
                        )
                      : _homeImagePlaceholder(96)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatDate(m.sentAt ?? ''), style: const TextStyle(color: Color(0xFFFFB74D), fontWeight: FontWeight.w700, fontSize: 10)),
                const SizedBox(height: 4),
                Text(m.title, style: const TextStyle(color: Color(0xFFE5E7EB), fontSize: 14)),
              ],
            ),
          )
        ],
      ),
    );
  }

  String _formatDate(String? sentAt) {
    if (sentAt == null || sentAt.isEmpty) return '—';
    try {
      final parsed = DateTime.tryParse(sentAt);
      if (parsed != null) {
        const months = [
          'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
          'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
        ];
        return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
      }
    } catch (_) {}
    return sentAt;
  }

}
