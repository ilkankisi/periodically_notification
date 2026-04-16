import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../services/onboarding_service.dart';

/// İlk açılış değer önerisinden sonra: günlük aksiyon + zincir (2 adım).
/// Tur bitince faz günlük aksiyona geçer; rozet önizlemesi zincirin sonunda açılır.
class FirstMissionCoach {
  FirstMissionCoach._();

  static const Object _idAction = 'daily_action';
  static const Object _idChain = 'chain';

  /// [onFlowComplete] coach tamamen kapandıktan ve tercih kaydedildikten sonra çağrılır (Geç / son Tamam).
  static void show({
    required BuildContext context,
    required GlobalKey actionKey,
    required GlobalKey zincirKey,
    Future<void> Function(BuildContext context)? onFlowComplete,
  }) {
    const accent = Color(0xFF0095FF);
    const cardBg = Color(0xFF1C1C1E);
    const border = Color(0xFF2C2C2E);
    const muted = Color(0xFF9CA3AF);
    const totalSteps = 2;

    Widget stepCard({
      required TutorialCoachMarkController controller,
      required int step,
      required String title,
      required String body,
      required String buttonLabel,
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
                        'İlk görev • $step/$totalSteps',
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
                      buttonLabel,
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

    final targets = <TargetFocus>[
      TargetFocus(
        identify: _idAction,
        keyTarget: actionKey,
        shape: ShapeLightFocus.RRect,
        radius: 20,
        enableTargetTab: false,
        enableOverlayTab: false,
        paddingFocus: 12,
        borderSide: const BorderSide(color: Color(0x400095FF), width: 1.5),
        contents: [
          TargetContent(
            align: ContentAlign.top,
            padding: const EdgeInsets.only(bottom: 14),
            builder: (ctx, controller) {
              return stepCard(
                controller: controller,
                step: 1,
                title: 'Bugün ne yaptığını yaz',
                body:
                    'Motivasyon tek başına yetmez — kısa bir not bırak. İstersen sonra düzenlersin; önemli olan günlük ritmi başlatmak.',
                buttonLabel: 'Sonraki',
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: _idChain,
        keyTarget: zincirKey,
        shape: ShapeLightFocus.RRect,
        radius: 999,
        enableTargetTab: false,
        enableOverlayTab: false,
        paddingFocus: 10,
        borderSide: const BorderSide(color: Color(0x400095FF), width: 1.5),
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            padding: const EdgeInsets.only(top: 14),
            builder: (ctx, controller) {
              return stepCard(
                controller: controller,
                step: 2,
                title: 'Günlük zincir',
                body:
                    'Serini ve ilerlemeni buradan takip et. Sonraki adımda günün içeriği kartına dokunarak topluluğa katılacaksın.',
                buttonLabel: 'Tamam',
              );
            },
          ),
        ],
      ),
    ];

    Future<void> scrollTargetIntoView(GlobalKey key) async {
      final ctx = key.currentContext;
      if (ctx == null) return;
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        alignment: 0.35,
      );
    }

    void finishFlow() {
      OnboardingService.markFirstMissionCoachCompleted();
      final next = onFlowComplete;
      if (next != null) {
        unawaited(next(context));
      }
    }

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
      showSkipInLastTarget: false,
      onSkip: () {
        finishFlow();
        return true;
      },
      onFinish: finishFlow,
      beforeFocus: (target) async {
        if (target.identify == _idAction) {
          await scrollTargetIntoView(actionKey);
        } else if (target.identify == _idChain) {
          await scrollTargetIntoView(zincirKey);
        }
      },
    ).show(context: context);
  }
}
