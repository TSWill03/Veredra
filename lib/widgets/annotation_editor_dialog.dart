// Signature: dev.tswicolly03
import 'package:flutter/material.dart';

import '../models/reader_annotation.dart';
import '../models/reader_highlight_color.dart';

class AnnotationEditorResult {
  const AnnotationEditorResult({
    required this.note,
    required this.color,
    required this.isFavorite,
  });

  final String note;
  final ReaderHighlightColor color;
  final bool isFavorite;
}

Future<AnnotationEditorResult?> showAnnotationEditorDialog({
  required BuildContext context,
  required String chapterTitle,
  required String selectedText,
  required bool requireNote,
  ReaderAnnotation? existing,
}) async {
  final TextEditingController noteController = TextEditingController(
    text: existing?.note ?? '',
  );
  ReaderHighlightColor selectedColor =
      existing?.color ?? ReaderHighlightColor.amber;
  bool isFavorite = existing?.isFavorite ?? false;

  final AnnotationEditorResult? result =
      await showDialog<AnnotationEditorResult>(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text(existing == null ? 'Nova anotacao' : 'Editar anotacao'),
            content: SizedBox(
              width: 540,
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selectedColor.backgroundColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(selectedText),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final ReaderHighlightColor color
                            in ReaderHighlightColor.values)
                          ChoiceChip(
                            label: Text(color.label),
                            selected: selectedColor == color,
                            onSelected: (bool selected) {
                              if (!selected) {
                                return;
                              }
                              setState(() {
                                selectedColor = color;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Favoritar este destaque'),
                      value: isFavorite,
                      onChanged: (bool value) {
                        setState(() {
                          isFavorite = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Comentario',
                        hintText: 'Escreva sua observacao sobre este trecho',
                      ),
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
                  final String note = noteController.text.trim();
                  if (requireNote && note.isEmpty) {
                    return;
                  }
                  Navigator.of(context).pop(
                    AnnotationEditorResult(
                      note: note,
                      color: selectedColor,
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
  return result;
}
