import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/action_model.dart';
import '../services/metadata_service.dart';
import '../services/app_discovery_service.dart';
import '../../shared/theme.dart';
import '../../shared/widgets.dart';

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
                    onWillAcceptWithDetails: (details) => details.data != index,
                    onAcceptWithDetails: (details) {
                      widget.onActionReordered(details.data, index);
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
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (action != null)
                ? (isFeedback || widget.activeIndices.contains(index)
                      ? Colors.white
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.5))
                : Colors.white.withValues(alpha: 0.1),
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
            return Dialog(
              backgroundColor: Colors.transparent,
              child: GlassContainer(
                color: AppTheme.surface,
                opacity: 0.9,
                borderRadius: BorderRadius.circular(24),
                padding: const EdgeInsets.all(0),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Text(
                              existingAction == null
                                  ? 'New Action'
                                  : 'Edit Action',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white54,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Colors.white10),

                      // Content
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Type Selector
                              const Text(
                                'Action Type',
                                style: TextStyle(
                                  color: AppTheme.neonCyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<ActionType>(
                                    value: selectedType,
                                    hint: const Text(
                                      "Select Action Type",
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                    isExpanded: true,
                                    dropdownColor: AppTheme.surface,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: AppTheme.accent,
                                    ),
                                    items: ActionType.values
                                        .where(
                                          (type) => type != ActionType.toggle,
                                        )
                                        .map((type) {
                                          return DropdownMenuItem(
                                            value: type,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  _getIconForType(type),
                                                  size: 18,
                                                  color: AppTheme.neonCyan,
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
                                        setStateDialog(
                                          () => selectedType = value,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Dynamic Content
                              if (selectedType == null) ...[
                                Container(
                                  height: 150,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.02),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white10,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.touch_app,
                                        color: Colors.white24,
                                        size: 48,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        "Select an action type to configure",
                                        style: TextStyle(color: Colors.white24),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (selectedType == ActionType.macro) ...[
                                const Text(
                                  'Macro Actions',
                                  style: TextStyle(
                                    color: AppTheme.neonCyan,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 250,
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white10,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: _buildMacroList(
                                          dataController,
                                          () => setStateDialog(() {}),
                                        ),
                                      ),
                                      const Divider(
                                        height: 1,
                                        color: Colors.white10,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: TextButton.icon(
                                            onPressed: () =>
                                                _showAddMacroActionDialog(
                                                  context,
                                                  dataController,
                                                  () => setStateDialog(() {}),
                                                ),
                                            icon: const Icon(
                                              Icons.add,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Add Step to Macro',
                                            ),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  AppTheme.textPrimary,
                                              backgroundColor: Colors.white
                                                  .withValues(alpha: 0.05),
                                              padding: const EdgeInsets.all(16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  _getTargetLabel(selectedType!).toUpperCase(),
                                  style: const TextStyle(
                                    color: AppTheme.neonCyan,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                if (selectedType == ActionType.hotkey) ...[
                                  HotkeyRecorder(
                                    initialValue: dataController.text,
                                    onRecorded: (value) {
                                      dataController.text = value;
                                      setStateDialog(() {});
                                    },
                                  ),
                                ] else ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: dataController,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: _getHintText(
                                              selectedType!,
                                            ),
                                            hintStyle: TextStyle(
                                              color: Colors.grey.withValues(
                                                alpha: 0.5,
                                              ),
                                            ),
                                            filled: true,
                                            fillColor: Colors.black26,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: Colors.white.withValues(
                                                  alpha: 0.1,
                                                ),
                                              ),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 16,
                                                ),
                                          ),
                                        ),
                                      ),
                                      if (selectedType ==
                                          ActionType.openApp) ...[
                                        const SizedBox(width: 12),
                                        Tooltip(
                                          message: 'Browse Applications',
                                          child: InkWell(
                                            onTap: () => _showAppSelector(
                                              context,
                                              dataController,
                                              labelController,
                                              (base64) => setStateDialog(() {
                                                pickedImageBase64 = base64;
                                              }),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppTheme.primary
                                                        .withValues(alpha: 0.4),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.apps,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],

                              if (selectedType != null) ...[
                                const SizedBox(height: 32),
                                const Text(
                                  'APPEARANCE',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Label',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: labelController,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'My Action',
                                              hintStyle: TextStyle(
                                                color: Colors.grey.withValues(
                                                  alpha: 0.5,
                                                ),
                                              ),
                                              filled: true,
                                              fillColor: Colors.black26,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide.none,
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.1),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Column(
                                      children: [
                                        const Text(
                                          'Icon',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: () async {
                                            FilePickerResult? result =
                                                await FilePicker.platform
                                                    .pickFiles(
                                                      type: FileType.image,
                                                    );
                                            if (result != null) {
                                              final bytes = File(
                                                result.files.single.path!,
                                              ).readAsBytesSync();
                                              setStateDialog(() {
                                                pickedImageBase64 =
                                                    base64Encode(bytes);
                                              });
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Container(
                                            width: 80,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              color: Colors.black26,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors.white12,
                                              ),
                                              image: pickedImageBase64 != null
                                                  ? DecorationImage(
                                                      image: MemoryImage(
                                                        base64Decode(
                                                          pickedImageBase64!,
                                                        ),
                                                      ),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : null,
                                              boxShadow:
                                                  pickedImageBase64 != null
                                                  ? [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                        blurRadius: 10,
                                                        offset: const Offset(
                                                          0,
                                                          5,
                                                        ),
                                                      ),
                                                    ]
                                                  : [],
                                            ),
                                            child: pickedImageBase64 == null
                                                ? const Icon(
                                                    Icons.add_photo_alternate,
                                                    color: Colors.white24,
                                                    size: 32,
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
                      ),

                      const Divider(height: 1, color: Colors.white10),

                      // Actions Footer
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (existingAction != null)
                              TextButton.icon(
                                onPressed: () {
                                  widget.onActionRemoved(existingAction.id);
                                  Navigator.pop(context);
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                label: const Text('Delete'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.accent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 16),
                            if (selectedType != null)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 8,
                                  shadowColor: AppTheme.primary.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                onPressed: () async {
                                  if (dataController.text.isNotEmpty) {
                                    // Fetch Metadata logic (simplified for brevity, logic remains)
                                    if ((selectedType == ActionType.openUrl) &&
                                        (labelController.text.isEmpty ||
                                            pickedImageBase64 == null)) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Fetching metadata...'),
                                          duration: Duration(milliseconds: 500),
                                          backgroundColor:
                                              AppTheme.surfaceLight,
                                        ),
                                      );
                                      if (labelController.text.isEmpty) {
                                        final title =
                                            await MetadataService.fetchPageTitle(
                                              dataController.text,
                                            );
                                        if (context.mounted && title != null) {
                                          labelController.text = title;
                                        }
                                      }
                                      pickedImageBase64 ??=
                                          await MetadataService.fetchFaviconBase64(
                                            dataController.text,
                                          );
                                    }

                                    if (!context.mounted) return;

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

                                    setState(
                                      () =>
                                          _configuredActions[index] = newAction,
                                    );
                                    widget.onActionConfigured(newAction);
                                    Navigator.pop(context);
                                  }
                                },
                                child: const Text(
                                  'Save Action',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAppSelector(
    BuildContext context,
    TextEditingController pathController,
    TextEditingController labelController,
    Function(String?) onIconPicked,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: GlassContainer(
                color: AppTheme.surface,
                opacity: 0.9,
                borderRadius: BorderRadius.circular(24),
                padding: const EdgeInsets.all(0),
                child: Container(
                  width: 500,
                  height: 600,
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Text(
                              'Select Application',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white54,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Colors.white10),

                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                        child: TextField(
                          onChanged: (value) =>
                              setStateDialog(() => searchQuery = value),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search installed apps...',
                            hintStyle: TextStyle(
                              color: Colors.grey.withValues(alpha: 0.5),
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.white54,
                            ),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // App List
                      Expanded(
                        child: FutureBuilder<List<AppInfo>>(
                          future: AppDiscoveryService.getInstalledApps(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Error: ${snapshot.error}',
                                  style: const TextStyle(
                                    color: AppTheme.accent,
                                  ),
                                ),
                              );
                            }

                            final apps = snapshot.data ?? [];
                            final filteredApps = apps.where((app) {
                              return app.name.toLowerCase().contains(
                                searchQuery.toLowerCase(),
                              );
                            }).toList();

                            if (filteredApps.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.app_blocking_outlined,
                                      size: 48,
                                      color: Colors.white24,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No apps found.',
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        // Generic Picker
                                        FilePickerResult? result =
                                            await FilePicker.platform
                                                .pickFiles();
                                        if (result != null) {
                                          final path =
                                              result.files.single.path!;
                                          pathController.text = path;
                                          if (labelController.text.isEmpty) {
                                            labelController.text =
                                                MetadataService.getAppNameFromPath(
                                                  path,
                                                );
                                          }
                                          final icon =
                                              await MetadataService.fetchAppIcon(
                                                path,
                                              );
                                          if (icon != null) {
                                            onIconPicked(icon);
                                          }
                                        }
                                      },
                                      child: const Text('Browse Manually'),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: filteredApps.length,
                              separatorBuilder: (c, i) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final app = filteredApps[index];
                                return ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  tileColor: Colors.white.withValues(
                                    alpha: 0.05,
                                  ),
                                  hoverColor: Colors.white.withValues(
                                    alpha: 0.1,
                                  ),
                                  title: Text(
                                    app.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    app.path,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.apps,
                                      color: AppTheme.primary,
                                      size: 20,
                                    ),
                                  ),
                                  onTap: () async {
                                    pathController.text = app.path;
                                    if (labelController.text.isEmpty) {
                                      labelController.text = app.name;
                                    }
                                    final icon =
                                        await MetadataService.fetchAppIcon(
                                          app.path,
                                        );
                                    if (icon != null) {
                                      onIconPicked(icon);
                                    }
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),

                      const Divider(height: 1, color: Colors.white10),

                      // Footer
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                FilePickerResult? result = await FilePicker
                                    .platform
                                    .pickFiles();
                                if (result != null) {
                                  final path = result.files.single.path!;
                                  pathController.text = path;
                                  if (labelController.text.isEmpty) {
                                    labelController.text =
                                        MetadataService.getAppNameFromPath(
                                          path,
                                        );
                                  }
                                  final icon =
                                      await MetadataService.fetchAppIcon(path);
                                  if (icon != null) {
                                    onIconPicked(icon);
                                  }
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                              ),
                              child: const Text('Browse File System...'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddMacroActionDialog(
    BuildContext context,
    TextEditingController parentDataController,
    VoidCallback onUpdate,
  ) {
    ActionType selectedType = ActionType.hotkey;
    TextEditingController subDataController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: GlassContainer(
                color: AppTheme.surface,
                opacity: 0.95,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Add Macro Step',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<ActionType>(
                              value: selectedType,
                              dropdownColor: AppTheme.surface,
                              isExpanded: true,
                              items: ActionType.values
                                  .where(
                                    (t) =>
                                        t != ActionType.macro &&
                                        t != ActionType.toggle,
                                  )
                                  .map((type) {
                                    return DropdownMenuItem(
                                      value: type,
                                      child: Row(
                                        children: [
                                          Icon(
                                            _getIconForType(type),
                                            size: 18,
                                            color: AppTheme.neonCyan,
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
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            if (selectedType == ActionType.hotkey)
                              HotkeyRecorder(
                                initialValue: subDataController.text,
                                onRecorded: (value) {
                                  subDataController.text = value;
                                  setStateDialog(() {});
                                },
                              )
                            else if (selectedType == ActionType.openApp)
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: subDataController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: _getTargetLabel(
                                          selectedType,
                                        ),
                                        labelStyle: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                        filled: true,
                                        fillColor: Colors.black26,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Tooltip(
                                    message: 'Browse Applications',
                                    child: InkWell(
                                      onTap: () {
                                        final dummyLabel =
                                            TextEditingController();
                                        _showAppSelector(
                                          context,
                                          subDataController,
                                          dummyLabel,
                                          (_) {
                                            // Icon ignore for macro steps
                                            setStateDialog(() {});
                                          },
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.primary
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.apps,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              TextField(
                                controller: subDataController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: _getTargetLabel(selectedType),
                                  labelStyle: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                  filled: true,
                                  fillColor: Colors.black26,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                if (subDataController.text.isNotEmpty) {
                                  List<dynamic> currentSteps = [];
                                  if (parentDataController.text.isNotEmpty) {
                                    try {
                                      currentSteps = jsonDecode(
                                        parentDataController.text,
                                      );
                                    } catch (e) {
                                      // Ignore error
                                    }
                                  }

                                  currentSteps.add({
                                    'type': selectedType
                                        .toString()
                                        .split('.')
                                        .last,
                                    'data': subDataController.text,
                                  });

                                  parentDataController.text = jsonEncode(
                                    currentSteps,
                                  );
                                  onUpdate();
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text('Add Step'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
        ActionType type;
        if (actionMap['type'] is int) {
          type = ActionType.values[actionMap['type'] as int];
        } else {
          type = ActionType.values.firstWhere(
            (e) => e.toString().split('.').last == actionMap['type'],
            orElse: () => ActionType.hotkey,
          );
        }
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
            hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5)),
            filled: true,
            fillColor: _isRecording
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
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
