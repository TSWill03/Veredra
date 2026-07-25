<!-- Signature: dev.tswicolly03 -->
# Sincronizacao offline-first

## Politica

O usuario pode usar o app sem conta em builds locais. Criar conta nao envia dados
automaticamente. `Sincronizar dados de leitura` exige consentimento explicito por
perfil. O envio dos capitulos usa uma segunda autorizacao independente chamada
`Sincronizar livros e traducoes`.

Desativar a sincronizacao principal tambem desativa a transferencia de arquivos.
Desativar apenas os arquivos mantem metadados e progresso sincronizados, sem enviar
conteudo novo.

## Entidades leves

- perfil e preferencias;
- metadados/favorito do livro, sem caminho local ou conteudo;
- progresso;
- marcadores, anotacoes e destaques;
- estatisticas de leitura.

## Fluxo de metadados

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

## Pacotes privados de livros

Quando a autorizacao de arquivos esta ativa:

1. o livro textual ou EPUB convertido e reaberto no armazenamento local;
2. capitulos sao empacotados em um ZIP com `manifest.json`;
3. o pacote recebe checksum SHA-256;
4. o upload usa o bucket privado `veredra-books`;
5. o caminho sempre comeca pelo UUID autenticado do usuario;
6. `book_assets` registra caminho, tamanho, MIME e checksum;
7. outro dispositivo baixa, verifica tamanho e SHA-256 e so depois persiste;
8. Web grava no IndexedDB e plataformas nativas usam staging + rename;
9. a copia baixada permanece disponivel offline.

Pacotes possuem limite inicial de 100 MB, ate 5.000 capitulos e 16 MB por
capitulo. Livros inalterados sao deduplicados localmente pelo checksum. PDF e
capas continuam locais nesta entrega.

## Traducoes

Traducoes produzidas pelo Argos e ja registradas na biblioteca sao livros
textuais normais e usam o mesmo pipeline privado. A varredura de pastas antigas
ou orfas em `translated_books` pertence a Fase 4 e nao faz parte desta entrega.

## Conflitos

- anotacoes, marcadores e destaques: merge por ID;
- campos simples: maior `version`, depois `updated_at`;
- progresso: maior capitulo e, no mesmo capitulo, maior progresso;
- exclusoes: tombstone `deleted_at`, nunca remocao silenciosa imediata;
- empates ambiguos: mantem o estado deterministico mais recente e registra
  diagnostico local sem conteudo do livro;
- pacote de livro: o checksum mais recente enviado para o mesmo `local_id`
  substitui o manifesto remoto, sem apagar a copia local antes da verificacao.

## Privacidade de arquivos

Metadados continuam removendo referencias de caminho local. Os pacotes sao
opcionais, ficam em bucket privado e as politicas RLS/Storage exigem o prefixo
`auth.uid()`. Nenhuma service-role key e usada no cliente. O app nao gera URL
publica permanente para os livros.

## Estados de UI

`Sincronizado`, `Sincronizando`, `Offline`, `Alteracoes pendentes`,
`Erro de sincronizacao` e `Sessao expirada`. Todos sao informativos; nenhum
substitui ou bloqueia o storage local. A tela de conta mostra separadamente o
consentimento de metadados e o consentimento de capitulos/traducoes.

## Testes obrigatorios

- fila, retry, deduplicacao, conflito e offline/reconexao;
- encode/decode de pacote e rejeicao de checksum alterado;
- RLS entre usuarios diferentes;
- Storage bloqueando prefixo de outro usuario;
- upload interrompido e retomada;
- download para Web e plataforma nativa;
- livro grande e traducao com milhares de capitulos;
- copia local intacta em toda falha remota.

O backend local prova migration, lint e RLS. O teste completo entre dispositivos
com Supabase hospedado depende das credenciais de staging descritas em
`TESTING.md`.
