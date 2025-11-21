import 'dart:io';
import '../misc/logger.dart';

class DeepLinkManager {
  static const String _urlScheme = 'boothelper';

  // Setup deep links for the current platform
  Future<bool> setupDeepLinks(String executablePath) async {
    try {
      if (Platform.isWindows) {
        return await _setupWindowsDeepLinks(executablePath);
      } else if (Platform.isMacOS) {
        return await _setupMacOSDeepLinks(executablePath);
      } else if (Platform.isLinux) {
        return await _setupLinuxDeepLinks(executablePath);
      } else {
        AppLogger.warning('Deep links not supported on this platform');
        return false;
      }
    } catch (e) {
      AppLogger.error('Failed to setup deep links: $e');
      return false;
    }
  }

  // Check if deep links are already configured
  Future<bool> areDeepLinksConfigured() async {
    try {
      if (Platform.isWindows) {
        return await _checkWindowsDeepLinks();
      } else if (Platform.isMacOS) {
        return await _checkMacOSDeepLinks();
      } else if (Platform.isLinux) {
        return await _checkLinuxDeepLinks();
      }
      return false;
    } catch (e) {
      AppLogger.error('Failed to check deep links: $e');
      return false;
    }
  }

  // Remove deep links configuration
  Future<bool> removeDeepLinks() async {
    try {
      if (Platform.isWindows) {
        return await _removeWindowsDeepLinks();
      } else if (Platform.isMacOS) {
        return await _removeMacOSDeepLinks();
      } else if (Platform.isLinux) {
        return await _removeLinuxDeepLinks();
      }
      return false;
    } catch (e) {
      AppLogger.error('Failed to remove deep links: $e');
      return false;
    }
  }

  // Windows implementation using registry
  Future<bool> _setupWindowsDeepLinks(String executablePath) async {
    try {
      AppLogger.info('Setting up Windows deep links...');

      // Escape backslashes for registry
      String escapedPath = executablePath.replaceAll('\\', '\\\\');

      // Create registry entries
      List<String> commands = [
        'reg add "HKCU\\Software\\Classes\\$_urlScheme" /ve /d "URL:Boot Helper Protocol" /f',
        'reg add "HKCU\\Software\\Classes\\$_urlScheme" /v "URL Protocol" /d "" /f',
        'reg add "HKCU\\Software\\Classes\\$_urlScheme\\DefaultIcon" /ve /d "\\"$escapedPath\\",0" /f',
        'reg add "HKCU\\Software\\Classes\\$_urlScheme\\shell\\open\\command" /ve /d "\\"$escapedPath\\" \\"%1\\"" /f',
      ];

      for (String command in commands) {
        ProcessResult result = await Process.run('cmd', [
          '/c',
          command,
        ], runInShell: true);

        if (result.exitCode != 0) {
          AppLogger.error('Failed to run: $command');
          AppLogger.error('Error: ${result.stderr}');
          return false;
        }
      }

      AppLogger.info('Windows deep links configured successfully');
      return true;
    } catch (e) {
      AppLogger.error('Error setting up Windows deep links: $e');
      return false;
    }
  }

  Future<bool> _checkWindowsDeepLinks() async {
    try {
      ProcessResult result = await Process.run('reg', [
        'query',
        'HKCU\\Software\\Classes\\$_urlScheme',
      ], runInShell: true);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _removeWindowsDeepLinks() async {
    try {
      AppLogger.info('Removing Windows deep links...');
      ProcessResult result = await Process.run('reg', [
        'delete',
        'HKCU\\Software\\Classes\\$_urlScheme',
        '/f',
      ], runInShell: true);
      return result.exitCode == 0;
    } catch (e) {
      AppLogger.error('Error removing Windows deep links: $e');
      return false;
    }
  }

  // macOS implementation using .app bundle
  Future<bool> _setupMacOSDeepLinks(String executablePath) async {
    try {
      AppLogger.info('Setting up macOS deep links...');

      // Find the .app bundle (go up from executable to Contents/MacOS/)
      String appPath = executablePath;
      if (appPath.contains('Contents/MacOS')) {
        appPath = appPath.split('Contents/MacOS')[0];
      }

      // Create/update Info.plist with URL scheme
      String infoPlistPath = '${appPath}Contents/Info.plist';
      File infoPlist = File(infoPlistPath);

      if (!await infoPlist.exists()) {
        AppLogger.warning('Info.plist not found at: $infoPlistPath');
        return false;
      }

      // Use PlistBuddy to add URL scheme
      List<String> commands = [
        '/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$infoPlistPath" 2>/dev/null || true',
        '/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$infoPlistPath" 2>/dev/null || true',
        '/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLName string boot-helper" "$infoPlistPath" 2>/dev/null || true',
        '/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$infoPlistPath" 2>/dev/null || true',
        '/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $_urlScheme" "$infoPlistPath" 2>/dev/null || true',
      ];

      for (String command in commands) {
        await Process.run('sh', ['-c', command]);
      }

      // Register the app with Launch Services
      await Process.run('sh', [
        '-c',
        '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$appPath"',
      ]);

      AppLogger.info('macOS deep links configured successfully');
      return true;
    } catch (e) {
      AppLogger.error('Error setting up macOS deep links: $e');
      return false;
    }
  }

  Future<bool> _checkMacOSDeepLinks() async {
    try {
      ProcessResult result = await Process.run('sh', [
        '-c',
        '/usr/bin/open -Ra "$_urlScheme:" 2>/dev/null',
      ]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _removeMacOSDeepLinks() async {
    // Removing from macOS requires editing the Info.plist
    // This is complex and may require app reinstall
    AppLogger.info(
      'To remove macOS deep links, rebuild the app or manually edit Info.plist',
    );
    return false;
  }

  // Linux implementation using .desktop file
  Future<bool> _setupLinuxDeepLinks(String executablePath) async {
    try {
      AppLogger.info('Setting up Linux deep links...');

      // Get user home directory
      String? home = Platform.environment['HOME'];
      if (home == null) {
        AppLogger.error('Could not determine HOME directory');
        return false;
      }

      // Create .desktop file in ~/.local/share/applications/
      String applicationsDir = '$home/.local/share/applications';
      await Directory(applicationsDir).create(recursive: true);

      String desktopFilePath = '$applicationsDir/boot-helper.desktop';

      String desktopFileContent =
          '''[Desktop Entry]
Version=1.0
Type=Application
Name=Boot Helper
Exec=$executablePath %u
Icon=boot-helper
Terminal=false
Categories=Development;
MimeType=x-scheme-handler/$_urlScheme;
''';

      await File(desktopFilePath).writeAsString(desktopFileContent);

      // Register the MIME type handler
      await Process.run('xdg-mime', [
        'default',
        'boot-helper.desktop',
        'x-scheme-handler/$_urlScheme',
      ]);

      // Update desktop database
      await Process.run('update-desktop-database', [applicationsDir]);

      AppLogger.info('Linux deep links configured successfully');
      return true;
    } catch (e) {
      AppLogger.error('Error setting up Linux deep links: $e');
      return false;
    }
  }

  Future<bool> _checkLinuxDeepLinks() async {
    try {
      String? home = Platform.environment['HOME'];
      if (home == null) return false;

      File desktopFile = File(
        '$home/.local/share/applications/boot-helper.desktop',
      );
      return await desktopFile.exists();
    } catch (e) {
      return false;
    }
  }

  Future<bool> _removeLinuxDeepLinks() async {
    try {
      AppLogger.info('Removing Linux deep links...');

      String? home = Platform.environment['HOME'];
      if (home == null) return false;

      String desktopFilePath =
          '$home/.local/share/applications/boot-helper.desktop';
      File desktopFile = File(desktopFilePath);

      if (await desktopFile.exists()) {
        await desktopFile.delete();
        AppLogger.info('Linux deep links removed');
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Error removing Linux deep links: $e');
      return false;
    }
  }

  // Parse deep link URL
  Map<String, String>? parseDeepLink(String url) {
    try {
      if (!url.startsWith('$_urlScheme://')) {
        return null;
      }

      Uri uri = Uri.parse(url);
      Map<String, String> params = {};

      // Parse query parameters
      uri.queryParameters.forEach((key, value) {
        params[key] = value;
      });

      // Also parse path segments as key=value pairs
      if (uri.path.isNotEmpty) {
        String path = uri.path.replaceFirst('/', '');
        for (String segment in path.split('&')) {
          if (segment.contains('=')) {
            List<String> parts = segment.split('=');
            if (parts.length == 2) {
              params[parts[0]] = parts[1];
            }
          }
        }
      }

      return params;
    } catch (e) {
      AppLogger.error('Error parsing deep link: $e');
      return null;
    }
  }
}
