import 'package:flutter/material.dart';
import '../../shared/action_model.dart';

class ActionSidebar extends StatelessWidget {
  const ActionSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Actions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildActionItem(
                  context,
                  Icons.apps,
                  'Open App',
                  ActionType.openApp,
                ),
                _buildActionItem(
                  context,
                  Icons.link,
                  'Open Website',
                  ActionType.openUrl,
                ),
                _buildActionItem(
                  context,
                  Icons.keyboard,
                  'Hotkey',
                  ActionType.hotkey,
                ),
                _buildActionItem(
                  context,
                  Icons.terminal,
                  'Run Command',
                  ActionType.runCommand,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    IconData icon,
    String label,
    ActionType type,
  ) {
    return Draggable(
      data: type,
      feedback: Material(
        color: Colors.transparent,
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.drag_indicator, color: Colors.white70),
              const SizedBox(width: 8),
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildListItem(context, icon, label),
      ),
      child: _buildListItem(context, icon, label),
    );
  }

  Widget _buildListItem(BuildContext context, IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}
