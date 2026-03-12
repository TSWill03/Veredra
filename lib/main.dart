// Signature: dev.tswicolly03
import 'package:flutter/material.dart';

import 'models/app_profile.dart';
import 'models/book_reference.dart';
import 'models/reader_font_preset.dart';
import 'pages/library_page.dart';
import 'services/annotation_service.dart';
import 'services/backup_service.dart';
import 'services/bookmark_service.dart';
import 'services/book_service.dart';
import 'services/library_service.dart';
import 'services/profile_service.dart';
import 'services/progress_service.dart';
import 'services/translation_service.dart';
import 'widgets/app_watermark_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VeredraApp());
}

class VeredraApp extends StatefulWidget {
  const VeredraApp({super.key});

  @override
  State<VeredraApp> createState() => _VeredraAppState();
}

class _VeredraAppState extends State<VeredraApp> {
  final ProfileService _profileService = ProfileService();
  final BookService _bookService = BookService();
  final LibraryService _libraryService = LibraryService();
  final ProgressService _progressService = ProgressService();
  final BookmarkService _bookmarkService = BookmarkService();
  final AnnotationService _annotationService = AnnotationService();
  final TranslationService _translationService = TranslationService();
  late final BackupService _backupService = BackupService(
    profileService: _profileService,
    libraryService: _libraryService,
    progressService: _progressService,
    bookmarkService: _bookmarkService,
    annotationService: _annotationService,
  );

  ThemeMode _themeMode = ThemeMode.dark;
  double _fontSize = 19;
  ReaderFontPreset _readerFontPreset = ReaderFontPreset.system;
  AppProfile? _currentProfile;
  BookReference? _lastBookReference;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _loadAppState();
  }

  Future<void> _loadAppState() async {
    final AppProfile currentProfile =
        await _profileService.loadCurrentProfile();
    _configureServicesForProfile(currentProfile.id);
    final ThemeMode savedThemeMode = await _progressService.loadThemeMode();
    final double savedFontSize = await _progressService.loadFontSize();
    final ReaderFontPreset savedReaderFontPreset =
        await _progressService.loadReaderFontPreset();
    final BookReference? lastBookReference =
        await _progressService.loadLastBookReference();

    if (!mounted) {
      return;
    }

    setState(() {
      _currentProfile = currentProfile;
      _themeMode = savedThemeMode;
      _fontSize = savedFontSize;
      _readerFontPreset = savedReaderFontPreset;
      _lastBookReference = lastBookReference;
      _isReady = true;
    });
  }

  void _configureServicesForProfile(String profileId) {
    _bookService.configureProfile(profileId);
    _libraryService.configureProfile(profileId);
    _progressService.configureProfile(profileId);
    _bookmarkService.configureProfile(profileId);
    _annotationService.configureProfile(profileId);
    _translationService.configureProfile(profileId);
  }

  Future<void> _handleThemeModeChanged(ThemeMode themeMode) async {
    if (_themeMode == themeMode) {
      return;
    }

    setState(() {
      _themeMode = themeMode;
    });

    await _progressService.saveThemeMode(themeMode);
  }

  Future<void> _handleFontSizeChanged(double fontSize) async {
    if ((_fontSize - fontSize).abs() < 0.01) {
      return;
    }

    setState(() {
      _fontSize = fontSize;
    });

    await _progressService.saveFontSize(fontSize);
  }

  Future<void> _handleReaderFontPresetChanged(ReaderFontPreset preset) async {
    if (_readerFontPreset == preset) {
      return;
    }

    setState(() {
      _readerFontPreset = preset;
    });

    await _progressService.saveReaderFontPreset(preset);
  }

  Future<void> _handleLastBookChanged(BookReference reference) async {
    setState(() {
      _lastBookReference = reference;
    });
  }

  Future<void> _handleProfileChanged(AppProfile profile) async {
    _configureServicesForProfile(profile.id);
    final ThemeMode savedThemeMode = await _progressService.loadThemeMode();
    final double savedFontSize = await _progressService.loadFontSize();
    final ReaderFontPreset savedReaderFontPreset =
        await _progressService.loadReaderFontPreset();
    final BookReference? lastBookReference =
        await _progressService.loadLastBookReference();

    if (!mounted) {
      return;
    }

    setState(() {
      _currentProfile = profile;
      _themeMode = savedThemeMode;
      _fontSize = savedFontSize;
      _readerFontPreset = savedReaderFontPreset;
      _lastBookReference = lastBookReference;
    });
  }

  ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: const Color(0xFF8C6B43),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF101315) : const Color(0xFFF4EFE7),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
      textTheme: ThemeData(
        brightness: brightness,
      ).textTheme.apply(
            bodyColor: colorScheme.onSurface,
            displayColor: colorScheme.onSurface,
          ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Veredra',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      builder: (BuildContext context, Widget? child) {
        if (child == null) {
          return const SizedBox.shrink();
        }

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            child,
            const Positioned.fill(
              child: AppWatermarkOverlay(),
            ),
          ],
        );
      },
      home: _isReady
          ? LibraryPage(
              currentProfile: _currentProfile!,
              profileService: _profileService,
              backupService: _backupService,
              bookService: _bookService,
              annotationService: _annotationService,
              bookmarkService: _bookmarkService,
              libraryService: _libraryService,
              progressService: _progressService,
              translationService: _translationService,
              lastBookReference: _lastBookReference,
              fontSize: _fontSize,
              readerFontPreset: _readerFontPreset,
              onThemeModeChanged: _handleThemeModeChanged,
              onFontSizeChanged: _handleFontSizeChanged,
              onReaderFontPresetChanged: _handleReaderFontPresetChanged,
              onProfileChanged: _handleProfileChanged,
              onLastBookChanged: _handleLastBookChanged,
            )
          : const _StartupPage(),
    );
  }
}

class _StartupPage extends StatelessWidget {
  const _StartupPage();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Text(
              'Veredra',
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}
