import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_spotlight_layer.dart';

/// Full tur: giriş ekranında platforma göre Google / Apple butonlarına spotlight.
class LoginFullTourCoach {
  LoginFullTourCoach._();

  static Future<void> _scrollTo(GlobalKey gk) async {
    final kc = gk.currentContext;
    if (kc != null) {
      await Scrollable.ensureVisible(
        kc,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    }
  }

  static Widget _infoCard({
    required String title,
    required String body,
    required String stepLabel,
  }) {
    const accent = Color(0xFF0095FF);
    const cardBg = Color(0xFF1C1C1E);
    const border = Color(0xFF2C2C2E);
    const muted = Color(0xFF9CA3AF);

    return ConstrainedBox(
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
                      'Giriş',
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
                      stepLabel,
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
                title,
                style: GoogleFonts.newsreader(
                  color: const Color(0xFFE2E2E2),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
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
  }

  static Future<void> show({
    required BuildContext context,
    required GlobalKey introTitleKey,
    required GlobalKey googleKey,
    GlobalKey? appleKey,
  }) async {
    final skipStyle = GoogleFonts.notoSans(
      color: const Color(0xFF9CA3AF),
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );

    final steps = <AppSpotlightSequenceStep>[
      AppSpotlightSequenceStep(
        targetKey: introTitleKey,
        caption: _infoCard(
          title: 'Tura hoş geldin',
          body:
              'Önce giriş yapıp turu başlatıyoruz. Sonrasında anasayfada günlük aksiyon adımına geçeceksin.',
          stepLabel: 'Adım 1/22',
        ),
        holePadding: const EdgeInsets.all(8),
        holeBorderRadius: 12,
        skipTextStyle: skipStyle,
        captionAlignment: Alignment.bottomCenter,
        captionMargin: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        beforeShow: () => _scrollTo(introTitleKey),
      ),
    ];

    if ((Platform.isIOS || Platform.isMacOS) && appleKey != null) {
      steps.add(
        AppSpotlightSequenceStep(
          targetKey: appleKey,
          caption: _infoCard(
            title: 'Apple ile devam',
            body: 'Apple hesabınla giriş yaparak günlük aksiyonunu paylaşabilirsin.',
            stepLabel: 'Adım 2/22',
          ),
          holePadding: const EdgeInsets.all(8),
          holeBorderRadius: 14,
          skipTextStyle: skipStyle,
          captionAlignment: Alignment.topCenter,
          captionMargin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          beforeShow: () => _scrollTo(appleKey),
        ),
      );
    }

    steps.add(
      AppSpotlightSequenceStep(
        targetKey: googleKey,
        caption: _infoCard(
          title: 'Google ile devam',
          body: Platform.isAndroid
              ? 'Google hesabınla giriş yap; ardından ana sayfada bugünkü aksiyonunu yazacaksın.'
              : 'İstersen Google hesabınla da giriş yapabilirsin.',
          stepLabel: Platform.isAndroid ? 'Adım 2/22' : 'Adım 3/22',
        ),
        holePadding: const EdgeInsets.all(8),
        holeBorderRadius: 14,
        skipTextStyle: skipStyle,
        captionAlignment: Alignment.topCenter,
        captionMargin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
        beforeShow: () => _scrollTo(googleKey),
      ),
    );

    await AppSpotlightLayer.showSequence(
      context: context,
      steps: steps,
    );
  }
}
