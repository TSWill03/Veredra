<!-- Signature: dev.tswicolly03 -->
# Plano de validacao e rollout: livros completos

## Objetivo
Garantir que um livro presente no cliente A seja legivel **sem acesso ao
arquivo original** no cliente B autenticado com a mesma conta, preservando
progresso e anotacoes que ja sincronizam separadamente.

## Pre-requisitos
- PR da branch `feat/sync-book-content-storage-20261119` revisado, sem merge.
- Migração `20261119165543_book_content_sync.sql` revisada e aplicada em staging;
  confirmar storage privado, MIME ZIP, policy por `auth.uid()`.
- Duas contas isoladas e dois clientes distintos, apenas arquivos autorizados.
- Backend com quota e tamanho permitidos; credenciais de staging (nao em Git).
- Build com `--dart-define-from-file=config/supabase.production.json`
  apenas se for realmente desejado usar producao; staging preferivel.

## Checklist funcional
1. Importar TXT multipartes, MD/HTML, EPUB com capa e PDF em um cliente nativo.
2. Habilitar primeiro sync de metadados e verificar que nenhum blob foi enviado.
3. Consentir separadamente no envio de livros e verificar upload e checksum.
4. Abrir Web em outro navegador e baixar TXT/EPUB: capas, capitulos e progresso.
5. Abrir Windows/Android e baixar PDF; abrir PDF e reler apos reinicio offline.
6. Em dispositivo B, importar arquivos com ID igual/diferente e verificar
   comportamento de deduplicacao/possiveis duplicatas por identidade local.
7. Modificar o mesmo livro em dois dispositivos: nao pode sobrescrever dados
   divergentes sem aviso explicito.
8. Interromper upload/download e reiniciar: arquivo local original intacto.
9. Desligar sync de arquivos: nenhum novo upload; leitura local segue normal.
10. Tentar pacote >95 MiB, ZIP corrompido e arquivo nao autorizado: falhar
    com mensagem util sem sobrescrever biblioteca.
11. Conta A nao pode listar/baixar/remover objetos da conta B.
12. Excluir conta: remover primeiro TODOS objetos do bucket e depois registros;
    falha de limpeza deve impedir exclusao da conta.
13. Rodar `flutter pub get`, `dart format --set-exit-if-changed lib test`,
    `flutter analyze`, `flutter test`, Web PWA e Windows/Android conforme CI.

## Criterio de liberacao
Nao liberar automaticamente nem fazer merge ate CI e teste real de duas contas
e dois dispositivos terminarem sem erros. Validar tambem custos e quotas do
Storage e compatibilidade com planos gratuitos. Para pacotes grandes, planejar
TUS/resumable antes de garantir retomada de upload.

## Rollback
Desabilitar consentimento para novos envios, restaurar build anterior,
preservar os arquivos ja existentes no Storage e metadados. Nao executar
exclusao destrutiva de dados de usuario no rollback; mantenha backup e
procedimento separado e auditado para eventual limpeza.

## Supabase hosted rollout — 2026-11-19

The existing and reviewed `book_content_sync` migration was applied to the Veredra hosted Supabase project (ref `bfvbkypjyvyolguzzslt`) on 2026-11-19. The hosted migration version assigned by Supabase is `20261119165543`, so the versioned SQL filename in this branch is aligned with hosted migration history to prevent duplicate migration execution in later `db push` runs.

Verified against hosted schema: private bucket retains `public=false`; `application/zip` is allowed by the bucket and `book_assets_mime_type_check`; user-prefixed authenticated INSERT policy permits `.zip`; SELECT/UPDATE/DELETE policies remain unchanged; index `book_assets_owner_book_idx` exists. Before/after metadata counts: 10 books, 0 assets, 0 blobs. Rollback-only SQL probe of book_assets ZIP insert succeeded without committed data. This is schema verification only, NOT a successful end-to-end authenticated Storage upload/download.

Before enabling wide rollout, do a real upload/download via the app with a test account, verify user A cannot access B, quotas, conflicts, offline restore and upload error diagnostics. Backup of preflight policy definitions and cautious rollback procedure is stored outside Git on the authorized Destruking computer.


## Large EPUB with repeated TOC chapter bodies — 2026-11-19

The Windows source device revealed a historical imported EPUB with 326 distinct
chapter paths but byte-identical chapter text. Raw total: about 335.9 MiB;
unique body: about 1.03 MiB. The old code refused reopening/sync at 128 MiB
before any upload could reach Supabase.

The fix is conservative: reopening existing native collections still enforces
per-file (16 MiB) and chapter-count safety, without rejecting the sum of
duplicated legacy files. Transfer uses schema 2 only when repeated content is
present; the ZIP stores unique chapter bytes once, but a manifest preserves
each chapter index and title. Restore writes one content file per unique
body and retains every chapter reference. Older schema-1 bundles remain
unchanged and readable. A known-reasons allowlist improves warning messages
without exposing content or filesystem paths.

Verification: Flutter analyze 0 issues; regression tests cover deduplicated
upload, chapter/title preservation, restored offline reading, deterministic
re-sync and >128 MiB logical repeat data. A READ-ONLY offline dry run of
the actual 326-file imported book on the authorized Destruking computer
produced a schema-2 ZIP with 326 manifest entries, 1 unique chapter payload
and 892,191 bytes; the source was not changed, and no network upload occurred.
The temporary test using the private local path was removed from Git.

Important: this is a synchronization/archival fix. The EPUB importer's TOC
appears to repeat a whole-book body as 326 chapters; correct navigation
requires separate source-EPUB analysis, without silently changing progress.
