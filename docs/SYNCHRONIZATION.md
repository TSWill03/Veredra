<!-- Signature: dev.tswicolly03 -->
# Sincronizacao offline-first

## Politica e consentimento

O Veredra funciona sem conta e permanece offline-first. Criar conta nao envia
livros automaticamente. Existem dois consentimentos independentes:

1. **Sincronizar dados de leitura** (metadados, preferencias, progresso,
   marcadores, anotacoes, destaques e estatisticas).
2. **Sincronizar livros completos** (capitulos TXT, capitulos extraidos de EPUB,
   capas e PDFs nativos). Essa opcao exige que a primeira ja esteja ativa,
   exibe um aviso de privacidade, inicia desativada e pode ser desligada.

Os arquivos nao sao criptografados de ponta a ponta: ficam no bucket privado
`veredra-books` do Supabase, isolado por usuario com RLS. Apenas envie livros
que voce tem autorizacao para armazenar. Desativar a opcao impede novos envios,
mas nao exclui os arquivos ja presentes na nuvem. Excluir a conta tenta remover
os objetos do Storage antes de apagar os registros da conta; falha de limpeza
interrompe a exclusao.

## Metadados e dados de leitura

- perfil e preferencias;
- metadados e favoritos do livro, sem caminho local ou conteudo em JSON remoto;
- progresso;
- marcadores, anotacoes e destaques;
- estatisticas de leitura.

1. toda mudanca e salva localmente;
2. snapshots criam operacoes UUID em fila duravel por perfil;
3. operacoes repetidas sao deduplicadas;
4. offline, ficam pendentes e nao bloqueiam leitura;
5. reconexao/manual executa upserts idempotentes;
6. alteracoes remotas sao puxadas e aplicadas;
7. falhas usam backoff exponencial de 5 segundos a 30 minutos;
8. filas corrompidas vao para quarentena, sem apagar a biblioteca.

O dispositivo usa UUID aleatorio estavel, nao identificador fisico. Sync
automatico e opcional, por padrao a cada cinco minutos (configuravel em
1, 5, 10 ou 15 min), alem de login, reconexao e retorno ao primeiro plano.
O leitor salva o scroll local em debounce de 700 ms e tenta enviar apos 5 s
de inatividade; ao sair/ocultar faz flush em melhor esforco.

## Sincronizacao de arquivos (beta)

Apenas com consentimento separado:

1. sincronizar metadados e garantir o registro `books`;
2. listar `book_assets` do usuario;
3. para arquivos locais sem versao remota, criar ZIP portavel com manifesto e
   capitulos (ou PDF original), e capa opcional;
4. calcular SHA-256 do ZIP, enviar ao Storage privado
   `user_id/sha256(book_id)/sha256(zip).zip`, registrar checksum/tamanho;
5. em novo dispositivo, verificar tamanho e SHA-256, validar manifesto,
   restaurar no armazenamento local e associar ao mesmo ID de biblioteca;
6. se remoto e local divergem sem versao base conhecida, manter ambos intactos
   e apresentar aviso, sem sobrescrever.

TXT/MD/HTML e EPUB: a versao sincronizada preserva **capitulos de leitura**,
nao necessariamente o arquivo EPUB original com sua formatacao integral.
PDF: conserva o arquivo original, mas a versao Web ainda nao possui leitor PDF;
o download/restauro de PDF fica restrito aos clientes nativos.

Limites atuais: ZIP comprimido ate **95 MiB**, dados descompactados ate
**128 MiB**, ate **5.000 capitulos** com **16 MiB por capitulo**; capas ate
20 MiB. O Supabase bucket limita objetos ate 100 MiB. Ficheiros maiores ficam
locais, com aviso de falha; nao sao descartados. O primeiro download requer
conexao, depois o livro restaurado permanece no armazenamento local e legivel
offline. Sem upload em partes/TUS nesta implementacao inicial: transferencias
grandes interrompidas reiniciam o pacote.

## Conflitos de metadados

- anotacoes/marcadores/destaques: merge por ID;
- campos simples: maior `version`, depois `updated_at`;
- progresso: `savedAt` mais recente, mesmo se o usuario voltou capitulos;
  checkpoints locais antigos nao sao reenviados ao abrir outro dispositivo;
  RPC transacional e trigger protegem a atualizacao de posicoes obsoletas;
- exclusoes: tombstone `deleted_at`, nao remocao silenciosa;
- divergencias ambiguas: mantem dados locais e registra diagnostico sem
  conteudo do livro.

Para arquitetura detalhada e checklist de testes entre Windows, Web e iOS,
veja `docs/READING_CONTINUITY.md`.

## Estados de UI

`Sincronizado`, `Sincronizando`, `Offline`,
`Alteracoes pendentes`, `Erro de sincronizacao` e `Sessao expirada`.
Transferencias de arquivos exibem contagem, progresso e aviso de conflito.

## Implantacao e limites conhecidos

Antes de testar sincronizacao de arquivos, aplicar
`supabase/migrations/20261119165543_book_content_sync.sql` **apenas apos
revisao de schema/RLS**. Esta branch nao representa deploy.
Verificar com duas contas e dois dispositivos; confirmar isolamento de bucket,
limites de projeto, restore offline, interrupcao de rede e exclusao de conta.

A compactacao atualmente mantem um pacote em memoria por vez, verifica os
livros a cada sync e nao implementa upload resumivel. Reconciliacao de exclusao
individual de livros, quota detalhada por usuario, sincronizacao real multi-
dispositivo e testes E2E hospedados devem ser validados antes de habilitar
essa funcionalidade em producao.
