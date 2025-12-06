import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:supper/main.dart';
import 'dart:async';
import 'package:supper/services/video_preload_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final VideoPreloadService _videoService = VideoPreloadService();

  @override
  void initState() {
    super.initState();

    // Animation controller for floating & rotation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Setup video background - same pattern as onboarding
    if (_videoService.isReady) {
      _videoService.resume();
    } else {
      _videoService.addOnReadyCallback(_onVideoReady);
    }

    // Start video preload and wait for it before navigating
    _initializeAndNavigate();
  }

  void _onVideoReady() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initializeAndNavigate() async {
    // Start video preload immediately
    final videoFuture = _videoService.preload();

    // Wait for minimum splash time (3 seconds) AND video to be ready
    await Future.wait([
      videoFuture,
      Future.delayed(const Duration(seconds: 3)),
    ]);

    // Navigate only after video is ready
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    }
  }

  @override
  void dispose() {
    _videoService.removeOnReadyCallback(_onVideoReady);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      body: Stack(
        children: [
          // Gradient Background - always visible immediately
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1a1a2e),
                    Color(0xFF16213e),
                    Color(0xFF0f0f23),
                  ],
                ),
              ),
            ),
          ),

          // Video Background - layered on top when ready
          if (_videoService.isReady && _videoService.controller != null)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoService.controller!.value.size.width,
                  height: _videoService.controller!.value.size.height,
                  child: VideoPlayer(_videoService.controller!),
                ),
              ),
            ),

          // Dark overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),

          // Background circular elements with glassmorphism
          CustomPaint(
            size: screenSize,
            painter: _BackgroundPatternPainter(color: Colors.white),
          ),

          // Centered Logo with glassmorphism - truly centered
          Positioned.fill(
            child: Center(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final value = _animationController.value;
                  final scale = 1.0 + (value * 0.1);
                  final rotationY = value * 0.5;

                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..scale(scale)
                      ..rotateY(rotationY),
                    child: child,
                  );
                },
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: screenSize.height * 0.28,
                      height: screenSize.height * 0.28,
                      constraints: const BoxConstraints(
                        maxWidth: 280,
                        maxHeight: 280,
                        minWidth: 180,
                        minHeight: 180,
                      ),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3),
                            blurRadius: 40,
                            spreadRadius: 5,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/logo/Clogo.jpeg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Splash text with glassmorphism container
          Positioned(
            bottom: screenSize.height * 0.18,
            left: 24,
            right: 24,
            child: FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(
                CurvedAnimation(
                  parent: _animationController,
                  curve: Curves.easeIn,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Welcome to Supper',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenSize.height < 700 ? 22 : 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your campus marketplace',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Loading indicator
          Positioned(
            bottom: screenSize.height * 0.08,
            left: 0,
            right: 0,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Background pattern painter
class _BackgroundPatternPainter extends CustomPainter {
  final Color color;
  _BackgroundPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    // Big circles with reduced opacity for video background
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.4), 150, paint);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.6), 200, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.8), 120, paint);

    // Add border circles
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.2), 80, borderPaint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.3), 60, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
