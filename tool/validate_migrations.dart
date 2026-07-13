// Signature: dev.tswicolly03
import 'dart:io';

void main() {
  final Directory directory = Directory('supabase/migrations');
  final List<File> files = directory
      .listSync()
      .whereType<File>()
      .where((File file) => file.path.endsWith('.sql'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    stderr.writeln('Nenhuma migration Supabase encontrada.');
    exitCode = 1;
    return;
  }
  final String sql =
      files.map((File file) => file.readAsStringSync()).join('\n');
  final List<String> requiredTables = <String>[
    'profiles',
    'devices',
    'user_preferences',
    'books',
    'book_assets',
    'reading_progress',
    'bookmarks',
    'annotations',
    'highlights',
    'reading_stats',
    'sync_state',
    'sync_operations',
  ];
  final List<String> errors = <String>[];
  for (final String table in requiredTables) {
    if (!sql.contains('create table public.$table')) {
      errors.add('Tabela ausente: $table');
    }
  }
  for (final String marker in <String>[
    'enable row level security',
    'force row level security',
    'grant select, insert, update, delete',
    'revoke all on public.',
    '(select auth.uid()) = user_id',
    'veredra_assets_insert_own',
    'delete_own_account',
  ]) {
    if (!sql.contains(marker)) {
      errors.add('Protecao obrigatoria ausente: $marker');
    }
  }
  if (errors.isNotEmpty) {
    stderr.writeln(errors.join('\n'));
    exitCode = 1;
    return;
  }
  stdout.writeln('Migrations possuem schema, RLS e Storage esperados.');
}
