import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Full tur: giriş ekranında platforma göre Google / Apple butonlarına spotlight.
class LoginFullTourCoach {
  LoginFullTourCoach._();

  static const Object _idIntro = 'login_intro';
  static const Object _idGoogle = 'login_google';
  static const Object _idApple = 'login_apple';

  static void show({
    required BuildContext context,
    required GlobalKey introTitleKey,
    required GlobalKey googleKey,
    GlobalKey? appleKey,
  }) {
    final ctx = context;
    const accent = Color(0xFF0095FF);
    const cardBg = Color(0xFF1C1C1E);
    const border = Color(0xFF2C2C2E);
    const muted = Color(0xFF9CA3AF);

    Widget infoCard(
      TutorialCoachMarkController controller, {
      required String title,
      required String body,
      required String stepLabel,
    }) {
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
                    onPressed: controller.next,
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

    final targets = <TargetFocus>[];

    targets.add(
      TargetFocus(
        identify: _idIntro,
        keyTarget: introTitleKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        enableTargetTab: false,
        enableOverlayTab: false,
        paddingFocus: 8,
        borderSide: const BorderSide(color: Color(0x400095FF), width: 1.5),
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            padding: const EdgeInsets.only(top: 14),
            builder: (c, controller) => infoCard(
              controller,
              title: 'Tura hoş geldin',
              body: 'Önce giriş yapıp turu başlatıyoruz. Sonrasında anasayfada günlük aksiyon adımına geçeceksin.',
              stepLabel: 'Adım 4/22',
            ),
          ),
        ],
      ),
    );

    if (Platform.isIOS || Platform.isMacOS) {
      if (appleKey != null) {
        targets.add(
          TargetFocus(
            identify: _idApple,
            keyTarget: appleKey,
            shape: ShapeLightFocus.RRect,
            radius: 14,
            enableTargetTab: false,
            enableOverlayTab: false,
            paddingFocus: 8,
            borderSide: const BorderSide(color: Color(0x400095FF), width: 1.5),
            contents: [
              TargetContent(
                align: ContentAlign.top,
                padding: const EdgeInsets.only(bottom: 14),
                builder: (c, controller) => infoCard(
                  controller,
                  title: 'Apple ile devam',
                  body: 'Apple hesabınla giriş yaparak günlük aksiyonunu paylaşabilirsin.',
                  stepLabel: 'Adım 4/22',
                ),
              ),
            ],
          ),
        );
      }
    }

    targets.add(
      TargetFocus(
        identify: _idGoogle,
        keyTarget: googleKey,
        shape: ShapeLightFocus.RRect,
        radius: 14,
        enableTargetTab: false,
        enableOverlayTab: false,
        paddingFocus: 8,
        borderSide: const BorderSide(color: Color(0x400095FF), width: 1.5),
        contents: [
          TargetContent(
            align: ContentAlign.top,
            padding: const EdgeInsets.only(bottom: 14),
            builder: (c, controller) => infoCard(
              controller,
              title: 'Google ile devam',
              body: Platform.isAndroid
                  ? 'Google hesabınla giriş yap; ardından ana sayfada bugünkü aksiyonunu yazacaksın.'
                  : 'İstersen Google hesabınla da giriş yapabilirsin.',
              stepLabel: Platform.isAndroid ? 'Adım 4/22' : 'Adım 4/22',
            ),
          ),
        ],
      ),
    );

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.78,
      paddingFocus: 10,
      pulseEnable: false,
      alignSkip: Alignment.topRight,
      textSkip: 'Geç',
      textStyleSkip: GoogleFonts.notoSans(
        color: const Color(0xFF9CA3AF),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      showSkipInLastTarget: true,
      onSkip: () => true,
      beforeFocus: (target) async {
        GlobalKey gk = googleKey;
        if (target.identify == _idIntro) {
          gk = introTitleKey;
        } else if (target.identify == _idApple) {
          final ak = appleKey;
          if (ak != null) gk = ak;
        }
        final kc = gk.currentContext;
        if (kc != null) {
          await Scrollable.ensureVisible(
            kc,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            alignment: 0.5,
          );
        }
      },
    ).show(context: ctx);
  }
}
