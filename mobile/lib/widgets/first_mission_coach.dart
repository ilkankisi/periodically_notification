import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/onboarding_service.dart';
import 'app_spotlight_layer.dart';

/// İlk açılış değer önerisinden sonra: günün kartı + zincir (2 adım).
class FirstMissionCoach {
  FirstMissionCoach._();

  /// [onFlowComplete] coach tamamen kapandıktan ve tercih kaydedildikten sonra çağrılır (Geç / son Tamam).
  static void show({
    required BuildContext context,
    required GlobalKey mainCardKey,
    required GlobalKey zincirKey,
    Future<void> Function(BuildContext context)? onFlowComplete,
  }) {
    unawaited(
      _runShow(context, mainCardKey, zincirKey, onFlowComplete),
    );
  }

  static Future<void> _runShow(
    BuildContext context,
    GlobalKey mainCardKey,
    GlobalKey zincirKey,
    Future<void> Function(BuildContext context)? onFlowComplete,
  ) async {
    const accent = Color(0xFF0095FF);
    const cardBg = Color(0xFF1C1C1E);
    const border = Color(0xFF2C2C2E);
    const muted = Color(0xFF9CA3AF);
    const totalSteps = 2;

    Widget stepCard({
      required VoidCallback onAdvance,
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
                    onPressed: onAdvance,
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

    await scrollTargetIntoView(mainCardKey);
    final step0 = Completer<void>();
    AppSpotlightLayer.show(
      context: context,
      targetKey: mainCardKey,
      holePadding: const EdgeInsets.all(12),
      holeBorderRadius: 20,
      skipTextStyle: GoogleFonts.notoSans(
        color: const Color(0xFF9CA3AF),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      captionAlignment: Alignment.topCenter,
      captionMargin: const EdgeInsets.fromLTRB(18, 48, 18, 0),
      caption: stepCard(
        onAdvance: AppSpotlightLayer.completeCaptionStep,
        step: 1,
        title: 'Günün kartını aç',
        body:
            'Aksiyonunu burada değil, sözün içinde yaz: karta dokun, aşağı kaydır ve kısa notunu kaydet.',
        buttonLabel: 'Sonraki',
      ),
      onClosed: (reason) {
        if (reason == AppSpotlightReason.skipped) {
          finishFlow();
        }
        if (!step0.isCompleted) step0.complete();
      },
    );
    await step0.future;
    AppSpotlightLayer.dismiss();

    await scrollTargetIntoView(zincirKey);
    final step1 = Completer<void>();
    AppSpotlightLayer.show(
      context: context,
      targetKey: zincirKey,
      holePadding: const EdgeInsets.all(10),
      holeBorderRadius: 999,
      skipTextStyle: GoogleFonts.notoSans(
        color: const Color(0xFF9CA3AF),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      captionAlignment: Alignment.bottomCenter,
      captionMargin: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      caption: stepCard(
        onAdvance: AppSpotlightLayer.completeCaptionStep,
        step: 2,
        title: 'Günlük zincir',
        body:
            'Serini ve ilerlemeni buradan takip et; sözü açıp yorumlara da buradan devam edebilirsin.',
        buttonLabel: 'Tamam',
      ),
      onClosed: (reason) {
        finishFlow();
        if (!step1.isCompleted) step1.complete();
      },
    );
    await step1.future;
  }
}
