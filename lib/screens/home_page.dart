import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/motivation.dart';
import '../services/motivation_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<Motivation> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
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
    final all = await MotivationService.loadAll();
    setState(() {
      items = all;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final latest = items.isNotEmpty ? items.last : null;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 64,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF1F1F1F),
                border: Border(bottom: BorderSide(color: Colors.white)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  SizedBox(width: 8),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Günün İçeriği',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ),
                  SizedBox(width: 48),
                ],
              ),
            ),
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
                      // big card
                      Container(
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
                                        ? Image.memory(base64Decode(latest.imageBase64!), fit: BoxFit.cover, width: double.infinity, height: 224)
                                        : (latest != null && latest.imageUrl != null
                                            ? CachedNetworkImage(
                                                imageUrl: latest.imageUrl!,
                                                fit: BoxFit.cover,
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
                                    decoration: BoxDecoration(color: const Color(0xFFCCCCCC), borderRadius: BorderRadius.circular(12)),
                                    child: SingleChildScrollView(
                                              child: Text(
                                              latest?.body ?? 'Bu bir örnek içerik metnidir. Günün içeriği burada görünecek... Bu alan günün en önemli bilgilerini, güncel gelişmeleri ve sizin için seçtiğimiz özel makaleyi barındırır. Bilgi dolu bir gün dileriz.',
                                              style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 16),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule, color: Color(0xFF6B7280), size: 14),
                                      const SizedBox(width: 8),
                                      Text(
                                        latest?.sentAt ?? '',
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
                            // show in reverse chronological order excluding latest
                            final reversed = items.reversed.toList();
                            final item = reversed[index + 1];
                            return _smallCard(item);
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
      ),
      bottomNavigationBar: Container(
        height: 85,
        decoration: const BoxDecoration(color: Color(0xFF1F1F1F), border: Border(top: BorderSide(color: Colors.white))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navButton(Icons.home, 'Ana Sayfa', active: true),
                  _navButton(Icons.explore, 'Keşfet'),
                  _navButton(Icons.bookmark, 'Kaydedilenler'),
                  _navButton(Icons.person, 'Profil'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(width: 128, height: 4, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9999))),
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
                  ? Image.memory(base64Decode(m.imageBase64!), fit: BoxFit.cover, width: double.infinity, height: 96)
                  : (m.imageUrl != null
                      ? CachedNetworkImage(imageUrl: m.imageUrl!, fit: BoxFit.cover, width: double.infinity, height: 96, placeholder: (c, u) => Container(color: const Color(0xFF27272A)), errorWidget: (c, u, e) => Container(color: const Color(0xFF27272A)))
                      : null),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.sentAt ?? '', style: const TextStyle(color: Color(0xFFFFB74D), fontWeight: FontWeight.w700, fontSize: 10)),
                const SizedBox(height: 4),
                Text(m.title, style: const TextStyle(color: Color(0xFFE5E7EB), fontSize: 14)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget? _maybeImageFromBase64(String? base64Str) {
    if (base64Str == null) return null;
    try {
      final bytes = base64Decode(base64Str);
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
      );
    } catch (e) {
      return null;
    }
  }

  Widget _navButton(IconData icon, String label, {bool active = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: active ? const Color(0xFF2196F3) : const Color(0xFF9CA3AF)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: active ? const Color(0xFF2196F3) : const Color(0xFF9CA3AF), fontSize: 10, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
