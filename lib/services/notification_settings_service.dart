import 'package:shared_preferences/shared_preferences.dart';

/// Bildirim ayarları - tercih edilen saat (0-23).
/// Sunucu tarafında (Cloud Functions) bu değer kullanılabilir.
class NotificationSettingsService {
  static const _keyPreferredHour = 'notification_preferred_hour';

  /// Tercih edilen bildirim saati (0-23). Varsayılan: 9 (sabah 09:00)
  static Future<int> getPreferredHour() async {
    final prefs = await SharedPreferences.getInstance();
    final h = prefs.getInt(_keyPreferredHour);
    return h ?? 9;
  }

  static Future<void> setPreferredHour(int hour) async {
    final h = hour.clamp(0, 23);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPreferredHour, h);
  }
}
