import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/motivation.dart';
import '../services/motivation_service.dart';
import '../services/saved_items_service.dart';
import '../widgets/header_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import 'content_detail_page.dart';

/// Kaydedilenler sayfası - HTML tasarımı: header, filtre chip'leri, liste (thumbnail, başlık, kayıt tarihi, sil)
class SavedPage extends StatefulWidget {
  const SavedPage({
    super.key,
    this.showBottomBar = true,
    this.onTabTap,
  });

  final bool showBottomBar;
  final ValueChanged<int>? onTabTap;

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  int _filterIndex = 0;
  static const _filters = ['Tümü', 'Makaleler', 'Videolar', 'Sesler'];

  List<SavedEntry> _entries = [];
  Map<String, Motivation> _itemsById = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await SavedItemsService.getSavedEntries();
    entries.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final all = await MotivationService.loadAll();
    final byId = {for (var m in all) m.id: m};
    setState(() {
      _entries = entries;
      _itemsById = byId;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          HeaderBar(
            title: 'Kaydedilenler',
            leading: SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                onPressed: () {
                  widget.onTabTap?.call(0);
                },
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(minimumSize: const Size(24, 24)),
              ),
            ),
            trailing: SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(minimumSize: const Size(24, 24)),
              ),
            ),
          ),
          // Filtre chip'leri
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selected = index == _filterIndex;
                return GestureDetector(
                  onTap: () => setState(() => _filterIndex = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF2094F3) : const Color(0xFF27272A),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _filters[index],
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
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2094F3)))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: Colors.white,
                    child: _entries.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 48),
                              Center(
                                child: Text(
                                  'Henüz kaydedilmiş içerik yok.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: _entries.length,
                            separatorBuilder: (_, __) => Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              color: const Color(0xFF2C2C2C),
                            ),
                            itemBuilder: (context, index) {
                              final entry = _entries[index];
                              final item = _itemsById[entry.itemId];
                              if (item == null) return const SizedBox.shrink();
                              return _buildSavedRow(item: item, savedAt: entry.savedAt);
                            },
                          ),
                  ),
          ),
          if (widget.showBottomBar)
            BottomNavBar(activeIndex: 2, onTabTap: widget.onTabTap),
        ],
      ),
    );
  }

  Widget _buildSavedRow({required Motivation item, required String savedAt}) {
    return InkWell(
      onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContentDetailPage(item: item),
            ),
          ).then((_) => _load()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 64,
                child: item.imageBase64 != null
                    ? Image.memory(
                        base64Decode(item.imageBase64!),
                        fit: BoxFit.cover,
                      )
                    : (item.imageUrl != null && item.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: item.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: const Color(0xFF27272A)),
                              errorWidget: (_, __, ___) => Container(color: const Color(0xFF27272A)),
                            )
                          : Container(
                              color: const Color(0xFF27272A),
                              child: const Icon(Icons.article, color: Color(0xFF6B7280), size: 28),
                            )),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatSavedDate(savedAt),
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () async {
                await SavedItemsService.removeSaved(item.id);
                _load();
              },
              icon: const Icon(Icons.delete_outline, color: Color(0xFF6B7280), size: 22),
              style: IconButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.red.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSavedDate(String savedAt) {
    if (savedAt.isEmpty) return 'Kaydedildi';
    try {
      final parsed = DateTime.tryParse(savedAt);
      if (parsed != null) {
        const months = [
          'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
          'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
        ];
        return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year} tarihinde kaydedildi';
      }
    } catch (_) {}
    return 'Kaydedildi';
  }
}
