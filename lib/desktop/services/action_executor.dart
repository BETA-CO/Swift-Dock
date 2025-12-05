import 'package:url_launcher/url_launcher.dart';
import 'package:process_run/shell.dart';
import '../../server/server_service.dart';
import '../../shared/action_model.dart';

class ActionExecutor {
  final Function(String) onLog;

  ActionExecutor({required this.onLog});

  Future<void> execute(DeckAction action) async {
    onLog('Executing action: ${action.label} (${action.type})');

    try {
      switch (action.type) {
        case ActionType.openUrl:
          final Uri url = Uri.parse(action.data);
          if (!await launchUrl(url)) {
            throw 'Could not launch $url';
          }
          break;

        case ActionType.openApp:
        case ActionType.runCommand:
          final shell = Shell();
          await shell.run(action.data);
          break;

        case ActionType.hotkey:
          // Placeholder for hotkey simulation (requires specific OS library or careful implementation)
          onLog('Hotkey execution not yet implemented: ${action.data}');
          break;
      }
    } catch (e) {
      onLog('Execution Error: $e');
    }
  }
}
