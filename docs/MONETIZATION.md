<!-- Signature: dev.tswicolly03 -->
# Monetizacao do Veredra — temas e expansoes opcionais

Estado em 21/11/2026: **proposta e vitrine de temas premium, sem pagamentos**.
Nao existe checkout, assinatura, liberacao real de tema nem cobranca. Os cinco
fundos ja disponiveis (parchment, sepia, mist, graphite, forest)
continuam integralmente gratuitos. Fonte, tamanho, margens, alinhamento,
leitura offline, biblioteca e recursos gratuitos existentes nao sao removidos.

## Primeira entrega: vitrine de temas

- Configuracoes de leitura exibem cinco temas gratuitos selecionaveis.
- Quatro cartoes demonstrativos (Aurora, Oceano, Cerejeira e Ametista)
  exibem cores, cadeado e aviso **Em breve**.
- Toque mostra uma explicacao honesta. Nao ha preco, checkout ou promessa de
  liberacao. Os previews nao fazem parte de ReaderPreferences e nao sao
  aceitos pela serializacao legada, evitando ativacao indevida.
- As preferencias atuais continuam salvas e sincronizadas com os mesmos IDs.

## Modelo de negocio em avaliacao (nao aprovado)

| Camada | Experiencia | Monetizacao proposta |
| --- | --- | --- |
| Gratuito | Leitura e biblioteca existentes, offline, fontes, cinco fundos atuais | Sempre gratis |
| Pacote de temas | Temas exclusivos e editor de paletas (a construir) | Compra unica, faixa a testar R$ 9,90–19,90 |
| Veredra Pro futuro | Servicos com custo operacional comprovado: armazenamento adicional voluntario, traducao em nuvem ou TTS hospedado | Assinatura opcional; preco ainda nao definido |

Hipoteses iniciais a validar: pacote vitalicio simples pode converter melhor que
assinatura para cosmeticos; funcionalidades recorrentes com custo de infraestrutura
podem justificar Pro, mas nao retirar direitos atuais de usuarios gratuitos.
Nao exibir valores antes de existir produto configurado e politica de reembolso.

## Requisitos para habilitar compras reais

1. Definir SKU unico por pacote, catalogo/versionamento e precos por mercado.
2. iOS distribuido pela App Store: avaliar StoreKit/IAP e regras aplicaveis de
   compras digitais; Android Google Play: Google Play Billing. Web: checkout
   hospedado (provedor a decidir). As regras variam por pais/regiao.
3. Backend verificar recibos e webhooks com idempotencia; registrar compras e
   direitos de acesso vinculados ao auth.uid() e permitir restauracao de compras.
   **Nunca** considerar bool local, flag no cliente ou perfil sincronizado como
   autorizacao financeira.
4. Liberar temas comprados em Windows, iOS, Android e Web com a mesma conta,
   observando politicas de venda de cada loja; permitir acesso temporariamente
   offline a direitos previamente verificados, com politica de expiracao.
5. Separar dados de direitos de acesso das preferencias sincronizadas. Validar
   fallback para o tema gratuito se entitlement for revogado, sem perder
   historico de leitura ou alterar bibliotecas. Testar versoes antigas.
6. Adicionar E2E em sandbox para compra, restauracao, reembolso, chargeback,
   troca de conta, modo offline, multiplos dispositivos e fraude simples.
7. So abrir venda publica apos privacidade, termos, suporte, contabilidade e
   verificacao das politicas vigentes das lojas.

## Criterios de aceite desta etapa

- Cinco temas legados continuam selecionaveis, seus IDs nao mudaram.
- Temas premium aparecem apenas como demonstracao e nao podem ser ativados
  por toque nem via campo backgroundPreset do modelo atual.
- Nenhuma dependencia de SDK de pagamento, endpoint financeiro, banco ou
  migration foi adicionada. Nao ha cobranca nem paywall de recursos existentes.
- Flutter analyze e testes de tema devem aprovar antes de merge.

Referencias para etapa futura: https://developer.apple.com/app-store/review/guidelines/ ,
https://support.google.com/googleplay/android-developer/answer/9858738 ,
https://pub.dev/packages/in_app_purchase .
