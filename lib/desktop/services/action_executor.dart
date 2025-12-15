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
              if (Platform.isWindows) {
                await Process.start('start', [urlStr], runInShell: true);
              } else {
                throw 'LaunchUrl returned false';
              }
            }
          } catch (e) {
            if (Platform.isWindows) {
              await Process.start('start', [urlStr], runInShell: true);
            } else {
              rethrow;
            }
          }
          break;

        case ActionType.openApp:
          final executable = action.data.trim();
          onLog('Launching executable: "$executable"');

          if (Platform.isWindows) {
            try {
              // Extract directory for "Start in"
              final workingDir = File(executable).parent.path;

              // Use Process.start with workingDirectory for better compatibility
              await Process.start(
                executable,
                [],
                workingDirectory: workingDir,
                runInShell: true,
                mode: ProcessStartMode.detached,
              );
            } catch (e) {
              onLog('Direct launch failed, trying generic start: $e');
              // Fallback: start command
              // "start" "/D" "path/to/dir" "" "exe"
              final workingDir = File(executable).parent.path;
              await Process.run('start', [
                '/D',
                workingDir,
                '""',
                executable,
              ], runInShell: true);
            }
          } else {
            // MacOS/Linux
            try {
              // MacOS apps are folders (.app), use 'open' command
              if (Platform.isMacOS && executable.endsWith('.app')) {
                await Process.run('open', [executable]);
              } else {
                final workingDir = File(executable).parent.path;
                await Process.start(
                  executable,
                  [],
                  workingDirectory: workingDir,
                  mode: ProcessStartMode.detached,
                  runInShell: true,
                );
              }
            } catch (e) {
              final shell = Shell();
              await shell.run('"$executable"');
            }
          }
          break;

        case ActionType.runCommand:
          // Force execution in C root (Windows) or Root (Mac/Linux)
          String? workingDir;
          if (Platform.isWindows) {
            workingDir = 'C:\\';
          } else {
            workingDir = '/';
          }

          onLog('Running command: "${action.data}" in $workingDir');

          final shell = Shell(workingDirectory: workingDir);
          await shell.run(action.data);
          break;

        case ActionType.hotkey:
          final keyCombo = action.data;
          onLog('Simulating Hotkey: $keyCombo');

          if (Platform.isWindows) {
            // PowerShell SendKeys Wrapper
            String sendKeysStr = _convertToWindowsSendKeys(keyCombo);

            onLog('Sending formatted keys: "$sendKeysStr"');

            final psScript =
                '''
\$wshell = New-Object -ComObject WScript.Shell
\$wshell.SendKeys("$sendKeysStr")
''';
            await Process.run('powershell', ['-c', psScript]);
          } else if (Platform.isMacOS) {
            if (keyCombo.startsWith('tell')) {
              await Process.run('osascript', ['-e', keyCombo]);
            } else {
              // Basic implementation for Mac - still simple for now
              // Constructing "command down", "shift down" etc. requires parsing.
              // For now, we will try to parse basic modifiers to AppleScript "using {command down, ...}"
              // Example input: "Cmd + Shift + C"

              final parts = keyCombo.split(' + ');
              final modifiers = <String>[];
              String? key;

              for (final part in parts) {
                switch (part.toLowerCase()) {
                  case 'ctrl':
                  case 'control':
                    modifiers.add('control down');
                    break;
                  case 'alt':
                  case 'option':
                    modifiers.add('option down');
                    break;
                  case 'shift':
                    modifiers.add('shift down');
                    break;
                  case 'meta':
                  case 'cmd':
                  case 'command':
                  case 'win':
                    modifiers.add('command down');
                    break;
                  default:
                    if (!part.contains('Left') && !part.contains('Right')) {
                      key = part;
                    }
                }
              }

              if (key != null) {
                // AppleScript key code or keystroke
                // For special keys (F1, Enter) we need 'key code'. For chars, 'keystroke'.
                // Simple heuristic:
                if (key.length == 1) {
                  String script =
                      'tell application "System Events" to keystroke "$key"';
                  if (modifiers.isNotEmpty) {
                    script += ' using {${modifiers.join(", ")}}';
                  }
                  await Process.run('osascript', ['-e', script]);
                } else {
                  // Map special keys to key codes if needed, or ignored for now.
                  // Enter=36, Space=49, etc.
                  // Fallback to keystroke for now
                  String script =
                      'tell application "System Events" to keystroke "$key"';
                  if (modifiers.isNotEmpty) {
                    script += ' using {${modifiers.join(", ")}}';
                  }
                  await Process.run('osascript', ['-e', script]);
                }
              }
            }
          }
          break;

        case ActionType.toggle:
          onLog('Executing Toggle Action: ${action.data}');
          if (action.data.isNotEmpty) {
            final shell = Shell();
            await shell.run(action.data);
          }
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
                data: subActionMap['data'] ?? '',
              );

              onLog('Executing Sub-Action $i (Type: ${subAction.type})');
              await execute(subAction);

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

  String _convertToWindowsSendKeys(String keyCombo) {
    // Split by " + "
    final parts = keyCombo.split(' + ');
    final buffer = StringBuffer();

    // Modifiers
    bool hasCtrl = parts.contains('Ctrl') || parts.contains('Control');
    bool hasAlt = parts.contains('Alt');
    bool hasShift = parts.contains('Shift');

    if (hasCtrl) buffer.write('^');
    if (hasAlt) buffer.write('%');
    if (hasShift) buffer.write('+');

    // The Key
    // Filter out modifiers from parts to find the actual key
    final nonModifiers = parts.where((p) {
      final lp = p.toLowerCase();
      return ![
        'ctrl',
        'control',
        'alt',
        'shift',
        'meta',
        'win',
        'control left',
        'control right',
        'shift left',
        'shift right',
        'alt left',
        'alt right',
        'meta left',
        'meta right',
      ].contains(lp);
    }).toList();

    if (nonModifiers.isNotEmpty) {
      String key = nonModifiers.last; // Assume last one is the key

      // Map Special Keys
      switch (key.toUpperCase()) {
        case 'BACKSPACE':
          buffer.write('{BS}');
          break;
        case 'DELETE':
          buffer.write('{DEL}');
          break;
        case 'ENTER':
          buffer.write('{ENTER}');
          break;
        case 'TAB':
          buffer.write('{TAB}');
          break;
        case 'ESCAPE':
          buffer.write('{ESC}');
          break;
        case 'ARROW UP':
        case 'UP':
          buffer.write('{UP}');
          break;
        case 'ARROW DOWN':
        case 'DOWN':
          buffer.write('{DOWN}');
          break;
        case 'ARROW LEFT':
        case 'LEFT':
          buffer.write('{LEFT}');
          break;
        case 'ARROW RIGHT':
        case 'RIGHT':
          buffer.write('{RIGHT}');
          break;
        case 'F1':
          buffer.write('{F1}');
          break;
        case 'F2':
          buffer.write('{F2}');
          break;
        case 'F3':
          buffer.write('{F3}');
          break;
        case 'F4':
          buffer.write('{F4}');
          break;
        case 'F5':
          buffer.write('{F5}');
          break;
        case 'F6':
          buffer.write('{F6}');
          break;
        case 'F7':
          buffer.write('{F7}');
          break;
        case 'F8':
          buffer.write('{F8}');
          break;
        case 'F9':
          buffer.write('{F9}');
          break;
        case 'F10':
          buffer.write('{F10}');
          break;
        case 'F11':
          buffer.write('{F11}');
          break;
        case 'F12':
          buffer.write('{F12}');
          break;
        case 'SPACE':
          buffer.write(' ');
          break;
        default:
          if (key.length == 1) {
            // For characters like +, ^, %, ~, they must be braced
            if ([
              '+',
              '^',
              '%',
              '~',
              '(',
              ')',
              '{',
              '}',
              '[',
              ']',
            ].contains(key)) {
              buffer.write('{$key}');
            } else {
              buffer.write(key.toLowerCase());
            }
          } else {
            // Fallback for unknown
            // Maybe remove F-keys spaces? "F 1" -> "F1"
            key = key.replaceAll(' ', '');
            if (key.startsWith('F') && key.length > 1) {
              buffer.write('{$key}');
            } else {
              // generic
              buffer.write(key);
            }
          }
      }
    }
    return buffer.toString();
  }
}
