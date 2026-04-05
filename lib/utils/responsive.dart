import 'package:flutter/material.dart';

/// Responsive breakpoints - iPad ve büyük ekranlar için
class Responsive {
  /// Tablet başlangıcı (iPad mini ~768, iPad 11" ~834)
  static const double tabletBreakpoint = 600;
  static const double desktopBreakpoint = 900;

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= desktopBreakpoint;
  }

  /// Ekran genişliği
  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  /// Keşfet grid sütun sayısı: telefon 2, tablet 3-4
  static int exploreGridColumns(BuildContext context) {
    final w = width(context);
    if (w >= desktopBreakpoint) return 4;
    if (w >= tabletBreakpoint) return 3;
    return 2;
  }

  /// İçerik max genişliği - iPad'de metin çok geniş olmasın
  static double contentMaxWidth(BuildContext context) {
    return isTablet(context) ? 700 : double.infinity;
  }
}
