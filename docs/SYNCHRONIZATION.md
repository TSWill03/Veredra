<!-- Signature: dev.tswicolly03 -->
# Sincronizacao offline-first

## Politica

O usuario pode usar o app sem conta. Criar conta nao envia dados automaticamente.
A opcao `Sincronizar dados de leitura` exige consentimento explicito por perfil.
`Sincronizacao completa` permanece indisponivel nesta versao.

## Entidades iniciais

- perfil e preferencias;
- metadados/favorito do livro, sem caminho local ou conteudo;
- progresso;
- marcadores, anotacoes e destaques;
- estatisticas de leitura.

## Fluxo

1. toda mudanca e salva localmente;
2. um snapshot produz operacoes UUID na fila duravel do perfil;
3. operacoes repetidas da mesma entidade sao deduplicadas;
4. se offline, ficam pendentes sem bloquear leitura;
5. ao reconectar ou sincronizar manualmente, upserts idempotentes sao enviados;
6. alteracoes remotas desde o ultimo cursor sao puxadas e aplicadas;
7. falhas usam backoff exponencial de 5 segundos ate 30 minutos;
8. fila corrompida e isolada em quarentena em vez de apagar a biblioteca.

O dispositivo recebe UUID local estavel, sem usar identificador de hardware.
Sync automatico e opcional e usa intervalo conservador, alem do evento de
reconexao.

## Conflitos

- anotacoes, marcadores e destaques: merge por ID;
- campos simples: maior `version`, depois `updated_at`;
- progresso: maior capitulo e, no mesmo capitulo, maior progresso;
- exclusoes: tombstone `deleted_at`, nunca remocao silenciosa imediata;
- empates ambiguos: mantem o estado deterministico mais recente e registra
  diagnostico local sem conteudo do livro.

## Privacidade de arquivos

Metadados sincronizados removem referencias de caminho, capa e asset local.
Livros/capas nao sao enviados. Para habilitar a modalidade completa no futuro,
sao obrigatorios: consentimento separado, quota estimada, checksum, deduplicacao,
retomada de upload, MIME/extensao, limite, caminho `user_id/...`, exclusao
server-side e teste de interrupcao.

## Estados de UI

`Sincronizado`, `Sincronizando`, `Offline`, `Alteracoes pendentes`,
`Erro de sincronizacao` e `Sessao expirada`. Todos sao informativos; nenhum
substitui ou bloqueia o storage local.

## Limites

Os testes unitarios cobrem fila, retry, deduplicacao, conflito, offline/reconexao
e duas sessoes fake. O backend local prova RLS. A sincronizacao entre navegadores
com Supabase hospedado depende das credenciais de staging descritas em
`TESTING.md`.
