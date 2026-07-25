// Signature: dev.tswicolly03
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../storage/app_storage.dart';

class DeviceIdentityService {
  DeviceIdentityService({AppStorage? storage, Uuid? uuid})
      : _storage = storage ?? createAppStorage(),
        _uuid = uuid ?? const Uuid();

  static const String _deviceIdKey = 'device/device_id.txt';
  final AppStorage _storage;
  final Uuid _uuid;

  Future<String> loadOrCreateId() async {
    final String? existing = await _storage.readString(_deviceIdKey);
    if (existing != null && Uuid.isValidUUID(fromString: existing)) {
      return existing;
    }
    final String created = _uuid.v4();
    await _storage.writeString(_deviceIdKey, created);
    return created;
  }

  String get platformLabel => defaultTargetPlatform.name;
}
