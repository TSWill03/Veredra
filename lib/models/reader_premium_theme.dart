// Signature: dev.tswicolly03
import 'package:flutter/material.dart';

/// Catalogo visual dos futuros temas pagos.
///
/// Estes itens nao sao preferencias persistiveis nem liberacoes de compra.
/// A leitura continua usando exclusivamente ReaderBackgroundPreset ate a
/// integracao de pagamentos e direitos de acesso verificados no servidor.
@immutable
class ReaderPremiumTheme {
  const ReaderPremiumTheme({
    required this.id,
    required this.label,
    required this.description,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.textColor,
  });

  final String id;
  final String label;
  final String description;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color textColor;

  static const List<ReaderPremiumTheme> previews = <ReaderPremiumTheme>[
    ReaderPremiumTheme(
      id: 'aurora',
      label: 'Aurora',
      description: 'Verde e violeta suaves',
      backgroundColor: Color(0xFF172731),
      surfaceColor: Color(0xFF25443E),
      textColor: Color(0xFFE8E6FA),
    ),
    ReaderPremiumTheme(
      id: 'ocean',
      label: 'Oceano',
      description: 'Azul profundo',
      backgroundColor: Color(0xFF0B1B33),
      surfaceColor: Color(0xFF15365A),
      textColor: Color(0xFFE5F0FF),
    ),
    ReaderPremiumTheme(
      id: 'cherry',
      label: 'Cerejeira',
      description: 'Rosa e papel delicado',
      backgroundColor: Color(0xFFF6E7E8),
      surfaceColor: Color(0xFFFFF5F3),
      textColor: Color(0xFF4A2F39),
    ),
    ReaderPremiumTheme(
      id: 'amethyst',
      label: 'Ametista',
      description: 'Roxo noturno',
      backgroundColor: Color(0xFF1D1935),
      surfaceColor: Color(0xFF322951),
      textColor: Color(0xFFF1ECFF),
    ),
  ];
}
