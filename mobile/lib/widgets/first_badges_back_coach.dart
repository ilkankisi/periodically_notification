import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_spotlight_layer.dart';

/// İlk görev akışında [BadgesPage] (firstLaunchPreview) açıldığında sol üst geri için tek adımlı spotlight.
class FirstBadgesBackCoach {
  FirstBadgesBackCoach._();

  static void show({
    required BuildContext context,
    required GlobalKey backButtonKey,
  }) {
    final badgesContext = context;

    const accent = Color(0xFF0095FF);
    const cardBg = Color(0xFF1C1C1E);
    const border = Color(0xFF2C2C2E);
    const muted = Color(0xFF9CA3AF);

    final caption = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
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
                      'İlk görev',
                      style: GoogleFonts.notoSans(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Buradan çık',
                style: GoogleFonts.newsreader(
                  color: const Color(0xFFE2E2E2),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Listeyi inceledikten sonra devam etmek için sol üstteki geri okuna bas — ana sayfaya döndüğünde Profil sekmesi seçilir.',
                style: GoogleFonts.notoSans(
                  color: muted,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    AppSpotlightLayer.show(
      context: badgesContext,
      targetKey: backButtonKey,
      caption: caption,
      holePadding: const EdgeInsets.all(8),
      holeBorderRadius: 12,
      captionAlignment: Alignment.bottomCenter,
      captionMargin: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      skipTextStyle: GoogleFonts.notoSans(
        color: const Color(0xFF9CA3AF),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      onHoleTap: () {
        if (badgesContext.mounted) {
          Navigator.of(badgesContext).pop();
        }
      },
      onClosed: (reason) {
        if (reason == AppSpotlightReason.skipped && badgesContext.mounted) {
          Navigator.of(badgesContext).pop();
        }
      },
    );
  }
}
