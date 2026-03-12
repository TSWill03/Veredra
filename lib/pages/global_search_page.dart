// Signature: dev.tswicolly03
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/library_entry.dart';
import '../models/library_search_result.dart';
import '../services/library_search_service.dart';

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({
    super.key,
    required this.entries,
    required this.librarySearchService,
  });

  final List<LibraryEntry> entries;
  final LibrarySearchService librarySearchService;

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  List<LibrarySearchResult> _results = const <LibrarySearchResult>[];
  String _query = '';
  bool _isSearching = false;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController
      ..removeListener(_handleQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    final String nextQuery = _searchController.text.trim();
    setState(() {
      _query = nextQuery;
    });

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_runSearch(nextQuery));
    });
  }

  Future<void> _runSearch(String query) async {
    final int token = ++_searchToken;
    if (query.trim().length < 2) {
      if (!mounted) {
        return;
      }
      setState(() {
        _results = const <LibrarySearchResult>[];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final List<LibrarySearchResult> results =
        await widget.librarySearchService.search(widget.entries, query);
    if (!mounted || token != _searchToken) {
      return;
    }

    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Busca global'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          SearchBar(
            controller: _searchController,
            autoFocus: true,
            hintText: 'Busque frase, titulo, autor, serie ou tags...',
            leading: const Icon(Icons.travel_explore_rounded),
            trailing: _query.isEmpty
                ? null
                : <Widget>[
                    IconButton(
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
          ),
          const SizedBox(height: 14),
          Text(
            'Pesquisa em metadados, conteudo, marcadores e destaques da sua biblioteca.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          if (_query.length < 2)
            _InfoCard(
              icon: Icons.manage_search_rounded,
              title: 'Digite pelo menos 2 caracteres',
              message:
                  'Veredra procura por titulos, autores, tags, trechos no conteudo, marcadores e comentarios das anotacoes.',
            )
          else if (_isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_results.isEmpty)
            const _InfoCard(
              icon: Icons.search_off_rounded,
              title: 'Nada encontrado',
              message:
                  'Tente outra palavra, uma frase menor ou procure por nome de autor, serie ou capitulo.',
            )
          else ...<Widget>[
            Text(
              '${_results.length} resultado(s)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final LibrarySearchResult result in _results)
              _ResultCard(
                result: result,
                onTap: () => Navigator.of(context).pop(result.toOpenRequest()),
              ),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.onTap,
  });

  final LibrarySearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final IconData sourceIcon;
    switch (result.source) {
      case LibrarySearchResultSource.metadata:
        sourceIcon = Icons.info_outline_rounded;
        break;
      case LibrarySearchResultSource.content:
        sourceIcon = Icons.text_snippet_rounded;
        break;
      case LibrarySearchResultSource.bookmark:
        sourceIcon = Icons.bookmark_rounded;
        break;
      case LibrarySearchResultSource.annotation:
        sourceIcon = Icons.edit_note_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: CircleAvatar(
          child: Icon(sourceIcon),
        ),
        title: Text(result.bookTitle),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(
                    label: Text(result.sourceLabel),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (result.source != LibrarySearchResultSource.metadata)
                    Chip(
                      label: Text('${result.matchCount} ocorrencia(s)'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                result.snippet,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        isThreeLine: true,
        onTap: onTap,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 34),
          const SizedBox(height: 14),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
