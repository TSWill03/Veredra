// Signature: dev.tswicolly03
class TranslationLanguage {
  const TranslationLanguage({
    required this.code,
    required this.name,
  });

  final String code;
  final String name;

  String get label => name.trim().isEmpty ? code.toUpperCase() : name.trim();

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'code': code,
      'name': name,
    };
  }

  factory TranslationLanguage.fromJson(Map<String, dynamic> json) {
    return TranslationLanguage(
      code: (json['code'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
    );
  }
}
