import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../models/motivation.dart';
import '../services/saved_items_service.dart';
import '../widgets/header_bar.dart';
import '../widgets/bottom_nav_bar.dart';

/// İçerik detay sayfası - Görsel tasarıma uygun makale görünümü
class ContentDetailPage extends StatefulWidget {
  final Motivation item;

  const ContentDetailPage({super.key, required this.item});

  @override
  State<ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends State<ContentDetailPage> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    SavedItemsService.isSaved(widget.item.id).then((v) => setState(() => _saved = v));
  }

  Future<void> _toggleSaved() async {
    final nowSaved = await SavedItemsService.toggleSaved(widget.item.id);
    setState(() => _saved = nowSaved);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          HeaderBar(
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _toggleSaved,
                  icon: Icon(
                    _saved ? Icons.bookmark : Icons.bookmark_border,
                    color: Colors.white,
                    size: 24,
                  ),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
                ),
                IconButton(
                  onPressed: () => _shareContent(context),
                  icon: const Icon(Icons.share, color: Colors.white, size: 24),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
                ),
              ],
            ),
          ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Image - 288px
                  _buildHeroImage(),
                  // Content - padding 20px horizontal, 96px bottom
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title - Newsreader 32px bold white
                        Text(
                          widget.item.title,
                          style: GoogleFonts.newsreader(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                            color: Colors.white,
                          ),
                        ),
                        // Category row - 4px 0 16px padding, border-bottom
                        Container(
                          padding: const EdgeInsets.only(top: 4, bottom: 16),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.white, width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.category,
                                color: Color(0xFF2094F3),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Günün İçeriği',
                                style: GoogleFonts.notoSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 19 / 14,
                                  color: const Color(0xFF2094F3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Body paragraphs - 17px Noto Sans, #B0B0B0
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Text(
                            widget.item.body,
                            style: GoogleFonts.notoSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                              height: 23 / 17,
                              color: const Color(0xFFB0B0B0),
                            ),
                          ),
                        ),
                        // Date footer - border-top, calendar icon
                        Container(
                          padding: const EdgeInsets.only(top: 24, bottom: 32),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.white, width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: Color(0xFF6B7280),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(widget.item.sentAt),
                                style: GoogleFonts.notoSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 16 / 12,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          BottomNavBar(activeIndex: 0, onHomeTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _buildHeroImage() {
    final item = widget.item;
    return SizedBox(
      width: double.infinity,
      height: 288,
      child: item.imageBase64 != null
          ? Image.memory(
              base64Decode(item.imageBase64!),
              fit: BoxFit.fitHeight,
              width: double.infinity,
              height: 288,
            )
          : (item.imageUrl != null && item.imageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: item.imageUrl!,
                  fit: BoxFit.fitHeight,
                  width: double.infinity,
                  height: 288,
                  placeholder: (_, __) => Container(
                    color: const Color(0xFF27272A),
                    child: const Center(
                      child: CircularProgressIndicator(color: Color(0xFF2094F3)),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFF27272A),
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Color(0xFF6B7280),
                      size: 48,
                    ),
                  ),
                )
              : Container(
                  color: const Color(0xFF27272A),
                  child: const Icon(
                    Icons.image,
                    color: Color(0xFF6B7280),
                    size: 64,
                  ),
                )),
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

  Future<void> _shareContent(BuildContext context) async {
    final item = widget.item;
    await Share.share(
      '${item.title}\n\n${item.body}',
      subject: item.title,
    );
  }
}
