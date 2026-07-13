<!-- Signature: dev.tswicolly03 -->
# Veredra

Veredra e um leitor Flutter offline-first para Windows, Android e Web/PWA. A
biblioteca local continua disponivel sem conta; quando um projeto Supabase e
configurado, o usuario pode autenticar e sincronizar somente os dados de leitura
que autorizou.

URL Web canonica, com caixa exata:

```text
https://wicolly.com.br/Veredra/
```

## Recursos

- TXT, Markdown, HTML, EPUB e PDF (PDF Web continua indisponivel).
- leitura continua, progresso, busca, favoritos, marcadores, destaques,
  anotacoes, estatisticas, capas, perfis e backup desktop;
- storage nativo atomico e IndexedDB na Web, com migracao do storage legado;
- conta por e-mail/senha, confirmacao de e-mail, recuperacao/redefinicao,
  logout, renovacao de sessao, exclusao de conta e OAuth Google;
- sincronizacao offline-first de perfil, preferencias, metadados, progresso,
  marcadores, anotacoes, destaques, favoritos e estatisticas;
- fila duravel, deduplicacao, retry com backoff, tombstones e resolucao
  deterministica de conflitos;
- modo local sempre disponivel. Arquivos de livros nunca sao enviados sem
  consentimento; nesta versao, upload completo permanece desabilitado.

## Requisitos

- Flutter `3.38.9` / Dart `3.10.8` ou versao compativel;
- Visual Studio com C++ para Windows;
- Android SDK/NDK para APK;
- Node 22 para Playwright;
- Docker Desktop e Supabase CLI para o backend local.

## Execucao local

```bash
flutter pub get
flutter run -d windows
flutter run -d chrome
flutter run -d android
```

Sem `dart-define`, o app inicia honestamente em modo local. Para habilitar o
cliente Supabase:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=PUBLIC_KEY \
  --dart-define=AUTH_REDIRECT_URL=https://wicolly.com.br/Veredra/ \
  --dart-define=NATIVE_AUTH_REDIRECT_URL=veredra://auth-callback/
```

`SUPABASE_PUBLISHABLE_KEY` e configuracao publica de cliente. Nunca use
`service_role`, client secret do Google, senha ou chave privada no app.
`.env.example` e somente um inventario de nomes; o Flutter recebe os valores por
`--dart-define` ou `--dart-define-from-file` mantido fora do Git.

## Supabase local

```bash
npx supabase start
npx supabase db reset
npx supabase db lint --local --level warning
npx supabase test db
```

A migration versionada cria tabelas, indices, RLS, grants, bucket privado e a
RPC de exclusao da propria conta. Os testes pgTAP tentam ler/escrever dados de
outro usuario e outro prefixo de Storage.

## Qualidade e builds

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
dart run tool/check_repository_security.dart
dart run tool/validate_migrations.dart

flutter build web --release --base-href /Veredra/
dart run tool/patch_flutter_service_worker.dart
dart run tool/validate_web_build.dart

flutter build windows --release
flutter build apk --debug
flutter build apk --release
```

E2E real em subpasta, desktop e viewport mobile:

```bash
cd e2e
npm ci
npx playwright install chromium
npm test
```

Os testes online de auth/sync exigem as variaveis `VEREDRA_E2E_EMAIL` e
`VEREDRA_E2E_PASSWORD` de uma conta exclusiva de teste. Sem elas, os cenarios
online sao marcados como ignorados, nunca como aprovados.

## Assinatura Android

O build release nao reutiliza a chave debug. Copie
`android/key.properties.example` para `android/key.properties`, aponte para uma
keystore guardada fora do repositorio e forneca as senhas apenas no ambiente
seguro. Sem esse arquivo, o Gradle gera um APK release nao assinado, util para
provar compilacao, mas inadequado para distribuicao.

## Deploy Web

```bash
flutter build web --release --base-href /Veredra/
dart run tool/patch_flutter_service_worker.dart
dart run tool/validate_web_build.dart
```

O conteudo de `build/web` e publicado no repositorio `Wicolly-Sites` sob a pasta
`Veredra`. O site deve manter:

```text
/Veredra  /Veredra/  301
```

O fallback equivalente a `/Veredra/* -> /Veredra/index.html 200` e implementado
por uma Pages Function. O runtime Cloudflare rejeita a regra literal como loop
porque o destino tambem casa com o wildcard.

Consulte `docs/DEPLOYMENT.md` antes de publicar.

## Limites atuais

- login/sync reais dependem de projeto Supabase, SMTP e Google Cloud externos;
- OAuth Windows requer instalador que registre `veredra://`; o executavel solto
  apenas recebe o callback quando o protocolo ja esta registrado;
- upload de livro/capa esta desabilitado ate existir UX de consentimento,
  medicao de quota, retomada e exclusao completa;
- PDF, backup/restauracao e Argos Translate possuem fallbacks claros na Web;
- build release Android precisa de keystore de producao.

## Documentacao

- `docs/ARCHITECTURE.md`
- `docs/AUTHENTICATION.md`
- `docs/SYNCHRONIZATION.md`
- `docs/LOCAL_STORAGE.md`
- `docs/SECURITY.md`
- `docs/PRIVACY.md`
- `docs/TESTING.md`
- `docs/ANDROID_TESTING.md`
- `docs/WEB_PWA.md`
- `docs/DEPLOYMENT.md`
- `docs/PRODUCTION_READINESS.md`
- `docs/ROADMAP.md`

Nao ha licenca publica definida. Ate uma decisao explicita do autor, trate o
codigo como propriedade intelectual do projeto.
