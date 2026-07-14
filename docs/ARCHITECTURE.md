<!-- Signature: dev.tswicolly03 -->
# Arquitetura

## Principios

1. leitura local nao depende de rede, conta ou backend;
2. UI depende de interfaces de auth/sync, nao diretamente do Supabase;
3. dados privados permanecem locais por padrao;
4. operacoes remotas sao idempotentes, isoladas por usuario e recuperaveis;
5. mudancas no storage preservam os dados existentes.

## Organizacao atual

```text
lib/
  config/                 # dart-defines e redirects
  models/                 # entidades locais existentes
  pages/                  # biblioteca, leitor, conta/sync
  services/
    auth/                 # gateway, controller, sessao segura, Supabase
    storage/              # contrato comum + IO/IndexedDB
    sync/                 # repositorios, fila, rede, conflitos, coordinator
    diagnostics_service.dart
    import_limits.dart
  widgets/
supabase/
  migrations/             # schema remoto versionado
  tests/database/         # pgTAP/RLS
e2e/                      # servidor /veredra/ e Playwright
```

Os modulos legados ainda sao organizados por tipo; a separacao por feature deve
continuar incrementalmente, sem reescrita ampla de `BookService`, `LibraryPage`
ou `ReaderPage`.

## Bootstrap

`main.dart` valida a configuracao. Com URL/chave publica validas, inicializa o
Supabase com PKCE, refresh automatico e storage seguro; caso contrario injeta
`LocalOnlyAuthGateway`. O mesmo app e a mesma biblioteca funcionam nos dois
modos. Erros de bootstrap sao registrados localmente e fazem fallback seguro.

## Persistencia local

- Windows/Android: arquivos no diretorio da aplicacao, com escrita temporaria e
  substituicao atomica.
- Web: IndexedDB `veredra_local_storage`, store `entries`, com valores string ou
  bytes. A primeira leitura migra chaves `veredra.storage.*` do
  `shared_preferences_web` e so remove o legado apos gravacao bem-sucedida.
- arquivos/binarios e metadados usam a mesma interface de storage hoje; uma
  evolucao para Drift/SQLite/OPFS continua possivel sem afetar a UI.

## Auth e sync

```text
AccountPage -> AccountController -> AuthGateway -> SupabaseAuthGateway
Library/UI -> SyncCoordinator -> Queue + LocalRepository + RemoteGateway
```

`LocalSyncRepository` gera snapshots e aplica mudancas pelos servicos locais
existentes. `SupabaseSyncGateway` converte as entidades para tabelas remotas.
`SyncCoordinator` envia a fila, puxa alteracoes desde o ultimo cursor, resolve
conflitos e atualiza estado visual. Uma falha remota nunca invalida a gravacao
local.

## Modelo remoto

`profiles`, `devices`, `user_preferences`, `books`, `book_assets`,
`reading_progress`, `bookmarks`, `annotations`, `highlights`, `reading_stats`,
`sync_state` e `sync_operations`. Registros sincronizaveis usam UUID, `user_id`,
`device_id`, timestamps, `deleted_at` e `version` conforme aplicavel.

RLS e grants restringem cada tabela a `auth.uid() = user_id`. O bucket
`veredra-books` e privado e limita caminhos ao prefixo do UUID do usuario.

## Evolucao recomendada

- extrair contratos de biblioteca/leitor para features;
- Drift/SQLite para consultas e migrations locais mais complexas;
- OPFS para blobs muito grandes na Web quando suporte e recuperacao forem
  comprovados;
- outbox transacional quando metadados e fila passarem ao mesmo banco local;
- instaladores assinados com registro de deep link por plataforma.

CQRS nao e necessario para a beta; somente indexacao/busca futura pode justificar
um read model separado.
