import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supper/screens/login/onboarding_screen.dart';
import 'package:supper/screens/main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    // Animation controller for floating & rotation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    Timer(const Duration(seconds: 3), () {
      // Check if user is already logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // User is logged in, go to main screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        );
      } else {
        // User not logged in, show onboarding
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 99, 99, 100),
                  Color.fromARGB(255, 42, 31, 44),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Background circular elements
          CustomPaint(
            size: screenSize,
            painter: _BackgroundPatternPainter(color: Colors.white),
          ),

          Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final value = _animationController.value;
                final scale = 1.0 + (value * 0.1);
                final rotationY = value * 0.5;

                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scale(scale) // ignore: deprecated_member_use
                    ..rotateY(rotationY),
                  child: child,
                );
              },
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.5),
                      blurRadius: 30,
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

          // Splash text
          Positioned(
            bottom: 200,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(
                CurvedAnimation(
                  parent: _animationController,
                  curve: Curves.easeIn,
                ),
              ),
              child: const Text(
                'Welcome to Supper',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
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
      ..color = color.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    // Big circles
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.4), 150, paint);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.6), 200, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.8), 120, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
