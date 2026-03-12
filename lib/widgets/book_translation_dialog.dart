// Signature: dev.tswicolly03
import 'package:flutter/material.dart';

import '../models/translation_engine_status.dart';
import '../models/translation_language.dart';
import '../models/translation_pair.dart';
import '../services/translation_service.dart';

class BookTranslationDialog extends StatefulWidget {
  const BookTranslationDialog({
    super.key,
    required this.bookTitle,
    required this.translationService,
  });

  final String bookTitle;
  final TranslationService translationService;

  @override
  State<BookTranslationDialog> createState() => _BookTranslationDialogState();
}

class _BookTranslationDialogState extends State<BookTranslationDialog> {
  TranslationEngineStatus? _status;
  bool _isLoading = true;
  bool _isInstalling = false;
  String? _selectedSourceCode;
  String? _selectedTargetCode;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _actionError = null;
    });

    try {
      final TranslationEngineStatus status =
          await widget.translationService.inspectLocalEngine();
      if (!mounted) {
        return;
      }

      final List<TranslationPair> pairs = _mergedPairs(status);
      final TranslationPair? preferredPair = _pickPreferredPair(pairs);
      setState(() {
        _status = status;
        _selectedSourceCode = preferredPair?.source.code;
        _selectedTargetCode = preferredPair?.target.code;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = null;
        _actionError = error.toString();
        _isLoading = false;
      });
    }
  }

  List<TranslationPair> _mergedPairs(TranslationEngineStatus status) {
    final Map<String, TranslationPair> pairsById = <String, TranslationPair>{};

    for (final TranslationPair pair in status.availablePairs) {
      pairsById[pair.id] = pair;
    }
    for (final TranslationPair pair in status.installedPairs) {
      final TranslationPair? existing = pairsById[pair.id];
      pairsById[pair.id] = TranslationPair(
        source: pair.source,
        target: pair.target,
        installed: true,
        availableOnline: existing?.availableOnline ?? pair.availableOnline,
      );
    }

    final List<TranslationPair> pairs = pairsById.values.toList(growable: false)
      ..sort((TranslationPair a, TranslationPair b) {
        final int sourceCompare = a.source.label
            .toLowerCase()
            .compareTo(b.source.label.toLowerCase());
        if (sourceCompare != 0) {
          return sourceCompare;
        }
        return a.target.label
            .toLowerCase()
            .compareTo(b.target.label.toLowerCase());
      });
    return pairs;
  }

  TranslationPair? _pickPreferredPair(List<TranslationPair> pairs) {
    if (pairs.isEmpty) {
      return null;
    }

    for (final TranslationPair pair in pairs) {
      if (pair.source.code == 'en' &&
          (pair.target.code == 'pb' || pair.target.code == 'pt')) {
        return pair;
      }
    }

    for (final TranslationPair pair in pairs) {
      if (pair.installed) {
        return pair;
      }
    }

    return pairs.first;
  }

  List<TranslationLanguage> _sourceLanguages(List<TranslationPair> pairs) {
    final Map<String, TranslationLanguage> languages =
        <String, TranslationLanguage>{};
    for (final TranslationPair pair in pairs) {
      languages[pair.source.code] = pair.source;
    }
    return languages.values.toList(growable: false)
      ..sort((TranslationLanguage a, TranslationLanguage b) {
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
  }

  List<TranslationPair> _targetPairs(List<TranslationPair> pairs) {
    final String? selectedSourceCode = _selectedSourceCode;
    if (selectedSourceCode == null || selectedSourceCode.isEmpty) {
      return pairs;
    }
    return pairs
        .where((TranslationPair pair) => pair.source.code == selectedSourceCode)
        .toList(growable: false);
  }

  TranslationPair? _selectedPair(List<TranslationPair> pairs) {
    final String? targetCode = _selectedTargetCode;
    if (targetCode == null) {
      return null;
    }

    for (final TranslationPair pair in pairs) {
      if (pair.target.code == targetCode) {
        return pair;
      }
    }
    return null;
  }

  Future<void> _installArgos() async {
    setState(() {
      _isInstalling = true;
      _actionError = null;
    });
    try {
      await widget.translationService.installArgosPackage();
      await _loadStatus();
    } catch (error) {
      if (mounted) {
        setState(() {
          _actionError = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInstalling = false;
        });
      }
    }
  }

  Future<void> _installModel(TranslationPair pair) async {
    setState(() {
      _isInstalling = true;
      _actionError = null;
    });
    try {
      await widget.translationService.installModel(pair);
      await _loadStatus();
    } catch (error) {
      if (mounted) {
        setState(() {
          _actionError = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInstalling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TranslationEngineStatus? status = _status;

    return AlertDialog(
      title: const Text('Traduzir livro'),
      content: SizedBox(
        width: 560,
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : status == null
                ? Text(
                    _actionError ?? 'Nao foi possivel verificar o motor local.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.bookTitle,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'O original permanece intacto. A traducao sera salva como um novo livro na sua biblioteca.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        _StatusCard(status: status),
                        if (_actionError?.trim().isNotEmpty ??
                            false) ...<Widget>[
                          const SizedBox(height: 14),
                          Text(
                            _actionError!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                        if (status.supported &&
                            !status.pythonDetected) ...<Widget>[
                          const SizedBox(height: 16),
                          const Text(
                            'Instale Python 3 com pip e reabra esta janela para ativar a traducao local.',
                          ),
                        ],
                        if (status.canInstallArgos &&
                            !status.argosInstalled) ...<Widget>[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _isInstalling ? null : _installArgos,
                            icon: const Icon(Icons.download_rounded),
                            label: Text(
                              _isInstalling
                                  ? 'Instalando motor local...'
                                  : 'Instalar Argos Translate neste desktop',
                            ),
                          ),
                        ],
                        if (status.isReady && _mergedPairs(status).isNotEmpty)
                          ..._buildPairSelector(status),
                        if (status.isReady &&
                            _mergedPairs(status).isEmpty) ...<Widget>[
                          const SizedBox(height: 16),
                          const Text(
                            'Nenhum par de idiomas foi encontrado. Conecte a internet para buscar modelos do Argos ou instale um modelo manualmente no seu Python.',
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isInstalling ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _buildCanTranslate(status)
              ? () {
                  final List<TranslationPair> targetPairs =
                      _targetPairs(_mergedPairs(status!));
                  final TranslationPair? pair = _selectedPair(targetPairs);
                  if (pair != null && pair.installed) {
                    Navigator.of(context).pop(pair);
                  }
                }
              : null,
          child: const Text('Traduzir'),
        ),
      ],
    );
  }

  List<Widget> _buildPairSelector(TranslationEngineStatus status) {
    final List<TranslationPair> pairs = _mergedPairs(status);
    final List<TranslationLanguage> sources = _sourceLanguages(pairs);
    if (_selectedSourceCode == null && sources.isNotEmpty) {
      _selectedSourceCode = sources.first.code;
    }

    final List<TranslationPair> targetPairs = _targetPairs(pairs);
    if (targetPairs.isNotEmpty &&
        !targetPairs.any(
          (TranslationPair pair) => pair.target.code == _selectedTargetCode,
        )) {
      _selectedTargetCode = targetPairs.first.target.code;
    }

    final TranslationPair? selectedPair = _selectedPair(targetPairs);

    return <Widget>[
      const SizedBox(height: 18),
      DropdownButtonFormField<String>(
        key: ValueKey<String>('source-${_selectedSourceCode ?? ''}'),
        initialValue: _selectedSourceCode,
        decoration: const InputDecoration(
          labelText: 'Idioma de origem',
        ),
        items: <DropdownMenuItem<String>>[
          for (final TranslationLanguage language in sources)
            DropdownMenuItem<String>(
              value: language.code,
              child: Text(language.label),
            ),
        ],
        onChanged: _isInstalling
            ? null
            : (String? value) {
                setState(() {
                  _selectedSourceCode = value;
                  _selectedTargetCode = null;
                });
              },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey<String>(
          'target-${_selectedSourceCode ?? ''}-${_selectedTargetCode ?? ''}',
        ),
        initialValue: _selectedTargetCode,
        decoration: const InputDecoration(
          labelText: 'Idioma de destino',
        ),
        items: <DropdownMenuItem<String>>[
          for (final TranslationPair pair in targetPairs)
            DropdownMenuItem<String>(
              value: pair.target.code,
              child: Text(pair.target.label),
            ),
        ],
        onChanged: _isInstalling
            ? null
            : (String? value) {
                setState(() {
                  _selectedTargetCode = value;
                });
              },
      ),
      const SizedBox(height: 14),
      if (selectedPair != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: themeColor(status, selectedPair),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                selectedPair.installed
                    ? 'Este par ja esta pronto para uso offline.'
                    : selectedPair.availableOnline
                        ? 'Esse modelo ainda nao esta instalado neste desktop.'
                        : 'Esse par nao esta instalado e nao ficou disponivel online agora.',
              ),
              if (!selectedPair.installed &&
                  selectedPair.availableOnline) ...<Widget>[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed:
                      _isInstalling ? null : () => _installModel(selectedPair),
                  icon: const Icon(Icons.cloud_download_rounded),
                  label: Text(
                    _isInstalling
                        ? 'Baixando modelo...'
                        : 'Baixar modelo para uso offline',
                  ),
                ),
              ],
            ],
          ),
        ),
    ];
  }

  bool _buildCanTranslate(TranslationEngineStatus? status) {
    if (status == null || !status.isReady) {
      return false;
    }

    final TranslationPair? pair =
        _selectedPair(_targetPairs(_mergedPairs(status)));
    return pair != null && pair.installed && !_isInstalling;
  }

  Color themeColor(TranslationEngineStatus status, TranslationPair pair) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    if (pair.installed) {
      return colorScheme.secondaryContainer;
    }
    if (pair.availableOnline) {
      return colorScheme.tertiaryContainer;
    }
    return colorScheme.surfaceContainerHighest;
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
  });

  final TranslationEngineStatus status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _row('Desktop suportado', status.supported ? 'Sim' : 'Nao'),
          _row('Python detectado', status.pythonDetected ? 'Sim' : 'Nao'),
          _row('Argos instalado', status.argosInstalled ? 'Sim' : 'Nao'),
          if (status.pythonCommandLabel?.trim().isNotEmpty ?? false)
            _row('Python', status.pythonCommandLabel!),
          if (status.pythonVersion?.trim().isNotEmpty ?? false)
            _row('Versao', status.pythonVersion!),
          _row(
            'Modelos instalados',
            status.installedPairs.length.toString(),
          ),
          if (status.message?.trim().isNotEmpty ?? false) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              status.message!,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 160,
            child: Text(label),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
