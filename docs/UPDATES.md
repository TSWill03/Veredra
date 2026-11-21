# Atualizações do Veredra (Web/PWA e Windows)

## Versão e aviso azul

O cliente possui identidade de build embutida em `AppConfig.clientVersion` (não lê o `version.json` recém-publicado como se fosse a versão executada). Na Web/PWA, consulta `https://wicolly.com.br/veredra/updates.json`; no Windows, consulta a release estável mais recente de `TSWill03/Veredra` pelo endpoint público do GitHub Releases e considera apenas tags `vMAJOR.MINOR.PATCH+BUILD`. A checagem acontece ao abrir, a cada 30 min e quando o usuário solicita; falhas de rede não impedem a leitura offline. Sem sincronização de informações de visualização entre perfis: `shared_preferences` guarda a versão vista por dispositivo/plataforma.

O ícone de atualização fica na barra da **Biblioteca**, nunca sobre um livro em leitura. O ponto azul aparece somente para uma versão maior e ainda não visualizada. Ao abrir, mostra novidades e ações disponíveis; visualizar remove o ponto azul, mas mantém a instalação disponível.

### Web e PWA no iPhone

O usuário escolhe **Atualizar e recarregar**. O Flutter sinaliza ao host Web `veredraReloadForUpdate` para tentar atualizar o service worker, observar eventual troca de controller e recarregar a URL com cache-buster. NÃO limpa IndexedDB, localStorage, bibliotecas, CacheStorage nem instala imediatamente quando o usuário está lendo. O PWA é atualizado como Web; iOS nativo assinado/TestFlight permanece um canal separado. Mantenha os testes PWA de cache offline e navegação.

### Windows (instalação sem assistente a cada update)

1. Em todo PR/push monitorado, o CI compila Windows e gera o instalador **Inno Setup por usuário** como artefato `veredra-windows`. Isso não publica releases instáveis.
2. Somente para uma versão aprovada, após merge em `main`, atualizar de forma coordenada `pubspec.yaml`, `AppConfig.clientVersion`, `web/updates.json`, documentação/changelog e criar a tag `vX.Y.Z+N` apontando para um commit de `main`. O workflow `windows-release.yml` executa análise/testes/build Windows, gera `Veredra-Setup-vX.Y.Z+N.exe`, publica no **GitHub Releases** e anexa `SHA256SUMS.txt`.
3. Instalador Inno possui AppId fixo, instala em `%LOCALAPPDATA%\Programs\Veredra` **sem UAC**, cria atalho no menu Iniciar, não guarda livros na pasta de instalação e não remove o diretório de suporte da aplicação.
4. Quando detectar nova release, o Veredra consulta a API pública do GitHub, exige asset com **nome e caminho oficial** e digest SHA-256 válido fornecido pela API, baixa via HTTPS (redirecionamentos limitados a domínios GitHub confiáveis) para `%TEMP%\veredra-verified-updates`, verifica tamanho/SHA-256 e somente após ação explícita do usuário inicia o Inno em modo silencioso. O app fecha após lançar o instalador e o instalador reabre o novo Veredra.
5. O **primeiro** uso a partir do ZIP portátil ainda exige migrar uma vez para o instalador. O arquivo e a biblioteca do usuário são preservados; novas versões no mesmo canal devem se atualizar sem execução manual do instalador.

**Limitações e segurança:** sem certificado Authenticode, o Windows SmartScreen ou antivírus ainda pode pedir confirmação/impedir execução; não tentar contornar esses avisos. Integridade SHA-256 é obrigatória e não substitui assinatura de publisher confiável. Se o GitHub não fornecer digest, o app NÃO permite instalação automática. Atualizações não são obrigatórias; o usuário decide quando aplicar. O instalador substitui apenas arquivos do programa, não a biblioteca/dados. Para rollback, reinstalar versão anterior do GitHub Releases e manter backup dos dados de aplicativo; o fluxo ainda não possui rollback transacional automático. Testar primeiro com uma conta e biblioteca de homologação.

## Operação de releases

```powershell
# Após aprovar e integrar o PR com versão alinhada e CI verde:
git checkout main
git pull --ff-only
git tag v0.1.4+5
git push origin v0.1.4+5

# Conferir GH Actions: Windows installer and GitHub Release
# Conferir release + digest; abrir app Windows instalado e validar upgrade com próxima versão.
```

A Web usa `web/updates.json` copiado no build Flutter para `build/web/updates.json`, depois para `Wicolly-Sites/veredra/updates.json`; no Wicolly-Sites configurar `Cache-Control: no-store` para o manifesto. A implantação do site continua independente do GitHub Releases: **não anunciar instalador Windows** antes de publicar a release estável.

`dart run tool/verify_update_version.dart` detecta divergências entre `pubspec.yaml`, `AppConfig.clientVersion` e manifesto Web. `flutter test test/update_service_test.dart` cobre comparações, feed Web, asset verificado e fallback sem checksum.
