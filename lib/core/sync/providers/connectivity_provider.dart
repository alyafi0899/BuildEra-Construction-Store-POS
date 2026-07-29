import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityStatus { online, offline }

final connectivityProvider = StreamProvider<ConnectivityStatus>((ref) {
  return Connectivity().onConnectivityChanged.map((result) {
    // connectivity_plus 6.x returns a List<ConnectivityResult>
    if (result.contains(ConnectivityResult.none)) {
      return ConnectivityStatus.offline;
    }
    return ConnectivityStatus.online;
  });
});

final isOnlineProvider = Provider<bool>((ref) {
  final asyncStatus = ref.watch(connectivityProvider);
  return asyncStatus.maybeWhen(
    data: (status) => status == ConnectivityStatus.online,
    orElse: () => true, // Assume online until connectivity_plus says otherwise
  );
});
