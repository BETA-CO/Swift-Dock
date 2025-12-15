import 'dart:convert';
import 'package:flutter/material.dart';
import '../server/server_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:docker_portal/desktop/tray_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
  bool _isConnected = false;
  final List<String> _logs = [];
  final TrayService _trayService = TrayService();
  bool _showLogs = false; // Kept internal for potential debug use
  Set<int> _activeIndices = {};

  // Profiles State
  List<DeckProfile> _profiles = [
    DeckProfile(id: 'default', name: 'Default Profile', actions: {}),
  ];
  String _currentProfileId = 'default';

  DeckProfile get _currentProfile => _profiles.firstWhere(
    (p) => p.id == _currentProfileId,
    orElse: () => _profiles.first,
  );

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
      final String? dataJson = prefs.getString('deck_data_v2');

      if (dataJson != null) {
        // Load v2 Data
        final Map<String, dynamic> data = jsonDecode(dataJson);
        _currentProfileId = data['currentProfileId'];
        _profiles = (data['profiles'] as List)
            .map((e) => DeckProfile.fromJson(e))
            .toList();
      } else {
        // Check for v1 data (legacy)
        final String? oldActionsJson = prefs.getString('deck_actions');
        if (oldActionsJson != null) {
          final List<dynamic> decoded = jsonDecode(oldActionsJson);
          final Map<String, DeckAction> actions = {};
          for (var item in decoded) {
            final action = DeckAction.fromJson(item);
            actions[action.id] = action;
          }
          // Create default profile with migrated actions
          _profiles = [
            DeckProfile(
              id: 'default',
              name: 'Default Profile',
              actions: actions,
            ),
          ];
          _currentProfileId = 'default';
          _log('Migrated legacy actions to Default Profile');
          _saveActions(); // Save in new format immediately
        } else {
          // No data found, initialize fresh
          _profiles = [
            DeckProfile(id: 'default', name: 'Default Profile', actions: {}),
          ];
          _currentProfileId = 'default';
        }
      }
      setState(() {});
      _log('Loaded ${_profiles.length} profiles. Active: $_currentProfileId');
    } catch (e) {
      _log('Error loading actions: $e');
      // Fallback
      _profiles = [
        DeckProfile(id: 'default', name: 'Default Profile', actions: {}),
      ];
    }

    if (_profiles.isEmpty) {
      _profiles = [
        DeckProfile(id: 'default', name: 'Default Profile', actions: {}),
      ];
      _currentProfileId = 'default';
    }
  }

  Future<void> _saveActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'currentProfileId': _currentProfileId,
        'profiles': _profiles.map((e) => e.toJson()).toList(),
      };
      await prefs.setString('deck_data_v2', jsonEncode(data));
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
          setState(() => _isConnected = true);
          Future.delayed(
            const Duration(milliseconds: 500),
            () => _broadcastSync(),
          );
        } else if (message.contains('Client disconnected')) {
          setState(() => _isConnected = false);
        }
      },
      onMessage: (message) {
        // Handle incoming commands directly from the message stream
        final command = message.trim();
        _handleCommand(command);
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
    if (command.startsWith('ACTION:')) {
      final actionId = command.split(':').last;

      // Visual Feedback
      // Only match direct action IDs, not sub-actions or other formats
      final match = RegExp(r'^action_(\d+)$').firstMatch(actionId);
      if (match != null) {
        final index = int.parse(match.group(1)!);
        setState(() {
          _activeIndices.add(index);
        });
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              _activeIndices.remove(index);
            });
          }
        });
      }

      final action = _currentProfile.actions[actionId];
      if (action != null) {
        _log('Executing ${action.label} (${action.type})');
        _actionExecutor?.execute(action);
      } else {
        _log('No action configured for $actionId in ${_currentProfile.name}');
      }
    } else if (command.startsWith('SWITCH_PROFILE:')) {
      final profileId = command.split(':').last;
      final profile = _profiles.firstWhere(
        (p) => p.id == profileId,
        orElse: () => _currentProfile,
      );

      if (profile.id != _currentProfileId) {
        setState(() => _currentProfileId = profile.id);
        _log('Mobile switched to profile: ${profile.name}');
        _broadcastSync();
      }
    }
  }

  void _onActionConfigured(DeckAction action) {
    setState(() {
      _currentProfile.actions[action.id] = action;
    });
    _log('Configured ${action.id}: ${action.label} in ${_currentProfile.name}');
    _saveActions();
    _broadcastSync();
  }

  void _onActionRemoved(String actionId) {
    setState(() {
      _currentProfile.actions.remove(actionId);
    });
    _log('Removed action $actionId from ${_currentProfile.name}');
    _saveActions();
    _broadcastSync();
  }

  void _broadcastSync() {
    final actionsList = _currentProfile.actions.values
        .map((e) => e.toJson())
        .toList();
    final profilesList = _profiles
        .map((p) => {'id': p.id, 'name': p.name})
        .toList();

    final jsonStr = jsonEncode({
      'currentProfileId': _currentProfile.id,
      'profiles': profilesList,
      'actions': actionsList,
    });
    _serverService?.broadcast('SYNC:$jsonStr');
  }

  void _onActionReordered(int oldIndex, int newIndex) {
    setState(() {
      final oldKey = 'action_$oldIndex';
      final newKey = 'action_$newIndex';
      final action = _currentProfile.actions[oldKey];

      if (action != null) {
        // If there's an action at the new index, swap them
        if (_currentProfile.actions.containsKey(newKey)) {
          final targetAction = _currentProfile.actions[newKey]!;
          _currentProfile.actions[oldKey] = targetAction.copyWith(id: oldKey);
        } else {
          _currentProfile.actions.remove(oldKey);
        }
        _currentProfile.actions[newKey] = action.copyWith(id: newKey);
      }
    });
    _saveActions();
    _broadcastSync();
  }

  void _createProfile() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('New Profile'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Profile Name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  final newProfile = DeckProfile(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: controller.text,
                    actions: {},
                  );
                  setState(() {
                    _profiles.add(newProfile);
                    _currentProfileId = newProfile.id;
                  });
                  _saveActions();
                  _broadcastSync();
                  Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showProfileSettings() {
    final nameController = TextEditingController(text: _currentProfile.name);
    int rows = _currentProfile.rows;
    int cols = _currentProfile.columns;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Profile Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Profile Name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Grid Size:'),
                      const SizedBox(width: 16),
                      DropdownButton<int>(
                        value: rows,
                        items: [3, 4, 5]
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text('$e Rows'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setStateDialog(() => rows = v!),
                      ),
                      const SizedBox(width: 8),
                      const Text('x'),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: cols,
                        items: [3, 4, 5, 6]
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text('$e Cols'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setStateDialog(() => cols = v!),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      // Update profile directly (creating a new instance to force rebuild if needed, though mutable change works too)
                      final index = _profiles.indexWhere(
                        (p) => p.id == _currentProfileId,
                      );
                      if (index != -1) {
                        _profiles[index] = DeckProfile(
                          id: _profiles[index].id,
                          name: nameController.text,
                          rows: rows,
                          columns: cols,
                          actions: _profiles[index].actions, // existing actions
                        );
                      }
                    });
                    _saveActions();
                    _broadcastSync();
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteProfile(DeckProfile profile) {
    if (_profiles.length <= 1) return; // Prevent deleting last profile

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${profile.name}?'),
        content: const Text(
          'Are you sure you want to delete this profile? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _profiles.removeWhere((p) => p.id == profile.id);
                if (_currentProfileId == profile.id) {
                  _currentProfileId = _profiles.first.id;
                }
              });
              _saveActions();
              _broadcastSync();
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
      body: Stack(
        children: [
          Column(
            children: [
              // Top Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // IP Address Badge or Connected Status
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: _isConnected
                          ? Container(
                              key: const ValueKey('connected'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.2),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Client Connected',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              key: const ValueKey('ip'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.wifi,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  SelectableText(
                                    'Server IP: $_ipAddress',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),

                    const Spacer(),

                    // Profile Selector with better styling
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _currentProfileId,
                          icon: const Icon(Icons.arrow_drop_down_rounded),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          borderRadius: BorderRadius.circular(12),
                          items: _profiles.map((profile) {
                            return DropdownMenuItem(
                              value: profile.id,
                              child: Text(profile.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _currentProfileId = value);
                              _broadcastSync();
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Action Buttons
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add),
                      tooltip: 'Create New Profile',
                      onPressed: _createProfile,
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.settings),
                      tooltip: 'Profile Grid Settings',
                      onPressed: _showProfileSettings,
                    ),
                    if (_profiles.length > 1) ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.1),
                          foregroundColor: Colors.redAccent,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete Current Profile',
                        onPressed: () => _deleteProfile(_currentProfile),
                      ),
                    ],
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Stack(
                  children: [
                    VirtualDeckGrid(
                      key: ValueKey(
                        _currentProfileId,
                      ), // Force rebuild when profile changes
                      actions: _currentProfile.actions,
                      rows: _currentProfile.rows,
                      columns: _currentProfile.columns,
                      activeIndices: _activeIndices,
                      onActionConfigured: _onActionConfigured,
                      onActionRemoved: _onActionRemoved,
                      onActionReordered: _onActionReordered,
                    ),
                    if (_showLogs) _buildLogsPanel(),
                  ],
                ),
              ),
            ],
          ),

          // QR Code Overlay
          IgnorePointer(
            ignoring: _isConnected,
            child: AnimatedOpacity(
              opacity: _isConnected ? 0.0 : 1.0,
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              child: Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: jsonEncode({"ip": _ipAddress, "port": 8080}),
                          version: QrVersions.auto,
                          size: 250.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        "Scan to Connect",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Open the mobile app and scan this QR code",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 48),
                      // Manual IP fallback (still visible but secondary)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SelectableText(
                          'Finding via Discovery or Manual IP: $_ipAddress',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsPanel() {
    return const SizedBox.shrink();
  }
}
