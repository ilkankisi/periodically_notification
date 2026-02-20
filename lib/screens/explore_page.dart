import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/motivation.dart';
import '../services/motivation_service.dart';
import '../services/saved_items_service.dart';
import '../widgets/header_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import 'content_detail_page.dart';

/// Keşfet sayfası: arama, kategoriler, Trend İçerikler (2x2 grid), Senin İçin Seçtiklerimiz.
/// Header başlık ortada, profil ve bildirim yok. Anasayfadaki card yapısı kullanılır.
class ExplorePage extends StatefulWidget {
  const ExplorePage({
    super.key,
    this.showBottomBar = true,
    this.onTabTap,
  });

  final bool showBottomBar;
  final ValueChanged<int>? onTabTap;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  int _selectedCategoryIndex = 0;
  static const _categories = ['Tümü', 'Teknoloji', 'Sanat', 'Tarih', 'Bilim'];

  List<Motivation> _items = [];
  final Set<String> _savedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await MotivationService.loadAll();
    final entries = await SavedItemsService.getSavedEntries();
    final savedIds = entries.map((e) => e.itemId).toSet();
    setState(() {
      _items = all;
      _savedIds.clear();
      _savedIds.addAll(savedIds);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          HeaderBar(
            title: 'Keşfet',
            leading: const SizedBox.shrink(),
            trailing: const SizedBox.shrink(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: Colors.white,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildSearchBar(),
                      const SizedBox(height: 8),
                      _buildCategoryChips(),
                      const SizedBox(height: 24),
                      _buildTrendSection(),
                      const SizedBox(height: 24),
                      _buildPicksSection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.showBottomBar)
            BottomNavBar(activeIndex: 1, onTabTap: widget.onTabTap),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF27272A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Icon(Icons.search, color: Color(0xFF9CA3AF), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'İçerik ara...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final selected = index == _selectedCategoryIndex;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategoryIndex = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF2094F3) : const Color(0xFF27272A),
                borderRadius: BorderRadius.circular(9999),
                border: selected ? null : Border.all(color: const Color(0xFF3F3F46)),
              ),
              alignment: Alignment.center,
              child: Text(
                _categories[index],
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendSection() {
    final trendItems = _items.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Trend İçerikler',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (trendItems.isNotEmpty)
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'Hepsini Gör',
                  style: TextStyle(
                    color: Color(0xFF2094F3),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        trendItems.isEmpty
            ? _buildEmptySection('Henüz trend içerik yok. Firebase\'den veriler yüklenecek.')
            : GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 3 / 4,
                children: trendItems.map((item) => _buildTrendCard(item)).toList(),
              ),
      ],
    );
  }

  Widget _buildEmptySection(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      ),
    );
  }

  /// Anasayfadaki card yapısına uygun: border, rounded, image + gradient + title + bookmark. Sadece Firebase/cache verisi.
  Widget _buildTrendCard(Motivation item) {
    final imageUrl = item.imageUrl ?? '';
    return GestureDetector(
      onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContentDetailPage(item: item),
            ),
          ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          border: Border.all(color: Colors.white),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              if (item.imageBase64 != null)
                Image.memory(
                  base64Decode(item.imageBase64!),
                  fit: BoxFit.cover,
                )
              else if (imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: const Color(0xFF27272A)),
                  errorWidget: (_, __, ___) => Container(color: const Color(0xFF27272A)),
                )
              else
                Container(color: const Color(0xFF27272A)),
              // Gradient overlay (bottom)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 80,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                    ),
                  ),
                ),
              ),
              // Bookmark top-right - Kaydedilenlere ekler / çıkarır
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () async {
                    await SavedItemsService.toggleSaved(item.id);
                    setState(() {
                      if (_savedIds.contains(item.id)) {
                        _savedIds.remove(item.id);
                      } else {
                        _savedIds.add(item.id);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Icon(
                      _savedIds.contains(item.id) ? Icons.bookmark : Icons.bookmark_border,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              // Title bottom
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPicksSection() {
    final picks = _items.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Senin İçin Seçtiklerimiz',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        if (picks.isEmpty)
          _buildEmptySection('Henüz seçilmiş içerik yok. Firebase\'den veriler yüklenecek.')
        else
          ...picks.map((m) => _buildPickRow(
                category: 'İÇERİK',
                title: m.title,
                readTime: _readTimeFromBody(m.body),
                imageUrl: m.imageUrl,
                imageBase64: m.imageBase64,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ContentDetailPage(item: m),
                  ),
                ),
              )),
      ],
    );
  }

  /// Gövde uzunluğuna göre tahmini okuma süresi (dk).
  String _readTimeFromBody(String body) {
    final words = body.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
    final minutes = (words / 200).ceil().clamp(1, 99);
    return '$minutes dk okuma';
  }

  Widget _buildPickRow({
    required String category,
    required String title,
    required String readTime,
    String? imageUrl,
    String? imageBase64,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2C2C2C)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: imageBase64 != null
                      ? Image.memory(base64Decode(imageBase64), fit: BoxFit.cover)
                      : (imageUrl != null && imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: const Color(0xFF27272A)),
                                errorWidget: (_, __, ___) => Container(color: const Color(0xFF27272A)),
                              )
                            : Container(color: const Color(0xFF27272A))),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        color: Color(0xFF2094F3),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      readTime,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
