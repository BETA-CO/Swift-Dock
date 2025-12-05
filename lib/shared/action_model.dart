import 'package:flutter/material.dart';

enum ActionType { openApp, openUrl, hotkey, runCommand }

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
    return DeckAction(
      id: json['id'],
      type: ActionType.values[json['type']],
      label: json['label'],
      icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
      data: json['data'],
      imageBase64: json['imageBase64'],
    );
  }
}
