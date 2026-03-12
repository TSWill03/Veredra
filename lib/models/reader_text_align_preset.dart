// Signature: dev.tswicolly03
import 'package:flutter/material.dart';

enum ReaderTextAlignPreset { left, justify, center }

ReaderTextAlignPreset readerTextAlignPresetFromId(String? id) {
  for (final ReaderTextAlignPreset preset in ReaderTextAlignPreset.values) {
    if (preset.name == id) {
      return preset;
    }
  }
  return ReaderTextAlignPreset.justify;
}

extension ReaderTextAlignPresetX on ReaderTextAlignPreset {
  String get label {
    switch (this) {
      case ReaderTextAlignPreset.left:
        return 'Esquerda';
      case ReaderTextAlignPreset.justify:
        return 'Justificado';
      case ReaderTextAlignPreset.center:
        return 'Centralizado';
    }
  }

  TextAlign get textAlign {
    switch (this) {
      case ReaderTextAlignPreset.left:
        return TextAlign.left;
      case ReaderTextAlignPreset.justify:
        return TextAlign.justify;
      case ReaderTextAlignPreset.center:
        return TextAlign.center;
    }
  }
}
