// Signature: dev.tswicolly03
import 'package:flutter/material.dart';

class AppWatermarkOverlay extends StatelessWidget {
  const AppWatermarkOverlay({
    super.key,
    this.brand = 'Veredra',
    this.signature = 'dev.tswicolly03',
  });

  final String brand;
  final String signature;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark
        ? const Color.fromRGBO(236, 217, 183, 0.20)
        : const Color.fromRGBO(67, 47, 22, 0.18);
    final Color backgroundColor = isDark
        ? const Color.fromRGBO(16, 19, 21, 0.18)
        : const Color.fromRGBO(244, 239, 231, 0.16);

    return IgnorePointer(
      child: SelectionContainer.disabled(
        child: ExcludeSemantics(
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 18, bottom: 14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: textColor.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      '$brand | $signature',
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.7,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
