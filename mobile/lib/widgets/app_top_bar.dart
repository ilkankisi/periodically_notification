import 'package:flutter/material.dart';

import '../services/notification_badge_controller.dart';

/// Uygulama genelinde kullanılan üst bar.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onChainTap;

  const AppTopBar({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.onBack,
    this.onNotificationsTap,
    this.onChainTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final badge = NotificationBadgeController.instance;
    final hasUnread = badge.unreadCount > 0;

    return AppBar(
      backgroundColor: const Color(0xFF2196F3),
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
      actions: [
        if (onChainTap != null)
          IconButton(
            tooltip: 'Aksiyon zinciri',
            icon: const Icon(Icons.link, color: Colors.white),
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
                      icon:
                          const Icon(Icons.notifications_none, color: Colors.white),
                      onPressed: onNotificationsTap,
                    ),
                    if (showBadge)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
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

