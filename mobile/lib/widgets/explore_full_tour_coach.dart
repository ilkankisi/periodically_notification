import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_spotlight_layer.dart';

/// Keşfet sayfası tanıtım spotlight’ı.
class ExploreIntroFullTourCoach {
  ExploreIntroFullTourCoach._();

  static void show({
    required BuildContext context,
    required GlobalKey headerKey,
    VoidCallback? onFinished,
  }) {
    final ctx = context;
    const accent = Color(0xFF0095FF);
    const cardBg = Color(0xFF1C1C1E);
    const border = Color(0xFF2C2C2E);
    const muted = Color(0xFF9CA3AF);

    void finish() {
      onFinished?.call();
    }

    final caption = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x60000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Keşfet',
                      style: GoogleFonts.notoSans(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0x14FFFFFF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Adım 9/22',
                      style: GoogleFonts.notoSans(
                        color: const Color(0xFFD1D5DB),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Yeni içerikler',
                style: GoogleFonts.newsreader(
                  color: const Color(0xFFE2E2E2),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Arama ve kategorilerle içerik bul; beğendiklerini kaydederek sonra Kaydedilenler’de açabilirsin.',
                style: GoogleFonts.notoSans(
                  color: muted,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: AppSpotlightLayer.completeCaptionStep,
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(
                    'Tamam',
                    style: GoogleFonts.notoSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    AppSpotlightLayer.show(
      context: ctx,
      targetKey: headerKey,
      holePadding: const EdgeInsets.all(8),
      holeBorderRadius: 12,
      skipTextStyle: GoogleFonts.notoSans(
        color: const Color(0xFF9CA3AF),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      captionAlignment: Alignment.bottomCenter,
      captionMargin: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      caption: caption,
      beforeShow: () async {
        final kc = headerKey.currentContext;
        if (kc != null) {
          await Scrollable.ensureVisible(
            kc,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            alignment: 0,
          );
        }
      },
      onClosed: (_) => finish(),
    );
  }
}

/// Keşfet kartında kaydet (yer imi) butonu spotlight’ı.
class ExploreSaveFullTourCoach {
  ExploreSaveFullTourCoach._();

  static void show({
    required BuildContext context,
    required GlobalKey bookmarkKey,
  }) {
    final ctx = context;
    const accent = Color(0xFF0095FF);
    const cardBg = Color(0xFF1C1C1E);
    const border = Color(0xFF2C2C2E);
    const muted = Color(0xFF9CA3AF);

    final caption = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x60000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Kaydet',
                      style: GoogleFonts.notoSans(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0x14FFFFFF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Adım 11/22',
                      style: GoogleFonts.notoSans(
                        color: const Color(0xFFD1D5DB),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Sonra okumak için kaydet',
                style: GoogleFonts.newsreader(
                  color: const Color(0xFFE2E2E2),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Yer imine ekle; Kaydedilenler sekmesinde bu içeriği tekrar açabileceksin.',
                style: GoogleFonts.notoSans(
                  color: muted,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: AppSpotlightLayer.completeCaptionStep,
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(
                    'Tamam',
                    style: GoogleFonts.notoSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    AppSpotlightLayer.show(
      context: ctx,
      targetKey: bookmarkKey,
      holePadding: const EdgeInsets.all(6),
      holeBorderRadius: 999,
      skipTextStyle: GoogleFonts.notoSans(
        color: const Color(0xFF9CA3AF),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      captionAlignment: Alignment.bottomCenter,
      captionMargin: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      caption: caption,
      beforeShow: () async {
        final kc = bookmarkKey.currentContext;
        if (kc != null) {
          await Scrollable.ensureVisible(
            kc,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            alignment: 0.25,
          );
        }
      },
      onClosed: (_) {},
    );
  }
}
