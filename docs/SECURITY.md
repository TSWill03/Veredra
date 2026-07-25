<!-- Signature: dev.tswicolly03 -->
# Seguranca

## Dados e autenticacao

- senha nunca e armazenada pelo app;
- tokens nativos usam secure storage e refresh do SDK;
- `service_role`, client secret, keystore e credenciais ficam fora do Git;
- `.gitignore`, `.env.example` e o scanner local/CI protegem configuracoes;
- mensagens de recuperacao nao confirmam se o e-mail existe.

## Banco remoto

Todas as tabelas sincronizaveis habilitam e forcam RLS. A role `authenticated`
recebe apenas SELECT/INSERT/UPDATE/DELETE, e cada policy exige
`auth.uid() = user_id`; `anon` tem os grants revogados. pgTAP executa casos
positivos do usuario A e tentativas negativas contra o usuario B.

O bucket `veredra-books` e privado, aceita somente MIME/extensoes conhecidas e
exige que o primeiro segmento do caminho seja o UUID do usuario. A migration
reserva 100 MiB por objeto, enquanto o limite global atual do projeto hospedado
e 50 MiB. Upload completo continua desligado; antes de ativa-lo, esses limites
precisam ser alinhados junto com o ciclo de exclusao e retomada.

## Importacao

- texto: 16 MiB por arquivo, 128 MiB total e ate 5000 arquivos;
- EPUB: 100 MiB; PDF: 256 MiB; capa: 20 MiB;
- texto extraido: limite de 64 milhoes de caracteres;
- HTML remove `script`, `style`, `iframe`, `object`, `embed` e `noscript` antes
  de virar texto; scripts nunca sao executados;
- backup valida path traversal, quantidade, tamanho individual e total
  descompactado; nomes sao sanitizados;
- erros de um livro nao devem corromper a biblioteca inteira.

## Android e Web

Android bloqueia cleartext e backup automatico do sistema. Release nunca usa a
chave debug. Na Web, a rota e os assets sao case-sensitive, headers devem usar
`nosniff` e o service worker recebe patch/validador pos-build.

## Diagnosticos

Erros sao classificados como startup, auth, sync, importacao ou leitor. A
redacao remove e-mail, bearer, authorization, cookie, token, password e secret.
Nao ha envio remoto nesta versao; `ENABLE_DIAGNOSTICS_UPLOAD` fica falso.

## Pendencias antes de producao

- pentest do ambiente Supabase hospedado e revisao de quotas/rate limit;
- rotina confiavel para excluir objetos do Storage ao excluir conta;
- assinatura/reproducibilidade de instaladores Windows e APK;
- politicas publicadas de privacidade/retencao e canal de suporte;
- testes fuzz/ZIP bomb mais amplos e SBOM/dependency audit recorrente.
