<!-- Signature: dev.tswicolly03 -->
# Deployment

## App

No repositorio Veredra:

```bash
flutter pub get
flutter build web --release --base-href /veredra/
dart run tool/patch_flutter_service_worker.dart
dart run tool/validate_web_build.dart
```

Quando houver backend de producao, passe `SUPABASE_URL`,
`SUPABASE_PUBLISHABLE_KEY`, `AUTH_REDIRECT_URL` e
`NATIVE_AUTH_REDIRECT_URL` como `--dart-define` no job de build e mantenha
`ENABLE_GOOGLE_AUTH=false`. Somente valores
publicos entram no bundle Web; secrets permanecem no Supabase/Google/GitHub.

## Site

No repositorio irmao `Wicolly-Sites`, use o script versionado para substituir a
pasta `veredra` pelo build validado e rode toda a validacao do site. Nao copie
arquivos isolados manualmente.

```bash
node scripts/update-veredra.mjs ../app/build/web
npm run build
npm run validate
npm run check-links
```

O comando exato pode variar conforme os scripts do site; o PR de deploy e a
fonte definitiva. Confirme `_redirects`, `_headers`, links da home, manifest,
service worker e assets em `dist/veredra`.

## Cloudflare Pages

- build do site reproduzivel, output `dist`;
- preview primeiro; uma validacao manual controlada pode publicar a branch em
  producao antes do merge, mantendo o deployment anterior como rollback;
- merge na `main` somente depois dos testes de producao;
- `/veredra` -> `/veredra/` (301);
- `/Veredra` e `/Veredra/*` -> equivalentes em `/veredra/` (301);
- Pages Function `/veredra/*` -> asset existente ou `/veredra/index.html` para
  navegacao SPA;
- nao usar wildcard que capture outras rotas do dominio;
- smoke test online: status, assets, reload, installabilidade e offline.

## Supabase

1. criar projeto/staging e vincular CLI;
2. revisar migration com `db lint` e pgTAP local;
3. aplicar migration de forma controlada;
4. configurar SMTP e redirects; manter Google desativado nesta entrega;
5. guardar secrets somente nos provedores;
6. rodar E2E online com conta exclusiva antes de promover.

## Rollback

Preserve o artefato Web anterior e nunca rode migration destrutiva nesta fase.
Rollback do site restaura a versao anterior da pasta/commit. Alteracoes de banco
devem ser aditivas; tombstones e compatibilidade local evitam perda durante
clientes em versoes diferentes.

## Projeto Supabase hospedado — 2026-11-18

- Organizacao: BlackLight Tech; ref `bfvbkypjyvyolguzzslt`; regiao `sa-east-1`.
- `config/supabase.production.json` e publicavel e contem somente a configuracao permitida nos clientes Flutter. Nao adicionar nenhuma credencial secreta a este arquivo.
- Os workflows de build recebem `--dart-define-from-file=config/supabase.production.json`. O deploy do site depende de atualizar `Wicolly-Sites` com o artefato Web assim gerado; atualizar o backend sozinho nao altera o bundle publicado.
- O schema `auth_sync_schema` foi aplicado com RLS e Storage privado, junto da migration `restrict_delete_account_rpc`; a RPC de exclusao e executavel por `authenticated`, nao por `anon`. O advisor pode alertar sobre a capacidade intencional do papel autenticado de invocar esta funcao `SECURITY DEFINER`.
- Pendencias externas: no Dashboard, confirmar Site URL `https://wicolly.com.br/veredra/`, allowlist de redirect Web e nativo `veredra://auth-callback/`, SMTP e politica de cadastro; testar email real, RLS com duas contas e sync de duas sessoes antes de publicar.
- Em cliente novo, use `flutter run -d chrome --dart-define-from-file=config/supabase.production.json`. Mantenha o build Web anterior para rollback.
