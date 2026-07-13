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
- Google OAuth com PKCE;
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
AUTH_REDIRECT_URL=https://wicolly.com.br/Veredra/
NATIVE_AUTH_REDIRECT_URL=veredra://auth-callback/
```

Nao use `service_role`. O client secret do Google pertence somente ao painel do
Supabase/Google Cloud.

## Supabase

1. aplique `supabase/migrations`;
2. habilite confirmacao de e-mail e configure SMTP de producao;
3. adicione exatamente os redirects Web e nativo acima;
4. configure Site URL como `https://wicolly.com.br/Veredra/`;
5. mantenha expiracao/refresh de JWT e protecao antiabuso adequadas.

## Google Cloud e OAuth

1. crie a tela de consentimento e credencial OAuth Web;
2. no Google, autorize o callback do Supabase:
   `https://PROJECT_REF.supabase.co/auth/v1/callback`;
3. configure Client ID e Client Secret apenas no provedor Google do Supabase;
4. no Supabase, permita `https://wicolly.com.br/Veredra/` e
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

Sem projeto Supabase/SMTP/Google configurado, foram validados mocks, UI, RLS e
contratos, mas nao e correto afirmar que envio de e-mail, callback Google ou
sessao entre dois dispositivos reais passaram. Os E2E online exigem credenciais
exclusivas de staging.
