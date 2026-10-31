# Veredra iOS — execução no Destruking (23/10/2026)

## Estado confirmado

- Projeto principal: `C:\Users\Usuario\Documents\Codex\Veredra\app` (Flutter 3.38.9). Versão antiga preservada em `C:\Users\Usuario\PycharmProjects\Veredra`.
- Backup completo dos fontes/Git: `D:\Veredra_iOS\Backups\Veredra_Codex_2026-10-23`. Ignorados diretórios regeneráveis build, .dart_tool, coverage e node_modules.
- SDK Darwin direcionado para `D:\Veredra_iOS\SDK\xcross-darwin.artifactbundle` com `D:\Veredra_iOS\xcross-config.yaml`.
- xcross 2.0.6 e Swift 6.4.1 instalados. xcross suporta Flutter debug/JIT no iPhone com iOS 17 ou superior; Flutter release/AOT ainda exige Mac (ou GitHub Actions/macOS).
- `xcross flutter doctor` encontrou SDK Darwin ausente, autenticação Apple ausente e iPhone desconectado.
- Xcode 27.1 estável não baixado: URL direta da Apple sem sessão autenticada redirecionou para /unauthorized/.

## Checklist para instalar no iPhone

1. Conectar o HD D: e rodar PowerShell: `& 'D:\Veredra_iOS\Scripts\Check-Veredra-iOS.ps1'`.
2. Abrir Apple Developer Downloads com login Apple, baixar o Xcode 27.1 .xip oficial para `D:\Veredra_iOS\Xcode\Xcode_27.1.xip`. Não compartilhar arquivo SDK extraído.
3. Rodar `& 'D:\Veredra_iOS\Scripts\Install-Darwin-SDK.ps1'` para instalar o SDK direto no HD.
4. Em PowerShell normal: `$env:XCROSS_CONFIG='D:\Veredra_iOS\xcross-config.yaml'; xcross auth --apple-id SEU_APPLE_ID`. Credenciais somente por entrada interativa, nunca em arquivo.
5. Conectar iPhone iOS 17+, desbloquear, aceitar confiança, ativar Developer Mode. Apple Mobile Device Service do Windows já está ativo.
6. Em PowerShell elevado, definir XCROSS_CONFIG como no passo 4 e executar `xcross tunnel`; manter aberto.
7. Em PowerShell normal: `& 'D:\Veredra_iOS\Scripts\Run-Veredra-iPhone.ps1'`. O primeiro run perguntará sobre bundle ID; conferir antes de selecionar.

## Funcionalidades e limitações

- Importação de TXT/Markdown/HTML, EPUB e PDF e leitura local possuem implementações para iOS no código, mas ainda precisam ser testadas no dispositivo.
- O esquema `veredra://auth-callback/` foi adicionado ao Info.plist para login nativo; também deverá ser incluído nas URLs autorizadas no Supabase antes de ativar o serviço.
- Exportação de backup no iOS/Android deve usar compartilhamento nativo via share_plus, pois file_selector não suporta getSaveLocation nesses sistemas. O usuário precisa escolher Salvar em Arquivos; o arquivo temporário não é backup durável. Restaurar pelo seletor de documento.
- Tradução offline via Python/Argos permanece **incompatível com iOS**, desabilitada intencionalmente.
- Para distribuir via TestFlight/App Store, usar GitHub Actions macOS, Apple Developer e certificados. Artefato sem assinatura não instala diretamente no iPhone.

## Validação e rollback

- Antes das edições: flutter analyze = sem problemas, flutter test = 26 aprovados.
- No commit desta etapa validar novamente análise, testes e compilação, sem declarar teste de iPhone sem dispositivo.
- Branch de trabalho: feat/ios-external-hd-20261023. Para voltar à main: primeiro salvar mudanças locais e então `git switch main`; nunca usar `git reset --hard` sobre alterações não salvas.
- Fontes: https://xcross.sh/docs/quick-start/ ; https://xcross.sh/docs/configuration/ ; https://docs.flutter.dev/deployment/ios .

## Atualizacao (30/10/2026)

- Motor iOS debug baixado para o cache do Flutter por meio do comando xcross flutter precache --mode debug (84,1 MB).
- Swift 6.4.1, LLVM/ld64.lld, pymobiledevice3 e servico Apple Mobile Device verificados.
- Xcode 27.2 estavel (27B52, 29/10/2026) recomendado: https://developer.apple.com/download/all/
- SDK ainda sem instalar: Apple exige download do Xcode.xip autenticado pelo usuario; nao ha Xcode.xip no computador.
- Salvamento direto em D:\Veredra_iOS\Xcode, evitando o C: com somente ~24 GB livres.
- Scripts de duplo clique no HD: 01_Baixar_Xcode.url; 02_Instalar_SDK.cmd; 03_Autenticar_Apple.cmd; 04_Executar_iPhone.cmd.
- Instalador detecta Xcode.xip oficial, valida tamanho e cabecalho xar! e extrai SDK/cache temporario para HD.
- A senha Apple nao e solicitada no chat. Autenticacao e conexao fisica do iPhone seguem pendentes.
- Compilacao unsigned iOS ja concluida com sucesso na CI; aparelho nao foi testado.
