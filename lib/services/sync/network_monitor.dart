// Signature: dev.tswicolly03
import 'package:connectivity_plus/connectivity_plus.dart';

abstract class NetworkMonitor {
  Future<bool> isOnline();

  Stream<bool> get changes;
}

class ConnectivityNetworkMonitor implements NetworkMonitor {
  ConnectivityNetworkMonitor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async {
    final List<ConnectivityResult> result =
        await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  @override
  Stream<bool> get changes => _connectivity.onConnectivityChanged.map(
        (List<ConnectivityResult> result) =>
            !result.contains(ConnectivityResult.none),
      );
}
