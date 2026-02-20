import 'package:flutter/material.dart';

/// Ortak alt navigasyon bar - Home ve Detail sayfalarında kullanılır
/// [activeIndex] aktif tab (0: Ana Sayfa, 1: Keşfet, 2: Kaydedilenler, 3: Profil)
/// [onTabTap] Herhangi bir tab tıklandığında (index 0..3). Ana sayfa/Keşfet geçişi için kullanılır.
/// [onHomeTap] Ana Sayfa tıklandığında (Detail sayfasında geri dönüş için). onTabTap yoksa kullanılır.
class BottomNavBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int>? onTabTap;
  final VoidCallback? onHomeTap;

  const BottomNavBar({
    super.key,
    this.activeIndex = 0,
    this.onTabTap,
    this.onHomeTap,
  });

  static const _navItems = [
    (icon: Icons.home, label: 'Ana Sayfa'),
    (icon: Icons.explore, label: 'Keşfet'),
    (icon: Icons.bookmark, label: 'Kaydedilenler'),
    (icon: Icons.person, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
      decoration: const BoxDecoration(
        color: Color(0xFF1F1F1F),
        border: Border(top: BorderSide(color: Color(0xFF2C2C2C), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < _navItems.length; i++)
                _NavItem(
                  icon: _navItems[i].icon,
                  label: _navItems[i].label,
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
          const SizedBox(height: 8),
          Container(
            width: 128,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
        ],
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
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF2196F3) : const Color(0xFF9CA3AF);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
