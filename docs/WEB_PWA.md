<!-- Signature: dev.tswicolly03 -->
# Web e PWA

## Rota canonica

Todos os valores usam caixa exata:

```text
base href: /Veredra/
manifest id: /Veredra/
start_url: /Veredra/
scope: /Veredra/
producao: https://wicolly.com.br/Veredra/
```

## Build validado

```bash
flutter build web --release --base-href /Veredra/
dart run tool/patch_flutter_service_worker.dart
dart run tool/validate_web_build.dart
```

O patch corrige chaves e URLs do service worker gerado para subpasta. O
validador falha se base, manifest, icones ou marcadores do patch estiverem
incorretos. Nao edite o service worker gerado manualmente.

## Teste local real

```bash
cd e2e
npm ci
npm test
```

`server.mjs` redireciona `/Veredra` para `/Veredra/`, serve assets com MIME e
headers corretos e aplica fallback SPA apenas sob o escopo. O Playwright valida
desktop e viewport mobile, incluindo reload offline apos o service worker ficar
pronto.

## Persistencia

IndexedDB guarda strings e bytes de biblioteca/capitulos/capas. O adapter migra
o legado `shared_preferences_web` na primeira leitura sem apagar a unica copia
em caso de falha. Livros importados podem ser reabertos offline apos o primeiro
carregamento.

## Deploy/Cloudflare

O site deve conter:

```text
/Veredra  /Veredra/  301
```

Uma Pages Function restrita a `/Veredra/*` serve assets existentes e devolve
`/Veredra/index.html` somente para navegacoes ausentes. A regra `_redirects`
literal de rewrite foi evitada porque o runtime Cloudflare a classifica como
loop infinito. Service worker e `index.html` usam no-cache; redirects lowercase
antigos apontam uma vez para o caminho canonico.

## Fallbacks honestos

- PDF Web indisponivel;
- importacao por pasta, backup/restauracao e Argos sao desktop-only;
- File System Access API nao e requisito;
- OAuth/sync online exigem HTTPS, redirects e backend configurado.
