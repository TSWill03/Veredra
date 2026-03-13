// Signature: dev.tswicolly03
import 'package:flutter/material.dart';

import '../models/reader_bookmark.dart';

class BookmarkEditorResult {
  const BookmarkEditorResult({
    required this.note,
    required this.excerpt,
    required this.isFavorite,
  });

  final String note;
  final String excerpt;
  final bool isFavorite;
}

Future<BookmarkEditorResult?> showBookmarkEditorDialog({
  required BuildContext context,
  required String chapterTitle,
  ReaderBookmark? existing,
}) async {
  final TextEditingController noteController = TextEditingController(
    text: existing?.note ?? '',
  );
  final TextEditingController excerptController = TextEditingController(
    text: existing?.excerpt ?? '',
  );
  bool isFavorite = existing?.isFavorite ?? false;

  final BookmarkEditorResult? result = await showDialog<BookmarkEditorResult>(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text(existing == null ? 'Novo marcador' : 'Editar marcador'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      chapterTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: excerptController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Trecho importante',
                        hintText: 'Cole ou escreva um trecho para lembrar',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Anotacao',
                        hintText: 'O que voce quer lembrar deste ponto?',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Marcar como favorito'),
                      value: isFavorite,
                      onChanged: (bool value) {
                        setState(() {
                          isFavorite = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    BookmarkEditorResult(
                      note: noteController.text.trim(),
                      excerpt: excerptController.text.trim(),
                      isFavorite: isFavorite,
                    ),
                  );
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      );
    },
  );

  noteController.dispose();
  excerptController.dispose();
  return result;
}
