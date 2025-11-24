import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

class AuroraBackground extends StatefulWidget {
  final Widget child;

  const AuroraBackground({Key? key, required this.child}) : super(key: key);

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _colorController;
  late AnimationController _flowController;

  @override
  void initState() {
    super.initState();

    // Main wave movement - slower for elegant feel
    _waveController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    // Color shifting
    _colorController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();

    // Flow/streak movement
    _flowController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _colorController.dispose();
    _flowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Base gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDarkMode
                  ? [
                      const Color(0xFF0F0F1E),
                      const Color(0xFF1A1A2E),
                      const Color(0xFF16213E),
                    ]
                  : [
                      const Color(0xFFF0F4FF),
                      const Color(0xFFE8F0FF),
                      const Color(0xFFD6E8FF),
                    ],
            ),
          ),
        ),
        // Aurora effect
        AnimatedBuilder(
          animation: Listenable.merge([
            _waveController,
            _colorController,
            _flowController,
          ]),
          builder: (context, child) {
            return CustomPaint(
              painter: _AuroraPainter(
                waveProgress: _waveController.value,
                colorProgress: _colorController.value,
                flowProgress: _flowController.value,
                isDarkMode: isDarkMode,
              ),
              size: Size.infinite,
            );
          },
        ),
        // Content
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double waveProgress;
  final double colorProgress;
  final double flowProgress;
  final bool isDarkMode;

  _AuroraPainter({
    required this.waveProgress,
    required this.colorProgress,
    required this.flowProgress,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Aurora colors that shift over time
    final colors = _getAuroraColors();

    // Draw multiple layers of aurora waves
    _drawAuroraWave(canvas, size, colors[0], 0.0, 0.25);
    _drawAuroraWave(canvas, size, colors[1], 0.33, 0.20);
    _drawAuroraWave(canvas, size, colors[2], 0.66, 0.22);

    // Add flowing light streaks
    _drawLightStreaks(canvas, size, colors);
  }

  List<Color> _getAuroraColors() {
    if (isDarkMode) {
      // Night aurora - more vibrant
      return [
        Color.lerp(
          const Color(0xFF0EA5E9).withValues(alpha: 0.15),
          const Color(0xFF8B5CF6).withValues(alpha: 0.18),
          math.sin(colorProgress * math.pi * 2) * 0.5 + 0.5,
        )!,
        Color.lerp(
          const Color(0xFF06B6D4).withValues(alpha: 0.12),
          const Color(0xFF10B981).withValues(alpha: 0.15),
          math.cos(colorProgress * math.pi * 2) * 0.5 + 0.5,
        )!,
        Color.lerp(
          const Color(0xFF8B5CF6).withValues(alpha: 0.10),
          const Color(0xFF0EA5E9).withValues(alpha: 0.14),
          math.sin(colorProgress * math.pi * 2 + 1) * 0.5 + 0.5,
        )!,
      ];
    } else {
      // Day aurora - more subtle
      return [
        Color.lerp(
          const Color(0xFF0EA5E9).withValues(alpha: 0.08),
          const Color(0xFF8B5CF6).withValues(alpha: 0.10),
          math.sin(colorProgress * math.pi * 2) * 0.5 + 0.5,
        )!,
        Color.lerp(
          const Color(0xFF06B6D4).withValues(alpha: 0.06),
          const Color(0xFF10B981).withValues(alpha: 0.08),
          math.cos(colorProgress * math.pi * 2) * 0.5 + 0.5,
        )!,
        Color.lerp(
          const Color(0xFF8B5CF6).withValues(alpha: 0.05),
          const Color(0xFF0EA5E9).withValues(alpha: 0.07),
          math.sin(colorProgress * math.pi * 2 + 1) * 0.5 + 0.5,
        )!,
      ];
    }
  }

  void _drawAuroraWave(
    Canvas canvas,
    Size size,
    Color color,
    double offset,
    double intensity,
  ) {
    final path = Path();
    final waveOffset = (waveProgress + offset) % 1.0;

    // Start from top left
    path.moveTo(0, size.height * 0.3);

    // Create flowing wave using sine curves
    for (double x = 0; x <= size.width; x += 5) {
      final normalizedX = x / size.width;

      // Multiple sine waves for complex aurora movement
      final y1 = math.sin((normalizedX + waveOffset) * math.pi * 2) * 60;
      final y2 = math.sin((normalizedX + waveOffset * 0.5) * math.pi * 3) * 30;
      final y3 = math.cos((normalizedX - waveOffset) * math.pi * 1.5) * 45;

      final yPosition = size.height * (0.3 + normalizedX * 0.4) + y1 + y2 + y3;

      path.lineTo(x, yPosition);
    }

    // Complete the path
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Create gradient for the wave
    final gradient = ui.Gradient.linear(
      Offset(0, size.height * 0.2),
      Offset(size.width, size.height * 0.8),
      [
        color.withValues(alpha: color.a * intensity * 1.5),
        color.withValues(alpha: color.a * intensity * 0.8),
        color.withValues(alpha: color.a * intensity * 0.3),
        Colors.transparent,
      ],
      [0.0, 0.3, 0.7, 1.0],
    );

    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

    canvas.drawPath(path, paint);
  }

  void _drawLightStreaks(Canvas canvas, Size size, List<Color> colors) {
    // Draw 5 flowing light streaks
    for (int i = 0; i < 5; i++) {
      final streakProgress = (flowProgress + i * 0.2) % 1.0;
      final startX = size.width * ((i * 0.2 + streakProgress) % 1.0);
      final startY = size.height * 0.2 + math.sin(streakProgress * math.pi) * 100;

      final endX = startX + 150 + math.cos(streakProgress * math.pi) * 50;
      final endY = startY + 200;

      final gradient = ui.Gradient.linear(
        Offset(startX, startY),
        Offset(endX, endY),
        [
          Colors.transparent,
          colors[i % colors.length].withValues(alpha: colors[i % colors.length].a * 0.4),
          colors[i % colors.length].withValues(alpha: colors[i % colors.length].a * 0.6),
          colors[i % colors.length].withValues(alpha: colors[i % colors.length].a * 0.3),
          Colors.transparent,
        ],
        [0.0, 0.2, 0.5, 0.8, 1.0],
      );

      final paint = Paint()
        ..shader = gradient
        ..strokeWidth = 3 + math.sin(streakProgress * math.pi) * 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => true;
}
