// Signature: dev.tswicolly03
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/pages/account_page.dart';
import 'package:txt_webnovel_reader/services/auth/account_controller.dart';
import 'package:txt_webnovel_reader/services/auth/auth_gateway.dart';
import 'package:txt_webnovel_reader/services/sync/device_identity_service.dart';
import 'package:txt_webnovel_reader/services/sync/local_sync_repository.dart';
import 'package:txt_webnovel_reader/services/sync/network_monitor.dart';
import 'package:txt_webnovel_reader/services/sync/remote_sync_gateway.dart';
import 'package:txt_webnovel_reader/services/sync/sync_coordinator.dart';
import 'package:txt_webnovel_reader/services/sync/sync_models.dart';
import 'package:txt_webnovel_reader/services/sync/sync_preferences_service.dart';
import 'package:txt_webnovel_reader/services/sync/sync_queue.dart';

import 'support/fake_auth_gateway.dart';
import 'support/memory_app_storage.dart';

void main() {
  testWidgets('shows an honest local-only state when backend is absent',
      (WidgetTester tester) async {
    final AccountController controller =
        AccountController(const LocalOnlyAuthGateway());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: AccountPage(accountController: controller)),
    );

    expect(find.text('Modo local'), findsOneWidget);
    expect(find.textContaining('Conta online nao configurada'), findsOneWidget);
  });

  testWidgets('validates login and prevents duplicate submissions',
      (WidgetTester tester) async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      delay: const Duration(milliseconds: 100),
    );
    final AccountController controller = AccountController(gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.close);
    await tester.pumpWidget(
      MaterialApp(home: AccountPage(accountController: controller)),
    );

    await tester.tap(find.byKey(const Key('auth-submit-button')));
    await tester.pump();
    expect(find.text('Informe seu e-mail.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'reader@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'SenhaValida123',
    );
    await tester.tap(find.byKey(const Key('auth-submit-button')));
    controller.signIn('reader@example.com', 'SenhaValida123');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(gateway.signInCalls, 1);

    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    expect(find.text('E-mail verificado'), findsOneWidget);
  });

  testWidgets('password recovery uses the validated email',
      (WidgetTester tester) async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    final AccountController controller = AccountController(gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.close);
    await tester.pumpWidget(
      MaterialApp(home: AccountPage(accountController: controller)),
    );
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'reader@example.com',
    );
    await tester.tap(find.byKey(const Key('forgot-password-button')));
    await tester.pumpAndSettle();
    expect(gateway.resetCalls, 1);
    expect(find.text('Recuperacao enviada.'), findsOneWidget);
  });

  testWidgets('keeps Google sign-in hidden while the feature is disabled',
      (WidgetTester tester) async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    final AccountController controller = AccountController(gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.close);
    await tester.pumpWidget(
      MaterialApp(home: AccountPage(accountController: controller)),
    );

    expect(find.byKey(const Key('google-sign-in-button')), findsNothing);
    expect(find.text('Entrar com Google'), findsNothing);
  });

  testWidgets('retains Google sign-in behind an explicit feature flag',
      (WidgetTester tester) async {
    final FakeAuthGateway gateway = FakeAuthGateway(googleAuthEnabled: true);
    final AccountController controller = AccountController(gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.close);
    await tester.pumpWidget(
      MaterialApp(home: AccountPage(accountController: controller)),
    );

    expect(find.byKey(const Key('google-sign-in-button')), findsOneWidget);
  });

  testWidgets('requires explicit confirmation before syncing book files',
      (WidgetTester tester) async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    final AccountController controller = AccountController(gateway);
    await controller.signIn('reader@example.com', 'SenhaValida123');
    final MemoryAppStorage storage = MemoryAppStorage();
    final SyncPreferencesService preferences = SyncPreferencesService(
      profileId: 'principal',
      storage: storage,
    );
    await preferences.setEnabled(true);
    final SyncCoordinator coordinator = SyncCoordinator(
      profileId: 'principal',
      currentUserId: () => controller.user?.id,
      localRepository: _EmptyLocalSyncDataSource(),
      queue: SyncQueue(profileId: 'principal', storage: storage),
      preferencesService: preferences,
      deviceIdentityService: DeviceIdentityService(storage: storage),
      networkMonitor: const _OfflineNetworkMonitor(),
      remoteGateway: const _NoopRemoteGateway(),
      storage: storage,
    );
    await coordinator.initialize();
    addTearDown(controller.dispose);
    addTearDown(gateway.close);
    addTearDown(coordinator.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AccountPage(
          accountController: controller,
          syncCoordinator: coordinator,
        ),
      ),
    );

    final Finder switchFinder =
        find.byKey(const Key('sync-book-files-switch'));
    expect(switchFinder, findsOneWidget);
    expect(coordinator.preferences.syncBookFiles, isFalse);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(find.text('Sincronizar capitulos e traducoes?'), findsOneWidget);
    expect(coordinator.preferences.syncBookFiles, isFalse);

    await tester.tap(
      find.byKey(const Key('confirm-book-files-sync-button')),
    );
    await tester.pumpAndSettle();
    expect(coordinator.preferences.syncBookFiles, isTrue);
  });
}

class _EmptyLocalSyncDataSource implements LocalSyncDataSource {
  @override
  Future<void> applyRemoteRecords(List<RemoteSyncRecord> records) async {}

  @override
  Future<List<LocalSyncSnapshot>> createSnapshot() async {
    return const <LocalSyncSnapshot>[];
  }
}

class _OfflineNetworkMonitor implements NetworkMonitor {
  const _OfflineNetworkMonitor();

  @override
  Stream<bool> get changes => const Stream<bool>.empty();

  @override
  Future<bool> isOnline() async => false;
}

class _NoopRemoteGateway implements RemoteSyncGateway {
  const _NoopRemoteGateway();

  @override
  Future<List<RemoteSyncRecord>> pullSince({
    required String userId,
    required DateTime? since,
  }) async {
    return const <RemoteSyncRecord>[];
  }

  @override
  Future<void> push(SyncOperation operation) async {}

  @override
  Future<void> upsertDevice({
    required String userId,
    required String deviceId,
    required String name,
    required String platform,
  }) async {}
}
