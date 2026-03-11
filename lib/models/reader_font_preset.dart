import 'package:flutter/material.dart';

enum ReaderFontPreset { system, serif, sans, mono }

ReaderFontPreset readerFontPresetFromId(String? id) {
  for (final ReaderFontPreset preset in ReaderFontPreset.values) {
    if (preset.name == id) {
      return preset;
    }
  }
  return ReaderFontPreset.system;
}

extension ReaderFontPresetX on ReaderFontPreset {
  String get label {
    switch (this) {
      case ReaderFontPreset.system:
        return 'Sistema';
      case ReaderFontPreset.serif:
        return 'Serifada';
      case ReaderFontPreset.sans:
        return 'Limpa';
      case ReaderFontPreset.mono:
        return 'Mono';
    }
  }

  String get previewLabel {
    switch (this) {
      case ReaderFontPreset.system:
        return 'Visual padrao do aparelho';
      case ReaderFontPreset.serif:
        return 'Leitura classica de livro';
      case ReaderFontPreset.sans:
        return 'Leitura limpa e moderna';
      case ReaderFontPreset.mono:
        return 'Espacamento fixo';
    }
  }

  TextStyle applyTo(TextStyle? style) {
    final TextStyle base = style ?? const TextStyle();

    switch (this) {
      case ReaderFontPreset.system:
        return base.copyWith(
          fontFamily: null,
          fontFamilyFallback: null,
        );
      case ReaderFontPreset.serif:
        return base.copyWith(
          fontFamily: 'Georgia',
          fontFamilyFallback: const <String>[
            'Times New Roman',
            'Noto Serif',
            'DejaVu Serif',
          ],
        );
      case ReaderFontPreset.sans:
        return base.copyWith(
          fontFamily: 'Verdana',
          fontFamilyFallback: const <String>[
            'Arial',
            'Roboto',
            'Noto Sans',
            'DejaVu Sans',
          ],
        );
      case ReaderFontPreset.mono:
        return base.copyWith(
          fontFamily: 'Consolas',
          fontFamilyFallback: const <String>[
            'Courier New',
            'Roboto Mono',
            'Menlo',
            'Monaco',
          ],
        );
    }
  }
}
