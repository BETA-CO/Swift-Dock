import 'package:flutter/material.dart';

enum ActionType { openApp, openUrl, hotkey, runCommand, toggle, macro }

class DeckAction {
  final String id;
  final ActionType type;
  final String label;
  final IconData icon;
  final String data;
  final String? imageBase64;

  DeckAction({
    required this.id,
    required this.type,
    required this.label,
    required this.icon,
    required this.data,
    this.imageBase64,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'label': label,
      'icon': icon.codePoint,
      'data': data,
      'imageBase64': imageBase64,
    };
  }

  factory DeckAction.fromJson(Map<String, dynamic> json) {
    // Helper to resolve icon from codePoint or fallback
    IconData resolveIcon(int? codePoint) {
      if (codePoint == Icons.link.codePoint) {
        return Icons.link;
      }
      if (codePoint == Icons.apps.codePoint) {
        return Icons.apps;
      }
      if (codePoint == Icons.terminal.codePoint) {
        return Icons.terminal;
      }
      if (codePoint == Icons.keyboard.codePoint) {
        return Icons.keyboard;
      }
      if (codePoint == Icons.toggle_on.codePoint) {
        return Icons.toggle_on;
      }
      if (codePoint == Icons.playlist_play.codePoint) {
        return Icons.playlist_play;
      }
      // Add other potential icons used in the app if necessary
      if (codePoint == Icons.add_rounded.codePoint) {
        return Icons.add_rounded;
      }

      // Default fallback if unknown (prevents build error by returning constant)
      return Icons.help_outline;
    }

    return DeckAction(
      id: json['id'],
      type: ActionType.values[json['type']],
      label: json['label'],
      icon: resolveIcon(json['icon']),
      data: json['data'],
      imageBase64: json['imageBase64'],
    );
  }

  DeckAction copyWith({
    String? id,
    ActionType? type,
    String? label,
    IconData? icon,
    String? data,
    String? imageBase64,
  }) {
    return DeckAction(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      data: data ?? this.data,
      imageBase64: imageBase64 ?? this.imageBase64,
    );
  }
}

class DeckProfile {
  final String id;
  String name;
  final int rows;
  final int columns;
  final Map<String, DeckAction> actions;

  DeckProfile({
    required this.id,
    required this.name,
    this.rows = 3,
    this.columns = 5,
    required this.actions,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rows': rows,
      'columns': columns,
      'actions': actions.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  factory DeckProfile.fromJson(Map<String, dynamic> json) {
    final actionsMap = <String, DeckAction>{};
    if (json['actions'] != null) {
      json['actions'].forEach((key, value) {
        actionsMap[key] = DeckAction.fromJson(value);
      });
    }

    return DeckProfile(
      id: json['id'],
      name: json['name'],
      rows: json['rows'] ?? 3,
      columns: json['columns'] ?? 5,
      actions: actionsMap,
    );
  }
}
