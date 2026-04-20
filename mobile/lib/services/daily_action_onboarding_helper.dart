import 'package:flutter/material.dart';

import '../screens/badges_page.dart';
import 'content_sync_service.dart';
import 'onboarding_service.dart';

/// Günlük aksiyon kaydı (içerik detayı vb.) sonrası tam tur / v1 faz güncellemesi.
class DailyActionOnboardingHelper {
  DailyActionOnboardingHelper._();

  static Future<void> afterDailyActionSaved(BuildContext context) async {
    await OnboardingService.ensureFullTourMigrated();
    final ftp = await OnboardingService.getGlobalTourStep();
    if (ftp == OnboardingService.ftNeedHomeAction) {
      await ContentSyncService.syncFromBackend();
      if (!context.mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const BadgesPage(firstLaunchPreview: false),
        ),
      );
      if (!context.mounted) return;
      await OnboardingService.setGlobalTourStep(
        OnboardingService.ftExploreIntro,
      );
      OnboardingService.requestTab(1);
      return;
    }
    final phaseBefore = await OnboardingService.getOnboardingV1Phase();
    if (phaseBefore == OnboardingService.v1NeedDailyAction) {
      await OnboardingService.setOnboardingV1Phase(
        OnboardingService.v1NeedMainCardCoach,
      );
    }
    await ContentSyncService.syncFromBackend();
  }
}
