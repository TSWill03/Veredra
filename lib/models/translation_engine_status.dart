import 'translation_pair.dart';

class TranslationEngineStatus {
  const TranslationEngineStatus({
    required this.supported,
    required this.pythonDetected,
    required this.argosInstalled,
    required this.onlineIndexAvailable,
    required this.pythonCommandLabel,
    required this.pythonVersion,
    required this.installedPairs,
    required this.availablePairs,
    required this.message,
  });

  final bool supported;
  final bool pythonDetected;
  final bool argosInstalled;
  final bool onlineIndexAvailable;
  final String? pythonCommandLabel;
  final String? pythonVersion;
  final List<TranslationPair> installedPairs;
  final List<TranslationPair> availablePairs;
  final String? message;

  bool get canInstallArgos => supported && pythonDetected;
  bool get isReady => supported && pythonDetected && argosInstalled;
  bool get hasPairs => installedPairs.isNotEmpty || availablePairs.isNotEmpty;

  factory TranslationEngineStatus.fromJson(Map<String, dynamic> json) {
    return TranslationEngineStatus(
      supported: json['supported'] as bool? ?? false,
      pythonDetected: json['pythonDetected'] as bool? ?? false,
      argosInstalled: json['argosInstalled'] as bool? ?? false,
      onlineIndexAvailable: json['onlineIndexAvailable'] as bool? ?? false,
      pythonCommandLabel: json['pythonCommandLabel'] as String?,
      pythonVersion: json['pythonVersion'] as String?,
      installedPairs:
          (json['installedPairs'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(TranslationPair.fromJson)
              .toList(growable: false),
      availablePairs:
          (json['availablePairs'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(TranslationPair.fromJson)
              .toList(growable: false),
      message: json['message'] as String?,
    );
  }
}
