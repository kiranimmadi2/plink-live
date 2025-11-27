import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supper/screens/home/home_screen.dart';
import 'package:supper/screens/login/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to Supper',
      subtitle:
          'Your ultimate campus marketplace for buying, selling, and connecting with students',
      imagePath: 'assets/logo/Clogo.jpeg',
      color: const Color.fromARGB(255, 208, 231, 250),
      gradient: [
        const Color.fromARGB(255, 208, 231, 250),
        const Color.fromARGB(255, 61, 47, 63),
      ],
    ),
    OnboardingPage(
      title: 'Find Anything',
      subtitle:
          'From textbooks to bikes, rooms to part-time jobs - everything you need on campus',
      imagePath: 'assets/logo/searchRequirementData.jpeg',
      color: const Color.fromARGB(255, 166, 243, 169),
      gradient: [
        const Color.fromARGB(255, 166, 243, 169),
        const Color.fromARGB(255, 35, 51, 49),
      ],
    ),
    OnboardingPage(
      title: 'Connect Instantly',
      subtitle:
          'Chat with verified students and make secure transactions in real-time',
      imagePath: 'assets/logo/searchannaunceData.jpeg',
      color: const Color.fromARGB(255, 235, 200, 152),
      gradient: [
        const Color.fromARGB(255, 235, 200, 152),
        const Color.fromARGB(255, 77, 58, 57),
      ],
    ),
    OnboardingPage(
      title: 'Get Started',
      subtitle: 'Join thousands of students already using Supper every day',
      imagePath: 'assets/logo/searchData.jpeg',
      color: const Color.fromARGB(255, 217, 166, 226),
      gradient: [
        const Color.fromARGB(255, 217, 166, 226),
        const Color.fromARGB(255, 44, 32, 36),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.8);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _getStarted() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 65, 63, 63),
        body: SafeArea(
          child: Column(
            children: [
              // Skip button
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Supper',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_currentPage < 3)
                      TextButton(
                        onPressed: _getStarted,
                        child: const Text(
                          'Skip',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      ),
                  ],
                ),
              ),

              // 3D Page View
              Expanded(
                flex: 2,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _build3DPage(_pages[index], index);
                  },
                ),
              ),

              // Indicators
              _buildPageIndicators(),

              // Content
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      const Spacer(),
                      Text(
                        _pages[_currentPage].title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _pages[_currentPage].subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                      const Spacer(),

                      // Next/Get Started Button
                      if (_currentPage == 3)
                        _buildGetStartedButton()
                      else
                        _buildNextButton(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build3DPage(OnboardingPage page, int index) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double pageOffset = 0;
        if (_pageController.position.haveDimensions) {
          pageOffset = _pageController.page! - index;
        }

        double scale = (1 - (pageOffset.abs() * 0.3)).clamp(0.8, 1.0);
        double rotation = pageOffset * 0.5;
        double opacity = (1 - pageOffset.abs()).clamp(0.5, 1.0);

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..scale(scale) // ignore: deprecated_member_use
            ..rotateY(rotation),
          child: Opacity(opacity: opacity, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(color: const Color.fromARGB(255, 231, 215, 215)),
          borderRadius: BorderRadius.circular(9),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: page.gradient,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BackgroundPatternPainter(color: page.color),
              ),
            ),

            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _build3DImage(page.imagePath, page.color),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build3DImage(String imagePath, Color color) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final value = _animationController.value;
        final scale = 1.0 + (value * 0.1);
        final offset = (value * 10) - 5;

        return Transform(
          transform: Matrix4.identity()
            ..scale(scale) // ignore: deprecated_member_use
            ..translate(0.0, offset, 0.0), // ignore: deprecated_member_use
          child: child,
        );
      },
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: const Color.fromARGB(255, 231, 215, 215)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 40,
              spreadRadius: 8,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glow effect
            Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.35),
                    color.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
              child: ClipOval(child: Image.asset(imagePath, fit: BoxFit.fill)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicators() {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pages.length, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: _currentPage == index ? 30 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentPage == index
                  ? _pages[index].color
                  : Colors.white24,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: const Color.fromARGB(255, 155, 149, 149),
              ),
              boxShadow: _currentPage == index
                  ? [
                      BoxShadow(
                        color: _pages[index].color.withValues(alpha: 0.5),
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNextButton() {
    return GestureDetector(
      onTap: () {
        if (_currentPage < _pages.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(color: const Color.fromARGB(255, 129, 127, 127)),
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: _pages[_currentPage].gradient),
        ),
        child: const Icon(Icons.arrow_forward, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildGetStartedButton() {
    return GestureDetector(
      onTap: _getStarted,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(color: const Color.fromARGB(255, 231, 215, 215)),
          gradient: LinearGradient(colors: _pages[3].gradient),
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Get Started',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 10),
            Icon(Icons.rocket_launch, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final String imagePath;
  final Color color;
  final List<Color> gradient;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.color,
    required this.gradient,
  });
}

class _BackgroundPatternPainter extends CustomPainter {
  final Color color;

  _BackgroundPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw grid pattern
    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Draw circles
    final circlePaint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.3),
      40,
      circlePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.7),
      60,
      circlePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.4, size.height * 0.8),
      30,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
