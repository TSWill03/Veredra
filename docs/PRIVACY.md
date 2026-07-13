<!-- Signature: dev.tswicolly03 -->
# Privacidade

## Padrao local

Sem conta, biblioteca, titulos, arquivos, capas, progresso, anotacoes,
marcadores, preferencias e estatisticas permanecem somente no dispositivo. O app
nao exige login para ler.

## Sincronizacao consentida

Ao habilitar `Sincronizar dados de leitura`, podem ser enviados ao Supabase:
perfil, preferencias, metadados do livro, favorito, progresso, marcadores,
anotacoes, destaques e estatisticas. Caminhos locais e conteudo dos livros nao
sao incluidos.

`Sincronizacao completa` esta desabilitada. Nenhum livro ou capa e enviado sem
uma futura autorizacao separada e informada.

## Terceiros

- Supabase processa auth e dados sincronizados quando configurado;
- Google participa apenas se o usuario escolher OAuth;
- Argos Translate e local no desktop apos instalacao explicita;
- nao ha analytics, publicidade nem upload de diagnostico por padrao.

Logs locais nao devem conter conteudo, titulo, anotacao, token ou e-mail. Se
telemetria opcional for adicionada, deve ser opt-in, redigida e substituivel.

## Controle do usuario

O usuario pode manter modo local, desligar sync, sair e solicitar exclusao da
conta. Dados locais nao sao apagados automaticamente no logout. Exclusao remota
remove tabelas em cascade; limpeza de arquivos remotos precisa estar pronta antes
de habilitar upload completo.

Esta pagina descreve o comportamento tecnico e nao substitui uma politica legal
publicada e revisada para a jurisdicao de lancamento.
