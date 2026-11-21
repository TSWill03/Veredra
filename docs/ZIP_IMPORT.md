# Importação de ZIP de capítulos na Web/PWA

## Por que foi trazida para a main moderna
A PR histórica #10 ficou empilhada sobre o modo privado da PR #8, que ainda não é uma decisão de produto aprovada. A importação ZIP é útil independentemente de exigir login. Esta consolidação recupera exclusivamente o parser, a integração Web e os testes, sem ativar acesso privado, sem exigir Supabase e sem alterar a importação desktop.

## Fluxo
Biblioteca > Importar livro > ZIP de capítulos. Aceita arquivos TXT, Markdown e HTML no mesmo ZIP, organiza nomes como 1, 2, 10 e cria um livro textual com todos os capítulos armazenados localmente no IndexedDB do perfil. O mesmo fluxo funciona no PWA do iPhone; não é upload automático à nuvem. O envio de livros ao Supabase continua exigindo consentimento separado nas opções de sincronização.

## Proteções
- Limites de segurança existentes em `ImportLimits`: até 5.000 capítulos de texto, 16 MiB por arquivo e 128 MiB somados de texto; 10.000 entradas ZIP.
- Recusa nomes absolutos, traversal (`..`) e paths duplicados independentemente de maiúsculas/minúsculas.
- Ignora metadados ocultos, entradas não textuais e pastas `__MACOSX`.
- Usa identificador UUID v4 **novo para cada importação**: ZIPs com mesmo nome, mesma contagem e primeiros/últimos títulos não substituem livros já importados. Rollback em caso de erro limpa somente o prefixo exclusivo da nova importação.
- Salva primeiro os capítulos no armazenamento local; se ocorrer erro, não modifica os livros anteriores. Não remove dados existentes durante importação ou atualização.

## Observações técnicas
- ZIPs podem ser grandes: o navegador precisa ter RAM e quota de armazenamento suficientes; validar com bibliotecas reais grandes antes de promover para uso intensivo.
- O parser atual verifica o ZIP com `ZipDecoder(verify: true)` e só depois aplica os limites de tamanho do conteúdo extraído. ZIPs hostis com declaração de tamanho fraudulenta ainda precisam de pré-inspeção da central directory e proteção adicional contra bombas de descompressão. Por isso, não tratar a funcionalidade como segura para ZIPs arbitrários da internet sem uma auditoria adicional.
- Importar a mesma obra duas vezes cria duas entradas independentes; não há deduplicação automática de livros.
- E2E `e2e/tests/zip-import.spec.mjs` simula ZIPs com mesmos nomes e conteúdos distintos, recarrega o PWA e confirma preservação.

## Rollback
Reverter o commit de integração ou remover a opção da interface **não** deve apagar a biblioteca nem as chaves IndexedDB existentes. O formato de armazenamento é o mesmo usado pelo leitor Web tradicional.
