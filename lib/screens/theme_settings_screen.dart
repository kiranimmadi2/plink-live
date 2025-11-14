import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/glassmorphic_container.dart';

class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F7),
      body: Stack(
        children: [
          // Animated gradient background
          if (themeProvider.isGlassmorphism)
            AnimatedContainer(
              duration: const Duration(seconds: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ThemeProvider.glassmorphismBackground[0],
                    ThemeProvider.glassmorphismBackground[1],
                    ThemeProvider.glassmorphismBackground[2],
                    ThemeProvider.glassmorphismBackground[3],
                  ],
                  stops: const [0.0, 0.3, 0.6, 1.0],
                ),
              ),
              child: CustomPaint(
                painter: _BackgroundPainter(),
              ),
            ),
          
          SafeArea(
            child: Column(
              children: [
                // Custom App Bar with glassmorphic effect
                GlassmorphicContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.all(16),
                  borderRadius: 20,
                  blur: 20,
                  opacity: isDark ? 0.1 : 0.05,
                  color: isDark ? Colors.white : Colors.white,
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          CupertinoIcons.back,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Theme Settings',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        themeProvider.isGlassmorphism 
                            ? CupertinoIcons.sparkles 
                            : CupertinoIcons.moon_fill,
                        color: ThemeProvider.iosPurple,
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          const SizedBox(height: 20),
                          
                          // Theme Preview Cards
                          Center(
                            child: Text(
                              'Choose Your Theme',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Glassmorphism Theme Card
                          _buildThemeCard(
                            context,
                            title: 'iOS 16 Glassmorphism',
                            subtitle: 'Premium glass effect with depth',
                            icon: CupertinoIcons.sparkles,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFE3F2FD),
                                Color(0xFFF3E5F5),
                              ],
                            ),
                            isSelected: themeProvider.isGlassmorphism,
                            onTap: () {
                              themeProvider.setTheme(AppThemeMode.glassmorphism);
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Dark Theme Card
                          _buildThemeCard(
                            context,
                            title: 'Dark Mode',
                            subtitle: 'Easy on the eyes',
                            icon: CupertinoIcons.moon_fill,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1C1C1E),
                                Color(0xFF000000),
                              ],
                            ),
                            isSelected: themeProvider.isDarkMode,
                            onTap: () {
                              themeProvider.setTheme(AppThemeMode.dark);
                            },
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Features Section
                          AnimatedGlassmorphicContainer(
                            padding: const EdgeInsets.all(20),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            borderRadius: 24,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.paintbrush_fill,
                                      color: ThemeProvider.iosPurple,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Theme Features',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildFeatureItem(
                                  'Smooth Animations',
                                  'Fluid transitions and effects',
                                  CupertinoIcons.waveform_path_ecg,
                                  isDark,
                                ),
                                _buildFeatureItem(
                                  'Adaptive Colors',
                                  'Automatically adjusts to content',
                                  CupertinoIcons.eyedropper,
                                  isDark,
                                ),
                                _buildFeatureItem(
                                  'Premium Feel',
                                  'Modern iOS 16 design language',
                                  CupertinoIcons.star_fill,
                                  isDark,
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildThemeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0, end: isSelected ? 1 : 0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 1.0 + (value * 0.02),
          child: GlassmorphicCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 24,
            onTap: onTap,
            blur: 15,
            opacity: isSelected ? 0.15 : 0.08,
            enableShadow: isSelected,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected 
                      ? ThemeProvider.iosBlue.withValues(alpha: 0.5)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected 
                          ? ThemeProvider.iosBlue
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected 
                            ? ThemeProvider.iosBlue
                            : (isDark ? Colors.white30 : Colors.black26),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFeatureItem(
    String title,
    String description,
    IconData icon,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ThemeProvider.iosBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: ThemeProvider.iosBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for animated background
class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    // Draw circles for glassmorphic effect
    paint.color = Colors.purple.withValues(alpha: 0.1);
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.3),
      100,
      paint,
    );

    paint.color = Colors.blue.withValues(alpha: 0.1);
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.5),
      120,
      paint,
    );

    paint.color = Colors.teal.withValues(alpha: 0.1);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.8),
      80,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}