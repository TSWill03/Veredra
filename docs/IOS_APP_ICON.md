# Icone do Veredra no iOS (build Windows/xcross)

## Fonte da marca

O desenho aprovado e mantido em `assets/branding/app_icon_master.png`.
O gerador `tool/generate_branding_assets.py` deriva os PNGs de
`ios/Runner/Assets.xcassets/AppIcon.appiconset/`. Para iOS, o gerador
preenche os cantos transparentes com fundo escuro, mantendo a arte; o sistema
iOS faz o arredondamento de bordas. A imagem 1024x1024 deve ser opaca.

## Causa do icone generico no iPhone

O xcross 2.0.9 montava o `.app` sem `Assets.car`, sem os PNGs de
icone na raiz e sem `CFBundleIcons` no `Info.plist`, mesmo com o
`AppIcon.appiconset` correto no repositorio. O suporte a `actool`
(compilador de catalogo de assets) foi incluido no **xcross 2.1.0**.
Use **xcross >= 2.1.0**, preferindo release estavel testada e
com checksum verificado, para builds nativas Windows/Linux.

## Checklist antes de instalar

1. Use worktree limpa e preserve o perfil, bundle identifier e versao instalada.
2. Configure Flutter e o backend do mesmo ambiente da instalacao anterior.
3. Gere a build iOS com xcross >= 2.1.0.
4. Execute `python tool/validate_ios_app_icon.py "<caminho>/Runner.app"`.
   Deve encontrar `Assets.car`, `AppIcon60x60@2x.png`,
   `AppIcon76x76@2x~ipad.png` e `CFBundleIcons` no `Info.plist`.
5. Confirme assinatura e numero de build antes de instalar como **upgrade**
   com o **mesmo bundle identifier**. Nunca desinstale para corrigir icone:
   isso pode apagar biblioteca/progresso armazenados localmente.
6. No iPhone, abra o app e confira icone, dados locais, leitura e login.
   Sem dispositivo conectado nao considerar a implantacao concluida.

## Validacao de regressao

`tool/validate_ios_app_icon.py` falha (exit code 1) para qualquer `.app`
sem recursos de icone. O arquivo `Contents.json` da catalogo continua
configurado como `AppIcon` no projeto iOS.
