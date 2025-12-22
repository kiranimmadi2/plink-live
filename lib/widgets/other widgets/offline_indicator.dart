import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/chat services/connectivity_service.dart';

/// A widget that shows an offline indicator banner when there's no internet connection
class OfflineIndicator extends StatefulWidget {
  final Widget child;
  final bool showBanner;

  const OfflineIndicator({
    super.key,
    required this.child,
    this.showBanner = true,
  });

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator>
    with SingleTickerProviderStateMixin {
  final ConnectivityService _connectivityService = ConnectivityService();
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isOffline = false;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _isOffline = !_connectivityService.hasConnection;
    if (_isOffline) {
      _animationController.forward();
    }

    _connectivitySubscription = _connectivityService.connectionChange.listen((
      hasConnection,
    ) {
      if (mounted) {
        setState(() {
          _isOffline = !hasConnection;
        });
        if (_isOffline) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showBanner) {
      return widget.child;
    }

    return Column(
      children: [
        AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _isOffline ? 1.0 : 0.0,
                child: Transform.translate(
                  offset: Offset(0, _slideAnimation.value * 50),
                  child: child,
                ),
              ),
            );
          },
          child: _buildOfflineBanner(),
        ),
        Expanded(child: widget.child),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade700, Colors.red.shade600],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Text(
              'No Internet Connection',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () async {
                // Trigger a connectivity check
                await _connectivityService.initialize();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small dot indicator for showing connection status
class ConnectionStatusDot extends StatelessWidget {
  final bool isOnline;
  final double size;

  const ConnectionStatusDot({super.key, required this.isOnline, this.size = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? Colors.green : Colors.red,
        boxShadow: [
          BoxShadow(
            color: (isOnline ? Colors.green : Colors.red).withValues(
              alpha: 0.4,
            ),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

/// Stream-based connection status widget
class ConnectionStatusIndicator extends StatelessWidget {
  final Widget Function(bool isOnline) builder;

  const ConnectionStatusIndicator({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService().connectionChange,
      initialData: ConnectivityService().hasConnection,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        return builder(isOnline);
      },
    );
  }
}
