import 'package:flutter/material.dart';

enum ReaderHighlightColor { amber, green, blue, rose }

ReaderHighlightColor readerHighlightColorFromId(String? id) {
  for (final ReaderHighlightColor color in ReaderHighlightColor.values) {
    if (color.name == id) {
      return color;
    }
  }
  return ReaderHighlightColor.amber;
}

extension ReaderHighlightColorX on ReaderHighlightColor {
  String get label {
    switch (this) {
      case ReaderHighlightColor.amber:
        return 'Amarelo';
      case ReaderHighlightColor.green:
        return 'Verde';
      case ReaderHighlightColor.blue:
        return 'Azul';
      case ReaderHighlightColor.rose:
        return 'Rosa';
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ReaderHighlightColor.amber:
        return const Color(0x66F7D774);
      case ReaderHighlightColor.green:
        return const Color(0x6678D6A3);
      case ReaderHighlightColor.blue:
        return const Color(0x6679B8FF);
      case ReaderHighlightColor.rose:
        return const Color(0x66F4A4B4);
    }
  }

  Color get accentColor {
    switch (this) {
      case ReaderHighlightColor.amber:
        return const Color(0xFFC28A16);
      case ReaderHighlightColor.green:
        return const Color(0xFF1E8A58);
      case ReaderHighlightColor.blue:
        return const Color(0xFF2E6FC8);
      case ReaderHighlightColor.rose:
        return const Color(0xFFC24B73);
    }
  }
}
