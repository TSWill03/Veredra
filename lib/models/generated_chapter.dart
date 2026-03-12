// Signature: dev.tswicolly03
class GeneratedChapter {
  const GeneratedChapter({
    required this.title,
    required this.content,
  });

  final String title;
  final String content;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'content': content,
    };
  }

  factory GeneratedChapter.fromJson(Map<String, dynamic> json) {
    return GeneratedChapter(
      title: json['title'] as String? ?? 'Capitulo',
      content: json['content'] as String? ?? '',
    );
  }
}
