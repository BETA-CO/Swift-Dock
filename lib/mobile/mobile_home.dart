import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nsd/nsd.dart';
import '../client/client_service.dart';
import '../../shared/action_model.dart';
import 'widgets/connection_screen.dart';
import 'widgets/deck_grid.dart';
import 'package:flutter/services.dart';
import 'package:docker_portal/mobile/services/mobile_discovery_service.dart';

class MobileHome extends StatefulWidget {
  const MobileHome({super.key});

  @override
  State<MobileHome> createState() => _MobileHomeState();
}

class _MobileHomeState extends State<MobileHome> {
  ClientService? _clientService;
  MobileDiscoveryService? _discoveryService;
  String _status = 'Disconnected';
  Map<int, DeckAction> _actions = {};
  List<Service> _discoveredServices = [];

  // Profile State
  String _currentProfileId = 'default';
  List<Map<String, String>> _availableProfiles = [];

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  void _initServices() {
    // Client Service
    _clientService = ClientService(
      onLog: (log) {
        if (log.startsWith('Connected')) {
          if (mounted) {
            setState(() => _status = 'Connected');
            _switchToLandscape();
          }
        } else if (log.startsWith('Disconnected') || log.startsWith('Error')) {
          if (mounted) {
            setState(() => _status = 'Disconnected');
            _switchToPortrait();
          }
        }
        debugPrint('Client Log: $log');
      },
      onMessage: (message) {
        if (message.startsWith('SYNC:')) {
          _handleSync(message);
        } else {
          debugPrint('Message: $message');
        }
      },
    );

    // Discovery Service
    _discoveryService = MobileDiscoveryService(
      onLog: (log) => debugPrint('Discovery: $log'),
    );
    _discoveryService!.servicesStream.listen((services) {
      if (mounted) {
        setState(() => _discoveredServices = services);
      }
    });
    _discoveryService!.startDiscovery();
  }

  void _handleSync(String message) {
    try {
      final jsonStr = message.substring(5);
      if (jsonStr.isEmpty) return;

      final data = jsonDecode(jsonStr);

      // 1. Update Profiles List
      if (data.containsKey('profiles')) {
        _availableProfiles = (data['profiles'] as List).map((e) {
          return {'id': e['id'].toString(), 'name': e['name'].toString()};
        }).toList();
      }

      // 2. Update Current Profile ID
      if (data.containsKey('currentProfileId')) {
        _currentProfileId = data['currentProfileId'];
      }

      // 3. Update Actions
      if (data.containsKey('actions')) {
        final List<dynamic> list = data['actions'];
        final Map<int, DeckAction> newActions = {};
        for (var item in list) {
          final action = DeckAction.fromJson(item);
          final indexStr = action.id.split('_').last;
          final index = int.tryParse(indexStr);
          if (index != null) {
            newActions[index] = action;
          }
        }
        if (mounted) {
          setState(() => _actions = newActions);
        }
        debugPrint('Received SYNC with ${newActions.length} actions');
      }
    } catch (e) {
      debugPrint('Error parsing sync data: $e');
    }
  }

  void _switchProfile(String profileId) {
    _sendCommand('SWITCH_PROFILE:$profileId');
    // Optimistic update
    setState(() => _currentProfileId = profileId);
  }

  Future<void> _switchToLandscape() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _switchToPortrait() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _clientService?.disconnect();
    _discoveryService?.stopDiscovery();
    _switchToPortrait();
    super.dispose();
  }

  void _connect(String ip) {
    _clientService?.connect(ip.trim());
  }

  void _sendCommand(String command) {
    _clientService?.sendCommand(command);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Only show AppBar when disconnected to save space in "Deck Mode"
      appBar: _status == 'Connected'
          ? null
          : AppBar(
              title: const Text('Stream Deck Remote'),
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
            ),
      floatingActionButton: _status == 'Connected'
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Profile Selector FAB
                PopupMenuButton<String>(
                  initialValue: _currentProfileId,
                  onSelected: _switchProfile,
                  itemBuilder: (context) {
                    return _availableProfiles.map((p) {
                      return PopupMenuItem(
                        value: p['id'],
                        child: Text(p['name']!),
                      );
                    }).toList();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.layers),
                  ),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.red.withValues(alpha: 0.5),
                  onPressed: () => _clientService?.disconnect(),
                  child: const Icon(Icons.close),
                ),
              ],
            )
          : null,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _status == 'Connected'
            ? DeckGrid(onCommand: _sendCommand, actions: _actions)
            : ConnectionScreen(
                onConnect: _connect,
                discoveredServices: _discoveredServices,
              ),
      ),
    );
  }
}
