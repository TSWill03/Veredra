// Signature: dev.tswicolly03
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/models/reader_background_preset.dart';
import 'package:txt_webnovel_reader/models/reader_premium_theme.dart';
import 'package:txt_webnovel_reader/models/reader_preferences.dart';
import 'package:txt_webnovel_reader/widgets/reader_settings.dart';

void main() {
  test(
    'todos os cinco temas existentes continuam gratuitos e com IDs estaveis',
    () {
      expect(
        ReaderBackgroundPreset.values.map((preset) => preset.name).toList(),
        <String>['parchment', 'sepia', 'mist', 'graphite', 'forest'],
      );
      for (final ReaderBackgroundPreset preset
          in ReaderBackgroundPreset.values) {
        expect(readerBackgroundPresetFromId(preset.name), preset);
      }
      expect(
        ReaderPreferences.defaults.backgroundPreset,
        ReaderBackgroundPreset.parchment,
      );
    },
  );

  test('temas premium nao podem ser carregados como presets gratuitos', () {
    final Set<String> freeIds =
        ReaderBackgroundPreset.values.map((preset) => preset.name).toSet();
    final Set<String> premiumIds =
        ReaderPremiumTheme.previews.map((theme) => theme.id).toSet();

    expect(premiumIds.length, ReaderPremiumTheme.previews.length);
    expect(premiumIds.intersection(freeIds), isEmpty);
    for (final String premiumId in premiumIds) {
      expect(
        readerBackgroundPresetFromId(premiumId),
        ReaderBackgroundPreset.parchment,
      );
    }
  });

  testWidgets('tema gratuito pode ser selecionado sem compra', (tester) async {
    ReaderPreferences latest = ReaderPreferences.defaults;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderSettings(
            preferences: ReaderPreferences.defaults,
            isDarkMode: false,
            onPreferencesChanged: (ReaderPreferences next) => latest = next,
            onDarkModeChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Floresta'));
    await tester.tap(find.text('Floresta'));
    await tester.pump();
    expect(latest.backgroundPreset, ReaderBackgroundPreset.forest);
  });

  testWidgets('preview premium nao muda preferencias nem cobra', (
    tester,
  ) async {
    ReaderPreferences latest = ReaderPreferences.defaults;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderSettings(
            preferences: ReaderPreferences.defaults,
            isDarkMode: false,
            onPreferencesChanged: (ReaderPreferences next) => latest = next,
            onDarkModeChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Aurora'));
    await tester.tap(find.text('Aurora'));
    await tester.pumpAndSettle();

    expect(find.text('Temas exclusivos em breve'), findsOneWidget);
    expect(latest.backgroundPreset, ReaderBackgroundPreset.parchment);
    expect(find.textContaining('Nenhuma compra'), findsNWidgets(2));
  });
}
