// Signature: dev.tswicolly03
import 'package:flutter/widgets.dart';

class PlatformCoverImage extends StatelessWidget {
  const PlatformCoverImage({
    super.key,
    required this.coverPath,
    required this.width,
    required this.height,
    required this.fit,
    required this.alignment,
    required this.placeholderBuilder,
  });

  final String coverPath;
  final double width;
  final double height;
  final BoxFit fit;
  final Alignment alignment;
  final WidgetBuilder placeholderBuilder;

  @override
  Widget build(BuildContext context) => placeholderBuilder(context);
}
