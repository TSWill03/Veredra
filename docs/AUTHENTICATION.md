<!-- Signature: dev.tswicolly03 -->
# Autenticacao

## Provedor

Supabase Auth foi escolhido por combinar e-mail/senha, OAuth, PostgreSQL, RLS e
Storage com um SDK Flutter compativel com Web, Android e desktop. Firebase nao
foi adotado porque o modelo relacional e as policies SQL reduzem complexidade
para os dados de leitura.

## Fluxos implementados

- cadastro com validacao de e-mail e senha forte;
- login, logout, refresh e persistencia de sessao;
- confirmacao de e-mail;
- solicitacao e conclusao de redefinicao de senha;
- Google OAuth com PKCE preservado no codigo, mas desativado por feature flag;
- estado de loading e bloqueio de envio duplicado;
- mensagens amigaveis sem revelar se um e-mail existe;
- sessao expirada e retorno ao modo local;
- exclusao da propria conta por RPC `delete_own_account()`.

Senhas nunca sao persistidas pelo Veredra. Tokens nativos ficam em
`flutter_secure_storage`; na Web, o SDK usa storage seguro do navegador e exige
HTTPS/localhost.

## Configuracao do cliente

Forneca como `--dart-define`:

```text
SUPABASE_URL
SUPABASE_PUBLISHABLE_KEY
AUTH_REDIRECT_URL=https://wicolly.com.br/veredra/
NATIVE_AUTH_REDIRECT_URL=veredra://auth-callback/
ENABLE_GOOGLE_AUTH=false
```

Nao use `service_role`. O client secret do Google pertence somente ao painel do
Supabase/Google Cloud.

## Supabase

1. aplique `supabase/migrations`;
2. habilite confirmacao de e-mail e configure SMTP de producao;
3. adicione exatamente os redirects Web e nativo acima;
4. configure Site URL como `https://wicolly.com.br/veredra/`;
5. mantenha expiracao/refresh de JWT e protecao antiabuso adequadas.

## Google Cloud e OAuth (pendencia futura)

Nesta entrega, `ENABLE_GOOGLE_AUTH=false` e o botao nao aparece. O gateway
tambem bloqueia qualquer tentativa programatica, portanto configuracao Google
incompleta nao afeta cadastro, login por senha, bootstrap, testes ou build Web.
O codigo nao foi removido. Para uma entrega futura:

1. crie a tela de consentimento e credencial OAuth Web;
2. no Google, autorize o callback do Supabase:
   `https://PROJECT_REF.supabase.co/auth/v1/callback`;
3. configure Client ID e Client Secret apenas no provedor Google do Supabase;
4. no Supabase, permita `https://wicolly.com.br/veredra/` e
   `veredra://auth-callback/` como destinos pos-login;
5. valide sucesso, cancelamento e erro em um projeto de staging antes de
   producao.

Android declara o intent filter `veredra://auth-callback/`. Windows recebe URLs
por `app_links`, mas o esquema precisa ser registrado por MSIX/instalador; o EXE
portatil nao registra protocolo sozinho. Linux, macOS e iOS exigem seus arquivos
de associacao/entitlements antes de habilitar OAuth publicamente.

## Exclusao

A RPC `security definer` verifica `auth.uid()`, exclui somente o chamador e tem
execucao revogada de `public`, concedida apenas a `authenticated`. Cascades
removem tabelas relacionadas. Objetos do Storage precisam de rotina server-side
de limpeza antes de ativar upload completo; por isso essa modalidade continua
desabilitada.

## Testes reais pendentes

Mocks, UI, RLS e contratos nao substituem o teste hospedado. Envio de e-mail e
sessao entre dois dispositivos so podem ser aprovados com uma conta exclusiva
de staging. O callback Google esta deliberadamente fora do escopo enquanto a
feature flag permanecer desativada.

## Integracao Google OAuth por navegador (2026-11-19)

Os arquivos de clientes OAuth do Google Cloud foram validados localmente para o
projeto `veredra`. **Nao copiar `Web.json`, `Desktop.json`, `Android.json` nem
`IOS.plist` para o repositorio ou para os assets de release.** O Web Client
Secret pertence exclusivamente a configuracao Google do Supabase hospedado.

- Callback registrado no Google Cloud Web: `https://bfvbkypjyvyolguzzslt.supabase.co/auth/v1/callback`.
- Origem Web registrada: `https://wicolly.com.br`.
- Supabase Site URL: `https://wicolly.com.br/veredra/`.
- Redirects pos-login: `https://wicolly.com.br/veredra/` e `veredra://auth-callback/`.
- Android: intent filter do esquema `veredra` ja presente no projeto.
- iOS: `CFBundleURLTypes` declara `veredra` para o retorno ao app via PKCE.
- Windows/macOS/Linux portateis: Google OAuth fica oculto ate existir registro
  e validacao de um manipulador de URI confiavel. Login por senha permanece.

O Veredra usa `signInWithOAuth` do Supabase via navegador, nao o SDK
`google_sign_in` nativo. Portanto `REVERSED_CLIENT_ID` do plist do Google
nao e necessario neste fluxo. Nunca versionar o Client Secret do Google ou
um Supabase PAT. Na branch de preview `feat/google-oauth-20261119`,
`ENABLE_GOOGLE_AUTH=true` permite validar o botao sem publicar em producao.
O build atual em `main` continua com Google desabilitado. Validar fluxo
PKCE completo, cancelamento, sessao e E2E em Web, Android e iOS, alem de
testar dispositivos fisicos antes da liberacao e deploy.
