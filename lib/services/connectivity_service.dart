// lib/services/connectivity_service.dart
import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/logger_service.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  // Keep track of the last known status
  bool _isConnected = true;
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  // Cache for successful DNS lookups to avoid constant checks
  final Map<String, DateTime> _successfulDnsLookups = {};
  static const Duration _dnsCacheDuration = Duration(minutes: 1);

  Future<void> initialize() async {
    // Check initial connectivity
    _isConnected = await checkConnectivity();
    _connectionStatusController.add(_isConnected);

    // Use onConnectivityChanged.listen for modern versions
    _connectivitySubscription = _connectivity.onConnectivityChanged
        .listen((ConnectivityResult result) async {
      final newStatus = await checkConnectivity();
      if (_isConnected != newStatus) {
        _isConnected = newStatus;
        _connectionStatusController.add(_isConnected);
        OseerLogger.info(
            'Network connectivity changed: ${_isConnected ? 'Connected' : 'Disconnected'}');
      }
    });
  }

  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  bool get isConnected => _isConnected;

  Future<bool> checkConnectivity() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }
    // Check if we can actually resolve a known host
    return await canReachHost('8.8.8.8');
  }

  /// **CRITICAL FIX: More robust host resolution check with caching.**
  Future<bool> canReachHost(String host,
      {Duration timeout = const Duration(seconds: 5)}) async {
    final lastSuccess = _successfulDnsLookups[host];
    if (lastSuccess != null &&
        DateTime.now().difference(lastSuccess) < _dnsCacheDuration) {
      OseerLogger.debug('Using cached DNS result for $host');
      return true;
    }

    try {
      final result = await InternetAddress.lookup(host).timeout(timeout);
      final success = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (success) {
        _successfulDnsLookups[host] = DateTime.now();
        OseerLogger.debug('Successfully resolved host: $host');
      }
      return success;
    } on SocketException catch (e) {
      OseerLogger.error('Failed host lookup for $host', e);
      return false;
    } catch (e) {
      OseerLogger.warning('Error checking host reachability for $host', e);
      return false;
    }
  }

  void dispose() {
    _connectivitySubscription.cancel();
    _connectionStatusController.close();
  }
}
