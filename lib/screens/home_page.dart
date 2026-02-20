import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/motivation.dart';
import '../services/firebase_service.dart';
import '../services/motivation_service.dart';
import '../widgets/header_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import 'content_detail_page.dart';

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

  StreamSubscription<void>? _contentUpdateSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _contentUpdateSub = FirebaseService.onContentUpdated.stream.listen((_) {
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
    // Anasayfada sadece bildirimle (FCM) gelen içerikler
    final all = await MotivationService.loadDeliveredOnly();
    setState(() {
      items = all;
      loading = false;
    });
    // Widget'ı güncelle - FCM arka planda geldiyse resim burada indirilir
    FirebaseService.refreshWidgetFromCache();
  }

  @override
  Widget build(BuildContext context) {
    final latest = items.isNotEmpty ? items.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          const HeaderBar(),
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
                      // big card - tıklanabilir
                      GestureDetector(
                        onTap: latest != null
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ContentDetailPage(item: latest),
                                  ),
                                )
                            : null,
                        child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F1F1F),
                          border: Border.all(color: Colors.white),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          children: [
                            // image placeholder (base64 preferred, then network cached URL)
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
                                    child: latest != null && latest.imageBase64 != null
                                        ? Image.memory(base64Decode(latest.imageBase64!), fit: BoxFit.fitHeight, width: double.infinity, height: 224)
                                        : (latest != null && latest.imageUrl != null
                                            ? CachedNetworkImage(
                                                imageUrl: latest.imageUrl!,
                                                fit: BoxFit.fitHeight,
                                                width: double.infinity,
                                                height: 224,
                                                placeholder: (c, u) => Container(color: const Color(0xFF27272A)),
                                                errorWidget: (c, u, e) => Container(color: const Color(0xFF27272A)),
                                              )
                                            : null),
                                  ),
                                ),
                                Positioned(
                                  left: 16,
                                  right: 16,
                                  bottom: 16,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: const [
                                      Text('Bugünün Öne Çıkanı', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(latest?.title ?? 'Günün İçeriği', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    height: 240,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(12)),
                                    child: SingleChildScrollView(
                                              child: Text(
                                              latest?.body ?? 'Bu bir örnek içerik metnidir. Günün içeriği burada görünecek... Bu alan günün en önemli bilgilerini, güncel gelişmeleri ve sizin için seçtiğimiz özel makaleyi barındırır. Bilgi dolu bir gün dileriz.',
                                              style: const TextStyle(color:  Colors.white, fontSize: 16),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule, color: Color(0xFF6B7280), size: 14),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatDate(latest?.sentAt ?? ''),
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
                    ),
                      const SizedBox(height: 24),
                      // Previous days header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Önceki Günler', style: TextStyle(color: Color(0xFFF3F4F6), fontSize: 18, fontWeight: FontWeight.w700)),
                          TextButton(onPressed: () {}, child: const Text('Tümünü Gör', style: TextStyle(color: Color(0xFF42A5F5))))
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 197,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: items.length > 1 ? items.length - 1 : 0,
                          separatorBuilder: (_, __) => const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            // sentAt azalan: items[0]=en son, items[1..]=önceki günler
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
                  ),
                ),
              ),
            ),
            ),
          ],
        ),
      bottomNavigationBar: widget.showBottomBar
          ? BottomNavBar(activeIndex: 0, onTabTap: widget.onTabTap)
          : null,
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
                  : (m.imageUrl != null
                      ? CachedNetworkImage(imageUrl: m.imageUrl!, fit: BoxFit.fitHeight, width: double.infinity, height: 96, placeholder: (c, u) => Container(color: const Color(0xFF27272A)), errorWidget: (c, u, e) => Container(color: const Color(0xFF27272A)))
                      : null),
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
