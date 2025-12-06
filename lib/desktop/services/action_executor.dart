import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:process_run/shell.dart';
import 'dart:convert';
import '../../shared/action_model.dart';

class ActionExecutor {
  final Function(String) onLog;

  ActionExecutor({required this.onLog});

  Future<void> execute(DeckAction action) async {
    onLog('Executing action: ${action.label} (${action.type})');

    try {
      switch (action.type) {
        case ActionType.openUrl:
          String urlStr = action.data;
          if (!urlStr.startsWith('http://') && !urlStr.startsWith('https://')) {
            urlStr = 'https://$urlStr';
          }
          final Uri url = Uri.parse(urlStr);
          try {
            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
              // Fallback for Windows
              if (Platform.isWindows) {
                await Process.start('start', [urlStr], runInShell: true);
              } else {
                throw 'LaunchUrl returned false';
              }
            }
          } catch (e) {
            // Second Fallback try
            if (Platform.isWindows) {
              await Process.start('start', [urlStr], runInShell: true);
            } else {
              rethrow;
            }
          }
          break;

        case ActionType.openApp:
          // Robust Windows execution:
          // 1. Try Process.run with 'start' command, which handles "Open" verb correctly for any file.
          // 2. Fallback to Shell().run().
          final executable = action.data.trim();
          onLog('Launching executable: "$executable"');

          if (Platform.isWindows) {
            try {
              // "start" command requires a title as first arg if the command is quoted.
              // Syntax: start "Title" "path/to/exe"
              // We use an empty title "".
              final args = ['""', executable];
              await Process.run('start', args, runInShell: true);
            } catch (e) {
              onLog('Process.run failed, trying shell fallback: $e');
              final shell = Shell();
              String command = executable;
              if (command.contains(' ') && !command.startsWith('"')) {
                command = '"$command"';
              }
              await shell.run(command);
            }
          } else {
            // Linux/macOS fallback
            try {
              await Process.start(
                executable,
                [],
                mode: ProcessStartMode.detached,
                runInShell: true,
              );
            } catch (e) {
              final shell = Shell();
              await shell.run(executable);
            }
          }
          break;

        case ActionType.runCommand:
          final shell = Shell();
          await shell.run(action.data);
          break;

        case ActionType.hotkey:
          // Placeholder for hotkey simulation (requires specific OS library or careful implementation)
          onLog('Hotkey execution not yet implemented: ${action.data}');
          break;

        case ActionType.toggle:
          onLog('Toggle State: ${action.data} (Logic Pending)');
          break;

        case ActionType.macro:
          onLog('Attempting to execute Macro. Data: ${action.data}');
          try {
            if (action.data.isEmpty) {
              onLog('Macro Error: Data is empty');
              break;
            }
            final List<dynamic> subActions = jsonDecode(action.data);
            onLog('Macro contains ${subActions.length} sub-actions');

            for (var i = 0; i < subActions.length; i++) {
              final subActionMap = subActions[i];
              onLog('Preparing Sub-Action $i: $subActionMap');

              final typeIndex = subActionMap['type'];
              if (typeIndex is! int ||
                  typeIndex < 0 ||
                  typeIndex >= ActionType.values.length) {
                onLog('Macro Error: Invalid sub-action type index $typeIndex');
                continue;
              }

              final subAction = DeckAction(
                id: '${action.id}_sub_$i',
                type: ActionType.values[typeIndex],
                label: 'Sub-Action $i',
                icon: action.icon,
                data: subActionMap['data'] ?? '', // Safety fallback
              );

              onLog('Executing Sub-Action $i (Type: ${subAction.type})');
              await execute(subAction);

              // Optional: Add small delay between actions if needed
              await Future.delayed(const Duration(milliseconds: 500));
            }
          } catch (e, stack) {
            onLog('Macro Exception: $e\n$stack');
          }
          break;
      }
    } catch (e) {
      onLog('Execution Error: $e');
    }
  }
}
