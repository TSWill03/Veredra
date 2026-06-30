<!-- Signature: dev.tswicolly03 -->
# Production readiness

## P0

Nenhum P0 bloqueando build/teste foi encontrado apos as correcoes. Antes de distribuicao publica ampla, a decisao de licenca precisa ser feita pelo autor.

## P1

- Web ainda usa `shared_preferences_web`; migrar para IndexedDB/OPFS para livros grandes.
- Backup Web ainda nao esta implementado.
- PDF Web ainda nao esta implementado.
- Importacao precisa de limites configuraveis de tamanho.
- Falta teste automatizado de navegador para provar importacao + reload + offline.

## P2

- `BookService`, `LibraryPage` e `ReaderPage` seguem grandes.
- Observabilidade ainda e basica.
- Traducao local precisa de ambiente virtual isolado e confirmacao mais explicita antes do `pip install`.
- CI cobre analyze/test, mas nao build de plataformas.

## P3

- Criptografia/senha por perfil.
- Sync multi-dispositivo.
- CQRS somente se a busca/indexacao crescer.

## Estado apos esta rodada

- `flutter analyze` passa.
- `flutter test` passa.
- `flutter build web --release --base-href /veredra/` passa.
- PWA tem nome, tema e manifest de Veredra.
- Fallbacks Web existem para recursos desktop-only.
- Nenhuma licenca foi aplicada.

