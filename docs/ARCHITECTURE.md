<!-- Signature: dev.tswicolly03 -->
# Arquitetura

## Estado atual

O Veredra ainda esta organizado por tipo de arquivo:

```text
lib/
  main.dart
  models/
  pages/
  services/
  widgets/
```

Esse desenho funcionou bem para o MVP, mas os arquivos maiores ja concentram responsabilidades demais. `BookService`, `LibraryPage`, `ReaderPage`, `BackupService` e `TranslationService` misturam regras de negocio, infraestrutura, persistencia e interacao de plataforma.

## Mudanca incremental aplicada

Foi criada uma camada de storage multiplataforma:

```text
lib/services/storage/
  app_storage.dart
  app_storage_base.dart
  app_storage_io.dart
  app_storage_web.dart
  app_storage_stub.dart
```

No desktop, o storage usa arquivos locais com escrita temporaria antes da substituicao. Na Web, usa `shared_preferences_web` como armazenamento local do navegador para o MVP PWA.

Tambem foi criado `PlatformCoverImage`, que separa renderizacao de capa local (`Image.file`) da capa persistida no navegador (`Image.memory`).

## Arquitetura recomendada

Migracao gradual sugerida:

```text
lib/
  app/
    veredra_app.dart
    app_bootstrap.dart
  shared/
    platform/
    storage/
    logging/
    errors/
  features/
    library/
      domain/
      application/
      infra/
      presentation/
    reader/
      domain/
      application/
      infra/
      presentation/
    profiles/
    backup/
    annotations/
    translation/
    settings/
```

## Onde aplicar conceitos de dominio

- Entidades: `Book`, `LibraryEntry`, `AppProfile`.
- Objetos de valor: `BookReference`, `ReadingProgress`, preferencias do leitor.
- Casos de uso: importar livro, reabrir livro, salvar progresso, exportar backup, restaurar backup, traduzir livro.
- Repositorios: biblioteca, capitulos, perfis, progresso, anotacoes, marcadores.
- DTOs/mappers: backup, EPUB/PDF/importacao, storage Web.

CQRS nao e necessario agora. Pode fazer sentido apenas para busca/indexacao futura, separando escrita da biblioteca e leitura/indexes.

