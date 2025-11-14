import 'dart:io';

class NetworkUtils {
  static Future<bool> hasNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
  
  static Future<T?> performNetworkOperation<T>({
    required Future<T> Function() operation,
    required String operationName,
    T? Function()? fallback,
    void Function()? onNoConnection,
  }) async {
    final hasConnection = await hasNetworkConnection();
    
    if (!hasConnection) {
      print('⚠️ No network connection for: $operationName');
      onNoConnection?.call();
      return fallback?.call();
    }
    
    try {
      return await operation();
    } on SocketException catch (e) {
      print('Network error during $operationName: $e');
      return fallback?.call();
    }
  }
  
  static Stream<bool> watchConnectivity({Duration interval = const Duration(seconds: 30)}) {
    return Stream.periodic(interval, (_) => hasNetworkConnection())
        .asyncMap((future) => future);
  }
}