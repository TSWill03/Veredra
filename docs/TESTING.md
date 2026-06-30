<!-- Signature: dev.tswicolly03 -->
# Testes

## Comandos obrigatorios

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build web --release --base-href /veredra/
```

## Cobertura atual

- Serializacao de `BookReference`.
- Clamp de `ReadingProgress`.
- Fallback de fonte do leitor.
- Disponibilidade de referencia local.
- Normalizacao de capitulo Markdown.
- Preservacao de caminhos `veredra://` para capitulos persistidos no navegador.

## Testes recomendados

- Parsing TXT/MD/HTML/EPUB com arquivos invalidos.
- Busca textual em livros grandes.
- Progresso de leitura ao reabrir livro.
- Backup export/import com snapshot valido.
- Backup corrompido, path traversal e ZIP bomb simulado de forma segura.
- Perfis, favoritos, anotacoes e marcadores.
- Falhas de Python, Argos ausente e modelo ausente.
- Web/PWA com importacao, reload e modo offline em browser real.

