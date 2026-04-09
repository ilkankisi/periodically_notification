import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/notification_badge_controller.dart';

/// Uygulama genelinde kullanılan üst bar (koyu tema, editorial başlık).
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onChainTap;

  /// Örn. Zincir hub: yarı saydam bar + başlık 24px / #E2E2E2 (Figma TopAppBar).
  final Color? backgroundColor;
  final bool hubTitleStyle;

  const AppTopBar({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.onBack,
    this.onNotificationsTap,
    this.onChainTap,
    this.backgroundColor,
    this.hubTitleStyle = false,
  });

  static const Color _bg = Color(0xFF131313);
  static const Color _accent = Color(0xFFA1C9FF);
  static const Color _iconMuted = Color(0xFFBFC7D5);

  /// Alt kabuktaki sayfalar ve özel üst çubuklar için ortalanmış başlık tipografisi (Newsreader).
  static TextStyle centeredTitleStyle({Color color = Colors.white}) => GoogleFonts.newsreader(
        color: color,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.2,
      );

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final badge = NotificationBadgeController.instance;

    return AppBar(
      backgroundColor: backgroundColor ?? _bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _accent, size: 20),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
      title: Text(
        title,
        style: hubTitleStyle
            ? GoogleFonts.newsreader(
                color: const Color(0xFFE2E2E2),
                fontSize: 24,
                fontWeight: FontWeight.w600,
                height: 32 / 24,
                letterSpacing: -0.6,
              )
            : centeredTitleStyle(),
      ),
      actions: [
        if (onChainTap != null)
          IconButton(
            tooltip: 'Aksiyon zinciri',
            icon: const Icon(Icons.link_rounded, color: _iconMuted, size: 22),
            onPressed: onChainTap,
          ),
        if (onNotificationsTap != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
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
                      icon: const Icon(Icons.notifications_none_rounded, color: _iconMuted, size: 24),
                      onPressed: onNotificationsTap,
                    ),
                    if (showBadge)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE53935),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              count > 9 ? '9+' : count.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
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
    );
  }
}
