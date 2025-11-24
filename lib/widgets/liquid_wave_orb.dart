import 'package:flutter/material.dart';
import 'dart:math' as math;

enum VoiceOrbState {
  idle,
  listening,
  processing,
  speaking,
}

class LiquidWaveOrb extends StatefulWidget {
  final VoiceOrbState state;
  final double size;

  const LiquidWaveOrb({
    Key? key,
    this.state = VoiceOrbState.idle,
    this.size = 200,
  }) : super(key: key);

  @override
  State<LiquidWaveOrb> createState() => _LiquidWaveOrbState();
}

class _LiquidWaveOrbState extends State<LiquidWaveOrb>
    with TickerProviderStateMixin {
  late AnimationController _flowController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    // Flow animation for the wave movement
    _flowController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    // Pulse for breathing/glow effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _updateAnimationState();
  }

  @override
  void didUpdateWidget(LiquidWaveOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimationState();
    }
  }

  void _updateAnimationState() {
    switch (widget.state) {
      case VoiceOrbState.idle:
        _flowController.duration = const Duration(seconds: 4);
        _flowController.repeat();
        break;
      case VoiceOrbState.listening:
      case VoiceOrbState.processing:
      case VoiceOrbState.speaking:
        _flowController.duration = const Duration(seconds: 3);
        _flowController.repeat();
        break;
    }
  }

  @override
  void dispose() {
    _flowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_flowController, _pulseController]),
        builder: (context, child) {
          return CustomPaint(
            painter: _CleanLiquidPainter(
              flowProgress: _flowController.value,
              pulseProgress: _pulseController.value,
              state: widget.state,
            ),
          );
        },
      ),
    );
  }
}

class _CleanLiquidPainter extends CustomPainter {
  final double flowProgress;
  final double pulseProgress;
  final VoiceOrbState state;

  _CleanLiquidPainter({
    required this.flowProgress,
    required this.pulseProgress,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Clip to circle
    canvas.save();
    final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.clipPath(clipPath);

    // 1. Fill entire circle with BLACK background
    final blackPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, blackPaint);

    // 2. Draw flowing wave with rainbow gradient
    _drawCleanWave(canvas, size, center, radius);

    canvas.restore();

    // 3. Draw outer glow and border
    _drawGlow(canvas, center, radius);
  }

  void _drawCleanWave(Canvas canvas, Size size, Offset center, double radius) {
    final path = Path();

    // Simple: Active = bigger wave, Idle = smaller wave
    final isActive = state != VoiceOrbState.idle;

    // Wave height position
    // IDLE: 45% from bottom
    // ACTIVE: 55% from bottom
    final fillPercent = isActive ? 0.55 : 0.45;
    final waveY = center.dy + (radius * (1.0 - fillPercent * 2));

    // Wave size
    final waveSize = isActive ? radius * 0.08 : radius * 0.04;

    // Start path
    path.moveTo(0, waveY);

    // Simple smooth wave - just one clean sine wave
    final points = 50;
    for (int i = 0; i <= points; i++) {
      final x = (i / points) * size.width;
      final t = i / points;

      // ONE simple sine wave
      final wave = math.sin((t * math.pi * 2.5) + (flowProgress * math.pi * 2));
      final y = waveY + (wave * waveSize);

      path.lineTo(x, y);
    }

    // Fill to bottom
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Rainbow gradient
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: _getRainbowColors(),
      stops: const [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  void _drawGlow(Canvas canvas, Offset center, double radius) {
    // Pulsing glow intensity
    final glowIntensity = 0.15 + (pulseProgress * 0.08);

    // Multi-color glow
    final glowGradient = SweepGradient(
      colors: [
        const Color(0xFF2196F3).withValues(alpha: glowIntensity),
        const Color(0xFF9C27B0).withValues(alpha: glowIntensity),
        const Color(0xFFE91E63).withValues(alpha: glowIntensity),
        const Color(0xFFFF9800).withValues(alpha: glowIntensity),
        const Color(0xFFFFEB3B).withValues(alpha: glowIntensity),
        const Color(0xFF4CAF50).withValues(alpha: glowIntensity),
        const Color(0xFF00BCD4).withValues(alpha: glowIntensity),
        const Color(0xFF2196F3).withValues(alpha: glowIntensity),
      ],
    );

    final glowPaint = Paint()
      ..shader = glowGradient.createShader(
        Rect.fromCircle(center: center, radius: radius + 20),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15;
    canvas.drawCircle(center, radius + 10, glowPaint);

    // Clean white border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);

    // Subtle top-left reflection
    final reflectionGradient = RadialGradient(
      center: const Alignment(-0.5, -0.5),
      radius: 0.5,
      colors: [
        Colors.white.withValues(alpha: 0.25),
        Colors.white.withValues(alpha: 0.08),
        Colors.white.withValues(alpha: 0.0),
      ],
    );

    final reflectionPaint = Paint()
      ..shader = reflectionGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawCircle(
      Offset(center.dx - radius * 0.3, center.dy - radius * 0.3),
      radius * 0.4,
      reflectionPaint,
    );
  }

  List<Color> _getRainbowColors() {
    final baseAlpha = (state == VoiceOrbState.idle) ? 0.85 : 0.95;
    return [
      const Color(0xFF2196F3).withValues(alpha: baseAlpha), // Blue
      const Color(0xFF9C27B0).withValues(alpha: baseAlpha), // Purple
      const Color(0xFFFF69B4).withValues(alpha: baseAlpha), // Pink
      const Color(0xFFE91E63).withValues(alpha: baseAlpha), // Magenta
      const Color(0xFFF44336).withValues(alpha: baseAlpha), // Red
      const Color(0xFFFF9800).withValues(alpha: baseAlpha), // Orange
      const Color(0xFFFFEB3B).withValues(alpha: baseAlpha), // Yellow
      const Color(0xFF4CAF50).withValues(alpha: baseAlpha), // Green
      const Color(0xFF00BCD4).withValues(alpha: baseAlpha), // Teal/Cyan
    ];
  }

  @override
  bool shouldRepaint(_CleanLiquidPainter oldDelegate) => true;
}
