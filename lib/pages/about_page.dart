// Signature: dev.tswicolly03
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const String _repositoryUrl = 'https://github.com/TSWill03/Veredra';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre o Veredra'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    'V',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Veredra', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Leitor multiplataforma para romances, webnovels e ebooks com leitura continua, biblioteca local, destaque de trechos e traducao desktop-first.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    Chip(
                      label: const Text('Versao 0.1.0+1'),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: const Text('Flutter'),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: const Text('dev.tswicolly03'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _AboutSection(
            title: 'O que faz o Veredra',
            lines: const <String>[
              'Leitura continua para livros textuais, EPUB e PDF.',
              'Biblioteca local com favoritos, capas, notas e perfis.',
              'Traducao local no desktop preservando o original.',
              'Backup completo para quebrar o galho entre dispositivos.',
            ],
          ),
          const SizedBox(height: 14),
          _AboutSection(
            title: 'Formatos',
            lines: const <String>[
              'TXT, MD, HTML, XHTML, EPUB e PDF.',
              'Capas em JPG, JPEG, PNG, WEBP, GIF e BMP.',
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Repositorio', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(_repositoryUrl, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: _repositoryUrl),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link do repositorio copiado.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copiar link'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({
    required this.title,
    required this.lines,
  });

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final String line in lines) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 7),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(line)),
              ],
            ),
            if (line != lines.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
