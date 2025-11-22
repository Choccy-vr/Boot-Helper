import 'dart:io';

/// Manages deep link registration across platforms
class DeepLinkManager {
  static const String _urlScheme = 'boothelper';

  /// Set up deep links for the application
  /// [executablePath] should be the absolute path to the application executable
  static Future<bool> setupDeepLinks(String executablePath) async {
    try {
      if (Platform.isWindows) {
        return await _setupWindowsDeepLinks(executablePath);
      } else if (Platform.isMacOS) {
        return await _setupMacOSDeepLinks(executablePath);
      } else if (Platform.isLinux) {
        return await _setupLinuxDeepLinks(executablePath);
      }
      return false;
    } catch (e) {
      print('Error setting up deep links: $e');
      return false;
    }
  }

  /// Check if deep links are configured
  static Future<bool> areDeepLinksConfigured() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('reg', [
          'query',
          'HKCU\\Software\\Classes\\$_urlScheme',
        ]);
        return result.exitCode == 0;
      } else if (Platform.isMacOS) {
        // Check if Info.plist has the URL scheme
        final result = await Process.run('/usr/libexec/PlistBuddy', [
          '-c',
          'Print CFBundleURLTypes:0:CFBundleURLSchemes:0',
          'Info.plist',
        ]);
        return result.stdout.toString().trim() == _urlScheme;
      } else if (Platform.isLinux) {
        final desktopFile = File(
          '${Platform.environment['HOME']}/.local/share/applications/boot-helper.desktop',
        );
        return await desktopFile.exists();
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Remove deep link configuration
  static Future<bool> removeDeepLinks() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('reg', [
          'delete',
          'HKCU\\Software\\Classes\\$_urlScheme',
          '/f',
        ]);
        return result.exitCode == 0;
      } else if (Platform.isMacOS) {
        // Remove from Info.plist
        final result = await Process.run('/usr/libexec/PlistBuddy', [
          '-c',
          'Delete CFBundleURLTypes:0',
          'Info.plist',
        ]);
        return result.exitCode == 0;
      } else if (Platform.isLinux) {
        final desktopFile = File(
          '${Platform.environment['HOME']}/.local/share/applications/boot-helper.desktop',
        );
        if (await desktopFile.exists()) {
          await desktopFile.delete();
          // Update MIME database
          await Process.run('xdg-mime', [
            'default',
            'boot-helper.desktop',
            'x-scheme-handler/$_urlScheme',
          ]);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error removing deep links: $e');
      return false;
    }
  }

  /// Parse a deep link URL
  /// Example: boothelper://project=21
  static Map<String, String> parseDeepLink(String url) {
    final uri = Uri.parse(url);
    final params = <String, String>{};

    // Parse query parameters
    if (uri.query.isNotEmpty) {
      uri.queryParameters.forEach((key, value) {
        params[key] = value;
      });
    }

    // Parse path-based parameters (e.g., boothelper://project=21)
    if (uri.host.isNotEmpty && uri.host.contains('=')) {
      final parts = uri.host.split('=');
      if (parts.length == 2) {
        params[parts[0]] = parts[1];
      }
    }

    return params;
  }

  // Windows-specific implementation
  static Future<bool> _setupWindowsDeepLinks(String executablePath) async {
    try {
      // Create registry entries for URL protocol
      final commands = [
        [
          'add',
          'HKCU\\Software\\Classes\\$_urlScheme',
          '/ve',
          '/d',
          'URL:Boot Helper Protocol',
          '/f',
        ],
        [
          'add',
          'HKCU\\Software\\Classes\\$_urlScheme',
          '/v',
          'URL Protocol',
          '/t',
          'REG_SZ',
          '/d',
          '',
          '/f',
        ],
        [
          'add',
          'HKCU\\Software\\Classes\\$_urlScheme\\DefaultIcon',
          '/ve',
          '/d',
          '"$executablePath,1"',
          '/f',
        ],
        [
          'add',
          'HKCU\\Software\\Classes\\$_urlScheme\\shell\\open\\command',
          '/ve',
          '/d',
          '"$executablePath" "%1"',
          '/f',
        ],
      ];

      for (final cmd in commands) {
        final result = await Process.run('reg', cmd);
        if (result.exitCode != 0) {
          print('Failed to execute: reg ${cmd.join(' ')}');
          print('Error: ${result.stderr}');
          return false;
        }
      }
      return true;
    } catch (e) {
      print('Error setting up Windows deep links: $e');
      return false;
    }
  }

  // macOS-specific implementation
  static Future<bool> _setupMacOSDeepLinks(String executablePath) async {
    try {
      // Modify Info.plist to add URL scheme
      final commands = [
        ['Add', 'CFBundleURLTypes:', 'array'],
        [
          'Add',
          'CFBundleURLTypes:0:CFBundleURLName',
          'string',
          'Boot Helper URL',
        ],
        ['Add', 'CFBundleURLTypes:0:CFBundleURLSchemes:', 'array'],
        [
          'Add',
          'CFBundleURLTypes:0:CFBundleURLSchemes:0',
          'string',
          _urlScheme,
        ],
      ];

      for (final cmd in commands) {
        final result = await Process.run('/usr/libexec/PlistBuddy', [
          '-c',
          cmd.join(' '),
          'Info.plist',
        ]);
        if (result.exitCode != 0 &&
            !result.stderr.toString().contains('Entry Already Exists')) {
          print('Failed to execute: PlistBuddy ${cmd.join(' ')}');
          print('Error: ${result.stderr}');
          return false;
        }
      }
      return true;
    } catch (e) {
      print('Error setting up macOS deep links: $e');
      return false;
    }
  }

  // Linux-specific implementation
  static Future<bool> _setupLinuxDeepLinks(String executablePath) async {
    try {
      final homeDir = Platform.environment['HOME'];
      if (homeDir == null) return false;

      final desktopDir = Directory('$homeDir/.local/share/applications');
      if (!await desktopDir.exists()) {
        await desktopDir.create(recursive: true);
      }

      final desktopFile = File('${desktopDir.path}/boot-helper.desktop');
      final desktopContent =
          '''[Desktop Entry]
Version=1.0
Type=Application
Name=Boot Helper
Comment=Boot Helper Application
Exec=$executablePath %u
Icon=boot-helper
Terminal=false
MimeType=x-scheme-handler/$_urlScheme;
''';

      await desktopFile.writeAsString(desktopContent);

      // Make it executable
      await Process.run('chmod', ['+x', desktopFile.path]);

      // Register the MIME type
      final result = await Process.run('xdg-mime', [
        'default',
        'boot-helper.desktop',
        'x-scheme-handler/$_urlScheme',
      ]);

      // Update desktop database
      await Process.run('update-desktop-database', [desktopDir.path]);

      return result.exitCode == 0;
    } catch (e) {
      print('Error setting up Linux deep links: $e');
      return false;
    }
  }
}
