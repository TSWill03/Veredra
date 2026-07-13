<!-- Signature: dev.tswicolly03 -->
# Persistencia local

## Contrato comum

`AppStorage` expoe leitura/escrita de string e bytes, existencia, exclusao e
exclusao por prefixo. Servicos de biblioteca, progresso, perfis e sync nao
precisam importar diretamente `dart:io`.

## Windows e Android

O adapter IO grava no diretorio da aplicacao. Escritas usam arquivo temporario e
promocao para reduzir corrupcao apos interrupcao. Caminhos de importacao e backup
sao validados e nomes restaurados sao sanitizados.

## Web

O adapter usa IndexedDB:

```text
database: veredra_local_storage
store: entries
```

Capitulos, capas e outros bytes nao usam mais `shared_preferences`. Em uma
instalacao antiga, a leitura procura a chave `veredra.storage.*`, grava no
IndexedDB, confirma e entao remove a copia antiga. Falha de migracao preserva o
legado para nova tentativa.

## Fila e sessao

- fila/cursor/device id: storage local por perfil;
- sessao Supabase: `flutter_secure_storage` nativo e storage do SDK na Web;
- diagnosticos: log local limitado a 200 eventos e redigido;
- senha e conteudo bruto do livro nunca entram em diagnosticos.

## Recuperacao

Fila JSON corrompida e movida para quarentena. Um erro de leitura de livro deve
afetar somente aquele item. Backup continua sendo a estrategia de recuperacao
do perfil no desktop; Web backup/export ainda e limitacao documentada.

## Evolucao

Drift/SQLite e recomendado quando consultas/migrations locais justificarem o
custo. OPFS pode hospedar blobs Web muito grandes, mas deve vir com deteccao de
suporte, fallback IndexedDB e teste de migracao. Nenhuma migracao ampla deve ser
feita sem fixtures de dados antigos e backup reversivel.
