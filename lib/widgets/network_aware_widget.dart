// lib/widgets/network_aware_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../utils/constants.dart';

/// A widget that shows network status and contains network-dependent content
class NetworkAwareWidget extends StatefulWidget {
  final Widget child;
  final Widget? offlineWidget;
  final ConnectivityService connectivityService;
  final bool showIndicator;

  const NetworkAwareWidget({
    Key? key,
    required this.child,
    this.offlineWidget,
    required this.connectivityService,
    this.showIndicator = true,
  }) : super(key: key);

  @override
  State<NetworkAwareWidget> createState() => _NetworkAwareWidgetState();
}

class _NetworkAwareWidgetState extends State<NetworkAwareWidget> {
  late StreamSubscription<bool> _connectionSubscription;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _isConnected = widget.connectivityService.isConnected;
    _connectionSubscription = widget.connectivityService.connectionStatus
        .listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _connectionSubscription.cancel();
    super.dispose();
  }

  void _updateConnectionStatus(bool connected) {
    if (mounted) {
      setState(() {
        _isConnected = connected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Network status indicator
        if (widget.showIndicator)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isConnected ? 0 : 36,
            width: double.infinity,
            color: _isConnected ? Colors.transparent : OseerColors.warning,
            child: _isConnected
                ? const SizedBox.shrink()
                : Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.signal_wifi_off,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'No internet connection. Some features may be limited.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                  ),
          ),

        // Main content
        Expanded(
          child: _isConnected
              ? widget.child
              : widget.offlineWidget ?? _buildDefaultOfflineWidget(),
        ),
      ],
    );
  }

  Widget _buildDefaultOfflineWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'You are offline',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your internet connection',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            onPressed: () async {
              // Manually check connectivity
              final isConnected =
                  await widget.connectivityService.checkConnectivity();
              if (mounted) {
                setState(() {
                  _isConnected = isConnected;
                });
              }
            },
          ),
        ],
      ),
    );
  }
}

/// A simpler version of NetworkAwareWidget that only shows an indicator
/// and doesn't replace content when offline
class NetworkStatusIndicator extends StatefulWidget {
  final ConnectivityService connectivityService;

  const NetworkStatusIndicator({
    Key? key,
    required this.connectivityService,
  }) : super(key: key);

  @override
  State<NetworkStatusIndicator> createState() => _NetworkStatusIndicatorState();
}

class _NetworkStatusIndicatorState extends State<NetworkStatusIndicator> {
  late StreamSubscription<bool> _connectionSubscription;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _isConnected = widget.connectivityService.isConnected;
    _connectionSubscription = widget.connectivityService.connectionStatus
        .listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _connectionSubscription.cancel();
    super.dispose();
  }

  void _updateConnectionStatus(bool connected) {
    if (mounted) {
      setState(() {
        _isConnected = connected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isConnected ? 0 : 36,
      width: double.infinity,
      color: _isConnected ? Colors.transparent : OseerColors.warning,
      child: _isConnected
          ? const SizedBox.shrink()
          : Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.signal_wifi_off,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'No internet connection. Some features may be limited.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
    );
  }
}
