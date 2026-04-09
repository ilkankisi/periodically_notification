import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/motivation.dart';
import '../widgets/motivation_cached_image.dart';
import '../services/content_sync_service.dart';
import '../services/motivation_service.dart';
import 'content_detail_page.dart';

/// Ana sayfa «Önceki günler» → «Tümünü Gör» — Figma (60-785) ile uyumlu liste + sayfalama.
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
    await ContentSyncService.syncFromBackend();
    final all = await MotivationService.loadAll();
    if (!mounted) return;
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFA1C9FF), size: 20),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(12),
            ),
          ),
          Expanded(
            child: Text(
              'Önceki günler',
              style: GoogleFonts.newsreader(
                color: const Color(0xFFE2E2E2),
                fontSize: 26,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131313),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF0095FF)),
                    )
                  : _items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Henüz içerik yok.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.notoSans(
                                color: const Color(0xFFBFC7D5),
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: const Color(0xFF0095FF),
                          backgroundColor: const Color(0xFF1F1F1F),
                          onRefresh: _load,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                            itemCount: _pageItems.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _buildListRow(_pageItems[index]);
                            },
                          ),
                        ),
            ),
            _buildPagination(),
          ],
        ),
      ),
    );
  }

  Widget _buildListRow(Motivation item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ContentDetailPage(item: item),
          ),
        ).then((_) => _load()),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x14FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x28000000),
                blurRadius: 16,
                offset: Offset(0, 6),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: item.imageBase64 != null
                        ? Image.memory(
                            base64Decode(item.imageBase64!),
                            fit: BoxFit.cover,
                          )
                        : (item.displayImageUrl != null && item.displayImageUrl!.isNotEmpty
                            ? MotivationCachedImage(
                                imageUrl: item.displayImageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: const Color(0xFF0E0E0E)),
                                error: (_, __, ___) => Container(color: const Color(0xFF0E0E0E)),
                              )
                            : Container(
                                color: const Color(0xFF0E0E0E),
                                child: const Icon(Icons.article_outlined, color: Color(0xFF6B7280), size: 32),
                              )),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.newsreader(
                          color: const Color(0xFFE2E2E2),
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _readTimeFromBody(item.body),
                        style: GoogleFonts.notoSans(
                          color: const Color(0xFFBFC7D5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFBFC7D5), size: 22),
              ],
            ),
          ),
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
    if (_loading || _items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: const Color(0xB31F1F1F),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14A1C9FF),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
        border: const Border(top: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Material(
            color: _currentPage > 1 ? const Color(0xFF2A2A2A) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            child: IconButton(
              onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
              icon: Icon(
                Icons.chevron_left_rounded,
                color: _currentPage > 1 ? const Color(0xFFA1C9FF) : const Color(0xFF525252),
                size: 28,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Sayfa $_currentPage / $_totalPages',
              style: GoogleFonts.notoSans(
                color: const Color(0xFFE2E2E2),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Material(
            color: _currentPage < _totalPages ? const Color(0xFF2A2A2A) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            child: IconButton(
              onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null,
              icon: Icon(
                Icons.chevron_right_rounded,
                color: _currentPage < _totalPages ? const Color(0xFFA1C9FF) : const Color(0xFF525252),
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
