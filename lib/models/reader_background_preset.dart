// Signature: dev.tswicolly03
import 'package:flutter/material.dart';

enum ReaderBackgroundPreset { parchment, sepia, mist, graphite, forest }

ReaderBackgroundPreset readerBackgroundPresetFromId(String? id) {
  for (final ReaderBackgroundPreset preset in ReaderBackgroundPreset.values) {
    if (preset.name == id) {
      return preset;
    }
  }
  return ReaderBackgroundPreset.parchment;
}

extension ReaderBackgroundPresetX on ReaderBackgroundPreset {
  String get label {
    switch (this) {
      case ReaderBackgroundPreset.parchment:
        return 'Pergaminho';
      case ReaderBackgroundPreset.sepia:
        return 'Sepia';
      case ReaderBackgroundPreset.mist:
        return 'Neblina';
      case ReaderBackgroundPreset.graphite:
        return 'Grafite';
      case ReaderBackgroundPreset.forest:
        return 'Floresta';
    }
  }

  Color get scaffoldColor {
    switch (this) {
      case ReaderBackgroundPreset.parchment:
        return const Color(0xFFF6F1E7);
      case ReaderBackgroundPreset.sepia:
        return const Color(0xFFF0E2C5);
      case ReaderBackgroundPreset.mist:
        return const Color(0xFFE8EEF2);
      case ReaderBackgroundPreset.graphite:
        return const Color(0xFF121518);
      case ReaderBackgroundPreset.forest:
        return const Color(0xFF13201B);
    }
  }

  Color get surfaceColor {
    switch (this) {
      case ReaderBackgroundPreset.parchment:
        return const Color(0xFFFFFBF4);
      case ReaderBackgroundPreset.sepia:
        return const Color(0xFFF6ECD6);
      case ReaderBackgroundPreset.mist:
        return const Color(0xFFF4F8FB);
      case ReaderBackgroundPreset.graphite:
        return const Color(0xFF1C2126);
      case ReaderBackgroundPreset.forest:
        return const Color(0xFF1B2C24);
    }
  }

  Color get primaryTextColor {
    switch (this) {
      case ReaderBackgroundPreset.graphite:
      case ReaderBackgroundPreset.forest:
        return const Color(0xFFF2F1EA);
      case ReaderBackgroundPreset.parchment:
      case ReaderBackgroundPreset.sepia:
      case ReaderBackgroundPreset.mist:
        return const Color(0xFF23201B);
    }
  }

  Color get secondaryTextColor {
    switch (this) {
      case ReaderBackgroundPreset.graphite:
        return const Color(0xFFA9B0B8);
      case ReaderBackgroundPreset.forest:
        return const Color(0xFFA7B6AF);
      case ReaderBackgroundPreset.parchment:
        return const Color(0xFF6B6157);
      case ReaderBackgroundPreset.sepia:
        return const Color(0xFF75644B);
      case ReaderBackgroundPreset.mist:
        return const Color(0xFF5D6B76);
    }
  }

  bool get isDark {
    switch (this) {
      case ReaderBackgroundPreset.graphite:
      case ReaderBackgroundPreset.forest:
        return true;
      case ReaderBackgroundPreset.parchment:
      case ReaderBackgroundPreset.sepia:
      case ReaderBackgroundPreset.mist:
        return false;
    }
  }
}
