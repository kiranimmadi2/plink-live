import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:supper/screens/login/login_screen.dart';
import '../../services/video_preload_service.dart';

class ChooseAccountTypeScreen extends StatefulWidget {
  const ChooseAccountTypeScreen({super.key});

  @override
  State<ChooseAccountTypeScreen> createState() =>
      _ChooseAccountTypeScreenState();
}

class _ChooseAccountTypeScreenState extends State<ChooseAccountTypeScreen> {
  int selectedIndex = -1;
  final VideoPreloadService _videoService = VideoPreloadService();

  final List<String> accountTypes = [
    "Personal Account",
    "Professional Account",
    "Business Account",
  ];

  @override
  void initState() {
    super.initState();
    // Setup video background
    if (_videoService.isReady) {
      _videoService.resume();
    } else {
      _videoService.addOnReadyCallback(_onVideoReady);
      _videoService.preload();
    }
  }

  void _onVideoReady() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _videoService.removeOnReadyCallback(_onVideoReady);
    super.dispose();
  }

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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Background
          Positioned.fill(
            child: _videoService.isReady && _videoService.controller != null
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoService.controller!.value.size.width,
                      height: _videoService.controller!.value.size.height,
                      child: VideoPlayer(_videoService.controller!),
                    ),
                  )
                : Container(
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

          // Dark overlay
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
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
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Select the account type that best suits your needs",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 15,
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
                      icon: Icons.badge,
                      title: "Professional Account",
                      subtitle: "For freelancers and service providers",
                      verificationLabel: "Verification Required",
                      items: const [
                        "Provide services",
                        "Verified professional badge",
                        "Portfolio showcase",
                        "eKYC verification required",
                      ],
                      selected: selectedIndex == 1,
                    ),
                  ),
                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: () => _onCardTap(2),
                    child: AccountCard(
                      icon: Icons.factory,
                      title: "Business Account",
                      subtitle: "For businesses and organizations",
                      verificationLabel: "Verification Required",
                      items: const [
                        "Business verification",
                        "Multiple team members",
                        "Advanced analytics",
                        "Priority support",
                      ],
                      selected: selectedIndex == 2,
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
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.2),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
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
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(icon, size: 22, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
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
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? Colors.green
                            : Colors.white.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 16, color: Colors.green)
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
                        color: Colors.green.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Text(
                        "Recommended",
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
                        color: Colors.orange.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        verificationLabel!,
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                text,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12,
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
