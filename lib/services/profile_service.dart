import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcı profil bilgisi: isim ve profil fotoğrafı yolu (cihazda).
class ProfileService {
  static const _keyDisplayName = 'profile_display_name';
  static const _keyProfileImagePath = 'profile_image_path';
  static const _profileImageFileName = 'profile_photo.jpg';

  static Future<String?> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDisplayName);
  }

  static Future<void> setDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDisplayName, name);
  }

  static Future<String?> getProfileImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyProfileImagePath);
  }

  /// Seçilen dosyayı uygulama dizinine kopyalayıp yolunu kaydeder.
  static Future<void> setProfileImageFromFile(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final destFile = File('${dir.path}/$_profileImageFileName');
    await File(sourcePath).copy(destFile.path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfileImagePath, destFile.path);
  }

  static Future<void> clearProfileImage() async {
    final path = await getProfileImagePath();
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyProfileImagePath);
  }
}
