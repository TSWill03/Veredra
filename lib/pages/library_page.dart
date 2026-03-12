// Signature: dev.tswicolly03
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/app_profile.dart';
import '../models/book.dart';
import '../models/book_format.dart';
import '../models/book_reference.dart';
import '../models/library_entry.dart';
import '../models/reader_font_preset.dart';
import '../models/translation_pair.dart';
import '../models/translation_progress.dart';
import '../services/annotation_service.dart';
import '../services/backup_service.dart';
import '../services/bookmark_service.dart';
import '../services/book_service.dart';
import '../services/library_service.dart';
import '../services/profile_service.dart';
import '../services/progress_service.dart';
import '../services/translation_service.dart';
import '../widgets/book_translation_dialog.dart';
import '../widgets/translation_progress_dialog.dart';
import 'pdf_reader_page.dart';
import 'reader_page.dart';

enum _LibraryFilter { all, favorites, recent }

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.currentProfile,
    required this.profileService,
    required this.backupService,
    required this.bookService,
    required this.annotationService,
    required this.bookmarkService,
    required this.libraryService,
    required this.progressService,
    required this.translationService,
    required this.lastBookReference,
    required this.fontSize,
    required this.readerFontPreset,
    required this.onThemeModeChanged,
    required this.onFontSizeChanged,
    required this.onReaderFontPresetChanged,
    required this.onProfileChanged,
    required this.onLastBookChanged,
  });

  final AppProfile currentProfile;
  final ProfileService profileService;
  final BackupService backupService;
  final BookService bookService;
  final AnnotationService annotationService;
  final BookmarkService bookmarkService;
  final LibraryService libraryService;
  final ProgressService progressService;
  final TranslationService translationService;
  final BookReference? lastBookReference;
  final double fontSize;
  final ReaderFontPreset readerFontPreset;
  final Future<void> Function(ThemeMode) onThemeModeChanged;
  final Future<void> Function(double) onFontSizeChanged;
  final Future<void> Function(ReaderFontPreset) onReaderFontPresetChanged;
  final Future<void> Function(AppProfile) onProfileChanged;
  final Future<void> Function(BookReference) onLastBookChanged;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _isBusy = false;
  bool _isLoadingEntries = true;
  bool _lastBookAvailable = false;
  List<LibraryEntry> _entries = const <LibraryEntry>[];
  _LibraryFilter _filter = _LibraryFilter.all;
  String _query = '';

  BookReference? get _lastBookReference => widget.lastBookReference;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _refreshLibrary();
    _refreshLastBookAvailability();
  }

  @override
  void didUpdateWidget(covariant LibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastBookReference != widget.lastBookReference ||
        oldWidget.currentProfile.id != widget.currentProfile.id) {
      _refreshLastBookAvailability();
      _refreshLibrary();
    }
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

  Future<void> _refreshLibrary() async {
    final List<LibraryEntry> entries =
        List<LibraryEntry>.from(await widget.libraryService.loadEntries());
    entries.sort((LibraryEntry a, LibraryEntry b) {
      final DateTime aMoment = a.lastOpenedAt ?? a.importedAt;
      final DateTime bMoment = b.lastOpenedAt ?? b.importedAt;
      return bMoment.compareTo(aMoment);
    });

    if (!mounted) {
      return;
    }

    setState(() {
      _entries = entries;
      _isLoadingEntries = false;
    });
  }

  Future<void> _refreshLastBookAvailability() async {
    final BookReference? reference = _lastBookReference;
    if (reference == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastBookAvailable = false;
      });
      return;
    }

    bool exists = false;
    if (reference.usesDirectory) {
      exists = await Directory(reference.directoryPath!).exists();
    } else {
      for (final String path in reference.assetPaths) {
        if (await File(path).exists()) {
          exists = true;
          break;
        }
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _lastBookAvailable = exists;
    });
  }

  Future<void> _runBusyTask(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await action();
      if (successMessage != null) {
        _showMessage(successMessage);
      }
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _importBook(ImportKind kind) async {
    await _runBusyTask(() async {
      final Book? book = await widget.bookService.importBook(kind);
      if (!mounted || book == null) {
        return;
      }

      await _openBook(book);
    });
  }

  Future<void> _continueLastBook() async {
    final BookReference? reference = _lastBookReference;
    if (reference == null) {
      return;
    }

    await _runBusyTask(() async {
      final Book book = await widget.bookService.reopenBook(reference);
      await _openBook(book);
      await _refreshLastBookAvailability();
    });
  }

  Future<void> _openLibraryEntry(LibraryEntry entry) async {
    await _runBusyTask(() async {
      final Book book = await widget.bookService.reopenBook(entry.reference);
      await _openBook(book);
    });
  }

  Future<void> _openBook(Book book) async {
    await widget.progressService.saveLastBookReference(book.reference);
    await widget.onLastBookChanged(book.reference);
    await widget.libraryService.upsertBook(book, markOpened: true);
    await _refreshLibrary();

    if (!mounted) {
      return;
    }

    final Widget destination = book.usesTextReader
        ? ReaderPage(
            book: book,
            bookService: widget.bookService,
            annotationService: widget.annotationService,
            bookmarkService: widget.bookmarkService,
            progressService: widget.progressService,
            initialFontSize: widget.fontSize,
            initialReaderFontPreset: widget.readerFontPreset,
            onThemeModeChanged: widget.onThemeModeChanged,
            onFontSizeChanged: widget.onFontSizeChanged,
            onReaderFontPresetChanged: widget.onReaderFontPresetChanged,
          )
        : PdfReaderPage(
            book: book,
            progressService: widget.progressService,
            onThemeModeChanged: widget.onThemeModeChanged,
          );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => destination,
      ),
    );

    await _refreshLibrary();
  }

  Future<void> _toggleFavorite(LibraryEntry entry) async {
    await widget.libraryService.toggleFavorite(entry.id);
    await _refreshLibrary();
  }

  Future<void> _renameEntry(LibraryEntry entry) async {
    final String? nextTitle = await _showTextInputDialog(
      title: 'Renomear livro',
      label: 'Novo nome',
      initialValue: entry.title,
    );
    final String? normalizedTitle = nextTitle?.trim();
    if (normalizedTitle == null ||
        normalizedTitle.isEmpty ||
        normalizedTitle == entry.title) {
      return;
    }

    await widget.libraryService.updateTitle(entry.id, normalizedTitle);
    await _syncLastBookReferenceIfNeeded(
      entry.reference,
      entry.reference.copyWith(title: normalizedTitle),
    );
    await _refreshLibrary();
    _showMessage('Livro renomeado com sucesso.');
  }

  Future<void> _editMetadata(LibraryEntry entry) async {
    final _MetadataFormResult? result =
        await _showMetadataDialog(entry.reference);
    if (result == null) {
      return;
    }

    await widget.libraryService.updateMetadata(
      entry.id,
      title: result.title,
      altTitle: result.altTitle,
      author: result.author,
      description: result.description,
      series: result.series,
      volume: result.volume,
      tags: result.tags,
    );

    await _syncLastBookReferenceIfNeeded(
      entry.reference,
      _applyMetadataToReference(entry.reference, result),
    );
    await _refreshLibrary();
    _showMessage('Metadados atualizados.');
  }

  Future<void> _changeCover(LibraryEntry entry) async {
    await _runBusyTask(() async {
      final String? coverPath =
          await widget.bookService.pickAndStoreCustomCover(
        bookId: entry.id,
      );
      if (coverPath == null) {
        return;
      }

      await widget.libraryService.updateCover(entry.id, coverPath);
      await _syncLastBookReferenceIfNeeded(
        entry.reference,
        entry.reference.copyWith(coverPath: coverPath),
      );
      await _refreshLibrary();
    }, successMessage: 'Capa atualizada com sucesso.');
  }

  Future<void> _adjustCoverFrame(LibraryEntry entry) async {
    if (!entry.reference.hasCover) {
      _showMessage('Adicione uma capa antes de ajustar o enquadramento.');
      return;
    }

    final _CoverFrameResult? result =
        await _showCoverFrameDialog(entry.reference);
    if (result == null) {
      return;
    }

    await widget.libraryService.updateCoverFrame(
      entry.id,
      coverZoom: result.coverZoom,
      coverAlignmentX: result.coverAlignmentX,
      coverAlignmentY: result.coverAlignmentY,
    );
    await _syncLastBookReferenceIfNeeded(
      entry.reference,
      entry.reference.copyWith(
        coverZoom: result.coverZoom,
        coverAlignmentX: result.coverAlignmentX,
        coverAlignmentY: result.coverAlignmentY,
      ),
    );
    await _refreshLibrary();
    _showMessage('Enquadramento da capa salvo.');
  }

  Future<void> _removeEntry(LibraryEntry entry) async {
    final bool confirmed = await _confirmRemoveEntry(entry);
    if (!confirmed) {
      return;
    }

    await widget.libraryService.remove(entry.id);
    await _refreshLibrary();
    _showMessage('Livro removido da biblioteca local.');
  }

  Future<void> _translateEntry(LibraryEntry entry) async {
    if (!entry.reference.usesTextReader) {
      _showMessage(
          'A traducao local do MVP funciona apenas em livros textuais e EPUB convertido.');
      return;
    }

    final TranslationPair? pair = await showDialog<TranslationPair>(
      context: context,
      builder: (BuildContext context) {
        return BookTranslationDialog(
          bookTitle: entry.title,
          translationService: widget.translationService,
        );
      },
    );
    if (pair == null || !mounted) {
      return;
    }

    final ValueNotifier<TranslationProgress> progressNotifier =
        ValueNotifier<TranslationProgress>(
      const TranslationProgress(
        stage: 'Preparando traducao',
        completedChapters: 0,
        totalChapters: 1,
      ),
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ValueListenableBuilder<TranslationProgress>(
          valueListenable: progressNotifier,
          builder: (
            BuildContext context,
            TranslationProgress value,
            Widget? child,
          ) {
            return TranslationProgressDialog(
              bookTitle: entry.title,
              progress: value,
            );
          },
        );
      },
    );

    try {
      final Book sourceBook =
          await widget.bookService.reopenBook(entry.reference);
      final Book translatedBook = await widget.translationService.translateBook(
        sourceBook: sourceBook,
        sourceLanguage: pair.source,
        targetLanguage: pair.target,
        bookService: widget.bookService,
        onProgress: (TranslationProgress value) {
          progressNotifier.value = value;
        },
      );

      await widget.libraryService.upsertBook(translatedBook);
      await _refreshLibrary();
      if (!mounted) {
        return;
      }
      final NavigatorState navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
      _showMessage(
        'Nova copia traduzida criada: ${translatedBook.title}',
      );
    } catch (error) {
      if (mounted) {
        final NavigatorState navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        }
        _showMessage(error.toString());
      }
    } finally {
      progressNotifier.dispose();
    }
  }

  Future<bool> _confirmRemoveEntry(LibraryEntry entry) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remover da biblioteca'),
          content: Text(
            'Isso remove "${entry.title}" da biblioteca do app, mas nao apaga os arquivos originais.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showImportOptions() async {
    final ImportKind? selectedKind = await showModalBottomSheet<ImportKind>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        final List<ImportOption> options =
            widget.bookService.getImportOptions();
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (final ImportOption option in options)
                ListTile(
                  leading: Icon(_iconForImportKind(option.kind)),
                  title: Text(option.label),
                  subtitle: Text(option.description),
                  onTap: () => Navigator.of(context).pop(option.kind),
                ),
            ],
          ),
        );
      },
    );

    if (selectedKind == null) {
      return;
    }

    await _importBook(selectedKind);
  }

  Future<void> _showProfileSheet() async {
    final List<AppProfile> profiles =
        await widget.profileService.loadProfiles();
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person_outline_rounded),
                ),
                title: Text(widget.currentProfile.name),
                subtitle: const Text('Perfil ativo'),
              ),
              const Divider(height: 1),
              for (final AppProfile profile in profiles)
                ListTile(
                  leading: Icon(
                    profile.id == widget.currentProfile.id
                        ? Icons.check_circle_rounded
                        : Icons.person_outline_rounded,
                  ),
                  title: Text(profile.name),
                  subtitle: Text(
                    profile.id == widget.currentProfile.id
                        ? 'Usando agora'
                        : 'Trocar para este perfil',
                  ),
                  enabled: profile.id != widget.currentProfile.id,
                  onTap: profile.id == widget.currentProfile.id
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          _switchProfile(profile);
                        },
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded),
                title: const Text('Criar novo perfil'),
                onTap: () {
                  Navigator.of(context).pop();
                  _createProfile();
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline_rounded),
                title: const Text('Renomear perfil atual'),
                onTap: () {
                  Navigator.of(context).pop();
                  _renameCurrentProfile();
                },
              ),
              ListTile(
                leading: const Icon(Icons.outbox_rounded),
                title: const Text('Exportar backup deste perfil'),
                onTap: () {
                  Navigator.of(context).pop();
                  _exportBackup();
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive_rounded),
                title: const Text('Importar backup como novo perfil'),
                onTap: () {
                  Navigator.of(context).pop();
                  _importBackup();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Remover perfil atual'),
                enabled: profiles.length > 1,
                onTap: profiles.length <= 1
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        _deleteCurrentProfile();
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _switchProfile(AppProfile profile) async {
    await _runBusyTask(() async {
      final AppProfile nextProfile =
          await widget.profileService.switchProfile(profile.id);
      await widget.onProfileChanged(nextProfile);
      await _refreshLibrary();
      await _refreshLastBookAvailability();
    }, successMessage: 'Perfil alterado para ${profile.name}.');
  }

  Future<void> _createProfile() async {
    final String? name = await _showTextInputDialog(
      title: 'Novo perfil',
      label: 'Nome do perfil',
      initialValue: '',
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }

    await _runBusyTask(() async {
      final AppProfile profile =
          await widget.profileService.createProfile(name);
      await widget.onProfileChanged(profile);
      await _refreshLibrary();
      await _refreshLastBookAvailability();
    }, successMessage: 'Perfil criado com sucesso.');
  }

  Future<void> _renameCurrentProfile() async {
    final String? name = await _showTextInputDialog(
      title: 'Renomear perfil',
      label: 'Nome do perfil',
      initialValue: widget.currentProfile.name,
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }

    await _runBusyTask(() async {
      final AppProfile updated = await widget.profileService.renameProfile(
        widget.currentProfile.id,
        name,
      );
      await widget.onProfileChanged(updated);
    }, successMessage: 'Perfil renomeado.');
  }

  Future<void> _deleteCurrentProfile() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remover perfil'),
          content: Text(
            'O perfil "${widget.currentProfile.name}" sera apagado deste aparelho. Os outros perfis permanecem intactos.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    await _runBusyTask(() async {
      await widget.profileService.deleteProfile(widget.currentProfile.id);
      final AppProfile nextProfile =
          await widget.profileService.loadCurrentProfile();
      await widget.onProfileChanged(nextProfile);
      await _refreshLibrary();
      await _refreshLastBookAvailability();
    }, successMessage: 'Perfil removido.');
  }

  Future<void> _exportBackup() async {
    await _runBusyTask(() async {
      final String? backupPath = await widget.backupService
          .exportCurrentProfile(widget.currentProfile);
      if (backupPath == null) {
        return;
      }
      _showMessage('Backup salvo em $backupPath');
    });
  }

  Future<void> _importBackup() async {
    await _runBusyTask(() async {
      final AppProfile? importedProfile =
          await widget.backupService.importProfileBackup();
      if (importedProfile == null) {
        return;
      }

      await widget.onProfileChanged(importedProfile);
      await _refreshLibrary();
      await _refreshLastBookAvailability();
    }, successMessage: 'Backup importado como novo perfil.');
  }

  Future<String?> _showTextInputDialog({
    required String title,
    required String label,
    required String initialValue,
  }) async {
    final TextEditingController controller =
        TextEditingController(text: initialValue);

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
            onSubmitted: (String value) {
              Navigator.of(context).pop(value.trim());
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<_MetadataFormResult?> _showMetadataDialog(
    BookReference reference,
  ) async {
    final TextEditingController titleController =
        TextEditingController(text: reference.title);
    final TextEditingController altTitleController =
        TextEditingController(text: reference.altTitle ?? '');
    final TextEditingController authorController =
        TextEditingController(text: reference.author ?? '');
    final TextEditingController seriesController =
        TextEditingController(text: reference.series ?? '');
    final TextEditingController volumeController =
        TextEditingController(text: reference.volume ?? '');
    final TextEditingController tagsController =
        TextEditingController(text: reference.tags.join(', '));
    final TextEditingController descriptionController =
        TextEditingController(text: reference.description ?? '');

    final _MetadataFormResult? result = await showDialog<_MetadataFormResult>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Editar metadados'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Titulo'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: altTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Nome alternativo',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: authorController,
                    decoration: const InputDecoration(labelText: 'Autor'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: seriesController,
                          decoration: const InputDecoration(
                            labelText: 'Serie',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: volumeController,
                          decoration: const InputDecoration(
                            labelText: 'Volume',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags',
                      hintText: 'fantasia, romance, cultivacao',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Descricao'),
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
                final String title = titleController.text.trim();
                if (title.isEmpty) {
                  return;
                }

                Navigator.of(context).pop(
                  _MetadataFormResult(
                    title: title,
                    altTitle: altTitleController.text.trim(),
                    author: authorController.text.trim(),
                    description: descriptionController.text.trim(),
                    series: seriesController.text.trim(),
                    volume: volumeController.text.trim(),
                    tags: tagsController.text
                        .split(RegExp(r'[,;]'))
                        .map((String value) => value.trim())
                        .where((String value) => value.isNotEmpty)
                        .toList(growable: false),
                  ),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    altTitleController.dispose();
    authorController.dispose();
    seriesController.dispose();
    volumeController.dispose();
    tagsController.dispose();
    descriptionController.dispose();
    return result;
  }

  Future<_CoverFrameResult?> _showCoverFrameDialog(
    BookReference reference,
  ) async {
    double coverZoom = reference.coverZoom;
    double coverAlignmentX = reference.coverAlignmentX;
    double coverAlignmentY = reference.coverAlignmentY;

    return showDialog<_CoverFrameResult>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final BookReference previewReference = reference.copyWith(
              coverZoom: coverZoom,
              coverAlignmentX: coverAlignmentX,
              coverAlignmentY: coverAlignmentY,
            );

            return AlertDialog(
              title: const Text('Ajustar capa'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: _BookCoverThumbnail(
                        reference: previewReference,
                        width: 170,
                        height: 240,
                        borderRadius: 24,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Zoom: ${coverZoom.toStringAsFixed(2)}x'),
                    Slider(
                      value: coverZoom,
                      min: 1,
                      max: 2.6,
                      divisions: 16,
                      onChanged: (double value) {
                        setState(() {
                          coverZoom = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Posicao horizontal: ${coverAlignmentX.toStringAsFixed(2)}',
                    ),
                    Slider(
                      value: coverAlignmentX,
                      min: -1,
                      max: 1,
                      divisions: 20,
                      onChanged: (double value) {
                        setState(() {
                          coverAlignmentX = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Posicao vertical: ${coverAlignmentY.toStringAsFixed(2)}'),
                    Slider(
                      value: coverAlignmentY,
                      min: -1,
                      max: 1,
                      divisions: 20,
                      onChanged: (double value) {
                        setState(() {
                          coverAlignmentY = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      _CoverFrameResult(
                        coverZoom: coverZoom,
                        coverAlignmentX: coverAlignmentX,
                        coverAlignmentY: coverAlignmentY,
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
  }

  Future<void> _syncLastBookReferenceIfNeeded(
    BookReference previousReference,
    BookReference updatedReference,
  ) async {
    final BookReference? lastBookReference = _lastBookReference;
    if (lastBookReference == null ||
        !_isSameBookReference(lastBookReference, previousReference)) {
      return;
    }

    await widget.progressService.saveLastBookReference(updatedReference);
    await widget.onLastBookChanged(updatedReference);
  }

  bool _isSameBookReference(BookReference a, BookReference b) {
    if (a.format != b.format || a.directoryPath != b.directoryPath) {
      return false;
    }

    if (a.assetPaths.length != b.assetPaths.length) {
      return false;
    }

    for (int index = 0; index < a.assetPaths.length; index++) {
      if (a.assetPaths[index] != b.assetPaths[index]) {
        return false;
      }
    }

    return true;
  }

  BookReference _applyMetadataToReference(
    BookReference reference,
    _MetadataFormResult result,
  ) {
    String? normalize(String value) {
      final String normalized = value.trim();
      return normalized.isEmpty ? null : normalized;
    }

    return BookReference(
      title: result.title,
      format: reference.format,
      sourceLabel: reference.sourceLabel,
      directoryPath: reference.directoryPath,
      coverPath: reference.coverPath,
      author: normalize(result.author),
      description: normalize(result.description),
      series: normalize(result.series),
      volume: normalize(result.volume),
      altTitle: normalize(result.altTitle),
      coverZoom: reference.coverZoom,
      coverAlignmentX: reference.coverAlignmentX,
      coverAlignmentY: reference.coverAlignmentY,
      tags: result.tags,
      assetPaths: reference.assetPaths,
    );
  }

  IconData _iconForImportKind(ImportKind kind) {
    switch (kind) {
      case ImportKind.textFolder:
        return Icons.folder_open_rounded;
      case ImportKind.textFiles:
        return Icons.notes_rounded;
      case ImportKind.epub:
        return Icons.menu_book_rounded;
      case ImportKind.pdf:
        return Icons.picture_as_pdf_rounded;
    }
  }

  List<LibraryEntry> _filteredEntries() {
    Iterable<LibraryEntry> entries = _entries;

    switch (_filter) {
      case _LibraryFilter.all:
        break;
      case _LibraryFilter.favorites:
        entries = entries.where((LibraryEntry entry) => entry.isFavorite);
        break;
      case _LibraryFilter.recent:
        entries =
            entries.where((LibraryEntry entry) => entry.lastOpenedAt != null);
        break;
    }

    if (_query.isNotEmpty) {
      entries = entries.where((LibraryEntry entry) {
        return entry.reference.searchMetadata.contains(_query);
      });
    }

    return entries.toList(growable: false);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final List<LibraryEntry> visibleEntries = _filteredEntries();
    final List<LibraryEntry> favoriteEntries = _entries
        .where((LibraryEntry entry) => entry.isFavorite)
        .take(3)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca'),
        centerTitle: false,
        actions: <Widget>[
          IconButton(
            tooltip: 'Perfil e backup',
            onPressed: _showProfileSheet,
            icon: const Icon(Icons.manage_accounts_rounded),
          ),
          IconButton(
            tooltip: isDark ? 'Modo claro' : 'Modo escuro',
            onPressed: () {
              widget.onThemeModeChanged(
                isDark ? ThemeMode.light : ThemeMode.dark,
              );
            },
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isBusy ? null : _showImportOptions,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Importar livro'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshLibrary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: <Widget>[
            _buildHeroCard(theme),
            const SizedBox(height: 18),
            SearchBar(
              controller: _searchController,
              hintText: 'Buscar por titulo, autor, serie, tags...',
              leading: const Icon(Icons.search_rounded),
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
            _buildFilterChips(),
            if (favoriteEntries.isNotEmpty &&
                _filter == _LibraryFilter.all) ...<Widget>[
              const SizedBox(height: 22),
              Text('Favoritos', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final LibraryEntry entry in favoriteEntries)
                _buildBookCard(entry),
            ],
            const SizedBox(height: 22),
            Text('Biblioteca', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_isLoadingEntries)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (visibleEntries.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  _entries.isEmpty
                      ? 'Nenhum livro importado ainda. Use o botao de importar para comecar.'
                      : 'Nenhum livro corresponde ao filtro atual.',
                  style: theme.textTheme.bodyLarge,
                ),
              )
            else
              for (final LibraryEntry entry in visibleEntries)
                _buildBookCard(entry),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Sua biblioteca local',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'Perfil ativo: ${widget.currentProfile.name}. Importe livros em pasta, texto, EPUB e PDF. Backup e troca de usuario ficam isolados por perfil.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: _isBusy ? null : _showProfileSheet,
                icon: const Icon(Icons.person_outline_rounded),
                label: const Text('Perfis e backup'),
              ),
              if (_lastBookAvailable && _lastBookReference != null)
                FilledButton.icon(
                  onPressed: _isBusy ? null : _continueLastBook,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text('Continuar ${_lastBookReference!.title}'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        ChoiceChip(
          label: const Text('Todos'),
          selected: _filter == _LibraryFilter.all,
          onSelected: (_) {
            setState(() {
              _filter = _LibraryFilter.all;
            });
          },
        ),
        ChoiceChip(
          label: const Text('Favoritos'),
          selected: _filter == _LibraryFilter.favorites,
          onSelected: (_) {
            setState(() {
              _filter = _LibraryFilter.favorites;
            });
          },
        ),
        ChoiceChip(
          label: const Text('Recentes'),
          selected: _filter == _LibraryFilter.recent,
          onSelected: (_) {
            setState(() {
              _filter = _LibraryFilter.recent;
            });
          },
        ),
      ],
    );
  }

  Widget _buildBookCard(LibraryEntry entry) {
    return _LibraryBookCard(
      entry: entry,
      onOpen: () => _openLibraryEntry(entry),
      onTranslate: () => _translateEntry(entry),
      onRename: () => _renameEntry(entry),
      onEditMetadata: () => _editMetadata(entry),
      onUpdateCover: () => _changeCover(entry),
      onAdjustCover: () => _adjustCoverFrame(entry),
      onToggleFavorite: () => _toggleFavorite(entry),
      onRemove: () => _removeEntry(entry),
    );
  }
}

class _LibraryBookCard extends StatelessWidget {
  const _LibraryBookCard({
    required this.entry,
    required this.onOpen,
    required this.onTranslate,
    required this.onRename,
    required this.onEditMetadata,
    required this.onUpdateCover,
    required this.onAdjustCover,
    required this.onToggleFavorite,
    required this.onRemove,
  });

  final LibraryEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onTranslate;
  final VoidCallback onRename;
  final VoidCallback onEditMetadata;
  final VoidCallback onUpdateCover;
  final VoidCallback onAdjustCover;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasCover = entry.reference.hasCover;
    final String secondaryMeta = entry.chapterCount > 0
        ? '${entry.reference.format.label} - ${entry.chapterCount} capitulos'
        : entry.reference.format.label;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _BookCoverThumbnail(reference: entry.reference),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(entry.title, style: theme.textTheme.titleLarge),
                          const SizedBox(height: 6),
                          Text(
                            secondaryMeta,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: entry.isFavorite
                          ? 'Remover dos favoritos'
                          : 'Adicionar aos favoritos',
                      onPressed: onToggleFavorite,
                      icon: Icon(
                        entry.isFavorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (String value) {
                        switch (value) {
                          case 'rename':
                            onRename();
                            break;
                          case 'translate':
                            onTranslate();
                            break;
                          case 'metadata':
                            onEditMetadata();
                            break;
                          case 'cover':
                            onUpdateCover();
                            break;
                          case 'frame':
                            onAdjustCover();
                            break;
                          case 'remove':
                            onRemove();
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        return <PopupMenuEntry<String>>[
                          if (entry.reference.usesTextReader)
                            const PopupMenuItem<String>(
                              value: 'translate',
                              child: Text('Traduzir livro'),
                            ),
                          const PopupMenuItem<String>(
                            value: 'rename',
                            child: Text('Renomear livro'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'metadata',
                            child: Text('Editar metadados'),
                          ),
                          PopupMenuItem<String>(
                            value: 'cover',
                            child: Text(
                              hasCover ? 'Trocar capa' : 'Adicionar capa',
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'frame',
                            child: Text('Ajustar enquadramento da capa'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'remove',
                            child: Text('Remover da biblioteca'),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  entry.reference.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                if (entry.reference.altTitle?.trim().isNotEmpty ??
                    false) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    'Tambem conhecido como ${entry.reference.altTitle!}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (entry.reference.tags.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final String tag in entry.reference.tags.take(5))
                        Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        entry.lastOpenedAt != null
                            ? 'Aberto por ultimo em ${_formatDate(entry.lastOpenedAt!)}'
                            : 'Importado em ${_formatDate(entry.importedAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.auto_stories_rounded),
                      label: const Text('Abrir'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String year = value.year.toString();
    return '$day/$month/$year';
  }
}

class _BookCoverThumbnail extends StatelessWidget {
  const _BookCoverThumbnail({
    required this.reference,
    this.width = 76,
    this.height = 108,
    this.borderRadius = 18,
  });

  final BookReference reference;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? coverPath = reference.coverPath;
    final bool hasCover = coverPath != null &&
        coverPath.isNotEmpty &&
        File(coverPath).existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        color: theme.colorScheme.surfaceContainerHighest,
        child: hasCover
            ? ClipRect(
                child: Transform.scale(
                  scale: reference.coverZoom,
                  alignment: Alignment(
                    reference.coverAlignmentX,
                    reference.coverAlignmentY,
                  ),
                  child: Image.file(
                    File(coverPath),
                    width: width,
                    height: height,
                    fit: BoxFit.cover,
                    alignment: Alignment(
                      reference.coverAlignmentX,
                      reference.coverAlignmentY,
                    ),
                    errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
                  ),
                ),
              )
            : _buildPlaceholder(theme),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    final IconData icon;
    switch (reference.format) {
      case BookFormat.text:
        icon = Icons.article_rounded;
        break;
      case BookFormat.epub:
        icon = Icons.menu_book_rounded;
        break;
      case BookFormat.pdf:
        icon = Icons.picture_as_pdf_rounded;
        break;
    }

    return Center(
      child: Icon(
        icon,
        size: width * 0.4,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _MetadataFormResult {
  const _MetadataFormResult({
    required this.title,
    required this.altTitle,
    required this.author,
    required this.description,
    required this.series,
    required this.volume,
    required this.tags,
  });

  final String title;
  final String altTitle;
  final String author;
  final String description;
  final String series;
  final String volume;
  final List<String> tags;
}

class _CoverFrameResult {
  const _CoverFrameResult({
    required this.coverZoom,
    required this.coverAlignmentX,
    required this.coverAlignmentY,
  });

  final double coverZoom;
  final double coverAlignmentX;
  final double coverAlignmentY;
}
