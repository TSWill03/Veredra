<!-- Signature: dev.tswicolly03 -->
# Seguranca

## Riscos encontrados

- Importacao de arquivos locais ainda precisa de limites configuraveis por tamanho e quantidade.
- Backup `.twrbackup` usava ZIP sem validacao suficiente contra caminhos internos perigosos.
- Restauracao podia escrever nomes vindos do arquivo compactado sem sanitizacao forte.
- Traducao local executa Python e pode instalar `argostranslate` via `pip`; isso exige consentimento claro do usuario e documentacao.
- Perfis locais nao possuem senha nem criptografia.
- Logs e mensagens devem continuar evitando conteudo de livros.

## Correcoes aplicadas

- Backup agora falha na Web com mensagem clara.
- Importacao de backup valida tamanho maximo do arquivo, quantidade de arquivos, tamanho por arquivo, total descompactado e caminhos internos.
- Restauracao sanitiza nomes de arquivos antes de gravar no disco.
- Escritas pelo `AppStorage` desktop usam arquivo temporario antes de substituir o destino.
- Traducao local agora e explicitamente desktop-only na Web.
- Subprocessos de traducao receberam timeout basico.

## Recomendacoes

- Adicionar limite por arquivo importado e aviso para arquivos grandes.
- Restaurar backups primeiro em diretorio temporario e somente depois promover para o perfil final.
- Criar backup automatico antes de restaurar sobre dados existentes.
- Adicionar hash/manifest de integridade ao backup.
- Criar painel de diagnostico local sem conteudo de livros.
- Planejar criptografia opcional por perfil e senha local opcional.
- Nunca instalar dependencias Python sem acao explicita do usuario.

