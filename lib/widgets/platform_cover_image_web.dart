// Signature: dev.tswicolly03
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../services/storage/app_storage.dart';

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

  static const String _webStoredPrefix = 'veredra://';

  final String coverPath;
  final double width;
  final double height;
  final BoxFit fit;
  final Alignment alignment;
  final WidgetBuilder placeholderBuilder;

  @override
  Widget build(BuildContext context) {
    if (!coverPath.startsWith(_webStoredPrefix)) {
      return placeholderBuilder(context);
    }

    final AppStorage storage = createAppStorage();
    final String key =
        normalizeStorageKey(coverPath.replaceFirst(_webStoredPrefix, ''));
    return FutureBuilder<Uint8List?>(
      future: storage.readBytes(key),
      builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
        final Uint8List? bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return placeholderBuilder(context);
        }

        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          errorBuilder: (_, __, ___) => placeholderBuilder(context),
        );
      },
    );
  }
}
