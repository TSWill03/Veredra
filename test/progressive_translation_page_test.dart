import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/models/book.dart';
import 'package:txt_webnovel_reader/models/translation_progress.dart';
import 'package:txt_webnovel_reader/pages/progressive_translation_page.dart';

void main() {
  testWidgets('reads ready chapters while worker is still running',
      (tester) async {
    late ValueChanged<TranslationReadyChapter> ready;
    late TranslationPause signal;
    final completion = Completer<Book>();
    await tester.pumpWidget(MaterialApp(
        home: ProgressiveTranslationPage(
      bookTitle: 'Original',
      run: (pause, progress, chapter) {
        signal = pause;
        ready = chapter;
        progress(const TranslationProgress(
            stage: 'Traduzindo', completedChapters: 0, totalChapters: 3));
        pause.attach(
            () => completion.completeError(const TranslationPausedException()));
        return completion.future;
      },
    )));
    expect(find.textContaining('Aguardando o primeiro'), findsOneWidget);
    ready(TranslationReadyChapter(
        index: 0, title: 'Primeiro', loadContent: () async => 'Texto um.'));
    await tester.pumpAndSettle();
    expect(find.text('Texto um.'), findsOneWidget);
    final next = find.widgetWithIcon(IconButton, Icons.chevron_right);
    expect(tester.widget<IconButton>(next).onPressed, isNull);
    ready(TranslationReadyChapter(
        index: 1, title: 'Segundo', loadContent: () async => 'Texto dois.'));
    await tester.pumpAndSettle();
    expect(find.text('Texto um.'), findsOneWidget);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Texto dois.'), findsOneWidget);
    await tester.tap(find.text('Pausar e salvar'));
    await tester.pumpAndSettle();
    expect(signal.requested, isTrue);
    expect(find.text('Texto dois.'), findsOneWidget);
    expect(find.textContaining('Pausado.'), findsOneWidget);
  });
}
