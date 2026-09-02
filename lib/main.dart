// Signature: dev.tswicolly03
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'models/app_profile.dart';
import 'models/book_reference.dart';
import 'models/reader_font_preset.dart';
import 'pages/library_page.dart';
import 'pages/private_login_page.dart';
import 'services/annotation_service.dart';
import 'services/backup_service.dart';
import 'services/bookmark_service.dart';
import 'services/book_service.dart';
import 'services/library_service.dart';
import 'services/library_search_service.dart';
import 'services/profile_service.dart';
import 'services/progress_service.dart';
import 'services/reading_stats_service.dart';
import 'services/translation_service.dart';
import 'services/auth/account_controller.dart';
import 'services/auth/auth_gateway.dart';
import 'services/auth/secure_auth_storage.dart';
import 'services/auth/supabase_auth_gateway.dart';
import 'services/diagnostics_service.dart';
import 'services/sync/device_identity_service.dart';
import 'services/sync/local_sync_repository.dart';
import 'services/sync/network_monitor.dart';
import 'services/sync/remote_sync_gateway.dart';
import 'services/sync/supabase_sync_gateway.dart';
import 'services/sync/sync_coordinator.dart';
import 'services/sync/sync_preferences_service.dart';
import 'services/sync/sync_queue.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final DiagnosticsService diagnostics = DiagnosticsService();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    unawaited(
      diagnostics.record(
        DiagnosticCategory.startup,
        details.exception,
        details.stack ?? StackTrace.current,
        fatal: true,
      ),
    );
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    unawaited(
      diagnostics.record(
        DiagnosticCategory.startup,
        error,
        stackTrace,
        fatal: true,
      ),
    );
    return true;
  };

  await runZonedGuarded<Future<void>>(
    () async {
      AuthGateway authGateway = const LocalOnlyAuthGateway();
      RemoteSyncGateway? remoteSyncGateway;
      if (AppConfig.isSupabaseConfigured) {
        try {
          await Supabase.initialize(
            url: AppConfig.supabaseUrl,
            publishableKey: AppConfig.effectiveSupabaseKey,
            authOptions: FlutterAuthClientOptions(
              authFlowType: AuthFlowType.pkce,
              autoRefreshToken: true,
              detectSessionInUri: true,
              localStorage: SecureAuthLocalStorage(),
              pkceAsyncStorage: SecurePkceStorage(),
            ),
            debug: false,
          );
          final SupabaseClient client = Supabase.instance.client;
          authGateway = SupabaseAuthGateway(client);
          remoteSyncGateway = SupabaseSyncGateway(client);
        } catch (error, stackTrace) {
          await diagnostics.record(
            DiagnosticCategory.authentication,
            error,
            stackTrace,
          );
        }
      }

      runApp(
        VeredraApp(
          accountController: AccountController(authGateway),
          remoteSyncGateway: remoteSyncGateway,
          diagnostics: diagnostics,
        ),
      );
    },
    (Object error, StackTrace stackTrace) {
      unawaited(
        diagnostics.record(
          DiagnosticCategory.startup,
          error,
          stackTrace,
          fatal: true,
        ),
      );
    },
  );
}

class VeredraApp extends StatefulWidget {
  const VeredraApp({
    super.key,
    this.accountController,
    this.remoteSyncGateway,
    this.diagnostics,
    this.privateAccessRequired = AppConfig.privateAccessRequired,
  });

  final AccountController? accountController;
  final RemoteSyncGateway? remoteSyncGateway;
  final DiagnosticsService? diagnostics;
  final bool privateAccessRequired;

  @override
  State<VeredraApp> createState() => _VeredraAppState();
}

class _VeredraAppState extends State<VeredraApp> {
  final ProfileService _profileService = ProfileService();
  final BookService _bookService = BookService();
  final LibraryService _libraryService = LibraryService();
  late final LibrarySearchService _librarySearchService = LibrarySearchService(
    bookService: _bookService,
    bookmarkService: _bookmarkService,
    annotationService: _annotationService,
  );
  final ProgressService _progressService = ProgressService();
  final BookmarkService _bookmarkService = BookmarkService();
  final AnnotationService _annotationService = AnnotationService();
  final ReadingStatsService _readingStatsService = ReadingStatsService();
  final TranslationService _translationService = TranslationService();
  late final AccountController _accountController;
  late final bool _ownsAccountController;
  late final DiagnosticsService _diagnostics;
  SyncCoordinator? _syncCoordinator;
  late final BackupService _backupService = BackupService(
    profileService: _profileService,
    libraryService: _libraryService,
    progressService: _progressService,
    bookmarkService: _bookmarkService,
    annotationService: _annotationService,
    readingStatsService: _readingStatsService,
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
    _ownsAccountController = widget.accountController == null;
    _accountController = widget.accountController ??
        AccountController(const LocalOnlyAuthGateway());
    _diagnostics = widget.diagnostics ?? DiagnosticsService();
    _accountController.addListener(_handleAccountChanged);
    _loadAppState();
  }

  Future<void> _loadAppState() async {
    final AppProfile currentProfile =
        await _profileService.loadCurrentProfile();
    _configureServicesForProfile(currentProfile.id);
    await _configureSyncForProfile(currentProfile.id);
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
    _readingStatsService.configureProfile(profileId);
    _translationService.configureProfile(profileId);
  }

  Future<void> _configureSyncForProfile(String profileId) async {
    _syncCoordinator?.dispose();
    final LocalSyncRepository localRepository = LocalSyncRepository(
      profileId: profileId,
      profileService: _profileService,
      libraryService: _libraryService,
      progressService: _progressService,
      bookmarkService: _bookmarkService,
      annotationService: _annotationService,
      readingStatsService: _readingStatsService,
    );
    final SyncCoordinator coordinator = SyncCoordinator(
      profileId: profileId,
      currentUserId: () => _accountController.user?.id,
      localRepository: localRepository,
      queue: SyncQueue(profileId: profileId),
      preferencesService: SyncPreferencesService(profileId: profileId),
      deviceIdentityService: DeviceIdentityService(),
      networkMonitor: ConnectivityNetworkMonitor(),
      remoteGateway: widget.remoteSyncGateway,
      diagnostics: _diagnostics,
    );
    await coordinator.initialize();
    _syncCoordinator = coordinator;
  }

  void _handleAccountChanged() {
    final SyncCoordinator? coordinator = _syncCoordinator;
    if (_accountController.user != null &&
        coordinator != null &&
        coordinator.preferences.enabled &&
        coordinator.preferences.automatic) {
      unawaited(coordinator.syncNow());
    }
    if (mounted) {
      setState(() {});
    }
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
    await _configureSyncForProfile(profile.id);
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

  @override
  void dispose() {
    _accountController.removeListener(_handleAccountChanged);
    if (_ownsAccountController) {
      _accountController.dispose();
    }
    _syncCoordinator?.dispose();
    super.dispose();
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
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
            bodyColor: colorScheme.onSurface,
            displayColor: colorScheme.onSurface,
          ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _buildHome() {
    if (!_isReady) {
      return const _StartupPage();
    }

    return PrivateAccessGate(
      privateAccessRequired: widget.privateAccessRequired,
      accountController: _accountController,
      child: LibraryPage(
        currentProfile: _currentProfile!,
        profileService: _profileService,
        backupService: _backupService,
        bookService: _bookService,
        annotationService: _annotationService,
        bookmarkService: _bookmarkService,
        libraryService: _libraryService,
        librarySearchService: _librarySearchService,
        progressService: _progressService,
        readingStatsService: _readingStatsService,
        translationService: _translationService,
        accountController: _accountController,
        syncCoordinator: _syncCoordinator,
        lastBookReference: _lastBookReference,
        fontSize: _fontSize,
        readerFontPreset: _readerFontPreset,
        onThemeModeChanged: _handleThemeModeChanged,
        onFontSizeChanged: _handleFontSizeChanged,
        onReaderFontPresetChanged: _handleReaderFontPresetChanged,
        onProfileChanged: _handleProfileChanged,
        onLastBookChanged: _handleLastBookChanged,
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
      home: _buildHome(),
    );
  }
}

class PrivateAccessGate extends StatelessWidget {
  const PrivateAccessGate({
    super.key,
    required this.privateAccessRequired,
    required this.accountController,
    required this.child,
  });

  final bool privateAccessRequired;
  final AccountController accountController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!privateAccessRequired) {
      return child;
    }

    return AnimatedBuilder(
      animation: accountController,
      builder: (BuildContext context, Widget? _) {
        if (!accountController.isConfigured) {
          return const _PrivateAccessConfigurationPage();
        }
        if (!accountController.isSignedIn ||
            accountController.passwordRecovery) {
          return PrivateLoginPage(accountController: accountController);
        }
        return child;
      },
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
            Text('Veredra', style: theme.textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class _PrivateAccessConfigurationPage extends StatelessWidget {
  const _PrivateAccessConfigurationPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.admin_panel_settings_outlined,
                        size: 54,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Acesso privado não configurado',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Este build exige autenticação, mas não recebeu uma configuração válida do Supabase. O modo local anônimo foi bloqueado para proteger a biblioteca.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
