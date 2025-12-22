import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';
import '../../res/config/app_colors.dart';
import '../../services/other services/voice_call_service.dart';

class VoiceCallScreen extends StatefulWidget {
  final String callId;
  final UserProfile otherUser;
  final bool isOutgoing;

  const VoiceCallScreen({
    super.key,
    required this.callId,
    required this.otherUser,
    required this.isOutgoing,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  final VoiceCallService _voiceCallService = VoiceCallService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _callStatus = 'Connecting...';
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isConnected = false;
  Timer? _callTimer;
  int _callDuration = 0;
  StreamSubscription? _callStatusSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCall();
    _listenToCallStatus();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _callStatusSubscription?.cancel();
    _endCall(navigate: false);
    super.dispose();
  }

  void _listenToCallStatus() {
    _callStatusSubscription = _firestore
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      final data = snapshot.data();
      if (data == null) return;

      final status = data['status'] as String?;

      if (status == 'ended' || status == 'rejected') {
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else if (status == 'connected') {
        setState(() {
          _callStatus = 'Connected';
          _isConnected = true;
        });
        _startCallTimer();
      } else if (status == 'accepted') {
        // Receiver accepted, now connecting
        setState(() {
          _callStatus = 'Connecting...';
        });
      } else if (status == 'ringing') {
        setState(() {
          _callStatus = 'Ringing...';
        });
      }
    });
  }

  Future<void> _initializeCall() async {
    try {
      debugPrint('🎤 VoiceCallScreen: Initializing call ${widget.callId}, isOutgoing: ${widget.isOutgoing}');

      // Initialize voice call service
      final initialized = await _voiceCallService.initialize();
      if (!initialized) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to initialize call'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // Set up callbacks
      _voiceCallService.onUserJoined = (uid) async {
        debugPrint('🎤 VoiceCallScreen: onUserJoined callback triggered');
        if (mounted) {
          // Ensure speaker is on for audio
          await _voiceCallService.setSpeaker(true);

          setState(() {
            _callStatus = 'Connected';
            _isConnected = true;
            _isSpeakerOn = true;
          });
          _startCallTimer();

          // Update call status in Firestore
          _firestore.collection('calls').doc(widget.callId).update({
            'status': 'connected',
            'connectedAt': FieldValue.serverTimestamp(),
          });
        }
      };

      _voiceCallService.onUserOffline = (uid) {
        debugPrint('🎤 VoiceCallScreen: onUserOffline callback triggered');
        if (mounted) {
          setState(() {
            _callStatus = 'Call ended';
            _isConnected = false;
          });
          _callTimer?.cancel();

          // End call after a short delay
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      };

      _voiceCallService.onError = (message) {
        debugPrint('🎤 VoiceCallScreen: onError callback: $message');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
            ),
          );
        }
      };

      _voiceCallService.onJoinChannelSuccess = () {
        debugPrint('🎤 VoiceCallScreen: onJoinChannelSuccess callback triggered');
      };

      // For receiver, wait a bit to ensure caller's offer is ready
      if (!widget.isOutgoing) {
        debugPrint('🎤 VoiceCallScreen: Receiver - waiting for offer to be ready...');
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      // Enable speaker before joining
      await _voiceCallService.setSpeaker(true);
      setState(() {
        _isSpeakerOn = true;
      });

      // Join the call
      debugPrint('🎤 VoiceCallScreen: Joining call...');
      final joined = await _voiceCallService.joinCall(
        widget.callId,
        isCaller: widget.isOutgoing,
      );

      debugPrint('🎤 VoiceCallScreen: Join result: $joined');

      if (!joined && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to join call'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      } else {
        setState(() {
          _callStatus = widget.isOutgoing ? 'Calling...' : 'Connecting...';
        });

        // For receiver, check if we should wait more for connection
        if (!widget.isOutgoing) {
          // Poll for connection status
          _checkConnectionStatus();
        }
      }
    } catch (e) {
      debugPrint('🎤 VoiceCallScreen: Error initializing call: $e');
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  // Check connection status periodically for receiver
  void _checkConnectionStatus() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted || _isConnected) return;

      debugPrint('🎤 VoiceCallScreen: Checking connection status...');
      debugPrint('🎤 VoiceCallScreen: isInCall: ${_voiceCallService.isInCall}');

      // If still not connected after 5 seconds, show status
      if (!_isConnected && mounted) {
        setState(() {
          _callStatus = 'Waiting for connection...';
        });
      }
    });
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleMute() async {
    HapticFeedback.lightImpact();
    await _voiceCallService.toggleMute();
    setState(() {
      _isMuted = _voiceCallService.isMuted;
    });
  }

  Future<void> _toggleSpeaker() async {
    HapticFeedback.lightImpact();
    await _voiceCallService.toggleSpeaker();
    setState(() {
      _isSpeakerOn = _voiceCallService.isSpeakerOn;
    });
  }

  Future<void> _endCall({bool navigate = true}) async {
    HapticFeedback.mediumImpact();

    _callTimer?.cancel();

    try {
      // Update call status in Firestore
      await _firestore.collection('calls').doc(widget.callId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'duration': _callDuration,
      });

      // Leave the call
      await _voiceCallService.leaveCall();
    } catch (e) {
      debugPrint('Error ending call: $e');
    }

    if (navigate && mounted) {
      Navigator.of(context).pop();
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

          // Blur effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),

                // User avatar
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isConnected
                          ? AppColors.vibrantGreen.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.3),
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: widget.otherUser.profileImageUrl != null
                        ? NetworkImage(widget.otherUser.profileImageUrl!)
                        : null,
                    child: widget.otherUser.profileImageUrl == null
                        ? Text(
                            widget.otherUser.name.isNotEmpty
                                ? widget.otherUser.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 24),

                // User name
                Text(
                  widget.otherUser.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),

                // Call status or duration
                Text(
                  _isConnected ? _formatDuration(_callDuration) : _callStatus,
                  style: TextStyle(
                    fontSize: 16,
                    color: _isConnected
                        ? AppColors.vibrantGreen
                        : Colors.white70,
                  ),
                ),

                const Spacer(),

                // Call controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mute button
                      _buildControlButton(
                        icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        label: _isMuted ? 'Unmute' : 'Mute',
                        isActive: _isMuted,
                        onTap: _toggleMute,
                      ),

                      // End call button
                      _buildEndCallButton(),

                      // Speaker button
                      _buildControlButton(
                        icon: _isSpeakerOn
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                        isActive: _isSpeakerOn,
                        onTap: _toggleSpeaker,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndCallButton() {
    return GestureDetector(
      onTap: _endCall,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
            ),
            child: const Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'End',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
