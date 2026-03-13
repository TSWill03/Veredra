<!-- Signature: dev.tswicolly03 -->
# Veredra

Veredra e um leitor multiplataforma para romances, webnovels e livros digitais com foco em leitura continua, biblioteca local e personalizacao forte da experiencia de leitura.

O projeto foi pensado para desktop primeiro, mas com base preparada para Android e iOS. A proposta e unir o conforto de leitura vertical continua com recursos de biblioteca, progresso, anotacoes, importacao de formatos diferentes e traducao local de livros textuais.

## Identidade

- Nome da marca: `Veredra`
- Assinatura do projeto: `dev.tswicolly03`
- Package tecnico Flutter: `txt_webnovel_reader`

## O que o app faz hoje

- Importa livros por pasta ou por arquivos individuais
- Suporta leitura continua com carregamento progressivo
- Salva automaticamente o progresso de leitura
- Continua do ponto salvo ao reabrir o livro
- Mantem biblioteca local com recentes e favoritos
- Permite editar metadados do livro
- Permite trocar ou ajustar a capa
- Suporta multiplos perfis locais sem login
- Exporta e importa backup completo do perfil
- Permite busca por capitulos e busca textual dentro do livro
- Permite marcadores, destaques e anotacoes
- Possui temas, fundos, tipografia e ajustes de leitura
- Traduz livros textuais localmente no desktop com Argos Translate

## Formatos suportados

### Livros

- `.txt`
- `.md`
- `.markdown`
- `.html`
- `.htm`
- `.xhtml`
- `.epub`
- `.pdf`

### Imagens de capa

- `.jpg`
- `.jpeg`
- `.png`
- `.webp`
- `.gif`
- `.bmp`

## Recursos principais

### Biblioteca

- Importacao de livros locais
- Busca por titulo e metadados
- Favoritos
- Historico de recentes
- Edicao de titulo, autor, descricao, serie, volume, tags e nome alternativo
- Capas automaticas para EPUB e PDF quando disponiveis
- Capas manuais para livros textuais
- Ajuste de enquadramento da capa

### Leitura

- Rolagem vertical continua
- Carregamento lazy de capitulos
- Barra superior discreta
- Retomada automatica do ponto salvo
- Busca por conteudo no livro inteiro
- Painel lateral com capitulos, progresso e atalhos
- Ajuste de fonte, largura da coluna, espacamento e alinhamento
- Temas claro/escuro e presets de fundo adicionais

### Destaques e anotacoes

- Marcadores de leitura
- Destaques visuais no texto
- Anotacoes sobre trechos
- Favoritos de trechos importantes
- Painel lateral para navegar entre notas e marcadores

### Perfis e backup

- Perfis locais sem senha
- Isolamento de biblioteca e progresso por usuario
- Exportacao completa do perfil
- Importacao completa do perfil
- Backup inclui livros gerenciados, preferencias, capas, progresso, marcadores e anotacoes

### Traducao local

- Traducao desktop-first com `Argos Translate`
- Mantem o livro original intacto
- Gera uma nova copia traduzida do livro
- Traduz capitulo por capitulo
- Suporta pares de idiomas instalados localmente
- Funciona offline depois da instalacao inicial do motor e do modelo

## Arquitetura

O projeto esta organizado em camadas simples para facilitar manutencao e expansao:

```text
lib/
  main.dart
  models/
  pages/
  services/
  widgets/
```

### Pastas

- `models/`: estruturas de dados do app
- `services/`: leitura, biblioteca, progresso, backup, perfis, traducao, anotacoes
- `pages/`: telas principais como biblioteca, leitor e PDF
- `widgets/`: componentes reutilizaveis, configuracoes e overlays

## Como executar

### Requisitos

- Flutter SDK instalado e configurado no PATH
- Para desktop Windows: Visual Studio com toolchain C++
- Para Android: Android Studio ou SDK configurado
- Para iOS/macOS: Xcode em um Mac

### Instalar dependencias

```bash
flutter pub get
```

### Rodar no Windows

```bash
flutter run -d windows
```

### Rodar no Android

```bash
flutter run -d android
```

### Rodar no iOS

```bash
flutter run -d ios
```

## GitHub Actions para iOS

O repositório agora inclui o workflow [`.github/workflows/flutter-ios.yml`](C:/Users/Usuario/Documents/Playground/.github/workflows/flutter-ios.yml).

Ele roda em:

- `workflow_dispatch`
- `push` na branch `main`
- `pull_request`

### O que o workflow faz

- instala Flutter `3.38.9` com cache
- roda `flutter --version`
- roda `flutter pub get`
- roda `flutter analyze`
- roda `flutter test`
- instala CocoaPods no projeto iOS
- gera build iOS
- envia os artefatos do build para a aba de artifacts do GitHub Actions

### Como disparar manualmente

1. Abra o repositório no GitHub
2. Entre em `Actions`
3. Selecione `Flutter iOS`
4. Clique em `Run workflow`

### Secrets suportados

Secrets principais para build assinado:

- `BUILD_CERTIFICATE_BASE64`
- `P12_PASSWORD`
- `BUILD_PROVISION_PROFILE_BASE64`
- `KEYCHAIN_PASSWORD`

Secrets opcionais do App Store Connect:

- `APPSTORE_ISSUER_ID`
- `APPSTORE_KEY_ID`
- `APPSTORE_PRIVATE_KEY`

### Build sem assinatura x build assinado

Sem assinatura:

- acontece quando os secrets principais de assinatura nao existem
- o workflow roda `flutter build ios --release --no-codesign`
- o artefato enviado e o app iOS sem assinatura em `Runner.app`
- serve para validar que o projeto compila no runner macOS

Com assinatura:

- acontece quando os secrets principais de assinatura existem
- o workflow instala certificado e provisioning profile temporarios no runner
- o workflow gera um `.ipa` assinado
- os artefatos enviados incluem o `.ipa` e o `Runner.xcarchive`

Observacao:

- os secrets do App Store Connect sao preparados no workflow quando existem, deixando a base pronta para futuras etapas de distribuicao ou upload
- o `ExportOptions.plist` do workflow esta configurado para `app-store`; se voce usar outro tipo de provisioning profile, ajuste esse metodo no YAML

## Traducao local no desktop

Para usar a traducao local de livros textuais:

1. Instale Python 3 com `pip`
2. Abra o app no desktop
3. Escolha `Traduzir livro` no menu do livro
4. O proprio app pode instalar o `Argos Translate`
5. Baixe o modelo do idioma desejado
6. Gere a copia traduzida

Observacoes:

- A primeira instalacao exige internet
- Depois do modelo instalado, a traducao pode funcionar offline
- Nesta fase, a traducao foi pensada principalmente para livros textuais e EPUB convertido em texto
- PDF ainda nao entra no mesmo pipeline de traducao textual

## Estrutura de persistencia

O app salva localmente:

- ultimo livro aberto
- capitulo atual
- posicao de leitura
- tamanho da fonte
- tema e preferencias do leitor
- biblioteca do perfil
- metadados
- anotacoes e marcadores
- capas importadas ou ajustadas

As preferencias e estados leves usam armazenamento local simples e confiavel, enquanto os arquivos gerenciados do app ficam em diretorios locais da aplicacao para permitir reabertura, backup e migracao.

## Branding e autoria

Veredra possui:

- identidade visual propria
- icone original do app
- marca d'agua discreta no app
- assinatura `dev.tswicolly03` nos arquivos principais
- identificadores nativos assinados nas plataformas

Isso fortalece a procedencia do projeto e facilita identificar copias indevidas, embora nao seja um mecanismo juridico ou tecnico de bloqueio de copia por si so.

## Status atual

O projeto ja esta funcional como MVP avancado para leitura local, com biblioteca, progresso, personalizacao, backup e traducao local no desktop.

## Proximos passos naturais

- refinamento visual geral da marca Veredra
- melhoria do fluxo de traducao em lote
- sumario mais forte para EPUB/PDF baguncados
- sincronizacao entre dispositivos
- suporte mais profundo a mobile para traducao

## Licenca e uso

Ainda nao ha uma licenca publica definida neste repositorio. Ate que isso seja explicitamente definido, trate o codigo como propriedade intelectual do autor do projeto.
