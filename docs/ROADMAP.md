<!-- Signature: dev.tswicolly03 -->
# Roadmap

## Concluido nesta base

- IndexedDB Web com migracao legada;
- interfaces e UI de auth/sync;
- Supabase schema, RLS, grants, Storage e pgTAP;
- fila offline, retry, dedupe, tombstones e conflitos;
- limites de importacao, HTML seguro e diagnostico redigido;
- CI Web/Android/Windows/Supabase/Playwright;
- rota PWA canonica `/veredra/` com redirect permanente da variante maiuscula.

## Proxima entrega - beta controlada

- validar Supabase hospedado e SMTP;
- rodar E2E real de cadastro, confirmacao, recovery e duas sessoes;
- criar keystore/upload key e instalador Windows com `veredra://`;
- terminar checklist manual de todos os formatos/backup;
- preview Cloudflare, smoke test e aprovacao dos PRs;
- publicar privacidade e suporte.

## Depois da beta

- concluir e validar Google OAuth antes de habilitar `ENABLE_GOOGLE_AUTH`;
- upload completo opt-in com quota/checksum/resume/delete;
- PDF e backup Web;
- Drift/SQLite/OPFS conforme evidencias de escala;
- painel de diagnostico e telemetria estritamente opt-in;
- dependencias major, SBOM, fuzz de importadores e teste de carga;
- Linux, macOS e iOS.

## Fora de escopo imediato

CQRS amplo, reescrita visual total e refatoracao cosmetica. Priorizar perda de
dados, isolamento, recuperacao, observabilidade e experiencia offline.
