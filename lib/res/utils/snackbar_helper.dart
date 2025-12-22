import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_text_styles.dart';

/// Global SnackBar helper with consistent glassmorphism styling
class SnackBarHelper {
  SnackBarHelper._();

  /// Show error snackbar with red gradient
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      _buildSnackBar(
        message: message,
        icon: Icons.error_outline,
        gradient: AppColors.primaryGradient,
      ),
    );
  }

  /// Show success snackbar with green gradient
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      _buildSnackBar(
        message: message,
        icon: Icons.check_circle_outline,
        gradient: const LinearGradient(
          colors: [Color(0xFF00C853), Color(0xFF69F0AE)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }

  /// Show warning snackbar with orange gradient
  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      _buildSnackBar(
        message: message,
        icon: Icons.warning_amber_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }

  /// Show info snackbar with blue gradient
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      _buildSnackBar(
        message: message,
        icon: Icons.info_outline,
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }

  static SnackBar _buildSnackBar({
    required String message,
    required IconData icon,
    required Gradient gradient,
  }) {
    return SnackBar(
      content: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.glassBorder(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryShadow(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      duration: const Duration(seconds: 3),
    );
  }
}
