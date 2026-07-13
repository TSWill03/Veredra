<!-- Signature: dev.tswicolly03 -->
# Testes

## Matriz obrigatoria

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test --coverage
dart run tool/check_repository_security.dart
dart run tool/validate_migrations.dart
flutter build web --release --base-href /Veredra/
dart run tool/patch_flutter_service_worker.dart
dart run tool/validate_web_build.dart
flutter build apk --debug
flutter build windows --release
```

## Banco

```bash
npx supabase start
npx supabase db reset
npx supabase db lint --local --level warning
npx supabase test db
```

O pgTAP possui 10 assercoes: insert proprio, insert cruzado negado, select e
update isolados, progresso proprio/cruzado e prefixos Storage proprio/cruzado.

## Browser/PWA

```bash
cd e2e
npm ci
npx playwright install chromium
npm test
```

O servidor E2E hospeda exclusivamente em `/Veredra/` e testa Chromium desktop e
viewport mobile: carga, importacao TXT Unicode, abertura, retorno a biblioteca,
reload com IndexedDB, shell offline e redirect sem barra.

Auth/sync hospedado e condicional:

```text
VEREDRA_E2E_EMAIL
VEREDRA_E2E_PASSWORD
```

Use somente conta de staging. Sem as variaveis, os testes sao `skipped`; nao
conte como validacao real.

## Cobertura Flutter

Inclui validacao de credenciais, loading/duplicidade, recuperacao, fila,
deduplicacao, retry, corrupcao, consentimento, offline/reconexao, conflito de
progresso, duas sessoes fake, import limits, HTML, serializacao e diagnosticos.

## Testes manuais

Registre data, plataforma, build e fluxo realmente executado. Nunca generalize
um smoke test para todos os formatos. A checklist de importacao completa deve
cobrir TXT/MD/HTML/EPUB/PDF, arquivos invalidos/grandes, Unicode, acentos,
cancelamento, backup/restore e falha isolada por livro.

## CI

GitHub Actions falha em format, analyze, teste, scanner, contrato de migrations,
build/rota Web, APK debug, build Windows, PWA E2E, db lint ou pgTAP. Artefatos
Web/APK/Windows e cobertura sao anexados. Nao existe deploy automatico em
producao.
