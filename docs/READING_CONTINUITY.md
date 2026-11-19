<!-- Signature: dev.tswicolly03 -->
# Continuidade de leitura entre Windows, Web/PWA e iOS

## Motivacao
O sync anterior criava e enviava um snapshot de **todas** as posicoes locais
antes de consultar o servidor. Um navegador com checkpoint antigo podia
substituir o mais recente salvo no desktop. Alem disso, o resolvedor anterior
escolhia o capitulo mais avancado, impedindo a leitura deliberada de capitulos
anteriores. A hora de `updated_at` do sync nao deve representar uma nova leitura.

## Invariantes
- O livro e identificado por `bookId` estavel do Veredra. Os caminhos locais
  nao sao identidades portaveis. Se o mesmo EPUB foi importado separadamente
  em dois dispositivos com IDs diferentes, a posicao nao pode ser correlacionada
  sem uma futura migracao explicita de identidade ou sync do livro.
- A fonte canonica de conflito e `ReadingProgress.savedAt` em UTC, **nao**
  indice do capitulo nem porcentagem; reler capitulo anterior e valido.
- Cada `saveProgress` grava local primeiro. O servidor so aceita uma versao
  estritamente mais recente; se for rejeitada, um pull posterior restaura a
  versao aceita, e a copia local mais recente nao e apagada.
- O merge do progresso remoto e atomico por livro dentro da mesma fila
  serializada do `ProgressService`, evitando perder scroll gravado ao mesmo
  tempo que a resposta de rede chega.
- Sem sessao, sem consentimento ou offline: continua leitor local. Nenhum
  arquivo de livro e enviado sem a outra opcao de consentimento.
- Sao sincronizados estado de leitura e metadados, sem transmitir capitulos
  nas chamadas de checkpoint. Conteudo de livro continua por Storage separado.

## Fluxo
1. Ao entrar na conta, restaurar sessao, reconectar rede ou retornar o app ao
   primeiro plano, executar reconciliacao automatica quando habilitada.
2. Antes de abrir um livro, consultar apenas o progresso remoto; usar a
   posicao mais recente disponivel para inicializar capitulo e percentual.
3. Durante scroll TXT/EPUB: debounce local de 700 ms e timer ocioso de 5 s
   para tentar sync remoto depois de parar. Scroll continuo e atendido pelo
   ciclo periodico de 1, 5, 10 ou 15 min, configuravel (padrao 5 min).
   PDF: salvar pagina atual apos 500 ms.
4. Ao sair do leitor ou ocultar/suspender a janela, salvar o checkpoint
   antes de tentar flush remoto. Encerrar processo forcadamente, perder rede
   ou fechar a aba sem tempo para request nao garante o ultimo flush; o
   checkpoint local continua salvo quando a gravacao foi concluida.
5. Em `SyncCoordinator`, consultar todos os checkpoints remotos do usuario,
   reconciliar por `savedAt`, eliminar operacoes obsoletas da fila offline
   e enfileirar apenas posicoes locais estritamente mais recentes.
6. O endpoint RPC `public.veredra_upsert_progress_if_newer` executa
   compare-and-set atomico sob RLS (seguranca invoker + auth.uid) e atualiza
   `reading_progress` somente com checkpoint novo. Trigger cobre clientes
   antigos que ainda usam upsert direto.
7. Executar um segundo pull de progresso depois dos uploads para conciliar
   corridas entre dois dispositivos. A UI da biblioteca atualiza apos sync.

## Limites e verificacao antes do rollout
- Requer a migration
  `supabase/migrations/20261119181500_reading_progress_continuity.sql`
  instalada no Supabase hospedadado **antes** de distribuir clientes que
  invocam o novo RPC; caso contrario a operacao remota de progresso falhara.
- Migracao aditiva: nao modifica ou exclui os checkpoints existentes; adiciona
  RPC security-invoker de autoria autenticada e trigger contra atualizacoes
  obsoletas. Requer checagem da politica RLS existente e teste de acessos.
- Conflitos ainda dependem do horario do dispositivo que criou o checkpoint.
  Relogios muito incorretos podem fazer um cliente parecer mais recente.
  Versao futura pode usar relogio logico por sessao e eventos por livro.
- O usuario deve ativar `Sincronizar dados de leitura` no cliente. A conta
  sozinha nao concede silenciosamente consentimento de upload.
- Ao alterar a posicao num segundo dispositivo, um leitor ainda aberto no
  primeiro nao salta automaticamente para outro capitulo; isso evitaria
  interromper a leitura. A posicao remota e aplicada ao abrir o leitor.
- Testes automaticos necessarios: sync manual, automatico, offline/reconexao,
  reler trecho anterior, cliente Web com estado antigo, mesmo livro por ID,
  e duas contas isoladas. Confirmar upload/download end-to-end com Supabase
  e Windows + navegador antes do merge/deploy.

## Recuperacao
Desativar sync automatico em Configuracoes, preservando a biblioteca local.
A migracao possui apenas objetos auxiliares, removiveis isoladamente caso a
revisao tecnica confirme o rollback. Nunca dar DROP na tabela de progresso.
