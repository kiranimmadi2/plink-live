import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supper/providers/other%20providers/theme_provider.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import '../../widgets/home widgets/glassmorphic_container.dart';

class ThemeSettingsScreen extends ConsumerStatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  ConsumerState<ThemeSettingsScreen> createState() =>
      _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends ConsumerState<ThemeSettingsScreen>
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

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final isDark = themeState.isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark
          ? const Color(0xFF000000)
          : const Color(0xFFF5F5F7),
      body: Stack(
        children: [
          // Animated gradient background
          if (themeState.isGlassmorphism)
            AnimatedContainer(
              duration: const Duration(seconds: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ThemeNotifier.glassmorphismBackground[0],
                    ThemeNotifier.glassmorphismBackground[1],
                    ThemeNotifier.glassmorphismBackground[2],
                    ThemeNotifier.glassmorphismBackground[3],
                  ],
                  stops: const [0.0, 0.3, 0.6, 1.0],
                ),
              ),
              child: CustomPaint(painter: _BackgroundPainter()),
            ),

          SafeArea(
            child: Column(
              children: [
                // Custom App Bar with glassmorphic effect
                GlassmorphicContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  margin: const EdgeInsets.all(16),
                  borderRadius: 20,
                  blur: 20,
                  opacity: isDark ? 0.1 : 0.05,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryDark,
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          CupertinoIcons.back,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.backgroundDark,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Theme Settings',
                        style: isDark
                            ? AppTextStyles.headlineLarge
                            : AppTextStyles.headlineLargeLight,
                      ),
                      const Spacer(),
                      Icon(
                        themeState.isGlassmorphism
                            ? CupertinoIcons.sparkles
                            : CupertinoIcons.moon_fill,
                        color: AppColors.iosPurple,
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
                              style: isDark
                                  ? AppTextStyles.headlineMedium.copyWith(
                                      color: AppColors.textSecondaryDark,
                                    )
                                  : AppTextStyles.headlineMediumLight.copyWith(
                                      color: AppColors.textSecondaryLight,
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
                              colors: [Color(0xFFE3F2FD), Color(0xFFF3E5F5)],
                            ),
                            isSelected: themeState.isGlassmorphism,
                            onTap: () {
                              themeNotifier.setTheme(
                                AppThemeMode.glassmorphism,
                              );
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
                              colors: [Color(0xFF1C1C1E), Color(0xFF000000)],
                            ),
                            isSelected: themeState.isDarkMode,
                            onTap: () {
                              themeNotifier.setTheme(AppThemeMode.dark);
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
                                    const Icon(
                                      CupertinoIcons.paintbrush_fill,
                                      color: AppColors.iosPurple,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Theme Features',
                                      style: isDark
                                          ? AppTextStyles.titleLarge
                                          : AppTextStyles.titleLargeLight,
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
    final isDark = ref.watch(themeProvider).isDarkMode;

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
                      ? AppColors.iosBlue.withValues(alpha: 0.5)
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
                      color: AppColors.textPrimaryDark,
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
                          style: isDark
                              ? AppTextStyles.titleLarge
                              : AppTextStyles.titleLargeLight,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: isDark
                              ? AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondaryDark,
                                )
                              : AppTextStyles.bodySmallLight.copyWith(
                                  color: AppColors.textSecondaryLight,
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
                          ? AppColors.iosBlue
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.iosBlue
                            : (isDark
                                  ? AppColors.whiteAlpha(alpha: 0.3)
                                  : AppColors.blackAlpha(alpha: 0.26)),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: AppColors.textPrimaryDark,
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
              color: AppColors.iosBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.iosBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: isDark
                      ? AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        )
                      : AppTextStyles.bodyMediumLight.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                ),
                Text(
                  description,
                  style: isDark
                      ? AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textSecondaryDark,
                        )
                      : AppTextStyles.labelMediumLight.copyWith(
                          color: AppColors.textSecondaryLight,
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
    paint.color = AppColors.purpleTint(alpha: 0.1);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.3), 100, paint);

    paint.color = AppColors.blueTint(alpha: 0.1);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.5), 120, paint);

    paint.color = AppColors.tealTint(alpha: 0.1);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.8), 80, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
