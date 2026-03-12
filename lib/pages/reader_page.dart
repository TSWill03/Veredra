// Signature: dev.tswicolly03
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/book.dart';
import '../models/book_search_match.dart';
import '../models/chapter.dart';
import '../models/reader_annotation.dart';
import '../models/reader_background_preset.dart';
import '../models/reader_bookmark.dart';
import '../models/reader_font_preset.dart';
import '../models/reader_highlight_color.dart';
import '../models/reader_preferences.dart';
import '../models/reader_text_align_preset.dart';
import '../models/reading_progress.dart';
import '../services/annotation_service.dart';
import '../services/bookmark_service.dart';
import '../services/book_service.dart';
import '../services/progress_service.dart';
import '../services/reading_stats_service.dart';
import '../widgets/reader_settings.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.book,
    required this.bookService,
    required this.annotationService,
    required this.bookmarkService,
    required this.progressService,
    required this.readingStatsService,
    required this.initialFontSize,
    required this.initialReaderFontPreset,
    this.initialChapterIndex,
    this.initialChapterProgress,
    required this.onThemeModeChanged,
    required this.onFontSizeChanged,
    required this.onReaderFontPresetChanged,
  });

  final Book book;
  final BookService bookService;
  final AnnotationService annotationService;
  final BookmarkService bookmarkService;
  final ProgressService progressService;
  final ReadingStatsService readingStatsService;
  final double initialFontSize;
  final ReaderFontPreset initialReaderFontPreset;
  final int? initialChapterIndex;
  final double? initialChapterProgress;
  final Future<void> Function(ThemeMode) onThemeModeChanged;
  final Future<void> Function(double) onFontSizeChanged;
  final Future<void> Function(ReaderFontPreset) onReaderFontPresetChanged;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> with WidgetsBindingObserver {
  static const int _maxActiveChapters = 10;
  static const double _chapterCardSpacing = 28;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final Map<int, String> _chapterContents = <int, String>{};
  final Map<int, GlobalKey> _chapterKeys = <int, GlobalKey>{};
  final Map<int, SelectionListenerNotifier> _selectionNotifiers =
      <int, SelectionListenerNotifier>{};
  final Map<int, String> _selectedTextByChapter = <int, String>{};
  int? _pendingSecondaryHighlightChapter;

  Timer? _saveDebounce;
  List<ReaderAnnotation> _annotations = <ReaderAnnotation>[];
  ReaderPreferences _preferences = ReaderPreferences.defaults;
  List<ReaderBookmark> _bookmarks = <ReaderBookmark>[];
  int _startIndex = 0;
  int _endIndex = -1;
  int _currentChapterIndex = 0;
  bool _isBootstrapping = true;
  bool _isLoadingNextChapter = false;
  bool _isLoadingPreviousChapter = false;
  bool _isRestoringPosition = false;
  bool _isFocusMode = false;
  int _selectionResetVersion = 0;
  String? _errorMessage;
  DateTime? _readingSessionStartedAt;

  bool get _hasLoadedContent => _endIndex >= _startIndex;
  bool get _hasMoreNext => _endIndex < widget.book.chapterCount - 1;
  bool get _hasMorePrevious => _startIndex > 0;
  int get _loadedChapterCount =>
      _hasLoadedContent ? (_endIndex - _startIndex + 1) : 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _preferences = ReaderPreferences.defaults.copyWith(
      fontSize: widget.initialFontSize,
      fontPreset: widget.initialReaderFontPreset,
    );
    _scrollController.addListener(_handleScroll);
    _bootstrapReader();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    for (final SelectionListenerNotifier notifier
        in _selectionNotifiers.values) {
      notifier.dispose();
    }
    _saveDebounce?.cancel();
    unawaited(_persistProgress());
    unawaited(_flushReadingSession());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_persistProgress());
      unawaited(_flushReadingSession());
    } else if (state == AppLifecycleState.resumed) {
      _resumeReadingSession();
    }
  }

  Future<void> _bootstrapReader() async {
    try {
      final ReaderPreferences savedPreferences =
          await widget.progressService.loadReaderPreferences();
      final List<ReaderAnnotation> annotations =
          await widget.annotationService.loadAnnotations(widget.book.id);
      final List<ReaderBookmark> bookmarks =
          await widget.bookmarkService.loadBookmarks(widget.book.id);
      final ReadingProgress? savedProgress =
          await widget.progressService.loadProgress(widget.book.id);
      final int preferredChapterIndex =
          widget.initialChapterIndex ?? savedProgress?.chapterIndex ?? 0;
      final int initialChapterIndex = math.min(
        preferredChapterIndex,
        math.max(widget.book.chapterCount - 1, 0),
      );
      final int initialStart = math.max(0, initialChapterIndex - 1);
      final int initialEnd = math.min(
        widget.book.chapterCount - 1,
        initialChapterIndex + 1,
      );

      final Map<int, String> initialContent = <int, String>{};
      for (int index = initialStart; index <= initialEnd; index++) {
        initialContent[index] = await widget.bookService.readChapterContent(
          widget.book.chapters[index],
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _preferences = savedPreferences;
        _annotations = annotations
          ..sort((ReaderAnnotation a, ReaderAnnotation b) {
            if (a.chapterIndex != b.chapterIndex) {
              return a.chapterIndex.compareTo(b.chapterIndex);
            }
            return a.startOffset.compareTo(b.startOffset);
          });
        _bookmarks = bookmarks
          ..sort((ReaderBookmark a, ReaderBookmark b) {
            return b.createdAt.compareTo(a.createdAt);
          });
        _currentChapterIndex = initialChapterIndex;
        _startIndex = initialStart;
        _endIndex = initialEnd;
        _chapterContents
          ..clear()
          ..addAll(initialContent);
        _isBootstrapping = false;
      });
      _syncCacheWindow();
      await widget.readingStatsService.registerBookOpened(
        widget.book.id,
        chapterIndex: initialChapterIndex,
      );
      _resumeReadingSession();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_primeViewportIfNeeded());
        if (widget.initialChapterIndex != null) {
          unawaited(
            _restoreSavedPosition(
              ReadingProgress(
                chapterIndex: initialChapterIndex,
                chapterOffset: 0,
                chapterProgress: widget.initialChapterProgress ?? 0,
                savedAt: DateTime.now(),
              ),
            ),
          );
        } else if (savedProgress != null) {
          unawaited(_restoreSavedPosition(savedProgress));
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _isBootstrapping = false;
      });
    }
  }

  GlobalKey _keyForChapter(int chapterIndex) {
    return _chapterKeys.putIfAbsent(chapterIndex, GlobalKey.new);
  }

  List<Chapter> _loadedChapters() {
    if (!_hasLoadedContent) {
      return const <Chapter>[];
    }

    return <Chapter>[
      for (int index = _startIndex; index <= _endIndex; index++)
        widget.book.chapters[index],
    ];
  }

  void _syncCacheWindow() {
    widget.bookService.trimCachedChapters(_loadedChapters());
  }

  void _handleScroll() {
    if (_isBootstrapping ||
        _isRestoringPosition ||
        !_scrollController.hasClients) {
      return;
    }

    _updateCurrentChapterFromViewport();
    _scheduleProgressSave();
    unawaited(_maybeLoadNextChapter());
    unawaited(_maybeLoadPreviousChapter());
  }

  Future<void> _maybeLoadNextChapter() async {
    if (_isLoadingNextChapter ||
        !_hasMoreNext ||
        !_scrollController.hasClients ||
        _scrollController.position.extentAfter > 900) {
      return;
    }

    _isLoadingNextChapter = true;
    final int nextIndex = _endIndex + 1;

    try {
      final String content = await widget.bookService.readChapterContent(
        widget.book.chapters[nextIndex],
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _chapterContents[nextIndex] = content;
        _endIndex = nextIndex;
      });
      _trimLoadedWindowFromTop();
      _syncCacheWindow();
    } finally {
      _isLoadingNextChapter = false;
    }
  }

  Future<void> _maybeLoadPreviousChapter() async {
    if (_isLoadingPreviousChapter ||
        !_hasMorePrevious ||
        !_scrollController.hasClients ||
        _scrollController.position.pixels > 260) {
      return;
    }

    _isLoadingPreviousChapter = true;
    final int previousIndex = _startIndex - 1;
    final double previousOffset = _scrollController.position.pixels;
    final double previousMaxExtent = _scrollController.position.maxScrollExtent;

    try {
      final String content = await widget.bookService.readChapterContent(
        widget.book.chapters[previousIndex],
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _chapterContents[previousIndex] = content;
        _startIndex = previousIndex;
      });
      _trimLoadedWindowFromBottom();
      _syncCacheWindow();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) {
          return;
        }

        final double delta =
            _scrollController.position.maxScrollExtent - previousMaxExtent;
        final double targetOffset = _clampDouble(
          previousOffset + delta,
          0,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.jumpTo(targetOffset);
      });
    } finally {
      _isLoadingPreviousChapter = false;
    }
  }

  void _trimLoadedWindowFromTop() {
    if (_loadedChapterCount <= _maxActiveChapters ||
        _currentChapterIndex - _startIndex < 3) {
      return;
    }

    final int dropIndex = _startIndex;
    final BuildContext? chapterContext =
        _chapterKeys[dropIndex]?.currentContext;
    final RenderBox? chapterBox =
        chapterContext?.findRenderObject() as RenderBox?;
    final double currentOffset =
        _scrollController.hasClients ? _scrollController.offset : 0;
    final double removedExtent =
        (chapterBox?.size.height ?? 0) + _chapterCardSpacing;

    setState(() {
      _chapterContents.remove(dropIndex);
      _chapterKeys.remove(dropIndex);
      _startIndex = dropIndex + 1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      final double targetOffset = _clampDouble(
        currentOffset - removedExtent,
        0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(targetOffset);
    });
  }

  void _trimLoadedWindowFromBottom() {
    if (_loadedChapterCount <= _maxActiveChapters ||
        _endIndex - _currentChapterIndex < 3) {
      return;
    }

    final int dropIndex = _endIndex;
    setState(() {
      _chapterContents.remove(dropIndex);
      _chapterKeys.remove(dropIndex);
      _endIndex = dropIndex - 1;
    });
  }

  void _updateCurrentChapterFromViewport() {
    final int? visibleIndex = _detectCurrentChapterIndex();
    if (visibleIndex == null || visibleIndex == _currentChapterIndex) {
      return;
    }

    setState(() {
      _currentChapterIndex = visibleIndex;
    });
  }

  int? _detectCurrentChapterIndex() {
    final BuildContext? viewportContext = _viewportKey.currentContext;
    if (viewportContext == null) {
      return null;
    }

    final RenderBox? viewportBox =
        viewportContext.findRenderObject() as RenderBox?;
    if (viewportBox == null) {
      return null;
    }

    final double viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    const double anchorOffset = 24;

    int? activeIndex;
    for (int index = _startIndex; index <= _endIndex; index++) {
      final BuildContext? chapterContext = _chapterKeys[index]?.currentContext;
      final RenderBox? chapterBox =
          chapterContext?.findRenderObject() as RenderBox?;
      if (chapterBox == null) {
        continue;
      }

      final double chapterTop = chapterBox.localToGlobal(Offset.zero).dy;
      if (chapterTop <= viewportTop + anchorOffset) {
        activeIndex = index;
      } else {
        break;
      }
    }

    return activeIndex ?? (_hasLoadedContent ? _startIndex : null);
  }

  ReadingProgress? _captureCurrentProgress() {
    final BuildContext? viewportContext = _viewportKey.currentContext;
    if (viewportContext == null || !_hasLoadedContent) {
      return null;
    }

    final RenderBox? viewportBox =
        viewportContext.findRenderObject() as RenderBox?;
    if (viewportBox == null) {
      return null;
    }

    final int activeIndex =
        _detectCurrentChapterIndex() ?? _currentChapterIndex;
    final BuildContext? chapterContext =
        _chapterKeys[activeIndex]?.currentContext;
    final RenderBox? chapterBox =
        chapterContext?.findRenderObject() as RenderBox?;
    if (chapterBox == null) {
      return null;
    }

    final double viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    const double anchorOffset = 24;
    final double chapterTop = chapterBox.localToGlobal(Offset.zero).dy;
    final double offsetInsideChapter = _clampDouble(
      viewportTop + anchorOffset - chapterTop,
      0,
      chapterBox.size.height,
    );
    final double normalized = chapterBox.size.height <= 0
        ? 0
        : offsetInsideChapter / chapterBox.size.height;

    return ReadingProgress(
      chapterIndex: activeIndex,
      chapterOffset: offsetInsideChapter,
      chapterProgress: normalized,
      savedAt: DateTime.now(),
    );
  }

  void _scheduleProgressSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_persistProgress());
    });
  }

  Future<void> _persistProgress() async {
    final ReadingProgress? progress = _captureCurrentProgress();
    if (progress == null) {
      return;
    }

    _currentChapterIndex = progress.chapterIndex;
    await widget.progressService.saveProgress(widget.book.id, progress);
  }

  Future<void> _restoreSavedPosition(
    ReadingProgress progress, [
    int attempt = 0,
  ]) async {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    final BuildContext? viewportContext = _viewportKey.currentContext;
    final BuildContext? chapterContext =
        _chapterKeys[progress.chapterIndex]?.currentContext;

    if (viewportContext == null || chapterContext == null) {
      if (attempt < 6) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _restoreSavedPosition(progress, attempt + 1),
        );
      }
      return;
    }

    final RenderBox? viewportBox =
        viewportContext.findRenderObject() as RenderBox?;
    final RenderBox? chapterBox =
        chapterContext.findRenderObject() as RenderBox?;
    if (viewportBox == null || chapterBox == null) {
      if (attempt < 6) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _restoreSavedPosition(progress, attempt + 1),
        );
      }
      return;
    }

    final double viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final double chapterTop = chapterBox.localToGlobal(Offset.zero).dy;
    final double desiredOffsetWithinChapter = chapterBox.size.height > 0
        ? chapterBox.size.height * progress.chapterProgress
        : progress.chapterOffset;
    final double deltaToChapter =
        chapterTop - viewportTop - 24 + desiredOffsetWithinChapter;

    final double targetOffset = _clampDouble(
      _scrollController.offset + deltaToChapter,
      0,
      _scrollController.position.maxScrollExtent,
    );

    _isRestoringPosition = true;
    _scrollController.jumpTo(targetOffset);
    _isRestoringPosition = false;
  }

  Future<void> _scrollToChapterTop(int chapterIndex, [int attempt = 0]) async {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    final BuildContext? viewportContext = _viewportKey.currentContext;
    final BuildContext? chapterContext =
        _chapterKeys[chapterIndex]?.currentContext;
    if (viewportContext == null || chapterContext == null) {
      if (attempt < 6) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToChapterTop(chapterIndex, attempt + 1),
        );
      }
      return;
    }

    final RenderBox? viewportBox =
        viewportContext.findRenderObject() as RenderBox?;
    final RenderBox? chapterBox =
        chapterContext.findRenderObject() as RenderBox?;
    if (viewportBox == null || chapterBox == null) {
      if (attempt < 6) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToChapterTop(chapterIndex, attempt + 1),
        );
      }
      return;
    }

    final double viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final double chapterTop = chapterBox.localToGlobal(Offset.zero).dy;
    final double targetOffset = _clampDouble(
      _scrollController.offset + (chapterTop - viewportTop - 12),
      0,
      _scrollController.position.maxScrollExtent,
    );

    _isRestoringPosition = true;
    _scrollController.jumpTo(targetOffset);
    _isRestoringPosition = false;
  }

  Future<void> _primeViewportIfNeeded() async {
    if (!_scrollController.hasClients || !_hasMoreNext) {
      return;
    }

    while (_scrollController.position.extentAfter < 600 && _hasMoreNext) {
      await _maybeLoadNextChapter();
      if (!mounted) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _jumpToChapter(int chapterIndex) async {
    _resetTransientSelection();
    final int start = math.max(0, chapterIndex - 1);
    final int end = math.min(widget.book.chapterCount - 1, chapterIndex + 1);
    final Map<int, String> selectedContents = <int, String>{};

    for (int index = start; index <= end; index++) {
      selectedContents[index] = _chapterContents[index] ??
          await widget.bookService
              .readChapterContent(widget.book.chapters[index]);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _chapterContents
        ..clear()
        ..addAll(selectedContents);
      _chapterKeys.clear();
      _startIndex = start;
      _endIndex = end;
      _currentChapterIndex = chapterIndex;
    });
    _syncCacheWindow();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_scrollToChapterTop(chapterIndex));
      unawaited(_primeViewportIfNeeded());
    });
    _scheduleProgressSave();
  }

  Future<void> _openChapterSearch() async {
    final Chapter? chapter = await showSearch<Chapter?>(
      context: context,
      delegate: _ChapterSearchDelegate(widget.book.chapters),
    );
    if (chapter == null) {
      return;
    }
    await _jumpToChapter(chapter.index);
  }

  Future<void> _openContentSearch() async {
    final int? chapterIndex = await showSearch<int?>(
      context: context,
      delegate: _BookContentSearchDelegate(
        book: widget.book,
        search: (String query) {
          return widget.bookService.searchBookContent(widget.book, query);
        },
      ),
    );
    if (chapterIndex == null) {
      return;
    }
    await _jumpToChapter(chapterIndex);
  }

  Future<void> _refreshBookmarks() async {
    final List<ReaderBookmark> bookmarks =
        await widget.bookmarkService.loadBookmarks(widget.book.id);
    if (!mounted) {
      return;
    }

    setState(() {
      _bookmarks = bookmarks
        ..sort((ReaderBookmark a, ReaderBookmark b) {
          return b.createdAt.compareTo(a.createdAt);
        });
    });
  }

  Future<void> _refreshAnnotations() async {
    final List<ReaderAnnotation> annotations =
        await widget.annotationService.loadAnnotations(widget.book.id);
    if (!mounted) {
      return;
    }

    setState(() {
      _annotations = annotations
        ..sort((ReaderAnnotation a, ReaderAnnotation b) {
          if (a.chapterIndex != b.chapterIndex) {
            return a.chapterIndex.compareTo(b.chapterIndex);
          }
          return a.startOffset.compareTo(b.startOffset);
        });
    });
  }

  SelectionListenerNotifier _notifierForChapter(int chapterIndex) {
    return _selectionNotifiers.putIfAbsent(
      chapterIndex,
      SelectionListenerNotifier.new,
    );
  }

  SelectedContentRange? _selectedRangeForChapter(int chapterIndex) {
    final SelectionListenerNotifier? notifier =
        _selectionNotifiers[chapterIndex];
    if (notifier == null || !notifier.registered) {
      return null;
    }
    return notifier.selection.range;
  }

  _ChapterSelectionSnapshot? _selectionSnapshotForChapter(int chapterIndex) {
    final String selectedText =
        (_selectedTextByChapter[chapterIndex] ?? '').trim();
    final SelectedContentRange? range = _selectedRangeForChapter(chapterIndex);
    if (selectedText.isEmpty ||
        range == null ||
        range.startOffset == range.endOffset) {
      return null;
    }

    return _ChapterSelectionSnapshot(
      chapterIndex: chapterIndex,
      selectedText: selectedText,
      startOffset: math.min(range.startOffset, range.endOffset),
      endOffset: math.max(range.startOffset, range.endOffset),
    );
  }

  void _resetTransientSelection() {
    if (!mounted) {
      return;
    }

    final List<SelectionListenerNotifier> staleNotifiers =
        _selectionNotifiers.values.toList(growable: false);
    _selectionNotifiers.clear();

    setState(() {
      _selectedTextByChapter.clear();
      _pendingSecondaryHighlightChapter = null;
      _selectionResetVersion++;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final SelectionListenerNotifier notifier in staleNotifiers) {
        notifier.dispose();
      }
    });
  }

  bool _shouldUseSecondaryClickShortcut(BuildContext context) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  Future<void> _saveSelectionAsAnnotationFromSnapshot(
    _ChapterSelectionSnapshot snapshot, {
    required bool withNote,
  }) async {
    final Chapter chapter = widget.book.chapters[snapshot.chapterIndex];
    final ReaderAnnotation? annotation = withNote
        ? await _showAnnotationDialog(
            chapterIndex: snapshot.chapterIndex,
            chapter: chapter,
            selectedText: snapshot.selectedText,
            startOffset: snapshot.startOffset,
            endOffset: snapshot.endOffset,
            requireNote: true,
          )
        : ReaderAnnotation(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            bookId: widget.book.id,
            chapterIndex: snapshot.chapterIndex,
            chapterTitle: chapter.title,
            startOffset: snapshot.startOffset,
            endOffset: snapshot.endOffset,
            selectedText: snapshot.selectedText,
            createdAt: DateTime.now(),
            color: ReaderHighlightColor.amber,
          );
    if (annotation == null) {
      return;
    }

    await widget.annotationService.saveAnnotation(annotation);
    await _refreshAnnotations();
    _resetTransientSelection();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          withNote ? 'Anotacao salva.' : 'Trecho destacado com sucesso.',
        ),
      ),
    );
  }

  Future<ReaderAnnotation?> _showAnnotationDialog({
    required int chapterIndex,
    required Chapter chapter,
    required String selectedText,
    required int startOffset,
    required int endOffset,
    required bool requireNote,
    ReaderAnnotation? existing,
  }) async {
    final TextEditingController noteController = TextEditingController(
      text: existing?.note ?? '',
    );
    ReaderHighlightColor selectedColor =
        existing?.color ?? ReaderHighlightColor.amber;

    final ReaderAnnotation? result = await showDialog<ReaderAnnotation>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title:
                  Text(existing == null ? 'Nova anotacao' : 'Editar anotacao'),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        chapter.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selectedColor.backgroundColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(selectedText),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final ReaderHighlightColor color
                              in ReaderHighlightColor.values)
                            ChoiceChip(
                              label: Text(color.label),
                              selected: selectedColor == color,
                              onSelected: (bool selected) {
                                if (!selected) {
                                  return;
                                }
                                setState(() {
                                  selectedColor = color;
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: noteController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Comentario',
                          hintText: 'Escreva sua observacao sobre este trecho',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final String note = noteController.text.trim();
                    if (requireNote && note.isEmpty) {
                      return;
                    }
                    final DateTime now = DateTime.now();
                    Navigator.of(context).pop(
                      ReaderAnnotation(
                        id: existing?.id ??
                            now.microsecondsSinceEpoch.toString(),
                        bookId: widget.book.id,
                        chapterIndex: chapterIndex,
                        chapterTitle: chapter.title,
                        startOffset: startOffset,
                        endOffset: endOffset,
                        selectedText: selectedText,
                        createdAt: existing?.createdAt ?? now,
                        color: selectedColor,
                        note: note,
                      ),
                    );
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    noteController.dispose();
    return result;
  }

  Future<void> _deleteAnnotation(ReaderAnnotation annotation) async {
    await widget.annotationService
        .removeAnnotation(widget.book.id, annotation.id);
    await _refreshAnnotations();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Anotacao removida.')),
    );
  }

  Future<void> _editAnnotation(ReaderAnnotation annotation) async {
    final ReaderAnnotation? updated = await _showAnnotationDialog(
      chapterIndex: annotation.chapterIndex,
      chapter: widget.book.chapters[annotation.chapterIndex],
      selectedText: annotation.selectedText,
      startOffset: annotation.startOffset,
      endOffset: annotation.endOffset,
      requireNote: false,
      existing: annotation,
    );
    if (updated == null) {
      return;
    }

    await widget.annotationService.saveAnnotation(updated);
    await _refreshAnnotations();
  }

  Future<void> _jumpToAnnotation(ReaderAnnotation annotation) async {
    await _jumpToChapter(annotation.chapterIndex);
    final String content = _chapterContents[annotation.chapterIndex] ?? '';
    final double progress = content.isEmpty
        ? 0
        : annotation.startOffset.clamp(0, content.length) / content.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _restoreSavedPosition(
          ReadingProgress(
            chapterIndex: annotation.chapterIndex,
            chapterOffset: 0,
            chapterProgress: progress,
            savedAt: annotation.createdAt,
          ),
        ),
      );
    });
  }

  Future<void> _showAddBookmarkDialog([ReaderBookmark? existing]) async {
    final ReadingProgress? progress = _captureCurrentProgress();
    final int chapterIndex = existing?.chapterIndex ??
        progress?.chapterIndex ??
        _currentChapterIndex;
    final Chapter chapter = widget.book.chapters[chapterIndex];
    final TextEditingController noteController = TextEditingController(
      text: existing?.note ?? '',
    );
    final TextEditingController excerptController = TextEditingController(
      text: existing?.excerpt ?? '',
    );
    bool isFavorite = existing?.isFavorite ?? false;

    final ReaderBookmark? bookmark = await showDialog<ReaderBookmark>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text(
                existing == null ? 'Novo marcador' : 'Editar marcador',
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        chapter.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: excerptController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Trecho importante',
                          hintText: 'Cole ou escreva um trecho para lembrar',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Anotacao',
                          hintText: 'O que voce quer lembrar deste ponto?',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Marcar como favorito'),
                        value: isFavorite,
                        onChanged: (bool value) {
                          setState(() {
                            isFavorite = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final DateTime now = DateTime.now();
                    Navigator.of(context).pop(
                      ReaderBookmark(
                        id: existing?.id ??
                            now.microsecondsSinceEpoch.toString(),
                        bookId: widget.book.id,
                        chapterIndex: chapterIndex,
                        chapterTitle: chapter.title,
                        chapterProgress: existing?.chapterProgress ??
                            progress?.chapterProgress ??
                            0,
                        createdAt: existing?.createdAt ?? now,
                        note: noteController.text.trim(),
                        excerpt: excerptController.text.trim(),
                        isFavorite: isFavorite,
                      ),
                    );
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    noteController.dispose();
    excerptController.dispose();
    if (bookmark == null) {
      return;
    }

    await widget.bookmarkService.saveBookmark(bookmark);
    await _refreshBookmarks();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marcador salvo.')),
    );
  }

  Future<void> _deleteBookmark(ReaderBookmark bookmark) async {
    await widget.bookmarkService.removeBookmark(widget.book.id, bookmark.id);
    await _refreshBookmarks();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marcador removido.')),
    );
  }

  Future<void> _jumpToBookmark(ReaderBookmark bookmark) async {
    await _jumpToChapter(bookmark.chapterIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _restoreSavedPosition(
          ReadingProgress(
            chapterIndex: bookmark.chapterIndex,
            chapterOffset: 0,
            chapterProgress: bookmark.chapterProgress,
            savedAt: bookmark.createdAt,
          ),
        ),
      );
    });
  }

  List<ReaderAnnotation> _annotationsForChapter(int chapterIndex) {
    return _annotations
        .where((ReaderAnnotation annotation) =>
            annotation.chapterIndex == chapterIndex)
        .toList(growable: false);
  }

  List<InlineSpan> _buildAnnotatedSpans(
    String content,
    List<ReaderAnnotation> annotations,
    TextStyle baseStyle,
  ) {
    if (annotations.isEmpty) {
      return <InlineSpan>[TextSpan(text: content, style: baseStyle)];
    }

    final List<ReaderAnnotation> sorted =
        List<ReaderAnnotation>.from(annotations)
          ..sort((ReaderAnnotation a, ReaderAnnotation b) {
            final int startComparison = a.startOffset.compareTo(b.startOffset);
            if (startComparison != 0) {
              return startComparison;
            }
            return a.endOffset.compareTo(b.endOffset);
          });

    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;
    for (final ReaderAnnotation annotation in sorted) {
      final int start = annotation.startOffset.clamp(0, content.length);
      final int end = annotation.endOffset.clamp(0, content.length);
      if (start >= end || start < cursor) {
        continue;
      }

      if (cursor < start) {
        spans.add(
          TextSpan(
            text: content.substring(cursor, start),
            style: baseStyle,
          ),
        );
      }

      spans.add(
        TextSpan(
          text: content.substring(start, end),
          style: baseStyle.copyWith(
            backgroundColor: annotation.color.backgroundColor,
            decoration: (annotation.note?.trim().isNotEmpty ?? false)
                ? TextDecoration.underline
                : TextDecoration.none,
            decorationColor: annotation.color.accentColor,
            decorationThickness: 1.6,
          ),
        ),
      );
      cursor = end;
    }

    if (cursor < content.length) {
      spans.add(
        TextSpan(
          text: content.substring(cursor),
          style: baseStyle,
        ),
      );
    }

    return spans;
  }

  Future<void> _openSettings() async {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return ReaderSettings(
          preferences: _preferences,
          isDarkMode: isDarkMode,
          onPreferencesChanged: (ReaderPreferences preferences) {
            setState(() {
              _preferences = preferences;
            });
            unawaited(
                widget.progressService.saveReaderPreferences(preferences));
            unawaited(widget.onFontSizeChanged(preferences.fontSize));
            unawaited(widget.onReaderFontPresetChanged(preferences.fontPreset));
            _scheduleProgressSave();
          },
          onDarkModeChanged: (bool enabled) {
            unawaited(
                _applyThemeMode(enabled ? ThemeMode.dark : ThemeMode.light));
          },
        );
      },
    );
  }

  Future<void> _applyThemeMode(ThemeMode themeMode) async {
    ReaderPreferences nextPreferences = _preferences;
    final bool wantsDarkMode = themeMode == ThemeMode.dark;
    if (_preferences.backgroundPreset.isDark != wantsDarkMode) {
      nextPreferences = _preferences.copyWith(
        backgroundPreset: wantsDarkMode
            ? ReaderBackgroundPreset.graphite
            : ReaderBackgroundPreset.parchment,
      );
    }

    if (nextPreferences != _preferences) {
      setState(() {
        _preferences = nextPreferences;
      });
      await widget.progressService.saveReaderPreferences(nextPreferences);
    }

    await widget.onThemeModeChanged(themeMode);
  }

  void _toggleFocusMode() {
    setState(() {
      _isFocusMode = !_isFocusMode;
    });
  }

  void _resumeReadingSession() {
    _readingSessionStartedAt ??= DateTime.now();
  }

  Future<void> _flushReadingSession() async {
    final DateTime? startedAt = _readingSessionStartedAt;
    if (startedAt == null) {
      return;
    }

    _readingSessionStartedAt = null;
    final Duration duration = DateTime.now().difference(startedAt);
    if (duration.inSeconds < 5) {
      return;
    }

    await widget.readingStatsService.recordReadingSession(
      widget.book.id,
      duration,
      chapterIndex: _currentChapterIndex,
    );
  }

  double _clampDouble(double value, double min, double max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ReaderBackgroundPreset backgroundPreset =
        _preferences.backgroundPreset;
    final double progressValue = widget.book.chapterCount == 0
        ? 0
        : (_currentChapterIndex + 1) / widget.book.chapterCount;
    final TextStyle readerTextStyle =
        _preferences.fontPreset.applyTo(theme.textTheme.bodyLarge).copyWith(
              fontSize: _preferences.fontSize,
              height: _preferences.lineHeight,
              letterSpacing: 0.15,
              color: backgroundPreset.primaryTextColor,
            );

    if (_isBootstrapping) {
      return Scaffold(
        backgroundColor: backgroundPreset.scaffoldColor,
        appBar: AppBar(title: Text(widget.book.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: backgroundPreset.scaffoldColor,
        appBar: AppBar(title: Text(widget.book.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: backgroundPreset.primaryTextColor,
              ),
            ),
          ),
        ),
      );
    }

    final Widget readerBody = ListView.builder(
      key: _viewportKey,
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        _preferences.horizontalPadding,
        _isFocusMode ? 32 : 24,
        _preferences.horizontalPadding,
        _isFocusMode ? 100 : 120,
      ),
      itemCount: _loadedChapterCount + (_hasMoreNext ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (_hasMoreNext && index == _loadedChapterCount) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                _isLoadingNextChapter
                    ? 'Carregando proximo capitulo...'
                    : 'Role mais para continuar lendo',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: backgroundPreset.secondaryTextColor,
                ),
              ),
            ),
          );
        }

        final int chapterIndex = _startIndex + index;
        final Chapter chapter = widget.book.chapters[chapterIndex];
        final String content = _chapterContents[chapterIndex] ?? '';
        final List<ReaderAnnotation> chapterAnnotations =
            _annotationsForChapter(chapterIndex);

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _preferences.contentWidth),
            child: Container(
              key: _keyForChapter(chapterIndex),
              margin: const EdgeInsets.only(bottom: _chapterCardSpacing),
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
              decoration: BoxDecoration(
                color: backgroundPreset.surfaceColor,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    chapter.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: backgroundPreset.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onSecondaryTapDown: (_) {
                      if (_shouldUseSecondaryClickShortcut(context) &&
                          _selectionSnapshotForChapter(chapterIndex) != null) {
                        _pendingSecondaryHighlightChapter = chapterIndex;
                      } else {
                        _pendingSecondaryHighlightChapter = null;
                      }
                    },
                    child: SelectionArea(
                      key: ValueKey<String>(
                        'selection-$chapterIndex-$_selectionResetVersion',
                      ),
                      onSelectionChanged: (SelectedContent? selectedContent) {
                        final String selectedText =
                            selectedContent?.plainText.trim() ?? '';
                        if (selectedText.isEmpty) {
                          _selectedTextByChapter.remove(chapterIndex);
                        } else {
                          _selectedTextByChapter[chapterIndex] = selectedText;
                        }
                      },
                      contextMenuBuilder: (
                        BuildContext context,
                        SelectableRegionState selectableRegionState,
                      ) {
                        final _ChapterSelectionSnapshot? snapshot =
                            _selectionSnapshotForChapter(chapterIndex);
                        final bool shouldAutoHighlight =
                            _pendingSecondaryHighlightChapter == chapterIndex &&
                                _shouldUseSecondaryClickShortcut(context) &&
                                snapshot != null;
                        if (shouldAutoHighlight) {
                          _pendingSecondaryHighlightChapter = null;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            ContextMenuController.removeAny();
                            selectableRegionState.clearSelection();
                            unawaited(
                              _saveSelectionAsAnnotationFromSnapshot(
                                snapshot,
                                withNote: false,
                              ),
                            );
                          });
                          return const SizedBox.shrink();
                        }

                        final List<ContextMenuButtonItem> buttonItems =
                            List<ContextMenuButtonItem>.from(
                          selectableRegionState.contextMenuButtonItems,
                        );
                        if (snapshot != null) {
                          buttonItems.addAll(<ContextMenuButtonItem>[
                            ContextMenuButtonItem(
                              label: 'Destacar',
                              onPressed: () {
                                ContextMenuController.removeAny();
                                selectableRegionState.clearSelection();
                                unawaited(
                                  _saveSelectionAsAnnotationFromSnapshot(
                                    snapshot,
                                    withNote: false,
                                  ),
                                );
                              },
                            ),
                            ContextMenuButtonItem(
                              label: 'Anotar',
                              onPressed: () {
                                ContextMenuController.removeAny();
                                selectableRegionState.clearSelection();
                                unawaited(
                                  _saveSelectionAsAnnotationFromSnapshot(
                                    snapshot,
                                    withNote: true,
                                  ),
                                );
                              },
                            ),
                          ]);
                        }

                        return AdaptiveTextSelectionToolbar.buttonItems(
                          anchors: selectableRegionState.contextMenuAnchors,
                          buttonItems: buttonItems,
                        );
                      },
                      child: SelectionListener(
                        selectionNotifier: _notifierForChapter(chapterIndex),
                        child: Text.rich(
                          TextSpan(
                            children: _buildAnnotatedSpans(
                              content,
                              chapterAnnotations,
                              readerTextStyle,
                            ),
                          ),
                          textAlign: _preferences.textAlignPreset.textAlign,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundPreset.scaffoldColor,
      appBar: _isFocusMode
          ? null
          : AppBar(
              backgroundColor: backgroundPreset.scaffoldColor,
              foregroundColor: backgroundPreset.primaryTextColor,
              titleSpacing: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(widget.book.title),
                  Text(
                    'Capitulo ${_currentChapterIndex + 1} de ${widget.book.chapterCount}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: backgroundPreset.secondaryTextColor,
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: backgroundPreset.surfaceColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${(progressValue * 100).round()}%',
                        style:
                            TextStyle(color: backgroundPreset.primaryTextColor),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Buscar no conteudo',
                  onPressed: _openContentSearch,
                  icon: const Icon(Icons.search_rounded),
                ),
                IconButton(
                  tooltip: 'Buscar capitulos',
                  onPressed: _openChapterSearch,
                  icon: const Icon(Icons.subject_rounded),
                ),
                IconButton(
                  tooltip: 'Novo marcador',
                  onPressed: () => _showAddBookmarkDialog(),
                  icon: const Icon(Icons.bookmark_add_outlined),
                ),
                IconButton(
                  tooltip: 'Capitulos e marcadores',
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  icon: const Icon(Icons.list_rounded),
                ),
                IconButton(
                  tooltip: Theme.of(context).brightness == Brightness.dark
                      ? 'Modo claro'
                      : 'Modo escuro',
                  onPressed: () {
                    unawaited(
                      _applyThemeMode(
                        Theme.of(context).brightness == Brightness.dark
                            ? ThemeMode.light
                            : ThemeMode.dark,
                      ),
                    );
                  },
                  icon: Icon(
                    Theme.of(context).brightness == Brightness.dark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                  ),
                ),
                IconButton(
                  tooltip: _isFocusMode ? 'Sair do foco' : 'Modo foco',
                  onPressed: _toggleFocusMode,
                  icon: Icon(
                    _isFocusMode
                        ? Icons.center_focus_weak_rounded
                        : Icons.center_focus_strong_rounded,
                  ),
                ),
                IconButton(
                  tooltip: 'Configuracoes',
                  onPressed: _openSettings,
                  icon: const Icon(Icons.tune_rounded),
                ),
                const SizedBox(width: 4),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  value: _clampDouble(progressValue, 0, 1),
                  backgroundColor: backgroundPreset.surfaceColor,
                ),
              ),
            ),
      endDrawer: _isFocusMode
          ? null
          : _ReaderSidePanel(
              book: widget.book,
              currentChapterIndex: _currentChapterIndex,
              progressValue: progressValue,
              bookmarks: _bookmarks,
              annotations: _annotations.reversed.toList(growable: false),
              onJumpToChapter: (int chapterIndex) {
                Navigator.of(context).pop();
                unawaited(_jumpToChapter(chapterIndex));
              },
              onJumpToBookmark: (ReaderBookmark bookmark) {
                Navigator.of(context).pop();
                unawaited(_jumpToBookmark(bookmark));
              },
              onEditBookmark: (ReaderBookmark bookmark) {
                Navigator.of(context).pop();
                unawaited(_showAddBookmarkDialog(bookmark));
              },
              onDeleteBookmark: (ReaderBookmark bookmark) {
                Navigator.of(context).pop();
                unawaited(_deleteBookmark(bookmark));
              },
              onJumpToAnnotation: (ReaderAnnotation annotation) {
                Navigator.of(context).pop();
                unawaited(_jumpToAnnotation(annotation));
              },
              onEditAnnotation: (ReaderAnnotation annotation) {
                Navigator.of(context).pop();
                unawaited(_editAnnotation(annotation));
              },
              onDeleteAnnotation: (ReaderAnnotation annotation) {
                Navigator.of(context).pop();
                unawaited(_deleteAnnotation(annotation));
              },
            ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: readerBody),
          if (_isFocusMode)
            Positioned(
              right: 18,
              bottom: 18,
              child: FilledButton.tonalIcon(
                onPressed: _toggleFocusMode,
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Sair do foco'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChapterSearchDelegate extends SearchDelegate<Chapter?> {
  _ChapterSearchDelegate(this.chapters);

  final List<Chapter> chapters;

  @override
  String get searchFieldLabel => 'Buscar capitulos';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return <Widget>[
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear_rounded),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final String normalizedQuery = query.trim().toLowerCase();
    final List<Chapter> matches = normalizedQuery.isEmpty
        ? chapters
        : chapters.where((Chapter chapter) {
            final String haystack =
                '${chapter.title} ${chapter.fileName}'.toLowerCase();
            return haystack.contains(normalizedQuery);
          }).toList(growable: false);

    if (matches.isEmpty) {
      return const Center(
        child: Text('Nenhum capitulo encontrado.'),
      );
    }

    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (BuildContext context, int index) {
        final Chapter chapter = matches[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 16,
            child: Text('${chapter.index + 1}'),
          ),
          title: Text(chapter.title),
          subtitle: Text(
            chapter.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => close(context, chapter),
        );
      },
    );
  }
}

class _BookContentSearchDelegate extends SearchDelegate<int?> {
  _BookContentSearchDelegate({
    required this.book,
    required this.search,
  });

  final Book book;
  final Future<List<BookSearchMatch>> Function(String query) search;

  @override
  String get searchFieldLabel => 'Buscar no conteudo do livro';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return <Widget>[
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear_rounded),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildAsyncResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().length < 2) {
      return const Center(
        child: Text('Digite ao menos 2 caracteres para buscar no livro.'),
      );
    }
    return _buildAsyncResults();
  }

  Widget _buildAsyncResults() {
    return FutureBuilder<List<BookSearchMatch>>(
      future: search(query),
      builder: (BuildContext context,
          AsyncSnapshot<List<BookSearchMatch>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<BookSearchMatch> matches =
            snapshot.data ?? const <BookSearchMatch>[];
        if (matches.isEmpty) {
          return const Center(
            child: Text('Nenhum trecho encontrado.'),
          );
        }

        return ListView.builder(
          itemCount: matches.length,
          itemBuilder: (BuildContext context, int index) {
            final BookSearchMatch match = matches[index];
            return ListTile(
              leading: CircleAvatar(
                radius: 16,
                child: Text('${match.chapterIndex + 1}'),
              ),
              title: Text(match.chapterTitle),
              subtitle: Text(
                '${match.matchCount} ocorrencias\n${match.snippet}',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
              onTap: () => close(context, match.chapterIndex),
            );
          },
        );
      },
    );
  }
}

class _ReaderSidePanel extends StatelessWidget {
  const _ReaderSidePanel({
    required this.book,
    required this.currentChapterIndex,
    required this.progressValue,
    required this.bookmarks,
    required this.annotations,
    required this.onJumpToChapter,
    required this.onJumpToBookmark,
    required this.onEditBookmark,
    required this.onDeleteBookmark,
    required this.onJumpToAnnotation,
    required this.onEditAnnotation,
    required this.onDeleteAnnotation,
  });

  final Book book;
  final int currentChapterIndex;
  final double progressValue;
  final List<ReaderBookmark> bookmarks;
  final List<ReaderAnnotation> annotations;
  final ValueChanged<int> onJumpToChapter;
  final ValueChanged<ReaderBookmark> onJumpToBookmark;
  final ValueChanged<ReaderBookmark> onEditBookmark;
  final ValueChanged<ReaderBookmark> onDeleteBookmark;
  final ValueChanged<ReaderAnnotation> onJumpToAnnotation;
  final ValueChanged<ReaderAnnotation> onEditAnnotation;
  final ValueChanged<ReaderAnnotation> onDeleteAnnotation;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(book.title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Capitulo atual: ${currentChapterIndex + 1}/${book.chapterCount}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: progressValue),
                    const SizedBox(height: 12),
                    const TabBar(
                      tabs: <Widget>[
                        Tab(text: 'Capitulos'),
                        Tab(text: 'Marcadores'),
                        Tab(text: 'Notas'),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    ListView.builder(
                      itemCount: book.chapterCount,
                      itemBuilder: (BuildContext context, int index) {
                        final Chapter chapter = book.chapters[index];
                        final bool isCurrent = index == currentChapterIndex;
                        return ListTile(
                          selected: isCurrent,
                          leading: CircleAvatar(
                            radius: 16,
                            child: Text('${index + 1}'),
                          ),
                          title: Text(
                            chapter.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle:
                              isCurrent ? const Text('Capitulo atual') : null,
                          onTap: () => onJumpToChapter(index),
                        );
                      },
                    ),
                    bookmarks.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Ainda nao ha marcadores neste livro.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: bookmarks.length,
                            itemBuilder: (BuildContext context, int index) {
                              final ReaderBookmark bookmark = bookmarks[index];
                              final String detail =
                                  (bookmark.note?.trim().isNotEmpty ?? false)
                                      ? bookmark.note!.trim()
                                      : (bookmark.excerpt?.trim().isNotEmpty ??
                                              false)
                                          ? bookmark.excerpt!.trim()
                                          : 'Sem anotacao';
                              return ListTile(
                                leading: Icon(
                                  bookmark.isFavorite
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded,
                                ),
                                title: Text(bookmark.chapterTitle),
                                subtitle: Text(
                                  detail,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (String value) {
                                    if (value == 'edit') {
                                      onEditBookmark(bookmark);
                                    } else if (value == 'delete') {
                                      onDeleteBookmark(bookmark);
                                    }
                                  },
                                  itemBuilder: (BuildContext context) {
                                    return const <PopupMenuEntry<String>>[
                                      PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Text('Editar'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('Remover'),
                                      ),
                                    ];
                                  },
                                ),
                                onTap: () => onJumpToBookmark(bookmark),
                              );
                            },
                          ),
                    annotations.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Nenhum trecho destacado ainda.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: annotations.length,
                            itemBuilder: (BuildContext context, int index) {
                              final ReaderAnnotation annotation =
                                  annotations[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor:
                                      annotation.color.backgroundColor,
                                  child: Icon(
                                    Icons.edit_note_rounded,
                                    size: 18,
                                    color: annotation.color.accentColor,
                                  ),
                                ),
                                title: Text(annotation.chapterTitle),
                                subtitle: Text(
                                  '${annotation.selectedText}\n${(annotation.note?.trim().isNotEmpty ?? false) ? annotation.note!.trim() : 'Sem comentario'}',
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (String value) {
                                    if (value == 'edit') {
                                      onEditAnnotation(annotation);
                                    } else if (value == 'delete') {
                                      onDeleteAnnotation(annotation);
                                    }
                                  },
                                  itemBuilder: (BuildContext context) {
                                    return const <PopupMenuEntry<String>>[
                                      PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Text('Editar'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('Remover'),
                                      ),
                                    ];
                                  },
                                ),
                                onTap: () => onJumpToAnnotation(annotation),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterSelectionSnapshot {
  const _ChapterSelectionSnapshot({
    required this.chapterIndex,
    required this.selectedText,
    required this.startOffset,
    required this.endOffset,
  });

  final int chapterIndex;
  final String selectedText;
  final int startOffset;
  final int endOffset;
}
