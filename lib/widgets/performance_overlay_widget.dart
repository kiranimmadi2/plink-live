import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class PerformanceOverlayWidget extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const PerformanceOverlayWidget({
    super.key,
    required this.child,
    this.enabled = false,
  });

  @override
  State<PerformanceOverlayWidget> createState() =>
      _PerformanceOverlayWidgetState();
}

class _PerformanceOverlayWidgetState extends State<PerformanceOverlayWidget>
    with SingleTickerProviderStateMixin {
  double _currentFPS = 60.0;
  double _minFPS = 60.0;
  double _maxFPS = 60.0;
  double _avgFPS = 60.0;

  int _frameCount = 0;
  Duration _totalFrameTime = Duration.zero;
  DateTime _lastResetTime = DateTime.now();

  final List<double> _fpsHistory = [];
  final int _maxHistoryLength = 60;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    if (widget.enabled) {
      _startMonitoring();
    }
  }

  void _startMonitoring() {
    _animationController.repeat();
    SchedulerBinding.instance.addPostFrameCallback(_afterFrame);
  }

  void _stopMonitoring() {
    _animationController.stop();
  }

  void _afterFrame(Duration timestamp) {
    if (!widget.enabled || !mounted) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastResetTime);

    _frameCount++;
    _totalFrameTime += const Duration(microseconds: 16667); // Target 60fps

    if (elapsed >= const Duration(seconds: 1)) {
      final fps = (_frameCount * 1000) / elapsed.inMilliseconds;

      setState(() {
        _currentFPS = fps;
        _fpsHistory.add(fps);

        if (_fpsHistory.length > _maxHistoryLength) {
          _fpsHistory.removeAt(0);
        }

        _updateStats();
        _frameCount = 0;
        _lastResetTime = now;
      });
    }

    SchedulerBinding.instance.addPostFrameCallback(_afterFrame);
  }

  void _updateStats() {
    if (_fpsHistory.isEmpty) return;

    _minFPS = _fpsHistory.reduce((a, b) => a < b ? a : b);
    _maxFPS = _fpsHistory.reduce((a, b) => a > b ? a : b);
    _avgFPS = _fpsHistory.reduce((a, b) => a + b) / _fpsHistory.length;
  }

  Color _getFPSColor(double fps) {
    if (fps >= 55) return Colors.green;
    if (fps >= 30) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.enabled)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.speed,
                        color: _getFPSColor(_currentFPS),
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Performance Monitor',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildMetricRow(
                    'Current',
                    _currentFPS,
                    _getFPSColor(_currentFPS),
                  ),
                  _buildMetricRow('Average', _avgFPS, _getFPSColor(_avgFPS)),
                  _buildMetricRow('Min', _minFPS, _getFPSColor(_minFPS)),
                  _buildMetricRow('Max', _maxFPS, _getFPSColor(_maxFPS)),
                  const SizedBox(height: 8),
                  _buildFPSGraph(),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMetricRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ),
          Text(
            '${value.toStringAsFixed(1)} FPS',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFPSGraph() {
    return Container(
      height: 40,
      width: 180,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(4),
      ),
      child: CustomPaint(painter: FPSGraphPainter(_fpsHistory)),
    );
  }

  @override
  void didUpdateWidget(PerformanceOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _startMonitoring();
      } else {
        _stopMonitoring();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class FPSGraphPainter extends CustomPainter {
  final List<double> fpsHistory;

  FPSGraphPainter(this.fpsHistory);

  @override
  void paint(Canvas canvas, Size size) {
    if (fpsHistory.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    const maxFPS = 60.0;
    final step = size.width / 60;

    for (int i = 0; i < fpsHistory.length; i++) {
      final x = i * step;
      final y = size.height - (fpsHistory[i] / maxFPS * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw gradient effect
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.red.withValues(alpha: 0.8),
        Colors.orange.withValues(alpha: 0.8),
        Colors.green.withValues(alpha: 0.8),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    paint.shader = gradient.createShader(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );

    canvas.drawPath(path, paint);

    // Draw 60 FPS line
    final targetLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height * 0.1),
      Offset(size.width, size.height * 0.1),
      targetLinePaint,
    );
  }

  @override
  bool shouldRepaint(FPSGraphPainter oldDelegate) {
    return true;
  }
}
