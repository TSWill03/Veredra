// Signature: dev.tswicolly03
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/pages/account_page.dart';
import 'package:txt_webnovel_reader/services/auth/account_controller.dart';
import 'package:txt_webnovel_reader/services/auth/auth_gateway.dart';

import 'support/fake_auth_gateway.dart';

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
}
