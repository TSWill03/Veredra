<!-- Signature: dev.tswicolly03 -->
# Offline-first

## Desktop

O desktop ja funciona offline para livros importados, biblioteca, progresso, marcadores, anotacoes e preferencias porque os dados ficam em arquivos locais. A traducao local funciona offline depois que Python, Argos Translate e o modelo de idioma ja estao instalados.

## Web/PWA

Objetivo do MVP Web:

- O app shell abre offline depois do primeiro carregamento pelo service worker padrao do Flutter.
- Livros `.txt`, `.md`, `.markdown`, `.html`, `.htm`, `.xhtml` e EPUB convertido ficam salvos no storage local do navegador.
- Biblioteca, progresso, notas, marcadores, estatisticas e perfis usam storage compativel com Web.
- O usuario consegue fechar o navegador, abrir de novo e continuar lendo livros importados.

## Persistencia e limitacoes Web

- O storage Web usa IndexedDB para strings e bytes e migra automaticamente as
  chaves antigas de `shared_preferences_web`.
- Quota e despejo continuam sujeitos ao navegador; o usuario deve manter backup
  dos dados importantes.
- PDF ainda nao esta disponivel na versao Web.
- Importacao por pasta esta disponivel apenas no desktop.
- Backup/restauracao ainda esta disponivel apenas no desktop.
- Traducao local com Python/Argos esta disponivel apenas no desktop.

## Evolucao recomendada

- Avaliar OPFS para blobs muito grandes, preservando fallback IndexedDB.
- Criar manifest local com `schemaVersion`, `appVersion`, `profileId`, `createdAt` e `updatedAt`.
- Expandir os testes de browser existentes para livros grandes e upgrade entre
  versoes do service worker.
- Expor uso de armazenamento/quota para o usuario.

## Estrategia de schema local

Novos snapshots locais devem adotar metadados assim:

```json
{
  "schemaVersion": 1,
  "appVersion": "0.1.0",
  "profileId": "principal",
  "createdAt": "2026-06-30T00:00:00.000Z",
  "updatedAt": "2026-06-30T00:00:00.000Z"
}
```

Leitores devem aceitar ausencia desses campos para manter compatibilidade com dados antigos.
