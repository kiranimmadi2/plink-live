import 'package:flutter/material.dart';
import 'dart:ui' as ui;

enum VoiceOrbState {
  idle,
  listening,
  processing,
  speaking,
}

class SimpleVoiceOrb extends StatefulWidget {
  final VoiceOrbState state;
  final double size;

  const SimpleVoiceOrb({
    super.key,
    this.state = VoiceOrbState.idle,
    this.size = 200,
  });

  @override
  State<SimpleVoiceOrb> createState() => _SimpleVoiceOrbState();
}

class _SimpleVoiceOrbState extends State<SimpleVoiceOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Simple pulse/breathing animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _getGradient(),
              boxShadow: [
                BoxShadow(
                  color: _getGlowColor().withValues(alpha: 0.6),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: _getGlowColor().withValues(alpha: 0.3),
                  blurRadius: 80,
                  spreadRadius: 20,
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Gradient _getGradient() {
    switch (widget.state) {
      case VoiceOrbState.idle:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8B5CF6), // Purple
            Color(0xFF06B6D4), // Cyan
          ],
        );
      case VoiceOrbState.listening:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0EA5E9), // Blue
            Color(0xFF8B5CF6), // Purple
            Color(0xFF06B6D4), // Cyan
          ],
        );
      case VoiceOrbState.processing:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFAA00), // Orange
            Color(0xFFFF6B6B), // Red
            Color(0xFF8B5CF6), // Purple
          ],
        );
      case VoiceOrbState.speaking:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF10B981), // Green
            Color(0xFF06B6D4), // Cyan
          ],
        );
    }
  }

  Color _getGlowColor() {
    switch (widget.state) {
      case VoiceOrbState.idle:
        return const Color(0xFF8B5CF6);
      case VoiceOrbState.listening:
        return const Color(0xFF0EA5E9);
      case VoiceOrbState.processing:
        return const Color(0xFFFFAA00);
      case VoiceOrbState.speaking:
        return const Color(0xFF10B981);
    }
  }
}
