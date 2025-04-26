import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _key = 'darkMode';

  /// Returns true=dark, false=light, null=system
  static Future<bool?> getDarkModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_key)) return null;
    return prefs.getBool(_key);
  }

  /// Pass null to clear (use system), otherwise true=dark, false=light
  static Future<void> setDarkModePreference(bool? isDark) async {
    final prefs = await SharedPreferences.getInstance();
    if (isDark == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setBool(_key, isDark);
    }
  }
}
