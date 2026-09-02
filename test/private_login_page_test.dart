// Signature: dev.tswicolly03
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/pages/private_login_page.dart';
import 'package:txt_webnovel_reader/services/auth/account_controller.dart';

import 'support/fake_auth_gateway.dart';

void main() {
  testWidgets('private entry exposes login without public registration', (
    WidgetTester tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    final AccountController controller = AccountController(gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.close);

    await tester.pumpWidget(
      MaterialApp(home: PrivateLoginPage(accountController: controller)),
    );

    expect(find.text('Veredra privado'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.textContaining('Novos cadastros'), findsOneWidget);
    expect(find.text('Criar conta'), findsNothing);
    expect(find.byKey(const Key('auth-submit-button')), findsNothing);
  });

  testWidgets('validates and submits an authorized login', (
    WidgetTester tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    final AccountController controller = AccountController(gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.close);

    await tester.pumpWidget(
      MaterialApp(home: PrivateLoginPage(accountController: controller)),
    );

    await tester.tap(find.byKey(const Key('private-auth-submit-button')));
    await tester.pump();
    expect(find.text('Informe seu e-mail.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('private-auth-email-field')),
      'reader@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('private-auth-password-field')),
      'SenhaValida123',
    );
    await tester.tap(find.byKey(const Key('private-auth-submit-button')));
    await tester.pumpAndSettle();

    expect(gateway.signInCalls, 1);
    expect(controller.isSignedIn, isTrue);
  });

  testWidgets('password reset validates and uses the informed email', (
    WidgetTester tester,
  ) async {
    final FakeAuthGateway gateway = FakeAuthGateway();
    final AccountController controller = AccountController(gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.close);

    await tester.pumpWidget(
      MaterialApp(home: PrivateLoginPage(accountController: controller)),
    );

    await tester.enterText(
      find.byKey(const Key('private-auth-email-field')),
      'reader@example.com',
    );
    await tester.tap(
      find.byKey(const Key('private-auth-forgot-password-button')),
    );
    await tester.pumpAndSettle();

    expect(gateway.resetCalls, 1);
    expect(find.text('Recuperacao enviada.'), findsOneWidget);
  });
}
