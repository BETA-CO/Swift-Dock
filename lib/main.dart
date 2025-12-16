import 'dart:io';
import 'package:flutter/material.dart';
import 'desktop/desktop_home.dart';
import 'mobile/mobile_home.dart';
import 'shared/theme.dart';

import 'package:window_manager/window_manager.dart';

import 'package:flutter/services.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop Setup
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1000, 700),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    // System Tray is handled by TrayService in DesktopHome

    // Handle Window Close -> Minimize to Tray
    await windowManager.setPreventClose(true);

    bool isAutostart = args.contains('--autostart');

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (!isAutostart) {
        await windowManager.show();
        await windowManager.focus();
      }
    });
  }
  // Mobile Setup
  else {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // Minimize to tray instead of closing
    await windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swift Dock',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkTheme,
      home: const PlatformWrapper(),
    );
  }
}

class PlatformWrapper extends StatelessWidget {
  const PlatformWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return const DesktopHome();
    } else {
      return const MobileHome();
    }
  }
}
