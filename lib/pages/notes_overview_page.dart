// Signature: dev.tswicolly03
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book_open_request.dart';
import '../models/library_entry.dart';
import '../models/reader_annotation.dart';
import '../models/reader_bookmark.dart';
import '../models/reader_highlight_color.dart';
import '../services/annotation_service.dart';
import '../services/bookmark_service.dart';
import '../widgets/annotation_editor_dialog.dart';
import '../widgets/bookmark_editor_dialog.dart';

enum _NotesFilter { all, favorites, withNotes }

class NotesOverviewPage extends StatefulWidget {
  const NotesOverviewPage({
    super.key,
    required this.entries,
    required this.bookmarkService,
    required this.annotationService,
  });

  final List<LibraryEntry> entries;
  final BookmarkService bookmarkService;
  final AnnotationService annotationService;

  @override
  State<NotesOverviewPage> createState() => _NotesOverviewPageState();
}

class _NotesOverviewPageState extends State<NotesOverviewPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String _query = '';
  _NotesFilter _filter = _NotesFilter.all;
  List<_BookmarkOverviewItem> _bookmarks = const <_BookmarkOverviewItem>[];
  List<_AnnotationOverviewItem> _annotations =
      const <_AnnotationOverviewItem>[];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadItems();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    setState(() {
      _query = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _loadItems() async {
    final Map<String, LibraryEntry> entriesById = <String, LibraryEntry>{
      for (final LibraryEntry entry in widget.entries) entry.id: entry,
    };
    final Map<String, List<ReaderBookmark>> allBookmarks =
        await widget.bookmarkService.loadAllBookmarks();
    final Map<String, List<ReaderAnnotation>> allAnnotations =
        await widget.annotationService.loadAllAnnotations();

    final List<_BookmarkOverviewItem> bookmarks = <_BookmarkOverviewItem>[];
    for (final MapEntry<String, List<ReaderBookmark>> entry
        in allBookmarks.entries) {
      final LibraryEntry? libraryEntry = entriesById[entry.key];
      if (libraryEntry == null) {
        continue;
      }
      for (final ReaderBookmark bookmark in entry.value) {
        bookmarks.add(
          _BookmarkOverviewItem(
            entry: libraryEntry,
            bookmark: bookmark,
          ),
        );
      }
    }

    final List<_AnnotationOverviewItem> annotations =
        <_AnnotationOverviewItem>[];
    for (final MapEntry<String, List<ReaderAnnotation>> entry
        in allAnnotations.entries) {
      final LibraryEntry? libraryEntry = entriesById[entry.key];
      if (libraryEntry == null) {
        continue;
      }
      for (final ReaderAnnotation annotation in entry.value) {
        annotations.add(
          _AnnotationOverviewItem(
            entry: libraryEntry,
            annotation: annotation,
          ),
        );
      }
    }

    bookmarks
        .sort((a, b) => b.bookmark.createdAt.compareTo(a.bookmark.createdAt));
    annotations.sort(
      (a, b) => b.annotation.createdAt.compareTo(a.annotation.createdAt),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _bookmarks = bookmarks;
      _annotations = annotations;
      _isLoading = false;
    });
  }

  Future<void> _deleteBookmark(_BookmarkOverviewItem item) async {
    await widget.bookmarkService.removeBookmark(
      item.entry.id,
      item.bookmark.id,
    );
    await _loadItems();
  }

  Future<void> _deleteAnnotation(_AnnotationOverviewItem item) async {
    await widget.annotationService.removeAnnotation(
      item.entry.id,
      item.annotation.id,
    );
    await _loadItems();
  }

  Future<void> _toggleBookmarkFavorite(_BookmarkOverviewItem item) async {
    await widget.bookmarkService.saveBookmark(
      item.bookmark.copyWith(isFavorite: !item.bookmark.isFavorite),
    );
    await _loadItems();
  }

  Future<void> _toggleAnnotationFavorite(_AnnotationOverviewItem item) async {
    await widget.annotationService.saveAnnotation(
      item.annotation.copyWith(isFavorite: !item.annotation.isFavorite),
    );
    await _loadItems();
  }

  Future<void> _editBookmark(_BookmarkOverviewItem item) async {
    final BookmarkEditorResult? result = await showBookmarkEditorDialog(
      context: context,
      chapterTitle: item.bookmark.chapterTitle,
      existing: item.bookmark,
    );
    if (result == null) {
      return;
    }

    await widget.bookmarkService.saveBookmark(
      item.bookmark.copyWith(
        note: result.note,
        excerpt: result.excerpt,
        isFavorite: result.isFavorite,
      ),
    );
    await _loadItems();
  }

  Future<void> _editAnnotation(_AnnotationOverviewItem item) async {
    final AnnotationEditorResult? result = await showAnnotationEditorDialog(
      context: context,
      chapterTitle: item.annotation.chapterTitle,
      selectedText: item.annotation.selectedText,
      requireNote: false,
      existing: item.annotation,
    );
    if (result == null) {
      return;
    }

    await widget.annotationService.saveAnnotation(
      item.annotation.copyWith(
        note: result.note,
        color: result.color,
        isFavorite: result.isFavorite,
      ),
    );
    await _loadItems();
  }

  Future<void> _copyText(String content, String message) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<_BookmarkOverviewItem> _filteredBookmarks() {
    Iterable<_BookmarkOverviewItem> items = _bookmarks;
    if (_query.isNotEmpty) {
      items = items.where((item) => item.searchableText.contains(_query));
    }

    switch (_filter) {
      case _NotesFilter.all:
        break;
      case _NotesFilter.favorites:
        items = items.where((item) => item.bookmark.isFavorite);
        break;
      case _NotesFilter.withNotes:
        items = items.where(
          (item) =>
              (item.bookmark.note?.trim().isNotEmpty ?? false) ||
              (item.bookmark.excerpt?.trim().isNotEmpty ?? false),
        );
        break;
    }

    final List<_BookmarkOverviewItem> result = items.toList(growable: false);
    result.sort((a, b) {
      if (a.bookmark.isFavorite != b.bookmark.isFavorite) {
        return a.bookmark.isFavorite ? -1 : 1;
      }
      return b.bookmark.createdAt.compareTo(a.bookmark.createdAt);
    });
    return result;
  }

  List<_AnnotationOverviewItem> _filteredAnnotations() {
    Iterable<_AnnotationOverviewItem> items = _annotations;
    if (_query.isNotEmpty) {
      items = items.where((item) => item.searchableText.contains(_query));
    }

    switch (_filter) {
      case _NotesFilter.all:
        break;
      case _NotesFilter.favorites:
        items = items.where((item) => item.annotation.isFavorite);
        break;
      case _NotesFilter.withNotes:
        items = items.where(
          (item) => item.annotation.note?.trim().isNotEmpty ?? false,
        );
        break;
    }

    final List<_AnnotationOverviewItem> result = items.toList(growable: false);
    result.sort((a, b) {
      if (a.annotation.isFavorite != b.annotation.isFavorite) {
        return a.annotation.isFavorite ? -1 : 1;
      }
      return b.annotation.createdAt.compareTo(a.annotation.createdAt);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_BookmarkOverviewItem> visibleBookmarks = _filteredBookmarks();
    final List<_AnnotationOverviewItem> visibleAnnotations =
        _filteredAnnotations();
    final int favoriteCount =
        _bookmarks.where((item) => item.bookmark.isFavorite).length +
            _annotations.where((item) => item.annotation.isFavorite).length;
    final int commentaryCount = _bookmarks
            .where((item) =>
                (item.bookmark.note?.trim().isNotEmpty ?? false) ||
                (item.bookmark.excerpt?.trim().isNotEmpty ?? false))
            .length +
        _annotations
            .where((item) => item.annotation.note?.trim().isNotEmpty ?? false)
            .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas e destaques'),
      ),
      body: DefaultTabController(
        length: 2,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            SearchBar(
              controller: _searchController,
              hintText: 'Filtre por livro, capitulo, trecho ou comentario...',
              leading: const Icon(Icons.sticky_note_2_outlined),
              trailing: _query.isEmpty
                  ? null
                  : <Widget>[
                      IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Central de leitura',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Veja todos os marcadores, comentarios e trechos destacados da biblioteca. Toque em um item para abrir o livro no ponto correspondente.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      Chip(
                        label: Text('${_bookmarks.length} marcador(es)'),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text('${_annotations.length} destaque(s)'),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text('$favoriteCount favorito(s)'),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text('$commentaryCount com comentario'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Tudo'),
                  selected: _filter == _NotesFilter.all,
                  onSelected: (_) {
                    setState(() {
                      _filter = _NotesFilter.all;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Favoritos'),
                  selected: _filter == _NotesFilter.favorites,
                  onSelected: (_) {
                    setState(() {
                      _filter = _NotesFilter.favorites;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Com comentarios'),
                  selected: _filter == _NotesFilter.withNotes,
                  onSelected: (_) {
                    setState(() {
                      _filter = _NotesFilter.withNotes;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const TabBar(
              tabs: <Widget>[
                Tab(text: 'Marcadores'),
                Tab(text: 'Destaques'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.62,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: <Widget>[
                        visibleBookmarks.isEmpty
                            ? const _EmptyPanel(
                                icon: Icons.bookmark_border_rounded,
                                title: 'Nenhum marcador por aqui',
                                message:
                                    'Os marcadores que voce criar durante a leitura vao aparecer aqui.',
                              )
                            : ListView.builder(
                                itemCount: visibleBookmarks.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final _BookmarkOverviewItem item =
                                      visibleBookmarks[index];
                                  return _BookmarkCard(
                                    item: item,
                                    onTap: () {
                                      Navigator.of(context).pop(
                                        BookOpenRequest(
                                          reference: item.entry.reference,
                                          chapterIndex:
                                              item.bookmark.chapterIndex,
                                          chapterProgress:
                                              item.bookmark.chapterProgress,
                                        ),
                                      );
                                    },
                                    onEdit: () => _editBookmark(item),
                                    onCopy: () => _copyText(
                                      item.bookmark.excerpt
                                                  ?.trim()
                                                  .isNotEmpty ??
                                              false
                                          ? item.bookmark.excerpt!.trim()
                                          : item.bookmark.note
                                                      ?.trim()
                                                      .isNotEmpty ??
                                                  false
                                              ? item.bookmark.note!.trim()
                                              : item.bookmark.chapterTitle,
                                      'Marcador copiado.',
                                    ),
                                    onToggleFavorite: () =>
                                        _toggleBookmarkFavorite(item),
                                    onDelete: () => _deleteBookmark(item),
                                  );
                                },
                              ),
                        visibleAnnotations.isEmpty
                            ? const _EmptyPanel(
                                icon: Icons.draw_outlined,
                                title: 'Nenhum destaque encontrado',
                                message:
                                    'Os trechos destacados e anotados no leitor aparecem aqui.',
                              )
                            : ListView.builder(
                                itemCount: visibleAnnotations.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final _AnnotationOverviewItem item =
                                      visibleAnnotations[index];
                                  return _AnnotationCard(
                                    item: item,
                                    onTap: () {
                                      Navigator.of(context).pop(
                                        BookOpenRequest(
                                          reference: item.entry.reference,
                                          chapterIndex:
                                              item.annotation.chapterIndex,
                                        ),
                                      );
                                    },
                                    onEdit: () => _editAnnotation(item),
                                    onCopy: () => _copyText(
                                      item.annotation.selectedText,
                                      'Trecho copiado.',
                                    ),
                                    onToggleFavorite: () =>
                                        _toggleAnnotationFavorite(item),
                                    onDelete: () => _deleteAnnotation(item),
                                  );
                                },
                              ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarkOverviewItem {
  const _BookmarkOverviewItem({
    required this.entry,
    required this.bookmark,
  });

  final LibraryEntry entry;
  final ReaderBookmark bookmark;

  String get searchableText {
    return <String>[
      entry.title,
      bookmark.chapterTitle,
      bookmark.note ?? '',
      bookmark.excerpt ?? '',
      ...entry.reference.tags,
    ].join(' ').toLowerCase();
  }
}

class _AnnotationOverviewItem {
  const _AnnotationOverviewItem({
    required this.entry,
    required this.annotation,
  });

  final LibraryEntry entry;
  final ReaderAnnotation annotation;

  String get searchableText {
    return <String>[
      entry.title,
      annotation.chapterTitle,
      annotation.selectedText,
      annotation.note ?? '',
      ...entry.reference.tags,
    ].join(' ').toLowerCase();
  }
}

class _BookmarkCard extends StatelessWidget {
  const _BookmarkCard({
    required this.item,
    required this.onTap,
    required this.onEdit,
    required this.onCopy,
    required this.onToggleFavorite,
    required this.onDelete,
  });

  final _BookmarkOverviewItem item;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String detail = (item.bookmark.note?.trim().isNotEmpty ?? false)
        ? item.bookmark.note!.trim()
        : (item.bookmark.excerpt?.trim().isNotEmpty ?? false)
            ? item.bookmark.excerpt!.trim()
            : 'Sem anotacao adicional';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: Icon(
          item.bookmark.isFavorite
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
        ),
        title: Text(item.entry.title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${item.bookmark.chapterTitle}\n$detail',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (String value) {
            switch (value) {
              case 'edit':
                onEdit();
                break;
              case 'copy':
                onCopy();
                break;
              case 'favorite':
                onToggleFavorite();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'edit',
              child: Text('Editar'),
            ),
            const PopupMenuItem<String>(
              value: 'copy',
              child: Text('Copiar texto'),
            ),
            PopupMenuItem<String>(
              value: 'favorite',
              child: Text(
                item.bookmark.isFavorite
                    ? 'Remover dos favoritos'
                    : 'Favoritar',
              ),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Text('Remover'),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _AnnotationCard extends StatelessWidget {
  const _AnnotationCard({
    required this.item,
    required this.onTap,
    required this.onEdit,
    required this.onCopy,
    required this.onToggleFavorite,
    required this.onDelete,
  });

  final _AnnotationOverviewItem item;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String detail = item.annotation.note?.trim().isNotEmpty ?? false
        ? item.annotation.note!.trim()
        : 'Sem comentario';

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
          backgroundColor: item.annotation.color.backgroundColor,
          child: Icon(
            item.annotation.isFavorite
                ? Icons.star_rounded
                : Icons.edit_note_rounded,
            color: item.annotation.color.accentColor,
          ),
        ),
        title: Text(item.entry.title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${item.annotation.chapterTitle}\n${item.annotation.selectedText}\n$detail',
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (String value) {
            switch (value) {
              case 'edit':
                onEdit();
                break;
              case 'copy':
                onCopy();
                break;
              case 'favorite':
                onToggleFavorite();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'edit',
              child: Text('Editar'),
            ),
            const PopupMenuItem<String>(
              value: 'copy',
              child: Text('Copiar trecho'),
            ),
            PopupMenuItem<String>(
              value: 'favorite',
              child: Text(
                item.annotation.isFavorite
                    ? 'Remover dos favoritos'
                    : 'Favoritar',
              ),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Text('Remover'),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
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

    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 36),
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
      ),
    );
  }
}
