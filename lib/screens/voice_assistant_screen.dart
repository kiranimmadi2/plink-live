import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/voice_orb.dart';
import '../widgets/audio_visualizer.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({Key? key}) : super(key: key);

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  VoiceOrbState _currentState = VoiceOrbState.idle;
  String _statusText = 'Tap microphone to speak';
  String _transcriptionText = '';

  // Mock conversation for demo
  final List<Map<String, String>> _mockConversation = [
    {'user': 'listening', 'ai': 'I\'m listening...'},
    {'user': 'Hello, I need help', 'ai': 'Hi! What can I help you find today?'},
    {'user': 'Looking for a bike', 'ai': 'Great! What\'s your budget for the bike?'},
    {'user': 'Under 200 dollars', 'ai': 'Perfect! Looking for bikes under \$200. Should I search now?'},
  ];

  int _conversationIndex = 0;

  void _toggleListening() {
    HapticFeedback.mediumImpact();

    if (_currentState == VoiceOrbState.idle) {
      // Start listening
      setState(() {
        _currentState = VoiceOrbState.listening;
        _statusText = 'Listening...';
        _transcriptionText = '';
      });

      // Simulate processing after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _currentState == VoiceOrbState.listening) {
          _processVoice();
        }
      });
    } else if (_currentState == VoiceOrbState.listening) {
      // Stop listening
      _processVoice();
    } else {
      // Reset
      setState(() {
        _currentState = VoiceOrbState.idle;
        _statusText = 'Tap microphone to speak';
        _transcriptionText = '';
        _conversationIndex = 0;
      });
    }
  }

  void _processVoice() {
    setState(() {
      _currentState = VoiceOrbState.processing;
      _statusText = 'Processing...';
    });

    // Simulate processing
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _showResponse();
      }
    });
  }

  void _showResponse() {
    if (_conversationIndex < _mockConversation.length) {
      final conversation = _mockConversation[_conversationIndex];

      setState(() {
        _currentState = VoiceOrbState.speaking;
        _transcriptionText = conversation['user']!;
        _statusText = conversation['ai']!;
      });

      _conversationIndex++;

      // Return to idle after response
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _currentState = VoiceOrbState.idle;
            _statusText = 'Tap microphone to continue';
          });
        }
      });
    } else {
      // Conversation finished
      setState(() {
        _currentState = VoiceOrbState.idle;
        _statusText = 'Conversation complete!';
      });
    }
  }

  void _reset() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentState = VoiceOrbState.idle;
      _statusText = 'Tap microphone to speak';
      _transcriptionText = '';
      _conversationIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F0F1E),
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F0F1E),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with back button
              _buildTopBar(),

              const Spacer(flex: 2),

              // Voice Orb
              VoiceOrb(
                state: _currentState,
                size: 220,
              ),

              const SizedBox(height: 40),

              // Audio visualizer (shows when listening or speaking)
              if (_currentState == VoiceOrbState.listening ||
                  _currentState == VoiceOrbState.speaking)
                AudioVisualizer(
                  isActive: true,
                  height: 60,
                  barCount: 35,
                ),

              const SizedBox(height: 30),

              // Status text
              _buildStatusText(),

              const SizedBox(height: 20),

              // Transcription text
              if (_transcriptionText.isNotEmpty &&
                  _transcriptionText != 'listening')
                _buildTranscriptionText(),

              const Spacer(flex: 3),

              // Control buttons
              _buildControls(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 8),
          const Text(
            'Voice Assistant',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        _statusText,
        key: ValueKey(_statusText),
        style: TextStyle(
          color: _getStatusColor(),
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTranscriptionText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: AnimatedOpacity(
        opacity: _transcriptionText.isNotEmpty ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            _transcriptionText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Reset button
        _buildControlButton(
          icon: Icons.refresh_rounded,
          onTap: _reset,
          color: Colors.white.withValues(alpha: 0.3),
        ),

        const SizedBox(width: 30),

        // Main microphone button
        _buildMainMicButton(),

        const SizedBox(width: 30),

        // Close button
        _buildControlButton(
          icon: Icons.close_rounded,
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildMainMicButton() {
    final isActive = _currentState == VoiceOrbState.listening;

    return GestureDetector(
      onTap: _toggleListening,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isActive
                ? [
                    const Color(0xFF0EA5E9),
                    const Color(0xFF8B5CF6),
                  ]
                : [
                    const Color(0xFF8B5CF6),
                    const Color(0xFF06B6D4),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: (isActive
                      ? const Color(0xFF0EA5E9)
                      : const Color(0xFF8B5CF6))
                  .withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Icon(
          isActive ? Icons.stop_rounded : Icons.mic_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.8),
          size: 24,
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_currentState) {
      case VoiceOrbState.idle:
        return Colors.white.withValues(alpha: 0.6);
      case VoiceOrbState.listening:
        return const Color(0xFF0EA5E9);
      case VoiceOrbState.processing:
        return const Color(0xFFFFAA00);
      case VoiceOrbState.speaking:
        return const Color(0xFF10B981);
    }
  }
}
