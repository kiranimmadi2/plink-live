import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// A reusable background widget that provides consistent styling across the app.
/// The video background is provided by SharedVideoBackground in MainNavigationScreen.
/// This widget adds optional blur overlay on top of the video.
class AppBackground extends StatelessWidget {
  final Widget child;
  final bool showBlur;
  final double blurAmount;
  final double overlayOpacity;

  const AppBackground({
    super.key,
    required this.child,
    this.showBlur = false,
    this.blurAmount = 12,
    this.overlayOpacity = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Blur effect (optional)
        if (showBlur)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),
          )
        else if (overlayOpacity > 0)
          // Dark overlay (only if specified)
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: overlayOpacity)),
          ),

        // Main content
        child,
      ],
    );
  }
}
