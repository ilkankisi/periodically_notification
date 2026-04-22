import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_spotlight_layer.dart';

/// Full tur: ana sayfada günün içerik kartına tek adım spotlight (aksiyon detayda).
class FullTourHomeActionCoach {
  FullTourHomeActionCoach._();

  /// [HomePage] kartı: bu adımdayken [AppSpotlightLayer.completeTargetTap] ile tur ilerletilir (diğer spotlight’lardan ayırt için).
  static bool _expectsMainCardTapCompletion = false;

  static bool get expectsMainCardTapCompletion =>
      _expectsMainCardTapCompletion && AppSpotlightLayer.isShowing;

  /// [onOpenMainHeroFromHighlight]: Kart spotlight açıkken karta dokunuldu ([AppSpotlightLayer.completeTargetTap]).
  /// [onCoachDismissedContinueTour]: «Tamam» / «Geç» ile kapanınca (kart dokunulmadan).
  static void show({
    required BuildContext context,
    required GlobalKey targetKey,
    required Future<void> Function() onOpenMainHeroFromHighlight,
    required Future<void> Function() onCoachDismissedContinueTour,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Bugün',
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
                      'Adım 5/22',
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
                'Aksiyonunu sözün içinde yaz',
                style: GoogleFonts.newsreader(
                  color: const Color(0xFFE2E2E2),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Önce günün kartına dokun; açılan sayfada aşağı kaydırıp bugün ne yaptığını kaydedebilirsin.',
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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

    _expectsMainCardTapCompletion = true;
    AppSpotlightLayer.show(
      context: ctx,
      targetKey: targetKey,
      holePadding: const EdgeInsets.all(12),
      holeBorderRadius: 20,
      skipTextStyle: GoogleFonts.notoSans(
        color: const Color(0xFF9CA3AF),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      captionAlignment: Alignment.bottomCenter,
      captionMargin: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      caption: caption,
      beforeShow: () async {
        final kc = targetKey.currentContext;
        if (kc != null) {
          await Scrollable.ensureVisible(
            kc,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            alignment: 0.35,
          );
        }
      },
      onClosed: (reason) {
        _expectsMainCardTapCompletion = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (reason == AppSpotlightReason.skipped ||
              reason == AppSpotlightReason.captionNext) {
            unawaited(onCoachDismissedContinueTour());
            return;
          }
          if (reason == AppSpotlightReason.targetTapped) {
            unawaited(onOpenMainHeroFromHighlight());
          }
        });
      },
    );
  }
}
