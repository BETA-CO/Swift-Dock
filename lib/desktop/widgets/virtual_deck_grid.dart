import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../shared/action_model.dart';
import '../services/metadata_service.dart';

class VirtualDeckGrid extends StatefulWidget {
  final Map<String, DeckAction> actions;
  final Function(DeckAction) onActionConfigured;

  const VirtualDeckGrid({
    super.key,
    required this.actions,
    required this.onActionConfigured,
  });

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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0,
                ),
                itemCount: 15,
                itemBuilder: (context, index) {
                  final actionKey = 'action_$index';
                  final action = widget.actions[actionKey];
                  return _buildGridSlot(index, action);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridSlot(int index, DeckAction? action) {
    return InkWell(
      onTap: () => _showConfigurationDialog(index, action),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: action != null
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: action != null
                ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
            width: action != null ? 2 : 1,
          ),
          boxShadow: action != null
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 12,
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
    ActionType selectedType = existingAction?.type ?? ActionType.openUrl;
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
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2C2C2C),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                          ),
                          items: ActionType.values.map((type) {
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
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setStateDialog(() => selectedType = value);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Dynamic Data Field
                    Text(
                      _getTargetLabel(selectedType),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dataController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: _getHintText(selectedType),
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
                                      MetadataService.getAppNameFromPath(path);
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
                    const SizedBox(height: 20),

                    // Appearance Section (Label + Icon)
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
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
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
                      // Fetch Metadata if needed (Loading State)
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
                        type: selectedType,
                        label: labelController.text.isEmpty
                            ? 'Action'
                            : labelController.text,
                        icon: _getIconForType(selectedType),
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
        return 'Key Combination';
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
        return 'Ctrl + C';
    }
  }
}
