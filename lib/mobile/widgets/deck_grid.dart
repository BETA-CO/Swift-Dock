import 'package:flutter/material.dart';
import '../../shared/action_model.dart';
import 'deck_button.dart';

class DeckGrid extends StatelessWidget {
  final Function(String) onCommand;
  final Map<int, DeckAction> actions;

  const DeckGrid({super.key, required this.onCommand, this.actions = const {}});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black, // Ensure solid background
      padding: const EdgeInsets.all(4), // Minimal outer padding
      child: Column(
        children: List.generate(3, (rowIndex) {
          return Expanded(
            child: Row(
              children: List.generate(5, (colIndex) {
                final index = rowIndex * 5 + colIndex;
                final action = actions[index];

                // Keep the grid structure but hide content if no action
                if (action == null) {
                  return const Expanded(child: SizedBox());
                }

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: DeckButton(
                      icon: action.icon,
                      label: action.label,
                      onTap: () => onCommand('ACTION:action_$index'),
                      action: action,
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}
