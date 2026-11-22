import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../config/app_config.dart';

Future<Directory> getVeredraDocumentsDirectory() async {
  final root = AppConfig.qaDataRoot;
  if (root.isEmpty) return getApplicationDocumentsDirectory();
  if (!p.isAbsolute(root) || p.dirname(root) == root) {
    throw StateError(
        'VEREDRA_QA_DATA_ROOT must be a dedicated absolute directory.');
  }
  return Directory(root).create(recursive: true);
}
