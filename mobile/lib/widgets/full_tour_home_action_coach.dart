import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Full tur: ana sayfada günün içerik kartına tek adım spotlight (aksiyon detayda).
class FullTourHomeActionCoach {
  FullTourHomeActionCoach._();

  static const Object _idAction = 'full_tour_home_action';

  /// [onOpenMainHeroFromHighlight]: Delik içine dokununca — overlay kartın üstünde
  /// olduğu için gerçek [GestureDetector] çalışmaz; aynı navigasyonu burada verin.
  /// [onCoachDismissedContinueTour]: «Tamam» / «Geç» ile kapanınca (Keşfet adımı vb.).
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

    Widget infoCard(TutorialCoachMarkController controller) {
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
                    onPressed: controller.next,
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
    }

    var openedFromHighlight = false;

    final targets = <TargetFocus>[
      TargetFocus(
        identify: _idAction,
        keyTarget: targetKey,
        shape: ShapeLightFocus.RRect,
        radius: 20,
        enableTargetTab: true,
        enableOverlayTab: false,
        paddingFocus: 12,
        borderSide: const BorderSide(color: Color(0x400095FF), width: 1.5),
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            padding: const EdgeInsets.only(top: 14),
            builder: (c, controller) => infoCard(controller),
          ),
        ],
      ),
    ];

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
      onClickTarget: (_) {
        openedFromHighlight = true;
      },
      onSkip: () {
        openedFromHighlight = false;
        unawaited(onCoachDismissedContinueTour());
        return true;
      },
      onFinish: () {
        final fromHighlight = openedFromHighlight;
        openedFromHighlight = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (fromHighlight) {
            unawaited(onOpenMainHeroFromHighlight());
          } else {
            unawaited(onCoachDismissedContinueTour());
          }
        });
      },
      beforeFocus: (target) async {
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
    ).show(context: ctx);
  }
}
