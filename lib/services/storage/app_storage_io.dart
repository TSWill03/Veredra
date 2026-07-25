// Signature: dev.tswicolly03
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_storage_base.dart';

AppStorage createAppStorage() => IoAppStorage();

class IoAppStorage implements AppStorage {
  @override
  Future<String?> readString(String key) async {
    final File file = await _fileForKey(key);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  @override
  Future<void> writeString(String key, String value) async {
    final File file = await _fileForKey(key);
    await _writeAtomically(file, (File tempFile) {
      return tempFile.writeAsString(value, flush: true);
    });
  }

  @override
  Future<Uint8List?> readBytes(String key) async {
    final File file = await _fileForKey(key);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  @override
  Future<void> writeBytes(String key, List<int> value) async {
    final File file = await _fileForKey(key);
    await _writeAtomically(file, (File tempFile) {
      return tempFile.writeAsBytes(value, flush: true);
    });
  }

  @override
  Future<bool> exists(String key) async {
    final File file = await _fileForKey(key);
    return file.exists();
  }

  @override
  Future<void> delete(String key) async {
    final File file = await _fileForKey(key);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> deletePrefix(String keyPrefix) async {
    final Directory directory = await _directoryForKey(keyPrefix);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<File> _fileForKey(String key) async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final List<String> segments = normalizeStorageKey(key).split('/');
    return File(p.joinAll(<String>[documentsDirectory.path, ...segments]));
  }

  Future<Directory> _directoryForKey(String key) async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final List<String> segments = normalizeStorageKey(key).split('/');
    return Directory(p.joinAll(<String>[documentsDirectory.path, ...segments]));
  }

  Future<void> _writeAtomically(
    File file,
    Future<File> Function(File tempFile) writeTempFile,
  ) async {
    await file.parent.create(recursive: true);
    final File tempFile = File(
      '${file.path}.tmp.${DateTime.now().microsecondsSinceEpoch}',
    );
    await writeTempFile(tempFile);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }
}
