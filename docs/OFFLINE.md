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

## Limitacoes Web conhecidas

- O storage Web atual usa `shared_preferences_web`, adequado para MVP e livros pequenos/medios, mas limitado por quota do navegador.
- PDF ainda nao esta disponivel na versao Web.
- Importacao por pasta esta disponivel apenas no desktop.
- Backup/restauracao ainda esta disponivel apenas no desktop.
- Traducao local com Python/Argos esta disponivel apenas no desktop.

## Evolucao recomendada

- Migrar livros/capitulos da Web para IndexedDB ou OPFS.
- Criar manifest local com `schemaVersion`, `appVersion`, `profileId`, `createdAt` e `updatedAt`.
- Adicionar testes de browser para reabrir PWA offline com livro importado.
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
