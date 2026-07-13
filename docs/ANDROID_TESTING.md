<!-- Signature: dev.tswicolly03 -->
# Testes Android

## Build e dispositivos

```bash
flutter doctor -v
flutter devices
flutter emulators
flutter build apk --debug
flutter build apk --release
flutter emulators --launch Medium_Phone_API_36.1
flutter run -d DEVICE_ID
```

Ou instale o debug por CLI:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb logcat -c
adb shell am start -n dev.tswicolly03.txt_webnovel_reader/.MainActivity
adb logcat -d | grep -E "FATAL EXCEPTION|E/flutter"
```

No Windows PowerShell, substitua `grep` por `Select-String`.

## Checklist

- install/launch e Activity resumed;
- tela pequena, landscape/portrait e teclado;
- back, force-stop/restart e persistencia;
- seletor de arquivo, cancelamento, TXT/EPUB/PDF e arquivo invalido;
- modo aviao, reconexao e fila pendente;
- login/logout/refresh/deep link com staging;
- livro grande e memoria/logcat;
- confirmacao de que release nao usa certificado debug.

## Assinatura

Use `android/key.properties.example`. O arquivo real e a keystore ficam fora do
Git. Verifique:

```bash
apksigner verify --verbose --print-certs app-release.apk
```

Um APK release nao assinado prova compilacao, mas nao atende distribuicao. O
SHA-256 do certificado de producao deve ser documentado fora do repositorio e
registrado na loja/Google quando necessario.

## Resultado local de 2026-07-13

Emulador API 36.1: instalacao debug, abertura, tela de conta local, rotacao,
force-stop/reabertura e scan de crash passaram. Seletor/importacao e auth real no
Android nao foram executados nesta rodada e permanecem checklist obrigatoria.
