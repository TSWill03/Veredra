// Signature: dev.tswicolly03
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/main.dart';
import 'package:txt_webnovel_reader/services/auth/account_controller.dart';
import 'package:txt_webnovel_reader/services/auth/auth_gateway.dart';
import 'package:txt_webnovel_reader/services/auth/auth_models.dart';

import 'support/fake_auth_gateway.dart';

void main() {
  const Key libraryKey = Key('private-library');

  Widget app(AccountController controller, {bool required = true}) {
    return MaterialApp(
      home: PrivateAccessGate(
        privateAccessRequired: required,
        accountController: controller,
        child: const Scaffold(key: libraryKey, body: Text('Biblioteca')),
      ),
    );
  }

  testWidgets('private build blocks an invalid or absent session', (
    WidgetTester tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    final AccountController controller = AccountController(gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.close);

    await tester.pumpWidget(app(controller));

    expect(find.byKey(libraryKey), findsNothing);
    expect(find.text('Veredra privado'), findsOneWidget);
    expect(find.text('Criar conta'), findsNothing);
  });

  testWidgets('valid session opens the private library', (
    WidgetTester tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      user: const AuthUser(
        id: 'user-a',
        email: 'reader@example.com',
        emailVerified: true,
      ),
    );
    final AccountController controller = AccountController(gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.close);

    await tester.pumpWidget(app(controller));

    expect(find.byKey(libraryKey), findsOneWidget);
    expect(find.text('Veredra privado'), findsNothing);
  });

  testWidgets('logout closes the library before the remote call completes', (
    WidgetTester tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      user: const AuthUser(
        id: 'user-a',
        email: 'reader@example.com',
        emailVerified: true,
      ),
      delay: const Duration(seconds: 1),
    );
    final AccountController controller = AccountController(gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.close);
    await tester.pumpWidget(app(controller));
    expect(find.byKey(libraryKey), findsOneWidget);

    final Future<void> logout = controller.signOut();
    await tester.pump();

    expect(find.byKey(libraryKey), findsNothing);
    expect(find.text('Veredra privado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await logout;
  });

  testWidgets('session expiration immediately closes the library', (
    WidgetTester tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway(
      user: const AuthUser(
        id: 'user-a',
        email: 'reader@example.com',
        emailVerified: true,
      ),
    );
    final AccountController controller = AccountController(gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.close);
    await tester.pumpWidget(app(controller));

    gateway.controller.add(
      const AuthSessionSnapshot(event: AuthSessionEvent.signedOut, user: null),
    );
    await tester.pump();

    expect(controller.sessionExpired, isTrue);
    expect(find.byKey(libraryKey), findsNothing);
    expect(find.text('Veredra privado'), findsOneWidget);
  });

  testWidgets('password recovery keeps the library closed', (
    WidgetTester tester,
  ) async {
    final AuthUser user = const AuthUser(
      id: 'user-a',
      email: 'reader@example.com',
      emailVerified: true,
    );
    final FakeAuthGateway gateway = FakeAuthGateway(user: user);
    final AccountController controller = AccountController(gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.close);
    await tester.pumpWidget(app(controller));

    gateway.controller.add(
      AuthSessionSnapshot(event: AuthSessionEvent.passwordRecovery, user: user),
    );
    await tester.pump();

    expect(find.byKey(libraryKey), findsNothing);
    expect(find.text('Defina uma nova senha'), findsOneWidget);
  });

  testWidgets('private build without Supabase never opens local mode', (
    WidgetTester tester,
  ) async {
    final AccountController controller = AccountController(
      const LocalOnlyAuthGateway(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(app(controller));

    expect(find.byKey(libraryKey), findsNothing);
    expect(find.text('Acesso privado não configurado'), findsOneWidget);
  });

  testWidgets('explicit non-private build preserves local mode', (
    WidgetTester tester,
  ) async {
    final AccountController controller = AccountController(
      const LocalOnlyAuthGateway(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(app(controller, required: false));

    expect(find.byKey(libraryKey), findsOneWidget);
  });
}
