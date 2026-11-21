// Signature: dev.tswicolly03
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:txt_webnovel_reader/services/update/update_service.dart';
import 'package:txt_webnovel_reader/services/update/update_controller.dart';
import 'package:txt_webnovel_reader/widgets/update_badge_button.dart';

class StubUpdateService extends UpdateService {
  StubUpdateService()
      : super(
          target: UpdateTarget.web,
          currentVersion: '0.1.4+5',
          client: MockClient((_) async => throw UnimplementedError()),
        );

  @override
  Future<AppRelease?> check() async => AppRelease(
        version: '0.1.5+6',
        notes: 'Nova leitura de capitulos',
        releaseUrl: Uri.https('github.com', '/TSWill03/Veredra/releases'),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('indicador azul some ao consultar novidades, sem reabrir livro',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final StubUpdateService service = StubUpdateService();
    final UpdateController controller = UpdateController(service: service);
    await controller.initialize();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          appBar: AppBar(actions: <Widget>[
        UpdateBadgeButton(controller: controller),
      ])),
    ));
    expect(find.byKey(const Key('update-blue-dot')), findsOneWidget);

    await tester.tap(find.byKey(const Key('app-update-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('update-blue-dot')), findsNothing);
    expect(find.text('Nova versao: 0.1.5+6'), findsOneWidget);
    expect(find.text('Nova leitura de capitulos'), findsOneWidget);

    await tester.tap(find.text('Agora nao'));
    await tester.pumpAndSettle();
    controller.dispose();
    service.dispose();
  });
}
