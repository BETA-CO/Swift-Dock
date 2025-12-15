import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/action_model.dart';
import '../services/metadata_service.dart';

class VirtualDeckGrid extends StatefulWidget {
  final Map<String, DeckAction> actions;
  final Function(DeckAction) onActionConfigured;
  final Function(String) onActionRemoved;
  final int rows;
  final int columns;
  final Function(int, int) onActionReordered;

  const VirtualDeckGrid({
    super.key,
    required this.actions,
    required this.onActionConfigured,
    required this.onActionRemoved,
    this.rows = 3,
    this.columns = 5,
    required this.onActionReordered,
    this.activeIndices = const {},
  });

  final Set<int> activeIndices;

  @override
  State<VirtualDeckGrid> createState() => _VirtualDeckGridState();
}

class _VirtualDeckGridState extends State<VirtualDeckGrid> {
  final Map<int, DeckAction> _configuredActions = {};

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900),
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Text(
              "Configuration Deck",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: widget.columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0,
                ),
                itemCount: widget.rows * widget.columns,
                itemBuilder: (context, index) {
                  final actionKey = 'action_$index';
                  final action = widget.actions[actionKey];
                  return DragTarget<int>(
                    onWillAccept: (data) => data != null && data != index,
                    onAccept: (fromIndex) {
                      widget.onActionReordered(fromIndex, index);
                    },
                    builder: (context, candidateData, rejectedData) {
                      return LongPressDraggable<int>(
                        data: index,
                        hapticFeedbackOnStart: true,
                        feedback: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: 100,
                            height: 100,
                            child: _buildGridSlot(
                              index,
                              action,
                              isFeedback: true,
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _buildGridSlot(index, action),
                        ),
                        child: _buildGridSlot(index, action),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridSlot(
    int index,
    DeckAction? action, {
    bool isFeedback = false,
  }) {
    return InkWell(
      onTap: () => _showConfigurationDialog(index, action),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: (action != null)
              ? (isFeedback || widget.activeIndices.contains(index)
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.primaryContainer)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (action != null)
                ? (isFeedback || widget.activeIndices.contains(index)
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary.withOpacity(0.5))
                : Colors.white.withOpacity(0.1),
            width:
                (action != null &&
                    (isFeedback || widget.activeIndices.contains(index)))
                ? 4
                : (action != null ? 2 : 1),
          ),
          boxShadow: action != null
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(
                      alpha: widget.activeIndices.contains(index) ? 0.8 : 0.3,
                    ),
                    blurRadius: widget.activeIndices.contains(index) ? 20 : 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
          image: (action?.imageBase64 != null)
              ? DecorationImage(
                  image: MemoryImage(base64Decode(action!.imageBase64!)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: action != null && action.imageBase64 != null
            ? null // Show only image
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    action?.icon ?? Icons.add_rounded,
                    size: 36,
                    color: action != null
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Colors.white24,
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        action.label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  void _showConfigurationDialog(int index, DeckAction? existingAction) {
    // Default values
    ActionType? selectedType = existingAction?.type;
    TextEditingController dataController = TextEditingController(
      text: existingAction?.data ?? '',
    );
    TextEditingController labelController = TextEditingController(
      text: existingAction?.label ?? '',
    );
    String? pickedImageBase64 = existingAction?.imageBase64;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                existingAction == null ? 'New Action' : 'Edit Action',
                style: const TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type Selector
                    const Text(
                      'Action Type',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ActionType>(
                          value: selectedType,
                          hint: const Text(
                            "Select Action Type",
                            style: TextStyle(color: Colors.white54),
                          ),
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2C2C2C),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                          ),
                          items: ActionType.values
                              .where(
                                (type) => type != ActionType.toggle,
                              ) // Remove Toggle
                              .map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getIconForType(type),
                                        size: 18,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _getLabelForType(type),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              })
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setStateDialog(() => selectedType = value);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Content based on selection
                    if (selectedType == null) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(
                            "Please select an action type above.",
                            style: TextStyle(color: Colors.white24),
                          ),
                        ),
                      ),
                    ] else if (selectedType == ActionType.macro) ...[
                      const Text(
                        'Macro Actions',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: _buildMacroList(
                                dataController,
                                () => setStateDialog(() {}),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ElevatedButton.icon(
                                onPressed: () => _showAddMacroActionDialog(
                                  context,
                                  dataController,
                                  () => setStateDialog(() {}),
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Action'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        _getTargetLabel(selectedType!),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Hotkey Recorder or Default TextField
                      if (selectedType == ActionType.hotkey) ...[
                        HotkeyRecorder(
                          initialValue: dataController.text,
                          onRecorded: (value) {
                            dataController.text = value;
                            setStateDialog(() {});
                          },
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            "Click above and perform the key combination.",
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: dataController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: _getHintText(selectedType!),
                                  hintStyle: TextStyle(
                                    color: Colors.grey.withOpacity(0.5),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            if (selectedType == ActionType.openApp) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () async {
                                  FilePickerResult? result = await FilePicker
                                      .platform
                                      .pickFiles();
                                  if (result != null) {
                                    final path = result.files.single.path!;
                                    dataController.text = path;
                                    // Auto-suggest label
                                    if (labelController.text.isEmpty) {
                                      labelController.text =
                                          MetadataService.getAppNameFromPath(
                                            path,
                                          );
                                    }
                                    // Auto-fetch icon
                                    if (pickedImageBase64 == null) {
                                      pickedImageBase64 =
                                          await MetadataService.fetchAppIcon(
                                            path,
                                          );
                                    }
                                    setStateDialog(() {});
                                  }
                                },
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.folder_open,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                tooltip: 'Browse',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),

                    // Appearance Section (Label + Icon)
                    if (selectedType != null) ...[
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Label (Optional)',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: labelController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'My Action',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.withOpacity(0.5),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.05),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            children: [
                              const Text(
                                'Icon',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  FilePickerResult? result = await FilePicker
                                      .platform
                                      .pickFiles(type: FileType.image);
                                  if (result != null) {
                                    final bytes = File(
                                      result.files.single.path!,
                                    ).readAsBytesSync();
                                    setStateDialog(() {
                                      pickedImageBase64 = base64Encode(bytes);
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white12),
                                    image: pickedImageBase64 != null
                                        ? DecorationImage(
                                            image: MemoryImage(
                                              base64Decode(pickedImageBase64!),
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: pickedImageBase64 == null
                                      ? const Icon(
                                          Icons.add_photo_alternate,
                                          color: Colors.white54,
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (existingAction != null)
                  TextButton(
                    onPressed: () {
                      widget.onActionRemoved(existingAction.id);
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    child: const Text('Delete'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                if (selectedType != null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      if (dataController.text.isNotEmpty) {
                        // Fetch Metadata if needed
                        if ((selectedType == ActionType.openUrl) &&
                            (labelController.text.isEmpty ||
                                pickedImageBase64 == null)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Fetching metadata...'),
                              duration: Duration(milliseconds: 500),
                            ),
                          );

                          if (labelController.text.isEmpty) {
                            final title = await MetadataService.fetchPageTitle(
                              dataController.text,
                            );
                            if (title != null) labelController.text = title;
                          }
                          if (pickedImageBase64 == null) {
                            pickedImageBase64 =
                                await MetadataService.fetchFaviconBase64(
                                  dataController.text,
                                );
                          }
                        }

                        final newAction = DeckAction(
                          id: 'action_$index',
                          type: selectedType!,
                          label: labelController.text.isEmpty
                              ? 'Action'
                              : labelController.text,
                          icon: _getIconForType(selectedType!),
                          data: dataController.text,
                          imageBase64: pickedImageBase64,
                        );

                        setState(() => _configuredActions[index] = newAction);
                        widget.onActionConfigured(newAction);
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Save Action'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _getIconForType(ActionType type) {
    switch (type) {
      case ActionType.openUrl:
        return Icons.link;
      case ActionType.openApp:
        return Icons.apps;
      case ActionType.runCommand:
        return Icons.terminal;
      case ActionType.hotkey:
        return Icons.keyboard;
      case ActionType.toggle:
        return Icons.toggle_on;
      case ActionType.macro:
        return Icons.playlist_play;
    }
  }

  String _getLabelForType(ActionType type) {
    switch (type) {
      case ActionType.openUrl:
        return 'Open URL';
      case ActionType.openApp:
        return 'Open Application';
      case ActionType.runCommand:
        return 'Run Command';
      case ActionType.hotkey:
        return 'Hotkey';
      case ActionType.toggle:
        return 'Toggle';
      case ActionType.macro:
        return 'Multi-Action Macro';
    }
  }

  String _getTargetLabel(ActionType type) {
    switch (type) {
      case ActionType.openUrl:
        return 'Website URL';
      case ActionType.openApp:
        return 'Application Path';
      case ActionType.runCommand:
        return 'Terminal Command';
      case ActionType.hotkey:
        return 'Perform Hotkey';
      case ActionType.toggle:
        return 'Toggle ID';
      case ActionType.macro:
        return 'Macro Actions';
    }
  }

  String _getHintText(ActionType type) {
    switch (type) {
      case ActionType.openUrl:
        return 'https://example.com';
      case ActionType.openApp:
        return 'Select .exe or app file...';
      case ActionType.runCommand:
        return 'npm start';
      case ActionType.hotkey:
        return 'Press keys...';
      case ActionType.toggle:
        return 'my_toggle';
      case ActionType.macro:
        return '[...]';
    }
  }

  Widget _buildMacroList(
    TextEditingController dataController,
    VoidCallback onUpdate,
  ) {
    List<dynamic> actions = [];
    try {
      if (dataController.text.isNotEmpty) {
        actions = jsonDecode(dataController.text);
      }
    } catch (_) {}

    return ListView.builder(
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final actionMap = actions[index];
        final typeIndex = actionMap['type'] as int;
        final type = ActionType.values[typeIndex];
        final data = actionMap['data'] as String;

        return ListTile(
          leading: Icon(_getIconForType(type), color: Colors.white70),
          title: Text(
            _getLabelForType(type),
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            data,
            style: const TextStyle(color: Colors.white54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () {
              actions.removeAt(index);
              dataController.text = jsonEncode(actions);
              onUpdate();
            },
          ),
        );
      },
    );
  }

  void _showAddMacroActionDialog(
    BuildContext context,
    TextEditingController mainDataController,
    VoidCallback onUpdate,
  ) {
    ActionType subType = ActionType.openUrl;
    final subDataController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSubState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2C2C2C),
              title: const Text(
                'Add Sub-Action',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<ActionType>(
                    value: subType,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2C2C2C),
                    items: ActionType.values
                        .where(
                          (t) => t != ActionType.macro,
                        ) // Prevent nested macros for sanity
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              _getLabelForType(t),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSubState(() => subType = v!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: subDataController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: _getTargetLabel(subType),
                      labelStyle: const TextStyle(color: Colors.grey),
                      hintText: _getHintText(subType),
                      hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                    ),
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
                    List<dynamic> actions = [];
                    try {
                      if (mainDataController.text.isNotEmpty) {
                        actions = jsonDecode(mainDataController.text);
                      }
                    } catch (_) {}

                    actions.add({
                      'type': subType.index,
                      'data': subDataController.text,
                    });
                    mainDataController.text = jsonEncode(actions);
                    onUpdate();
                    Navigator.pop(context);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class HotkeyRecorder extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onRecorded;

  const HotkeyRecorder({
    super.key,
    required this.initialValue,
    required this.onRecorded,
  });

  @override
  State<HotkeyRecorder> createState() => _HotkeyRecorderState();
}

class _HotkeyRecorderState extends State<HotkeyRecorder> {
  late FocusNode _focusNode;
  late TextEditingController _controller;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    // Ensure handler is removed if we dispose while recording
    if (_isRecording) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    }
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    // Only rebuild if the focus state literally changes to/from recording
    final bool hasFocus = _focusNode.hasFocus;
    if (hasFocus != _isRecording) {
      setState(() {
        _isRecording = hasFocus;
      });

      if (_isRecording) {
        HardwareKeyboard.instance.addHandler(_handleKeyEvent);
      } else {
        HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
      }
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!_isRecording) return false;

    // We only care about KeyDown for recording the combination
    if (event is KeyDownEvent) {
      final keys = <String>[];
      if (HardwareKeyboard.instance.isControlPressed) keys.add('Ctrl');
      if (HardwareKeyboard.instance.isShiftPressed) keys.add('Shift');
      if (HardwareKeyboard.instance.isAltPressed) keys.add('Alt');
      if (HardwareKeyboard.instance.isMetaPressed) keys.add('Meta');

      final keyLabel = event.logicalKey.keyLabel;
      if (![
        'Control',
        'Shift',
        'Alt',
        'Meta',
        'Control Left',
        'Control Right',
        'Shift Left',
        'Shift Right',
        'Alt Left',
        'Alt Right',
        'Meta Left',
        'Meta Right',
      ].contains(keyLabel)) {
        keys.add(keyLabel);
      }

      if (keys.isNotEmpty) {
        final combo = keys.join(' + ');
        // Update local controller first
        _controller.text = combo;
        // Notify parent
        widget.onRecorded(combo);
      }
    }

    // RETURN TRUE to block ALL keys (Down, Up, Repeat) from propagating
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Request focus to start recording
        _focusNode.requestFocus();
      },
      child: Focus(
        focusNode: _focusNode,
        child: TextField(
          controller: _controller,
          enabled: false, // Visual only
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'Click to record keys...',
            hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
            filled: true,
            fillColor: _isRecording
                ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _isRecording
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
              ),
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear, size: 16),
              onPressed: () {
                _controller.clear();
                widget.onRecorded('');
                // Re-request focus to keep recording
                _focusNode.requestFocus();
              },
            ),
          ),
        ),
      ),
    );
  }
}
