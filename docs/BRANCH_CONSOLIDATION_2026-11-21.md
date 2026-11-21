# Consolidação de branches — Veredra e Wicolly-Sites (21/11/2026)

**Objetivo:** preservar a experiência offline-first, continuidade de leitura, livros e dados do usuário. Unificar apenas mudanças demonstravelmente compatíveis com a `main`, evitar rollback de código antigo e remover referências remotas históricas verificadas. Esta operação **não** altera tabelas, storage remoto, dados do cliente, permissões ou credenciais.

## Integrações feitas e por quê

| Repositório / integração | Decisão | Motivo técnico / proteção |
| --- | --- | --- |
| Veredra [PR #25](https://github.com/TSWill03/Veredra/pull/25), merge `9649a7a` | **Mesclado** | O GitHub Releases retorna tags com `+` codificado em URL como `%2B`; a versão anterior recusava o instalador Windows oficial. Mantém verificação HTTPS, digest SHA-256, tamanho e consentimento. CI Flutter e iOS aprovados. Versão `0.1.4+6`. |
| Veredra [tag/release v0.1.4+6](https://github.com/TSWill03/Veredra/releases/tag/v0.1.4%2B6) | **Publicada** | Tag anotada no merge `9649a7a` após verificação de ancestralidade em main e contrato de versão. Workflow Windows installer and GitHub Release concluiu com sucesso, gerando instalador/checksum oficiais. |
| Wicolly-Sites [PR #37](https://github.com/TSWill03/Wicolly-Sites/pull/37), merge `47510d7` | **Mesclado** | Publica o Web/PWA `0.1.4+6` somente após release estável; build e manifesto alinhados. Não altera banco, livros locais nem outras seções do site. Deploy Cloudflare Pages possui CI e smoke de produção próprios. |
| Veredra [PR #26](https://github.com/TSWill03/Veredra/pull/26), merge `dad6ad7` | **Mesclado em substituição ao PR #21** | O PR #21 original estava atrás da main e em conflito. Portados somente 15 ícones iOS, gerador, validador e guia (18 arquivos). Não altera bundle ID, auth, sync, progresso, arquivos dos livros ou atualização Windows. Flutter CI e iOS CI aprovados; instalação iPhone física permanece procedimento separado e **nunca** desinstalar para ajustar o ícone. |

## Branches remotas excluídas e justificativa individual

Exclusão é de **refs remotas de desenvolvimento**, não do conteúdo integrado nem dos diretórios de trabalho locais. A exclusão foi condicionada a SHA esperado, ausência de PR aberto e ancestralidade direta na main, exceto dois casos comprovados de substituição. Commits integrados continuam recuperáveis pela main; PRs antigos continuam acessíveis pelo GitHub.

| Repositório | Branch remota excluída | Motivo |
| --- | --- | --- |
| Veredra | `feat/audit-web-pwa-production` | Commit `7a0e052` já é ancestral da main; auditoria Web/PWA foi absorvida pela base atual. |
| Veredra | `feat/auth-sync-validation-production` | Commit `a7f90bb` já integrado; manter branch duplicaria validação de autenticação/sync. |
| Veredra | `feat/reader-site-return-20261120` | PR #22 mesclado, botão discreto já na main e publicado. |
| Veredra | `feat/reconnect-supabase-2026-11` | PR #15 mesclado; configuração do Supabase Brasil e CI já estão na main. |
| Veredra | `feat/sync-book-content-storage-20261119` | PR #19 mesclado; sincronização de arquivos completos com consentimento já entrou na main. |
| Veredra | `feat/update-center-autoupdate-20261120` | PR #23 mesclado; badge azul e central de atualização já estão na main. |
| Veredra | `fix/windows-release-percent-encoded-url-20261120` | PR #25 mesclado e release estável `v0.1.4+6` publicada; branch sem função restante. |
| Veredra | `fix/windows-release-tag-check-20261120` | PR #24 mesclado; validação da tag/republicação já está na main. |
| Veredra | `fix/ios-app-icon-xcross-20261120` | PR #21 encerrado como **substituído** pela PR #26. Os 18 arquivos do delta original foram verificados byte a byte como idênticos aos da main após a integração; branch remota dispensável. Worktree com override local preservado. |
| Wicolly-Sites | `feat/veredra-production-reader-ui-20261120` | PR #35 mesclado; sync de leitura e botão de retorno já foram publicados. |
| Wicolly-Sites | `feat/veredra-update-center-20261120` | PR #36 mesclado; feed de updates `0.1.4+5` foi superado pela versão `0.1.4+6`. |
| Wicolly-Sites | `fix/veredra-update-center-0-1-4-6-20261120` | PR #37 mesclado; atualização do site integrada e branch não é mais necessária. |
| Wicolly-Sites | `feat/veredra-0-1-2-rc1-web-sync` | PR #34 foi encerrado sem merge: RC2 `0.1.2+3` ficou obsoleta frente à versão `0.1.4+6`. Promover essa branch faria downgrade do site, potencialmente quebrando cliente/sync; correção de EPUB já entrou pelo PR #19 do app. |

## O que foi intencionalmente preservado fora da main

| Branch / PR | Motivo da retenção |
| --- | --- |
| Veredra #8 (acesso privado) e Wicolly-Sites #5 (pipeline privado) | Exigir login antes da leitura mudaria a política offline-first e requer decisão explícita e testes Cloudflare Access; não aprovado nesta consolidação. |
| Veredra #10–#13 (importação ZIP, backup Web, arquivos privados, traduções) | Pilha de PRs dependentes de branch base antiga com mais de 60 commits de defasagem; mesclar toda a árvore pode reintroduzir bugs ou duplicar storage/RLS. Importador ZIP está sendo portado de forma independente, sem modo privado, com limites, testes e rollback; não publicar sem homologação de ZIPs hostis e navegador/iPhone. Reavaliar backup Web e recuperação de traduções separadamente. |
| Veredra #14 (ferramentas iOS/SDK histórico) | Configuração antiga do SDK externo não deve substituir xcross atual; revalidar apenas partes úteis. |
| `feat/reading-continuity-auto-sync-20261119` | Já integrada (#20), mas ainda há worktree do Goiatuba com dois stashes históricos que devem permanecer acessíveis. |
| `feat/google-oauth-20261119` e `feat/desktop-google-oauth-20261119` | Há worktrees locais com arquivos de configuração não commitados; preservar até revisão diferencial. As PRs originais #16/#18 foram mescladas. |
| `feat/update-alert-20261106`, `backup/auth-sync-pre-gitguardian-20260713` | Branch/protótipo local antigo com alterações não commitadas e branch de backup; preservar, não substituir sistema de updates atual. |
| Wicolly-Sites #17 (tema PT/EN), outras branches de MeuX, MundoFit, infraestrutura | Alterações de outros produtos não devem ser apagadas ou mescladas como efeito colateral de uma consolidação Veredra. |

## Evidências e rollback

- Antes do merge #25: Flutter CI e iOS CI verdes. A release `0.1.4+6` foi criada via tag sobre commit de main e a compilação do instalador foi concluída com sucesso.
- Antes do merge #26: CI Flutter/Windows/Android, Chromium PWA, migrações Supabase/RLS e iOS concluíram com sucesso.
- A branch PR #21 não pôde ser integrada diretamente sem risco de trazer código antigo; o delta útil foi portado e comparado (18 arquivos idênticos no main).
- Os worktrees do Destruking com `pubspec_overrides.yaml`, `pubspec.lock` e arquivos de protótipo, o worktree Goiatuba com stashes e arquivos não rastreados no site **não foram apagados**.
- Não há nenhuma exclusão de banco, livros, backup, conta ou storage neste trabalho.
- Rollback do site: reverter o merge PR #37 e publicar via pipeline Cloudflare; nunca apagar IndexedDB/CacheStorage ou desinstalar a PWA como tentativa inicial de recuperação. Release GitHub `v0.1.4+6` é imutável e não deve ser reescrita.
- Upgrade iOS nativo exige assinatura, bundle ID invariável, instalação in-place e verificação no dispositivo (conteúdo/progresso/login).

## Próximos passos

1. Confirmar smoke de produção após deploy Web/PWA 0.1.4+6 e testar o ciclo de atualização a partir de cliente `0.1.4+5`.
2. Validar auto-update Windows real do instalador anterior em ambiente de homologação; SHA-256 não é assinatura Authenticode.
3. Testar app iOS assinado in-place no iPhone antes de distribuir uma nova versão nativa.
4. Revisar segurança de ZIP de capítulos (descompressão e quota), backup Web e traduções em PRs independentes, sem mesclar a pilha histórica nem exigir login privado por consequência.
