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
- Google OAuth por navegador com PKCE e flag de ativacao por plataforma;
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

## Google Cloud e OAuth

Quando `ENABLE_GOOGLE_AUTH=false`, o botao Google permanece oculto e o gateway
bloqueia seu uso; login com e-mail/senha e leitura local continuam funcionando.
Nos builds publicados com Google habilitado, o provedor e os redirects devem
estar configurados previamente. A configuracao original contemplou:

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
- Windows: Google OAuth habilitado a partir de 0.1.3+4, com associacao do
  esquema via instalador por usuario e entrega do callback ao app_links.
- macOS/Linux: login Google permanece oculto ate configurar protocolo nativo.

O Veredra usa `signInWithOAuth` do Supabase via navegador, nao o SDK
`google_sign_in` nativo. Portanto `REVERSED_CLIENT_ID` do plist do Google
nao e necessario neste fluxo. Nunca versionar o Client Secret do Google ou
um Supabase PAT. Na branch de preview `feat/google-oauth-20261119`,
`ENABLE_GOOGLE_AUTH=true` permite validar o botao sem publicar em producao.
A flag Google foi habilitada nos builds publicados a partir de `0.1.1+2`.
Validar retorno PKCE, cancelamento, persistencia de sessao e sincronizacao em
Web, Android, iOS e Windows; testes de CI nao substituem testes com uma conta real.

## Windows Desktop: Google OAuth via app_links (0.1.3+4)

A tela de conta passa a oferecer `Entrar com Google` em Windows quando
`ENABLE_GOOGLE_AUTH=true` e o Supabase esta configurado no build. O login
abre o navegador padrao e volta pelo redirect existente
`veredra://auth-callback/`, com verificacao PKCE pelo `supabase_flutter`.

O EXE Windows portatil requer associar o esquema ao executavel, uma vez por
usuario, apos instalar a release. Exemplo (pelo diretorio do projeto):

```powershell
.\tool\install_windows_oauth_protocol.ps1 -AppPath "$env:LOCALAPPDATA\Programs\Veredra\0.1.3+4\veredra.exe"
```

O script verifica se outro aplicativo ja controla o esquema e altera apenas
`HKCU`, sem elevar privilegios. A futura distribuicao MSIX devera gerenciar
esse protocolo na instalacao/desinstalacao.

O runner Windows encaminha callbacks apenas para outra instancia do **mesmo
executavel**, sem duplicar janelas nem entregar um codigo PKCE a uma versao
anterior aberta. Se o aplicativo estiver fechado, uma nova instancia recebe
o link inicial pelo `app_links`. Nenhuma credencial ou token deve ser salvo
em logs. O login final requer interacao humana com a conta Google.
