<!-- Signature: dev.tswicolly03 -->
# Traducoes no Veredra

## Criacao

A traducao com Argos Translate continua desktop-first. O original permanece
intacto e uma nova copia textual e criada em:

```text
profiles/<perfil>/storage/translated_books/<id-da-traducao>/
```

Quando o fluxo termina normalmente, a copia traduzida e inserida na biblioteca
com a tag `traducao`.

## Recuperacao de traducoes antigas

Ao executar uma sincronizacao completa no desktop, o Veredra procura subpastas
de `translated_books` que ainda nao estejam representadas na biblioteca.

Para cada pasta valida:

1. lista TXT, Markdown e HTML sem seguir links;
2. ordena os capitulos numericamente;
3. reabre a pasta como livro textual;
4. adiciona as tags `traducao` e `recuperada`;
5. reinsere o livro na biblioteca local;
6. envia o livro pelo pipeline privado de pacotes, quando autorizado.

Pastas vazias, staging e traducoes ja registradas sao ignoradas. Nenhum arquivo
original e removido durante a recuperacao.

## Web, PWA e iPhone

O navegador e o iPhone nao executam Python/Argos. Eles recebem a copia ja
traduzida como um livro normal:

```text
Desktop traduz
  -> recupera/registra a copia
  -> gera ZIP + manifest.json
  -> calcula SHA-256
  -> envia ao bucket privado
  -> Web/iPhone baixa e verifica
  -> persiste para leitura offline
```

O usuario precisa ativar separadamente:

- `Sincronizar dados de leitura`;
- `Sincronizar livros e traducoes`.

## Limites atuais

- ate 5.000 capitulos por pacote;
- ate 16 MB por capitulo;
- ate 100 MB por livro sincronizado;
- PDF e capas ainda nao entram no pacote;
- traducao remota no servidor nao faz parte desta fase.

## Seguranca

- o bucket permanece privado;
- o caminho remoto inicia pelo UUID autenticado;
- o download e rejeitado se tamanho ou SHA-256 divergirem;
- nenhuma chave privada de provedor e exposta ao cliente;
- falha de upload/download nao apaga a copia local.
