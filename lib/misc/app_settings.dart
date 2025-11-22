import 'package:shared_preferences/shared_preferences.dart';

/// Manages application settings persistence
class AppSettings {
  static const String _keyQemuPath = 'qemu_path';
  static const String _keyIsoDownloadDir = 'iso_download_directory';
  static const String _keyDeepLinksConfigured = 'deeplinks_configured';

  /// Get QEMU executable path
  static Future<String?> getQemuPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyQemuPath);
  }

  /// Set QEMU executable path
  static Future<bool> setQemuPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_keyQemuPath, path);
  }

  /// Get ISO download directory
  static Future<String?> getIsoDownloadDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyIsoDownloadDir);
  }

  /// Set ISO download directory
  static Future<bool> setIsoDownloadDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_keyIsoDownloadDir, path);
  }

  /// Check if deep links are configured
  static Future<bool> areDeepLinksConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDeepLinksConfigured) ?? false;
  }

  /// Mark deep links as configured
  static Future<bool> setDeepLinksConfigured(bool configured) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(_keyDeepLinksConfigured, configured);
  }

  /// Check if app is fully configured (QEMU path, ISO dir, deep links)
  static Future<bool> isAppConfigured() async {
    final qemuPath = await getQemuPath();
    final isoDir = await getIsoDownloadDirectory();
    final deepLinks = await areDeepLinksConfigured();

    return qemuPath != null &&
        qemuPath.isNotEmpty &&
        isoDir != null &&
        isoDir.isNotEmpty &&
        deepLinks;
  }

  /// Clear all settings
  static Future<bool> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.clear();
  }
}
