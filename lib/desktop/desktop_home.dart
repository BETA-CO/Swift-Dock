import 'dart:convert';
import 'package:flutter/material.dart';
import '../server/server_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:docker_portal/desktop/tray_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:docker_portal/desktop/widgets/virtual_deck_grid.dart';
import 'package:docker_portal/desktop/services/action_executor.dart';
import 'package:docker_portal/shared/action_model.dart';
import 'package:docker_portal/desktop/services/discovery_service.dart';

class DesktopHome extends StatefulWidget {
  const DesktopHome({super.key});

  @override
  State<DesktopHome> createState() => _DesktopHomeState();
}

class _DesktopHomeState extends State<DesktopHome> with WindowListener {
  ServerService? _serverService;
  ActionExecutor? _actionExecutor;
  DiscoveryService? _discoveryService;
  String _ipAddress = 'Fetching...';
  final List<String> _logs = [];
  final TrayService _trayService = TrayService();
  bool _showLogs = false;

  // Temporary in-memory storage for configured actions
  final Map<String, DeckAction> _actionMap = {};

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // Initialize DiscoveryService
    _discoveryService = DiscoveryService(onLog: (msg) => _log(msg));
    _initServices();
  }

  Future<void> _initServices() async {
    await _trayService.initSystemTray();
    await _loadActions();

    _actionExecutor = ActionExecutor(onLog: (message) => _log(message));

    await _startServer();

    // Register service after server starts
    // We register on port 8080 as hardcoded in ServerService
    if (_serverService != null) {
      await _discoveryService?.registerService(8080);
    }
  }

  Future<void> _loadActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? actionsJson = prefs.getString('deck_actions');
      if (actionsJson != null) {
        final List<dynamic> decoded = jsonDecode(actionsJson);
        setState(() {
          for (var item in decoded) {
            final action = DeckAction.fromJson(item);
            _actionMap[action.id] = action;
          }
        });
        _log('Loaded ${_actionMap.length} actions from storage');
      }
    } catch (e) {
      _log('Error loading actions: $e');
    }
  }

  Future<void> _saveActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final actionsList = _actionMap.values.map((e) => e.toJson()).toList();
      await prefs.setString('deck_actions', jsonEncode(actionsList));
    } catch (e) {
      _log('Error saving actions: $e');
    }
  }

  void _log(String message) {
    if (mounted) {
      setState(() => _logs.add(message));
    }
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      windowManager.hide();
    }
  }

  Future<void> _startServer() async {
    _serverService = ServerService(
      onLog: (message) {
        _log(message);

        if (message.contains('New client connected')) {
          Future.delayed(
            const Duration(milliseconds: 500),
            () => _broadcastSync(),
          );
        }

        // Handle incoming commands
        if (message.startsWith('Received: ')) {
          final command = message.replaceFirst('Received: ', '').trim();
          _handleCommand(command);
        }
      },
    );

    final ip = await _serverService!.getIpAddress();
    if (mounted) {
      setState(() {
        _ipAddress = ip ?? 'Unknown';
      });
    }

    await _serverService!.startServer();
  }

  void _handleCommand(String command) {
    if (command.startsWith('ACTION_')) {
      final indexStr = command.split('_').last;
      final index = int.tryParse(indexStr);
      if (index != null) {
        // Map 1-based index from mobile to 0-based array index
        final actionKey = 'action_${index - 1}';
        final action = _actionMap[actionKey];

        if (action != null) {
          _actionExecutor?.execute(action);
        } else {
          _log('No action configured for button $index');
        }
      }
    }
  }

  void _onActionConfigured(DeckAction action) {
    setState(() {
      _actionMap[action.id] = action;
    });
    _log('Configured ${action.id}: ${action.label}');
    _saveActions();
    _broadcastSync();
  }

  void _broadcastSync() {
    final actionsList = _actionMap.values.map((e) => e.toJson()).toList();
    final jsonStr = jsonEncode({'actions': actionsList});
    _serverService?.broadcast('SYNC:$jsonStr');
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _serverService?.stopServer();
    _discoveryService?.unregisterService();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Main Content
      body: Column(
        children: [
          // Top Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Text(
                  'Device: $_ipAddress',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _showLogs ? Icons.terminal : Icons.terminal_outlined,
                  ),
                  onPressed: () => setState(() => _showLogs = !_showLogs),
                  tooltip: 'Toggle Logs',
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Stack(
              children: [
                VirtualDeckGrid(
                  actions: _actionMap,
                  onActionConfigured: _onActionConfigured,
                ),
                if (_showLogs) _buildLogsPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 200,
      child: Container(
        color: Colors.black87,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Text(
                    'Console Output',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    onPressed: () => setState(() => _showLogs = false),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.grey),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Text(
                    _logs[index],
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
