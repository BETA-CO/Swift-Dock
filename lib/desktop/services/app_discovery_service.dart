import 'dart:io';
import 'package:path/path.dart' as p;

class AppInfo {
  final String name;
  final String path;

  AppInfo({required this.name, required this.path});
}

class AppDiscoveryService {
  static Future<List<AppInfo>> getInstalledApps() async {
    final List<AppInfo> apps = [];

    try {
      if (Platform.isWindows) {
        apps.addAll(await _getWindowsApps());
      } else if (Platform.isMacOS) {
        apps.addAll(await _getMacApps());
      } else if (Platform.isLinux) {
        apps.addAll(await _getLinuxApps());
      }
    } catch (e) {
      // ignore
    }

    // Sort by name
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // De-duplicate by name (preferring typical paths if needed, but simple name check is fine for now)
    final uniqueApps = <String, AppInfo>{};
    for (var app in apps) {
      if (!uniqueApps.containsKey(app.name)) {
        uniqueApps[app.name] = app;
      }
    }

    return uniqueApps.values.toList();
  }

  static Future<List<AppInfo>> _getWindowsApps() async {
    final List<AppInfo> apps = [];
    final paths = [
      r'C:\ProgramData\Microsoft\Windows\Start Menu\Programs',
      '${Platform.environment['APPDATA']}\\Microsoft\\Windows\\Start Menu\\Programs',
    ];

    for (final path in paths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        try {
          await for (final entity in dir.list(recursive: true)) {
            if (entity is File) {
              final ext = p.extension(entity.path).toLowerCase();
              if (ext == '.lnk' || ext == '.url') {
                final name = p.basenameWithoutExtension(entity.path);
                // Filter out uninstaller/help links if possible, but keeping it simple
                if (!name.toLowerCase().contains('uninstall')) {
                  apps.add(AppInfo(name: name, path: entity.path));
                }
              }
            }
          }
        } catch (_) {}
      }
    }
    return apps;
  }

  static Future<List<AppInfo>> _getMacApps() async {
    final List<AppInfo> apps = [];
    final paths = [
      '/Applications',
      '/System/Applications',
      '${Platform.environment['HOME']}/Applications',
    ];

    for (final path in paths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        try {
          // macOS recursion can be deep, usually apps are top level or 1 level deep
          // Let's just do top level for safety and speed
          await for (final entity in dir.list(recursive: false)) {
            if (entity is Directory && entity.path.endsWith('.app')) {
              final name = p.basenameWithoutExtension(entity.path);
              apps.add(AppInfo(name: name, path: entity.path));
            }
          }
        } catch (_) {}
      }
    }
    return apps;
  }

  static Future<List<AppInfo>> _getLinuxApps() async {
    final List<AppInfo> apps = [];
    final paths = [
      '/usr/share/applications',
      '${Platform.environment['HOME']}/.local/share/applications',
    ];

    for (final path in paths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        try {
          await for (final entity in dir.list()) {
            if (entity is File && entity.path.endsWith('.desktop')) {
              // Parsing .desktop file for Name= is better, but filename is a fallback
              // Implementing simple parse
              String name = p.basenameWithoutExtension(entity.path);
              try {
                final lines = await entity.readAsLines();
                for (var line in lines) {
                  if (line.startsWith('Name=')) {
                    name = line.substring(5);
                    break;
                  }
                }
              } catch (_) {}

              apps.add(AppInfo(name: name, path: entity.path));
            }
          }
        } catch (_) {}
      }
    }
    return apps;
  }
}
