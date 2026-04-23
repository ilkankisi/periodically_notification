import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ortak alt navigasyon — Figma: ANA SAYFA, KEŞFET (pusula), KAYDEDİLENLER, PROFİL.
/// [activeIndex]: 0 Ana sayfa, 1 Keşfet, 2 Kaydedilenler, 3 Profil
class BottomNavBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int>? onTabTap;
  final VoidCallback? onHomeTap;
  final List<GlobalKey?>? itemKeys;

  const BottomNavBar({
    super.key,
    this.activeIndex = 0,
    this.onTabTap,
    this.onHomeTap,
    this.itemKeys,
  });

  static const List<IconData> _iconsIdle = [
    Icons.home_outlined,
    Icons.explore_outlined,
    Icons.bookmark_outline,
    Icons.person_outline,
  ];

  static const List<IconData> _iconsActive = [
    Icons.home_rounded,
    Icons.explore_rounded,
    Icons.bookmark_rounded,
    Icons.person_rounded,
  ];

  static const List<String> _labels = [
    'ANA SAYFA',
    'KEŞFET',
    'KAYDEDİLENLER',
    'PROFİL',
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Material(
      color: const Color(0xFF121212),
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 10, 12, bottomPadding + 8),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0x18FFFFFF), width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < _labels.length; i++)
              _NavItem(
                key: itemKeys != null && i < itemKeys!.length
                    ? itemKeys![i]
                    : null,
                icon: activeIndex == i ? _iconsActive[i] : _iconsIdle[i],
                label: _labels[i],
                active: activeIndex == i,
                onTap: () {
                  if (onTabTap != null) {
                    onTabTap!(i);
                  } else if (i == 0 && onHomeTap != null) {
                    onHomeTap!();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF0095FF) : const Color(0xFF9CA3AF);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSans(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.35,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
