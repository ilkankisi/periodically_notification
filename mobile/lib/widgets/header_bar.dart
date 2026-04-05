import 'package:flutter/material.dart';

/// Ortak üst bar - Home ve Detail sayfalarında kullanılır
/// [title] başlık metni
/// [leading] opsiyonel sol tarafta gösterilecek widget (örn. geri butonu)
/// [trailing] opsiyonel sağ tarafta gösterilecek widget (örn. share butonu)
class HeaderBar extends StatelessWidget {
  final String title;
  final Widget? leading;
  final Widget? trailing;

  const HeaderBar({
    super.key,
    this.title = 'Günün İçeriği',
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, padding.top + 12, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1F1F1F),
        border: Border(bottom: BorderSide(color: Colors.white, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leading ?? const SizedBox(width: 40, height: 40),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          trailing ?? const SizedBox(width: 40, height: 40),
        ],
      ),
    );
  }
}
