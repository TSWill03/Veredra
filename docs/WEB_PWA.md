<!-- Signature: dev.tswicolly03 -->
# Web e PWA

## Build

```bash
flutter build web --release --base-href /veredra/
dart run tool/patch_flutter_service_worker.dart
```

O build final fica em:

```text
build/web/
```

O patch pos-build ajusta o service worker gerado pelo Flutter para reconhecer recursos servidos sob `/veredra/`. Sem esse ajuste, o cache offline pode funcionar na raiz do dominio, mas falhar em subpasta.

## Teste local

Para testar como raiz do servidor:

```bash
cd build/web
python -m http.server 8080
```

Abra:

```text
http://localhost:8080/
```

Para simular a subpasta `/veredra/`, copie o conteudo de `build/web` para uma pasta `veredra/` dentro de um servidor estatico e abra:

```text
http://localhost:8080/veredra/
```

## Recursos Web

- Importacao de arquivos textuais.
- Importacao EPUB com conversao para capitulos textuais.
- Biblioteca persistida no navegador.
- Progresso, preferencias, notas, marcadores e estatisticas persistidos no navegador.
- App shell cacheado pelo service worker do Flutter em build release.

## Fallbacks

- PDF: `PDF ainda nao esta disponivel na versao Web.`
- Pasta: `Importacao por pasta esta disponivel apenas no desktop.`
- Backup: `Backup e restauracao ainda estao disponiveis apenas no desktop.`
- Traducao: `A traducao local com Argos esta disponivel apenas no desktop.`
