import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/motivation.dart';
import '../services/motivation_service.dart';
import '../widgets/header_bar.dart';
import 'content_detail_page.dart';

/// Keşfet > Hepsini Gör: Firebase'deki tüm içerikler, sayfa başı 5 öğe, pagination.
class AllContentListPage extends StatefulWidget {
  const AllContentListPage({super.key});

  @override
  State<AllContentListPage> createState() => _AllContentListPageState();
}

class _AllContentListPageState extends State<AllContentListPage> {
  static const int _pageSize = 5;

  List<Motivation> _items = [];
  bool _loading = true;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await MotivationService.loadAll();
    setState(() {
      _items = all;
      _loading = false;
      if (_currentPage > _totalPages && _totalPages > 0) {
        _currentPage = _totalPages;
      }
    });
  }

  int get _totalPages => _items.isEmpty ? 1 : (_items.length / _pageSize).ceil();

  List<Motivation> get _pageItems {
    if (_items.isEmpty) return [];
    final start = (_currentPage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, _items.length);
    if (start >= _items.length) return [];
    return _items.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          HeaderBar(
            title: 'Tüm İçerikler',
            leading: SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(minimumSize: const Size(24, 24)),
              ),
            ),
            trailing: const SizedBox(width: 40, height: 40),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2094F3)))
                : _items.isEmpty
                    ? Center(
                        child: Text(
                          'Henüz içerik yok.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 15,
                          ),
                        ),
                      )
                    : _buildEqualHeightList(),
          ),
          _buildPagination(),
        ],
      ),
    );
  }

  /// Liste alanını 5 eşit yüksekliğe böler; kaydırma yok (sabit 5 satır).
  Widget _buildEqualHeightList() {
    final pageItems = _pageItems;
    return Column(
      children: [
        for (var i = 0; i < _pageSize; i++) ...[
          if (i > 0)
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: const Color(0xFF2C2C2C),
            ),
          Expanded(
            child: i < pageItems.length
                ? _buildListRow(pageItems[i])
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }

  Widget _buildListRow(Motivation item) {
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
                    _readTimeFromBody(item.body),
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
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
    );
  }

  String _readTimeFromBody(String body) {
    final words = body.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
    final minutes = (words / 200).ceil().clamp(1, 99);
    return '$minutes dk okuma';
  }

  Widget _buildPagination() {
    if (_items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF1F1F1F),
        border: Border(top: BorderSide(color: Color(0xFF2C2C2C), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 1
                ? () => setState(() => _currentPage--)
                : null,
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
            style: IconButton.styleFrom(
              backgroundColor: _currentPage > 1 ? const Color(0xFF27272A) : Colors.transparent,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Sayfa $_currentPage / $_totalPages',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _currentPage < _totalPages
                ? () => setState(() => _currentPage++)
                : null,
            icon: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
            style: IconButton.styleFrom(
              backgroundColor: _currentPage < _totalPages ? const Color(0xFF27272A) : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
