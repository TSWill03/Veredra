import 'dart:convert';

import 'reader_background_preset.dart';
import 'reader_font_preset.dart';
import 'reader_text_align_preset.dart';

class ReaderPreferences {
  const ReaderPreferences({
    required this.fontSize,
    required this.fontPreset,
    required this.backgroundPreset,
    required this.lineHeight,
    required this.contentWidth,
    required this.horizontalPadding,
    required this.textAlignPreset,
  });

  static const ReaderPreferences defaults = ReaderPreferences(
    fontSize: 19,
    fontPreset: ReaderFontPreset.system,
    backgroundPreset: ReaderBackgroundPreset.parchment,
    lineHeight: 1.78,
    contentWidth: 860,
    horizontalPadding: 20,
    textAlignPreset: ReaderTextAlignPreset.justify,
  );

  final double fontSize;
  final ReaderFontPreset fontPreset;
  final ReaderBackgroundPreset backgroundPreset;
  final double lineHeight;
  final double contentWidth;
  final double horizontalPadding;
  final ReaderTextAlignPreset textAlignPreset;

  ReaderPreferences copyWith({
    double? fontSize,
    ReaderFontPreset? fontPreset,
    ReaderBackgroundPreset? backgroundPreset,
    double? lineHeight,
    double? contentWidth,
    double? horizontalPadding,
    ReaderTextAlignPreset? textAlignPreset,
  }) {
    return ReaderPreferences(
      fontSize: fontSize ?? this.fontSize,
      fontPreset: fontPreset ?? this.fontPreset,
      backgroundPreset: backgroundPreset ?? this.backgroundPreset,
      lineHeight: lineHeight ?? this.lineHeight,
      contentWidth: contentWidth ?? this.contentWidth,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      textAlignPreset: textAlignPreset ?? this.textAlignPreset,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fontSize': fontSize,
      'fontPreset': fontPreset.name,
      'backgroundPreset': backgroundPreset.name,
      'lineHeight': lineHeight,
      'contentWidth': contentWidth,
      'horizontalPadding': horizontalPadding,
      'textAlignPreset': textAlignPreset.name,
    };
  }

  String encode() => jsonEncode(toJson());

  factory ReaderPreferences.fromJson(Map<String, dynamic> json) {
    return ReaderPreferences(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? defaults.fontSize,
      fontPreset: readerFontPresetFromId(json['fontPreset'] as String?),
      backgroundPreset: readerBackgroundPresetFromId(
        json['backgroundPreset'] as String?,
      ),
      lineHeight:
          (json['lineHeight'] as num?)?.toDouble() ?? defaults.lineHeight,
      contentWidth:
          (json['contentWidth'] as num?)?.toDouble() ?? defaults.contentWidth,
      horizontalPadding: (json['horizontalPadding'] as num?)?.toDouble() ??
          defaults.horizontalPadding,
      textAlignPreset: readerTextAlignPresetFromId(
        json['textAlignPreset'] as String?,
      ),
    );
  }
}
