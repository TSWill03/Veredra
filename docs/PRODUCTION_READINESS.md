<!-- Signature: dev.tswicolly03 -->
# Prontidao para producao

Data da auditoria: 2026-07-13.

## P0

Corrigidos:

- livros/capitulos grandes na Web sairam de SharedPreferences para IndexedDB;
- APK release nao usa mais certificado debug;
- tabelas Supabase receberam grants `authenticated` e revoke `anon`; pgTAP
  provou RLS depois de detectar o grant ausente;
- rota Web foi normalizada para `/veredra/`.

Bloqueios externos restantes:

- SMTP e conta exclusiva de teste ainda precisam de comprovacao hospedada;
- APK release ainda nao tem keystore de producao;
- deploy live depende de merge/aprovacao e acesso Cloudflare.

## P1

Implementados:

- auth por e-mail/senha, recovery, sessao segura e exclusao de conta;
- Google OAuth preservado, isolado e desativado por feature flag;
- sync offline-first com consentimento, retry, conflito e tombstones;
- RLS/Storage privado e testes de usuario cruzado;
- limites/sanitizacao de importacao e diagnosticos redigidos;
- builds Web/Windows/Android, Playwright e CI multiplataforma;
- UI responsiva de conta/sync e fallbacks locais.

Pendentes para beta publica:

- validar e-mail e sync real entre duas sessoes no staging hospedado;
- assinar APK e registrar protocolo do instalador Windows;
- executar checklist manual completo de formatos/backup em Android e desktop;
- publicar politica legal de privacidade e canal de suporte.

## P2

- PDF/backup Web;
- upload completo com consentimento, quota, retomada e exclusao;
- Drift/SQLite e outbox transacional;
- reduzir `LibraryPage`, `ReaderPage` e servicos legados;
- audit de dependencias major e observabilidade remota opt-in.

## P3

- Linux/macOS/iOS com associacoes OAuth e testes nativos;
- criptografia/senha opcional para perfil local;
- indexacao incremental de busca e sync de arquivos avancado.

## Veredito

O app esta tecnicamente mais proximo de uma beta controlada, mas nao deve ser
declarado pronto para beta publica enquanto os quatro itens P1 externos acima
nao forem comprovados. Nao esta pronto para producao. Builds locais aprovados
nao substituem auth hospedado, assinatura, deploy e smoke test live.

## Atualizacao em 2026-11-18 — backend novo

- Supabase Veredra novo `bfvbkypjyvyolguzzslt` na organizacao BlackLight Tech, `sa-east-1`; project health ativo.
- Schema aplicado: 12 tabelas publicas, todas com RLS, 48 policies de propriedade e bucket `veredra-books` privado. Correcao extra: `anon` nao pode executar `public.delete_own_account()`.
- Chave publicavel e URL disponiveis na configuracao de build `config/supabase.production.json`; nenhum segredo privado nela.
- Ainda <b>nao validado</b>: configuracao Auth Dashboard (redirect, SMTP), login e sync com duas contas reais, builds de release e publicacao Web/iOS. Nao promover a producao nem declarar autenticacao real funcional com base apenas no esquema.
