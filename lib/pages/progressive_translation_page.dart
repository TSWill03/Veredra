import 'dart:async';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/translation_progress.dart';

typedef ProgressiveTranslationRunner = Future<Book> Function(
  TranslationPause pause,
  ValueChanged<TranslationProgress> onProgress,
  ValueChanged<TranslationReadyChapter> onChapterReady,
);

class ProgressiveTranslationResult {
  const ProgressiveTranslationResult(
      this.book, this.chapterIndex, this.chapterProgress);
  final Book book;
  final int chapterIndex;
  final double chapterProgress;
}

/// Read completed, immutable checkpoints while the worker continues.
class ProgressiveTranslationPage extends StatefulWidget {
  const ProgressiveTranslationPage(
      {super.key, required this.bookTitle, required this.run});
  final String bookTitle;
  final ProgressiveTranslationRunner run;
  @override
  State<ProgressiveTranslationPage> createState() =>
      _ProgressiveTranslationPageState();
}

class _ProgressiveTranslationPageState
    extends State<ProgressiveTranslationPage> {
  final _pause = TranslationPause();
  final _chapters = <int, TranslationReadyChapter>{};
  final _scroll = ScrollController();
  TranslationProgress _progress = const TranslationProgress(
      stage: 'Preparando traducao', completedChapters: 0, totalChapters: 0);
  Book? _book;
  bool _running = true;
  bool _loading = false;
  int? _index;
  String? _content;
  String? _error;
  String? _loadError;
  int _generation = 0;
  double _fontSize = 20;

  @override
  void initState() {
    super.initState();
    // Defer the first invocation until the route has rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_run());
    });
  }

  Future<void> _run() async {
    try {
      final book = await widget.run(_pause, (progress) {
        if (mounted) setState(() => _progress = progress);
      }, (chapter) {
        if (!mounted) return;
        setState(() => _chapters[chapter.index] = chapter);
        if (_index == null) unawaited(_load(chapter.index));
      });
      if (!mounted) return;
      setState(() {
        _book = book;
        _running = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is TranslationPausedException
            ? 'Pausado. Os capitulos concluidos foram preservados. Inicie novamente com os mesmos idiomas e motor para retomar.'
            : 'Trabalho interrompido. Checkpoints concluidos preservados.\n$error';
        _running = false;
      });
    }
  }

  Future<void> _load(int index) async {
    final chapter = _chapters[index];
    if (chapter == null) return;
    final generation = ++_generation;
    setState(() {
      _index = index;
      _content = null;
      _loading = true;
      _loadError = null;
    });
    try {
      final text = await chapter.loadContent();
      if (!mounted || generation != _generation) return;
      setState(() {
        _content = text;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients && generation == _generation) {
          _scroll.jumpTo(0);
        }
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _loadError = 'Falha ao ler checkpoint. Tente novamente.';
      });
    }
  }

  Future<void> _chooseChapter() async {
    final indices = _chapters.keys.toList()..sort();
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Capitulos disponiveis'),
        content: SizedBox(
          width: 420,
          height: 400,
          child: ListView.builder(
            itemCount: indices.length,
            itemBuilder: (context, i) {
              final index = indices[i];
              return ListTile(
                selected: index == _index,
                title: Text('Capitulo ${index + 1}'),
                subtitle: Text(_chapters[index]!.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.of(context).pop(index),
              );
            },
          ),
        ),
      ),
    );
    if (mounted && selected != null) await _load(selected);
  }

  void _finish() {
    final book = _book;
    if (book == null || book.chapterCount == 0) return;
    final extent = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
    final progress =
        extent > 0 ? (_scroll.offset / extent).clamp(0.0, 1.0).toDouble() : 0.0;
    Navigator.of(context).pop(ProgressiveTranslationResult(
        book, (_index ?? 0).clamp(0, book.chapterCount - 1), progress));
  }

  @override
  void dispose() {
    if (_running) _pause.request();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = _index;
    final chapter = index == null ? null : _chapters[index];
    final previous = index != null && _chapters.containsKey(index - 1);
    final next = index != null && _chapters.containsKey(index + 1);
    final saving = _progress.stage == 'Salvando copia traduzida';
    return PopScope(
      canPop: !_running,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !_running,
          title: const Text('Leitura durante a traducao'),
          actions: [
            if (_running)
              TextButton(
                onPressed: _pause.requested || saving
                    ? null
                    : () {
                        _pause.request();
                        setState(() {});
                      },
                child:
                    Text(_pause.requested ? 'Pausando...' : 'Pausar e salvar'),
              ),
            if (_book != null)
              TextButton(
                  onPressed: _finish,
                  child: const Text('Abrir livro completo')),
          ],
        ),
        body: SafeArea(
            child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.bookTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                      value: _running && _progress.totalChapters == 0
                          ? null
                          : _progress.fraction),
                  const SizedBox(height: 6),
                  Text(
                      '${_chapters.length} de ${_progress.totalChapters} capitulos disponiveis • ${_running ? 'Traduzindo' : _book != null ? 'Concluido' : 'Interrompido'}'),
                  if (_progress.detail != null)
                    Text(_progress.detail!,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (_error != null)
                    Text(_error!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                            tooltip: 'Capitulo anterior',
                            onPressed: previous ? () => _load(index - 1) : null,
                            icon: const Icon(Icons.chevron_left)),
                        if (index != null)
                          TextButton(
                            onPressed: _chooseChapter,
                            child: Text('Capitulo ${index + 1}'),
                          ),
                        IconButton(
                            tooltip: 'Proximo capitulo',
                            onPressed: next ? () => _load(index + 1) : null,
                            icon: const Icon(Icons.chevron_right)),
                        IconButton(
                            tooltip: 'Diminuir fonte',
                            onPressed: _fontSize > 14
                                ? () => setState(() => _fontSize -= 2)
                                : null,
                            icon: const Icon(Icons.text_decrease)),
                        IconButton(
                            tooltip: 'Aumentar fonte',
                            onPressed: _fontSize < 36
                                ? () => setState(() => _fontSize += 2)
                                : null,
                            icon: const Icon(Icons.text_increase)),
                      ]),
                ]),
          ),
          const Divider(height: 1),
          Expanded(
              child: chapter == null
                  ? Center(
                      child: Text(_running
                          ? 'Aguardando o primeiro capitulo. A leitura sera liberada automaticamente.'
                          : 'Nenhum capitulo disponivel.'))
                  : _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _loadError != null
                          ? Center(
                              child: TextButton(
                                  onPressed: () => _load(index!),
                                  child: Text(_loadError!)))
                          : SingleChildScrollView(
                              controller: _scroll,
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                  child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 780),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(chapter.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall),
                                      const SizedBox(height: 20),
                                      SelectableText(_content ?? '',
                                          style: TextStyle(
                                              fontSize: _fontSize,
                                              height: 1.65)),
                                      const SizedBox(height: 24),
                                      if (next)
                                        FilledButton(
                                            onPressed: () => _load(index + 1),
                                            child: const Text(
                                                'Continuar para o proximo capitulo'))
                                      else if (_running)
                                        const Text(
                                            'O proximo capitulo aparecera assim que estiver pronto.'),
                                    ]),
                              )),
                            )),
        ])),
      ),
    );
  }
}
