import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_profile.dart';
import '../../models/message_model.dart';
import '../../widgets/safe_circle_avatar.dart';
import '../../widgets/floating_particles.dart';
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

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final VoiceCallService _voiceCallService = VoiceCallService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _callStatus = 'calling';
  Timer? _callTimer;
  Timer? _callTimeoutTimer; // Timer to mark call as missed if not answered
  int _callDuration = 0;
  bool _isMuted = false;
  bool _isSpeakerOn = true; // Speaker on by default
  StreamSubscription? _callSubscription;
  bool _webrtcConnected = false;

  static const int _callTimeoutSeconds = 60; // Mark as missed after 60 seconds

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _setupVoiceCallService();
    _listenToCallStatus();
    _joinCall();

    // Start timeout timer for outgoing calls
    if (widget.isOutgoing) {
      _startCallTimeout();
    }
  }

  void _startCallTimeout() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(const Duration(seconds: _callTimeoutSeconds), () {
      // If call is still in calling/ringing state after timeout, mark as missed
      if (mounted && (_callStatus == 'calling' || _callStatus == 'ringing')) {
        _markCallAsMissed();
      }
    });
  }

  Future<void> _markCallAsMissed() async {
    _callTimer?.cancel();
    _callTimeoutTimer?.cancel();
    _callSubscription?.cancel();

    // Leave WebRTC call
    await _voiceCallService.leaveCall();

    try {
      await _firestore.collection('calls').doc(widget.callId).update({
        'status': 'missed',
        'missedAt': FieldValue.serverTimestamp(),
      });

      // Send missed call message to chat (only from caller's side to avoid duplicates)
      if (widget.isOutgoing) {
        await _sendCallMessageToChat(isMissed: true, duration: 0);
      }
    } catch (e) {
      // Error marking call as missed
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Send call event message to chat conversation
  /// Uses deterministic message ID to prevent duplicates if both users try to send
  Future<void> _sendCallMessageToChat({
    required bool isMissed,
    required int duration,
  }) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Get or create conversation ID
      final participants = [currentUserId, widget.otherUser.uid]..sort();
      final conversationId = participants.join('_');

      // Determine who was the actual caller (the one with isOutgoing = true)
      // This is important for correct message display
      final actualCallerId = widget.isOutgoing ? currentUserId : widget.otherUser.uid;
      final actualReceiverId = widget.isOutgoing ? widget.otherUser.uid : currentUserId;

      // Check if conversation exists
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      if (!conversationDoc.exists) {
        // Create conversation if it doesn't exist
        await _firestore.collection('conversations').doc(conversationId).set({
          'participants': participants,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
      }

      // Use deterministic message ID based on call ID to prevent duplicates
      // This allows both caller and receiver to attempt sending without creating duplicates
      final messageId = 'call_${widget.callId}';
      final messageRef = _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId);

      final now = DateTime.now();
      final messageType = isMissed
          ? MessageType.missedCall
          : MessageType.voiceCall;

      // Format duration for display
      String callText;
      if (isMissed) {
        callText = widget.isOutgoing
            ? 'Outgoing call - No answer'
            : 'Missed voice call';
      } else {
        final minutes = duration ~/ 60;
        final seconds = duration % 60;
        final durationStr =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        callText = 'Voice call • $durationStr';
      }

      // IMPORTANT: senderId is ALWAYS the caller, not necessarily the current user
      // This ensures the message displays correctly:
      // - Caller sees it as "outgoing" (isMe = true)
      // - Receiver sees it as "incoming" (isMe = false)
      await messageRef.set({
        'id': messageId,
        'senderId': actualCallerId,
        'receiverId': actualReceiverId,
        'chatId': conversationId,
        'text': callText,
        'type': messageType.index,
        'status': MessageStatus.delivered.index,
        'timestamp': Timestamp.fromDate(now),
        'isEdited': false,
        'read': false,
        'isRead': false,
        'metadata': {
          'callId': widget.callId,
          'duration': duration,
          'isOutgoing': widget.isOutgoing,
          'isMissed': isMissed,
        },
      });

      // Update conversation last message
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': isMissed ? '  Missed call' : '  Voice call',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': actualCallerId,
      });
    } catch (e) {
      // Error sending call message
    }
  }

  void _setupVoiceCallService() {
    _voiceCallService.onUserJoined = (uid) {
      if (mounted) {
        setState(() {
          _webrtcConnected = true;
        });
      }
    };

    _voiceCallService.onUserOffline = (uid) {
      if (mounted) {
        setState(() {
          _webrtcConnected = false;
        });
      }
    };

    _voiceCallService.onError = (message) {
      // Error handled silently - no snackbar
      debugPrint('VoiceCall error: $message');
    };
  }

  Future<void> _joinCall() async {
    final success = await _voiceCallService.joinCall(
      widget.callId,
      isCaller: widget.isOutgoing,
    );

    if (!success && mounted) {
      // Audio connection failed - handled silently
      debugPrint('Failed to connect audio');
    }
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _listenToCallStatus() {
    _callSubscription = _firestore
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          final data = snapshot.data();
          if (data != null) {
            final status = data['status'] as String? ?? 'calling';
            setState(() {
              _callStatus = status;
            });

            if (status == 'connected' || status == 'accepted') {
              // Cancel timeout timer since call is connected
              _callTimeoutTimer?.cancel();
              _startCallTimer();
              // Update status to connected if it was accepted
              if (status == 'accepted') {
                _firestore.collection('calls').doc(widget.callId).update({
                  'status': 'connected',
                  'connectedAt': FieldValue.serverTimestamp(),
                });
              }
            } else if (status == 'ended' ||
                status == 'declined' ||
                status == 'rejected' ||
                status == 'missed') {
              _callTimeoutTimer?.cancel();
              _endCall(
                wasMissedOrDeclined:
                    status == 'declined' ||
                    status == 'rejected' ||
                    status == 'missed',
                // Don't send message if rejected - IncomingCallScreen already sent it
                skipMessage: status == 'rejected',
              );
            }
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

  Future<void> _endCall({
    bool wasMissedOrDeclined = false,
    bool skipMessage = false,
  }) async {
    _callTimer?.cancel();
    _callTimeoutTimer?.cancel();
    _callSubscription?.cancel();

    // Leave WebRTC call
    await _voiceCallService.leaveCall();

    // Determine if this was a missed/declined call or completed call
    final bool wasMissed = wasMissedOrDeclined || _callDuration == 0;

    try {
      await _firestore.collection('calls').doc(widget.callId).update({
        'status': wasMissed ? 'missed' : 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'duration': _callDuration,
      });

      // Send call message to chat from BOTH sides for reliability
      // Uses deterministic message ID (call_{callId}) to prevent duplicates
      // This ensures the message is recorded even if one side disconnects
      // Skip only if rejected - IncomingCallScreen handles that case
      if (!skipMessage) {
        await _sendCallMessageToChat(
          isMissed: wasMissed,
          duration: _callDuration,
        );
      }
    } catch (e) {
      // Error updating call status
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _toggleMute() {
    HapticFeedback.lightImpact();
    _voiceCallService.toggleMute();
    setState(() {
      _isMuted = _voiceCallService.isMuted;
    });
  }

  void _toggleSpeaker() {
    HapticFeedback.lightImpact();
    _voiceCallService.toggleSpeaker();
    setState(() {
      _isSpeakerOn = _voiceCallService.isSpeakerOn;
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _callTimeoutTimer?.cancel();
    _callSubscription?.cancel();
    try {
      _voiceCallService.leaveCall();
    } catch (_) {}
    try {
      _pulseController.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Image (same as home screen)
          Positioned.fill(
            child: Image.asset(
              'assets/logo/home_background.webp',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.grey.shade900, Colors.black],
                    ),
                  ),
                );
              },
            ),
          ),

          // Blur effect with dark overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: Colors.black.withValues(alpha: 0.6)),
            ),
          ),

          // Floating particles
          const Positioned.fill(child: FloatingParticles(particleCount: 12)),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                _buildUserInfo(),
                const SizedBox(height: 40),
                _buildCallStatus(),
                const Spacer(),
                _buildCallControls(),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _callStatus == 'calling' ? _pulseAnimation.value : 1.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: SafeCircleAvatar(
                  photoUrl: widget.otherUser.photoUrl,
                  radius: 70,
                  name: widget.otherUser.name,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          widget.otherUser.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.otherUser.location != null)
          Text(
            widget.otherUser.location!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
      ],
    );
  }

  Widget _buildCallStatus() {
    String statusText;
    Color statusColor;

    switch (_callStatus) {
      case 'calling':
        statusText = widget.isOutgoing ? 'Calling...' : 'Incoming call...';
        statusColor = Colors.amber;
        break;
      case 'ringing':
        statusText = 'Ringing...';
        statusColor = Colors.amber;
        break;
      case 'connected':
        statusText = _formatDuration(_callDuration);
        statusColor = Colors.green;
        break;
      case 'ended':
        statusText = 'Call ended';
        statusColor = Colors.red;
        break;
      case 'declined':
        statusText = 'Call declined';
        statusColor = Colors.orange;
        break;
      default:
        statusText = 'Connecting...';
        statusColor = Colors.blue;
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_callStatus == 'connected')
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // WebRTC connection indicator
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _webrtcConnected ? Colors.green : Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _webrtcConnected ? 'Audio connected' : 'Connecting audio...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Voice Call',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildCallControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildControlButton(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              label: _isMuted ? 'Unmute' : 'Mute',
              onTap: _toggleMute,
              isActive: _isMuted,
            ),
            const SizedBox(width: 40),
            _buildControlButton(
              icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
              label: 'Speaker',
              onTap: _toggleSpeaker,
              isActive: _isSpeakerOn,
            ),
          ],
        ),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: () => _endCall(),
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.red, blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.call_end, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'End Call',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.blue : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
