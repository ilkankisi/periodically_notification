import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../models/motivation.dart';

/// İçerik detay sayfası - Görsel tasarıma uygun makale görünümü
class ContentDetailPage extends StatelessWidget {
  final Motivation item;

  const ContentDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          // Top Navigation Bar - 65px, #1F1F1F
          Container(
            width: double.infinity,
            height: 65,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1F1F1F),
              border: Border(bottom: BorderSide(color: Colors.white, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Center(
                    child: Text(
                      'Günün İçeriği',
                      style: GoogleFonts.newsreader(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    onPressed: () => _shareContent(context),
                    icon: const Icon(Icons.share, color: Colors.white, size: 24),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(24, 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
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
                          item.title,
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
                            item.body,
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
                                _formatDate(item.sentAt),
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
          // Bottom Navigation Bar - #1F1F1F, border-top #2C2C2C
          _buildBottomNav(context),
        ],
      ),
    );
  }

  Widget _buildHeroImage() {
    return SizedBox(
      width: double.infinity,
      height: 288,
      child: item.imageBase64 != null
          ? Image.memory(
              base64Decode(item.imageBase64!),
              fit: BoxFit.cover,
              width: double.infinity,
              height: 288,
            )
          : (item.imageUrl != null && item.imageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: item.imageUrl!,
                  fit: BoxFit.cover,
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

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF1F1F1F),
        border: Border(top: BorderSide(color: Color(0xFF2C2C2C), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home, 'Ana Sayfa', active: true, onTap: () => Navigator.pop(context)),
          _navItem(Icons.explore, 'Keşfet'),
          _navItem(Icons.bookmark, 'Kaydedilenler'),
          _navItem(Icons.person, 'Profil'),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, {bool active = false, VoidCallback? onTap}) {
    final color = active ? const Color(0xFF2094F3) : const Color(0xFF9E9E9E);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: active ? FontWeight.w400 : FontWeight.w500,
                height: 13 / 11,
                color: color,
              ),
            ),
          ],
        ),
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

  Future<void> _shareContent(BuildContext context) async {
    await Share.share(
      '${item.title}\n\n${item.body}',
      subject: item.title,
    );
  }
}
