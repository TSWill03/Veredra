// Signature: dev.tswicolly03
import 'package:flutter/material.dart';

import '../models/reader_background_preset.dart';
import '../models/reader_font_preset.dart';
import '../models/reader_preferences.dart';
import '../models/reader_text_align_preset.dart';

class ReaderSettings extends StatefulWidget {
  const ReaderSettings({
    super.key,
    required this.preferences,
    required this.isDarkMode,
    required this.onPreferencesChanged,
    required this.onDarkModeChanged,
  });

  final ReaderPreferences preferences;
  final bool isDarkMode;
  final ValueChanged<ReaderPreferences> onPreferencesChanged;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  State<ReaderSettings> createState() => _ReaderSettingsState();
}

class _ReaderSettingsState extends State<ReaderSettings> {
  late ReaderPreferences _preferences;
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _preferences = widget.preferences;
    _isDarkMode = widget.isDarkMode;
  }

  void _updatePreferences(ReaderPreferences next) {
    setState(() {
      _preferences = next;
    });
    widget.onPreferencesChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Configuracoes de leitura',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              _SectionLabel(
                icon: Icons.format_size_rounded,
                title: 'Tamanho da fonte',
                trailing: '${_preferences.fontSize.toStringAsFixed(0)} px',
              ),
              Slider(
                value: _preferences.fontSize,
                min: 14,
                max: 30,
                divisions: 16,
                label: _preferences.fontSize.toStringAsFixed(0),
                onChanged: (double value) {
                  _updatePreferences(_preferences.copyWith(fontSize: value));
                },
              ),
              const SizedBox(height: 8),
              _SectionLabel(
                icon: Icons.font_download_rounded,
                title: 'Fonte da leitura',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final preset in ReaderFontPreset.values)
                    ChoiceChip(
                      label: Text(preset.label),
                      selected: _preferences.fontPreset == preset,
                      onSelected: (bool selected) {
                        if (!selected) {
                          return;
                        }
                        _updatePreferences(
                          _preferences.copyWith(fontPreset: preset),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _SectionLabel(
                icon: Icons.palette_outlined,
                title: 'Plano de fundo',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final preset in ReaderBackgroundPreset.values)
                    ChoiceChip(
                      label: Text(preset.label),
                      selected: _preferences.backgroundPreset == preset,
                      onSelected: (bool selected) {
                        if (!selected) {
                          return;
                        }
                        _updatePreferences(
                          _preferences.copyWith(backgroundPreset: preset),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _SectionLabel(
                icon: Icons.format_line_spacing_rounded,
                title: 'Espacamento entre linhas',
                trailing: _preferences.lineHeight.toStringAsFixed(2),
              ),
              Slider(
                value: _preferences.lineHeight,
                min: 1.3,
                max: 2.3,
                divisions: 20,
                onChanged: (double value) {
                  _updatePreferences(_preferences.copyWith(lineHeight: value));
                },
              ),
              const SizedBox(height: 8),
              _SectionLabel(
                icon: Icons.width_normal_rounded,
                title: 'Largura da coluna',
                trailing: '${_preferences.contentWidth.toStringAsFixed(0)} px',
              ),
              Slider(
                value: _preferences.contentWidth,
                min: 560,
                max: 1100,
                divisions: 27,
                onChanged: (double value) {
                  _updatePreferences(
                      _preferences.copyWith(contentWidth: value));
                },
              ),
              const SizedBox(height: 8),
              _SectionLabel(
                icon: Icons.space_bar_rounded,
                title: 'Margem lateral',
                trailing:
                    '${_preferences.horizontalPadding.toStringAsFixed(0)} px',
              ),
              Slider(
                value: _preferences.horizontalPadding,
                min: 12,
                max: 48,
                divisions: 18,
                onChanged: (double value) {
                  _updatePreferences(
                    _preferences.copyWith(horizontalPadding: value),
                  );
                },
              ),
              const SizedBox(height: 8),
              _SectionLabel(
                icon: Icons.format_align_left_rounded,
                title: 'Alinhamento do texto',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final preset in ReaderTextAlignPreset.values)
                    ChoiceChip(
                      label: Text(preset.label),
                      selected: _preferences.textAlignPreset == preset,
                      onSelected: (bool selected) {
                        if (!selected) {
                          return;
                        }
                        _updatePreferences(
                          _preferences.copyWith(textAlignPreset: preset),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'A coluna, o fundo e o alinhamento ficam salvos por perfil para manter sua leitura consistente em qualquer livro.',
                  style: _preferences.fontPreset.applyTo(
                    theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  const Icon(Icons.dark_mode_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tema geral do app',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  Switch.adaptive(
                    value: _isDarkMode,
                    onChanged: (bool value) {
                      setState(() {
                        _isDarkMode = value;
                      });
                      widget.onDarkModeChanged(value);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.labelLarge,
          ),
      ],
    );
  }
}
