<!-- Signature: dev.tswicolly03 -->
# Acesso privado do Veredra

Esta configuração protege `https://wicolly.com.br/veredra/` em duas camadas:

1. Cloudflare Access bloqueia a requisição antes de o Flutter ser baixado.
2. O próprio Veredra exige uma sessão válida do Supabase quando o build usa `PRIVATE_ACCESS_REQUIRED=true`.

## 1. Preparação segura

Antes de fechar os cadastros:

1. confirme que a conta proprietária já existe no Supabase Auth;
2. confirme que o e-mail está verificado;
3. teste a senha e a recuperação de senha;
4. preserve o deployment anterior do Cloudflare Pages para rollback;
5. não altere nem apague o IndexedDB atual durante esta fase.

## 2. Supabase Auth

No painel do projeto:

1. abra **Authentication > Providers > Email** ou a área equivalente de configuração geral;
2. desative **Allow new users to sign up**;
3. mantenha login por e-mail e senha habilitado;
4. mantenha confirmação de e-mail habilitada;
5. mantenha login anônimo desabilitado;
6. revise os redirects autorizados:
   - `https://wicolly.com.br/veredra/`
   - URLs de preview explicitamente usadas em homologação;
7. não coloque `service_role` no Flutter, GitHub, Cloudflare Pages ou JavaScript público.

Mesmo que o painel seja configurado incorretamente, o cliente privado também recusa `signUp` quando `PUBLIC_SIGNUP_ENABLED=false`.

## 3. Cloudflare Access

Em **Zero Trust > Access controls > Applications**:

1. crie uma aplicação **Self-hosted**;
2. nome sugerido: `Veredra privado`;
3. proteja o hostname `wicolly.com.br` nos caminhos:
   - `/veredra`
   - `/veredra/*`
4. crie uma política `Allow` usando o seletor **Emails** com apenas os e-mails autorizados;
5. não use `Everyone` e não permita qualquer e-mail válido;
6. aplique MFA independente quando disponível;
7. use duração de sessão curta/moderada;
8. para CI, use uma política separada de `Service Auth` com token armazenado somente nos secrets, nunca um bypass público.

A ausência de correspondência com uma política `Allow` deve continuar bloqueando o acesso por padrão.

## 4. Build privado de produção

Use somente chaves públicas no bundle Web:

```bash
flutter pub get
flutter build web \
  --release \
  --base-href /veredra/ \
  --dart-define=PRIVATE_ACCESS_REQUIRED=true \
  --dart-define=PUBLIC_SIGNUP_ENABLED=false \
  --dart-define=ENABLE_GOOGLE_AUTH=false \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY" \
  --dart-define=AUTH_REDIRECT_URL=https://wicolly.com.br/veredra/

dart run tool/patch_flutter_service_worker.dart
dart run tool/validate_web_build.dart
```

Se `PRIVATE_ACCESS_REQUIRED=true` e a configuração do Supabase estiver ausente ou inválida, o aplicativo exibe um erro de configuração e não abre a biblioteca anônima.

## 5. Publicação no Wicolly-Sites

No repositório irmão:

```bash
node scripts/update-veredra.mjs ../Veredra/build/web
npm test
npm run build
npm run validate
npm run check:links
```

Publique primeiro um preview. Depois valide a produção real.

## 6. Testes obrigatórios

### Visitante não autorizado

- `/veredra` e `/veredra/` devem ser bloqueados pelo Cloudflare Access;
- nenhum `main.dart.js`, manifest ou service worker do Veredra deve ser entregue.

### Visitante autorizado sem Supabase

- deve ver somente a tela `Veredra privado`;
- não deve existir botão `Criar conta`;
- login inválido deve falhar sem revelar se o e-mail existe.

### Conta autorizada

- login abre a biblioteca;
- logout volta imediatamente para a tela privada;
- recarregar mantém ou renova a sessão;
- recuperação de senha retorna para `/veredra/`;
- expiração da sessão não deixa a biblioteca aberta.

### Isolamento

- usuário A não lê registros ou objetos do usuário B;
- bucket `veredra-books` permanece privado;
- RLS continua forçada em todas as tabelas sincronizadas.

## 7. Rollback

1. restaure o deployment anterior do projeto `wicolly-site`;
2. mantenha a política Cloudflare Access ativa durante o rollback;
3. não reative cadastro público como procedimento de recuperação;
4. não execute migration destrutiva;
5. preserve os dados locais e remotos existentes.
