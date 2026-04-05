import 'package:shared_preferences/shared_preferences.dart';

/// İlk açılış değer önerisi (App Store 4.2 — ürünün ne olduğu).
class OnboardingService {
  OnboardingService._();

  static const _key = 'value_prop_onboarding_v1_done';

  static Future<bool> isCompleted() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_key) ?? false;
  }

  static Future<void> markCompleted() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, true);
  }
}
