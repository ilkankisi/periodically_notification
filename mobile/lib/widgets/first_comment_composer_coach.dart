import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_spotlight_layer.dart';

/// Onboarding: içerik detayında yorum alanına tek adım spotlight.
class FirstCommentComposerCoach {
  FirstCommentComposerCoach._();

  static void show({
    required BuildContext context,
    required GlobalKey composerAreaKey,
    Future<void> Function()? onFlowFinished,
  }) {
    final ctx = context;
    const accent = Color(0xFF0095FF);
    const cardBg = Color(0xFF1C1C1E);
    const border = Color(0xFF2C2C2E);
    const muted = Color(0xFF9CA3AF);

    void finishFlow() {
      final next = onFlowFinished;
      if (next != null) {
        unawaited(next());
      }
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
                      'Yorum',
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
                'Düşünceni yaz',
                style: GoogleFonts.newsreader(
                  color: const Color(0xFFE2E2E2),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Yorumların sosyal puanına eklenir. İlk paylaşımından sonra puan özetini göstereceğiz.',
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
      targetKey: composerAreaKey,
      holePadding: const EdgeInsets.all(8),
      holeBorderRadius: 26,
      skipTextStyle: GoogleFonts.notoSans(
        color: const Color(0xFF9CA3AF),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      captionAlignment: Alignment.topCenter,
      captionMargin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      caption: caption,
      beforeShow: () async {
        final kc = composerAreaKey.currentContext;
        if (kc != null) {
          await Scrollable.ensureVisible(
            kc,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            alignment: 0.85,
          );
        }
      },
      onClosed: (_) => finishFlow(),
    );
  }
}
