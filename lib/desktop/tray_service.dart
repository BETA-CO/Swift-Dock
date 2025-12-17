import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart';

class TrayService {
  final SystemTray _systemTray = SystemTray();
  final AppWindow _appWindow = AppWindow();

  Future<void> initSystemTray({required VoidCallback onExit}) async {
    String iconPath = Platform.isWindows
        ? 'assets/app_icon.ico'
        : 'assets/app_icon.png';

    // We can use a default system icon if assets aren't set up yet,
    // but system_tray usually requires a real file path for custom icons.
    // For now, let's try to assume they have an icon or use a placeholder if possible.
    // NOTE: If this path doesn't exist, it might fail or show blank.
    // SystemTray package often requires the icon to be bundled in the assets.

    try {
      await _systemTray.initSystemTray(
        title: "Stream Deck Server",
        iconPath: iconPath,
      );
    } catch (e) {
      debugPrint('System Tray Init Error: $e');
    }

    final Menu menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(label: 'Show', onClicked: (menuItem) => _appWindow.show()),
      MenuItemLabel(
        label: 'Exit',
        onClicked: (menuItem) {
          onExit();
        },
      ),
    ]);

    await _systemTray.setContextMenu(menu);

    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        Platform.isWindows ? _appWindow.show() : _systemTray.popUpContextMenu();
      } else if (eventName == kSystemTrayEventRightClick) {
        Platform.isWindows ? _systemTray.popUpContextMenu() : _appWindow.show();
      }
    });
  }
}
