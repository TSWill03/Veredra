// Signature: dev.tswicolly03
import 'translation_language.dart';

class TranslationPair {
  const TranslationPair({
    required this.source,
    required this.target,
    required this.installed,
    required this.availableOnline,
  });

  final TranslationLanguage source;
  final TranslationLanguage target;
  final bool installed;
  final bool availableOnline;

  String get id => '${source.code}__${target.code}';
  String get label => '${source.label} -> ${target.label}';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'source': source.toJson(),
      'target': target.toJson(),
      'installed': installed,
      'availableOnline': availableOnline,
    };
  }

  factory TranslationPair.fromJson(Map<String, dynamic> json) {
    return TranslationPair(
      source: TranslationLanguage.fromJson(
        json['source'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      target: TranslationLanguage.fromJson(
        json['target'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      installed: json['installed'] as bool? ?? false,
      availableOnline: json['availableOnline'] as bool? ?? false,
    );
  }
}

enum TranslationEngineMode {
  argosSerial,
  argosFast,
  ctsCpu,
  ctsCuda,
  ctsCuda1024,
  ctsCudaBeam2
}

class TranslationRequest {
  const TranslationRequest({
    required this.pair,
    this.engine = TranslationEngineMode.ctsCpu,
    this.chapterLimit,
  });

  final TranslationPair pair;
  final TranslationEngineMode engine;
  final int? chapterLimit;
  bool get fast => engine == TranslationEngineMode.argosFast;
}
