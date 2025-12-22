import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:supper/screens/login/login_screen.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_assets.dart';
import '../../res/config/app_text_styles.dart';

class ChooseAccountTypeScreen extends StatefulWidget {
  const ChooseAccountTypeScreen({super.key});

  @override
  State<ChooseAccountTypeScreen> createState() =>
      _ChooseAccountTypeScreenState();
}

class _ChooseAccountTypeScreenState extends State<ChooseAccountTypeScreen> {
  int selectedIndex = -1;

  final List<String> accountTypes = [
    "Personal Account",
    "Business Account",
  ];

  void _onCardTap(int index) {
    setState(() {
      selectedIndex = index;
    });

    // Navigate to your full login screen with selected account type
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(accountType: accountTypes[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Image Background - Full Screen
          Image.asset(
            AppAssets.homeBackgroundImage,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: AppColors.splashGradient,
                ),
              );
            },
          ),

          // Dark overlay for better card visibility
          Container(
            color: AppColors.darkOverlay(),
          ),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Title with glassmorphism
                  Text(
                    "Choose Account Type",
                    style: AppTextStyles.displayMedium.copyWith(
                      shadows: [
                        Shadow(
                          color: AppColors.darkOverlay(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Select the account type that best suits your needs",
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.whiteAlpha(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 32),

                  GestureDetector(
                    onTap: () => _onCardTap(0),
                    child: AccountCard(
                      icon: Icons.person,
                      title: "Personal Account",
                      subtitle: "For individual buyers and sellers",
                      recommended: true,
                      items: const [
                        "Instant access",
                        "Buy and sell products",
                        "Create mutual listings",
                        "In-app chat",
                      ],
                      selected: selectedIndex == 0,
                    ),
                  ),
                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: () => _onCardTap(1),
                    child: AccountCard(
                      icon: Icons.business,
                      title: "Business Account",
                      subtitle: "For businesses and organizations",
                      verificationLabel: "Verification Required",
                      items: const [
                        "Business verification",
                        "Multiple team members",
                        "Advanced analytics",
                        "Priority support",
                      ],
                      selected: selectedIndex == 1,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AccountCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool recommended;
  final String? verificationLabel;
  final List<String> items;
  final bool selected;

  const AccountCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.items,
    this.recommended = false,
    this.verificationLabel,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.glassBackgroundDark(alpha: 0.2)
                : AppColors.glassBackgroundDark(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.glassBorder(alpha: 0.6)
                  : AppColors.glassBorder(alpha: 0.2),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.darkOverlay(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Icon with glassmorphism circle
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.glassBackgroundDark(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.glassBorder(alpha: 0.3),
                      ),
                    ),
                    child: Icon(icon, size: 22, color: AppColors.textPrimaryDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.titleSmall,
                        ),
                        Text(
                          subtitle,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.whiteAlpha(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Selection indicator
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.transparent,
                      border: Border.all(
                        color: selected
                            ? AppColors.success
                            : AppColors.glassBorder(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 16, color: AppColors.success)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Labels row
              Row(
                children: [
                  if (recommended)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        "Recommended",
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  if (verificationLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        verificationLabel!,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Features list
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items
                    .map(
                      (text) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppColors.whiteAlpha(alpha: 0.7),
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                text,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.whiteAlpha(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
