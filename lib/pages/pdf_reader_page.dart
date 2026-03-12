// Signature: dev.tswicolly03
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/book.dart';
import '../models/reading_progress.dart';
import '../services/progress_service.dart';

class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({
    super.key,
    required this.book,
    required this.progressService,
    required this.onThemeModeChanged,
  });

  final Book book;
  final ProgressService progressService;
  final Future<void> Function(ThemeMode) onThemeModeChanged;

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PdfViewerController _viewerController = PdfViewerController();
  late final PdfDocumentRefFile _documentRef;

  Timer? _saveDebounce;
  List<PdfOutlineNode> _outline = const <PdfOutlineNode>[];
  int _currentPage = 1;
  int _pageCount = 0;
  int _initialPageNumber = 1;
  bool _hasLoadedOutline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _documentRef = PdfDocumentRefFile(widget.book.reference.primaryAssetPath!);
    _loadSavedProgress();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDebounce?.cancel();
    unawaited(_persistProgress());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_persistProgress());
    }
  }

  Future<void> _loadSavedProgress() async {
    final ReadingProgress? progress =
        await widget.progressService.loadProgress(widget.book.id);
    if (!mounted || progress == null) {
      return;
    }

    setState(() {
      _initialPageNumber = progress.chapterIndex + 1;
      _currentPage = progress.chapterIndex + 1;
    });
  }

  Future<void> _loadOutline(PdfDocument document) async {
    if (_hasLoadedOutline) {
      return;
    }
    _hasLoadedOutline = true;
    final List<PdfOutlineNode> outline = await document.loadOutline();
    if (!mounted) {
      return;
    }
    setState(() {
      _outline = outline;
    });
  }

  void _handlePageChanged(int? pageNumber) {
    if (pageNumber == null || _currentPage == pageNumber) {
      return;
    }

    setState(() {
      _currentPage = pageNumber;
    });
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_persistProgress());
    });
  }

  Future<void> _persistProgress() async {
    await widget.progressService.saveProgress(
      widget.book.id,
      ReadingProgress(
        chapterIndex: _currentPage - 1,
        chapterOffset: 0,
        chapterProgress: 0,
        savedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _goToPage(int pageNumber) async {
    final Matrix4 matrix = _viewerController.calcMatrixForPage(
      pageNumber: pageNumber,
    );
    await _viewerController.goTo(matrix, duration: Duration.zero);
    _handlePageChanged(pageNumber);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return PdfDocumentViewBuilder(
      documentRef: _documentRef,
      builder: (BuildContext context, PdfDocument? document) {
        final int pageCount = document?.pages.length ?? _pageCount;
        if (pageCount != _pageCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _pageCount = pageCount;
            });
          });
        }
        if (document != null && !_hasLoadedOutline) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_loadOutline(document));
          });
        }

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(widget.book.title),
                Text(
                  _pageCount > 0
                      ? 'Pagina $_currentPage de $_pageCount'
                      : 'PDF importado',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Sumario',
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                icon: const Icon(Icons.list_rounded),
              ),
              IconButton(
                tooltip: isDark ? 'Modo claro' : 'Modo escuro',
                onPressed: () {
                  unawaited(
                    widget.onThemeModeChanged(
                      isDark ? ThemeMode.light : ThemeMode.dark,
                    ),
                  );
                },
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          endDrawer: _PdfOutlineDrawer(
            outline: _outline,
            currentPage: _currentPage,
            pageCount: _pageCount,
            onJumpToPage: (int pageNumber) {
              Navigator.of(context).pop();
              unawaited(_goToPage(pageNumber));
            },
          ),
          body: PdfViewer(
            _documentRef,
            controller: _viewerController,
            initialPageNumber: _initialPageNumber,
            params: PdfViewerParams(
              backgroundColor: theme.scaffoldBackgroundColor,
              enableTextSelection: true,
              onPageChanged: _handlePageChanged,
            ),
          ),
        );
      },
    );
  }
}

class _PdfOutlineDrawer extends StatelessWidget {
  const _PdfOutlineDrawer({
    required this.outline,
    required this.currentPage,
    required this.pageCount,
    required this.onJumpToPage,
  });

  final List<PdfOutlineNode> outline;
  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onJumpToPage;

  @override
  Widget build(BuildContext context) {
    final List<_OutlineEntry> entries = _flattenOutline(outline);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            ListTile(
              title: const Text('Sumario'),
              subtitle: Text('Pagina atual: $currentPage/$pageCount'),
            ),
            const Divider(height: 1),
            Expanded(
              child: entries.isEmpty
                  ? ListView.builder(
                      itemCount: pageCount,
                      itemBuilder: (BuildContext context, int index) {
                        final int pageNumber = index + 1;
                        return ListTile(
                          selected: pageNumber == currentPage,
                          leading: CircleAvatar(
                            radius: 16,
                            child: Text('$pageNumber'),
                          ),
                          title: Text('Pagina $pageNumber'),
                          onTap: () => onJumpToPage(pageNumber),
                        );
                      },
                    )
                  : ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (BuildContext context, int index) {
                        final _OutlineEntry entry = entries[index];
                        final int? pageNumber = entry.node.dest?.pageNumber;
                        return ListTile(
                          contentPadding: EdgeInsets.only(
                            left: 16 + entry.depth * 18,
                            right: 12,
                          ),
                          selected: pageNumber == currentPage,
                          leading: pageNumber == null
                              ? const Icon(
                                  Icons.subdirectory_arrow_right_rounded)
                              : CircleAvatar(
                                  radius: 16,
                                  child: Text('$pageNumber'),
                                ),
                          title: Text(
                            entry.node.title.trim().isEmpty
                                ? 'Secao'
                                : entry.node.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: pageNumber == null
                              ? null
                              : () => onJumpToPage(pageNumber),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<_OutlineEntry> _flattenOutline(
    List<PdfOutlineNode> nodes, [
    int depth = 0,
  ]) {
    final List<_OutlineEntry> result = <_OutlineEntry>[];
    for (final PdfOutlineNode node in nodes) {
      result.add(_OutlineEntry(node: node, depth: depth));
      result.addAll(_flattenOutline(node.children, depth + 1));
    }
    return result;
  }
}

class _OutlineEntry {
  const _OutlineEntry({
    required this.node,
    required this.depth,
  });

  final PdfOutlineNode node;
  final int depth;
}
