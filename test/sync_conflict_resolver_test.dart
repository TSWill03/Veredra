// Signature: dev.tswicolly03
import 'package:flutter_test/flutter_test.dart';
import 'package:txt_webnovel_reader/services/sync/sync_conflict_resolver.dart';

void main() {
  const SyncConflictResolver resolver = SyncConflictResolver();

  test('progress conflict keeps the furthest reading position', () {
    final Map<String, dynamic> winner = resolver.resolveProgress(
      <String, dynamic>{
        'chapter_index': 3,
        'chapter_progress': 0.9,
        'updated_at': '2026-07-13T13:00:00Z',
      },
      <String, dynamic>{
        'chapter_index': 4,
        'chapter_progress': 0.1,
        'updated_at': '2026-07-13T12:00:00Z',
      },
    );
    expect(winner['chapter_index'], 4);
  });

  test('independent records merge by id using updated time', () {
    final List<Map<String, dynamic>> merged = resolver.mergeById(
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'a',
          'value': 'old',
          'updated_at': '2026-07-13T10:00:00Z',
        },
      ],
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'a',
          'value': 'new',
          'updated_at': '2026-07-13T11:00:00Z',
        },
        <String, dynamic>{
          'id': 'b',
          'value': 'kept',
          'updated_at': '2026-07-13T09:00:00Z',
        },
      ],
    );
    expect(merged, hasLength(2));
    expect(merged.firstWhere((record) => record['id'] == 'a')['value'], 'new');
  });
}
