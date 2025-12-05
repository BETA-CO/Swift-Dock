import 'dart:convert';
import 'package:flutter/material.dart';
import '../client/client_service.dart';
import '../../shared/action_model.dart';
import 'widgets/connection_screen.dart';
import 'widgets/deck_grid.dart';
import 'package:flutter/services.dart';

class MobileHome extends StatefulWidget {
  const MobileHome({super.key});

  @override
  State<MobileHome> createState() => _MobileHomeState();
}

class _MobileHomeState extends State<MobileHome> {
  ClientService? _clientService;
  String _status = 'Disconnected';
  Map<int, DeckAction> _actions = {};

  @override
  void initState() {
    super.initState();
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
          try {
            final jsonStr = message.substring(5);
            if (jsonStr.isEmpty) return; // Prevent empty doc error

            final data = jsonDecode(jsonStr);
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
            // Don't log full sync message as it's huge
            debugPrint('Received SYNC with ${newActions.length} actions');
          } catch (e) {
            debugPrint('Error parsing sync data: $e');
          }
        } else {
          debugPrint('Message: $message');
        }
      },
    );
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
    _switchToPortrait(); // Reset on exit
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
          ? FloatingActionButton(
              mini: true,
              backgroundColor: Colors.red.withOpacity(0.5),
              onPressed: () => _clientService?.disconnect(),
              child: const Icon(Icons.close),
            )
          : null,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _status == 'Connected'
            ? DeckGrid(onCommand: _sendCommand, actions: _actions)
            : ConnectionScreen(onConnect: _connect),
      ),
    );
  }
}
