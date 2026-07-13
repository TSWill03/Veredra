<!-- Signature: dev.tswicolly03 -->
# Deployment

## App

No repositorio Veredra:

```bash
flutter pub get
flutter build web --release --base-href /Veredra/
dart run tool/patch_flutter_service_worker.dart
dart run tool/validate_web_build.dart
```

Quando houver backend de producao, passe `SUPABASE_URL`,
`SUPABASE_PUBLISHABLE_KEY`, `AUTH_REDIRECT_URL` e
`NATIVE_AUTH_REDIRECT_URL` como `--dart-define` no job de build. Somente valores
publicos entram no bundle Web; secrets permanecem no Supabase/Google/GitHub.

## Site

No repositorio irmao `Wicolly-Sites`, use o script versionado para substituir a
pasta `Veredra` pelo build validado e rode toda a validacao do site. Nao copie
arquivos isolados manualmente e nao publique a pasta lowercase como canonica.

```bash
node scripts/update-veredra.mjs ../app/build/web
npm run build
npm run validate
npm run check-links
```

O comando exato pode variar conforme os scripts do site; o PR de deploy e a
fonte definitiva. Confirme `_redirects`, `_headers`, links da home, manifest,
service worker e assets em `dist/Veredra`.

## Cloudflare Pages

- build do site reproduzivel, output `dist`;
- preview primeiro, producao somente apos revisao/merge;
- `/Veredra` -> `/Veredra/` (301);
- Pages Function `/Veredra/*` -> asset existente ou `/Veredra/index.html` para
  navegacao SPA;
- nao usar wildcard que capture outras rotas do dominio;
- smoke test online: status, assets, reload, installabilidade e offline.

## Supabase

1. criar projeto/staging e vincular CLI;
2. revisar migration com `db lint` e pgTAP local;
3. aplicar migration de forma controlada;
4. configurar SMTP, redirects e Google;
5. guardar secrets somente nos provedores;
6. rodar E2E online com conta exclusiva antes de promover.

## Rollback

Preserve o artefato Web anterior e nunca rode migration destrutiva nesta fase.
Rollback do site restaura a versao anterior da pasta/commit. Alteracoes de banco
devem ser aditivas; tombstones e compatibilidade local evitam perda durante
clientes em versoes diferentes.
