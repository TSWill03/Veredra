import 'package:flutter/material.dart';

import '../models/translation_progress.dart';

class TranslationProgressDialog extends StatelessWidget {
  const TranslationProgressDialog({
    super.key,
    required this.bookTitle,
    required this.progress,
  });

  final String bookTitle;
  final TranslationProgress progress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Traduzindo livro'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              bookTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            Text(progress.stage),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress.fraction),
            const SizedBox(height: 12),
            Text(
              '${progress.completedChapters} de ${progress.totalChapters} capitulos',
              style: theme.textTheme.bodyMedium,
            ),
            if (progress.currentChapterTitle?.trim().isNotEmpty ??
                false) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                progress.currentChapterTitle!,
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (progress.detail?.trim().isNotEmpty ?? false) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                progress.detail!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
