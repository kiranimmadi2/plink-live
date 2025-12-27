import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../../models/user_profile.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_text_styles.dart';
import '../call/voice_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final String? callerPhoto;
  final String callerId;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    this.callerPhoto,
    required this.callerId,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription? _callStatusSubscription;
  bool _isAnswering = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _listenToCallStatus();
    _updateStatusToRinging();
    _playRingtone();
    HapticFeedback.heavyImpact();
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  // Update call status to ringing so caller knows
  Future<void> _updateStatusToRinging() async {
    try {
      await _firestore.collection('calls').doc(widget.callId).update({
        'status': 'ringing',
        'ringingAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating status to ringing: $e');
    }
  }

  // Play ringtone sound
  Timer? _vibrationTimer;

  Future<void> _playRingtone() async {
    // Start vibration pattern
    _startVibration();

    try {
      // Play native ringtone instantly (no download needed)
      FlutterRingtonePlayer().playRingtone(
        looping: true,
        volume: 1.0,
        asAlarm: false,
      );
      debugPrint('🔔 Ringtone started playing (native)');
    } catch (e) {
      debugPrint('Error playing ringtone: $e');
    }
  }

  void _startVibration() {
    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      HapticFeedback.heavyImpact();
    });
    // Immediate first vibration
    HapticFeedback.heavyImpact();
  }

  Future<void> _stopRingtone() async {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    try {
      await FlutterRingtonePlayer().stop();
      debugPrint('🔔 Ringtone stopped');
    } catch (e) {
      debugPrint('Error stopping ringtone: $e');
    }
  }

  void _listenToCallStatus() {
    _callStatusSubscription = _firestore
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted || _isNavigating) return;

      final data = snapshot.data();
      if (data == null) {
        _safeNavigateBack();
        return;
      }

      final status = data['status'] as String?;

      if (status == 'ended' || status == 'rejected') {
        _safeNavigateBack();
      }
    });
  }

  void _safeNavigateBack() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _stopRingtone();
    _pulseController.dispose();
    _callStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    if (_isAnswering || _isNavigating) return;
    setState(() => _isAnswering = true);
    _isNavigating = true;

    HapticFeedback.mediumImpact();
    await _stopRingtone();

    try {
      // Update call status to connected so both sides know
      await _firestore.collection('calls').doc(widget.callId).update({
        'status': 'connected',
        'acceptedAt': FieldValue.serverTimestamp(),
        'connectedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Fetch caller's user profile
      final callerDoc =
          await _firestore.collection('users').doc(widget.callerId).get();

      if (!mounted) return;

      UserProfile callerProfile;

      if (callerDoc.exists) {
        final data = callerDoc.data()!;
        callerProfile = UserProfile(
          uid: widget.callerId,
          id: widget.callerId,
          name: data['name'] ?? data['displayName'] ?? widget.callerName,
          email: data['email'] ?? '',
          profileImageUrl: data['photoUrl'] ??
              data['photoURL'] ??
              data['profileImageUrl'] ??
              widget.callerPhoto,
          bio: data['bio'] ?? '',
          location: data['location'],
          interests:
              (data['interests'] as List<dynamic>?)?.cast<String>() ?? [],
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
        );
      } else {
        callerProfile = UserProfile(
          uid: widget.callerId,
          id: widget.callerId,
          name: widget.callerName,
          email: '',
          profileImageUrl: widget.callerPhoto,
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
        );
      }

      // Navigate to voice call screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => VoiceCallScreen(
            callId: widget.callId,
            otherUser: callerProfile,
            isOutgoing: false,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error accepting call: $e');
      setState(() => _isAnswering = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to accept call'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectCall() async {
    if (_isNavigating) return;
    HapticFeedback.mediumImpact();
    await _stopRingtone();

    try {
      await _firestore.collection('calls').doc(widget.callId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      _safeNavigateBack();
    } catch (e) {
      debugPrint('Error rejecting call: $e');
      _safeNavigateBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.splashGradient,
            ),
          ),

          // Blur effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                color: AppColors.blackAlpha(alpha: 0.3),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 80),

                // Incoming call text
                Text(
                  'Incoming Call',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.textSecondaryDark,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 40),

                // Animated caller avatar
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                AppColors.vibrantGreen.withValues(alpha: 0.5),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.vibrantGreen.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 70,
                          backgroundColor: AppColors.backgroundDarkTertiary,
                          backgroundImage: widget.callerPhoto != null
                              ? NetworkImage(widget.callerPhoto!)
                              : null,
                          child: widget.callerPhoto == null
                              ? Text(
                                  widget.callerName.isNotEmpty
                                      ? widget.callerName[0].toUpperCase()
                                      : 'U',
                                  style: AppTextStyles.displayLarge.copyWith(
                                    fontSize: 56,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),

                // Caller name
                Text(
                  widget.callerName,
                  style: AppTextStyles.displayMedium.copyWith(
                    fontSize: 32,
                  ),
                ),

                const SizedBox(height: 8),

                // Call type
                Text(
                  'Voice Call',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),

                const Spacer(),

                // Call action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Reject button
                      _buildActionButton(
                        icon: Icons.call_end_rounded,
                        color: AppColors.error,
                        label: 'Decline',
                        onTap: _rejectCall,
                      ),

                      // Accept button
                      _buildActionButton(
                        icon: Icons.call_rounded,
                        color: AppColors.vibrantGreen,
                        label: 'Accept',
                        onTap: _acceptCall,
                        isLoading: _isAnswering,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: AppColors.textPrimaryDark,
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : Icon(
                    icon,
                    color: AppColors.textPrimaryDark,
                    size: 32,
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
