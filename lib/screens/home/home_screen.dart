import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/universal_intent_service.dart';
import '../../models/user_profile.dart';
import '../enhanced_chat_screen.dart';
import '../../widgets/user_avatar.dart';
import '../../services/unified_intent_processor.dart';
import '../../services/realtime_matching_service.dart';
import '../profile/profile_with_history_screen.dart';
import '../../services/photo_cache_service.dart';
import '../../widgets/floating_particles.dart';
import 'package:lottie/lottie.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final UniversalIntentService _intentService = UniversalIntentService();
  final RealtimeMatchingService _realtimeService = RealtimeMatchingService();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PhotoCacheService _photoCache = PhotoCacheService();

  final TextEditingController _intentController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isSearchFocused = false;
  bool _isProcessing = false;

  List<String> _suggestions = [];
  bool _hasText = false;
  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _userIntents = [];
  Map<String, dynamic>? _currentIntent;
  String? _errorMessage;
  String _currentUserName = '';

  late AnimationController _controller;
  bool _visible = true;
  late Timer _timer;

  List<Map<String, dynamic>> _conversation = [];
  bool _showChatResponse = false;
  String _currentResponse = '';

  // Voice recording state
  bool _isRecording = false;
  bool _isVoiceProcessing = false;
  String _voiceText = '';

  @override
  void initState() {
    super.initState();
    _loadUserIntents();
    _loadUserProfile();
    _realtimeService.initialize();

    _controller = AnimationController(vsync: this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _visible = !_visible;
      });
    });

    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });

    _intentController.addListener(() {
      setState(() {
        _hasText = _intentController.text.isNotEmpty;
      });
    });

    _conversation.add({
      'text':
          'Hi! I\'m your Supper assistant. What would you like to find today?',
      'isUser': false,
      'timestamp': DateTime.now(),
    });
  }

  @override
  void dispose() {
    _intentController.dispose();
    _searchFocusNode.dispose();
    _realtimeService.dispose();
    _controller.dispose();
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          _currentUserName = userDoc.data()?['name'] ?? 'User';
        });
      }
    }
  }

  Future<void> _loadUserIntents() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      final intents = await _intentService.getUserIntents(userId);
      setState(() {
        _userIntents = intents;
      });
    }
  }

  void _processIntent() async {
    if (_intentController.text.isEmpty) return;

    final userMessage = _intentController.text.trim();
    if (userMessage.isEmpty) return;

    setState(() {
      _conversation.add({
        'text': userMessage,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
      _isProcessing = true;
      _showChatResponse = true;
    });

    _intentController.clear();

    await Future.delayed(const Duration(milliseconds: 1000));

    final aiResponse = _generateAIResponse(userMessage);

    setState(() {
      _conversation.add({
        'text': aiResponse,
        'isUser': false,
        'timestamp': DateTime.now(),
      });
      _isProcessing = false;
      _currentResponse = aiResponse;
    });

    if (_shouldProcessForMatches(userMessage)) {
      await _processWithIntent(userMessage);
    }
  }

  String _generateAIResponse(String userMessage) {
    final message = userMessage.toLowerCase();

    if (message.contains('hello') ||
        message.contains('hi') ||
        message.contains('hey')) {
      return 'Hello ${_currentUserName.split(' ')[0]}!  How can I help you find what you need today?';
    } else if (message.contains('bike') || message.contains('cycle')) {
      return ' Looking for a bike? I can help you find people selling or renting bicycles in your area. What\'s your budget?';
    } else if (message.contains('book') || message.contains('study')) {
      return 'Need books? Tell me which subject or specific books you\'re looking for, and I\'ll find students who have them.';
    } else if (message.contains('room') ||
        message.contains('hostel') ||
        message.contains('rent')) {
      return ' Looking for accommodation? I can connect you with people offering rooms or looking for roommates nearby.';
    } else if (message.contains('job') ||
        message.contains('work') ||
        message.contains('hire')) {
      return ' Job hunting? Let me know what kind of work you\'re looking for or if you\'re hiring, and I\'ll find relevant matches.';
    } else if (message.contains('sell') || message.contains('buy')) {
      return 'Looking to buy or sell something? Describe what you need, and I\'ll find the perfect match for you!';
    } else if (message.contains('thank') || message.contains('thanks')) {
      return 'You\'re welcome! Let me know if you need help with anything else.';
    } else if (message.contains('help')) {
      return 'I can help you find:\n• Items to buy/sell\n• Roommates\n• Study materials\n• Part-time jobs\n• Services\nJust tell me what you need!';
    } else {
      return 'I understand you\'re looking for: "$userMessage". Let me find the best matches for you in our community!';
    }
  }

  bool _shouldProcessForMatches(String message) {
    final lowerMessage = message.toLowerCase();
    return lowerMessage.contains('bike') ||
        lowerMessage.contains('book') ||
        lowerMessage.contains('room') ||
        lowerMessage.contains('job') ||
        lowerMessage.contains('sell') ||
        lowerMessage.contains('buy') ||
        lowerMessage.contains('rent') ||
        lowerMessage.contains('hire') ||
        lowerMessage.contains('find') ||
        lowerMessage.contains('look');
  }

  void _loadSuggestions(String value) {
    setState(() {
      _suggestions =
          [
                "Looking for a bike under \$200",
                "Need study books for engineering",
                "Room for rent near campus",
                "Part-time job opportunities",
                "Selling my old laptop",
              ]
              .where(
                (suggestion) =>
                    suggestion.toLowerCase().contains(value.toLowerCase()),
              )
              .toList();

      if (_suggestions.length < 3) {
        _suggestions.addAll([
          "Find roommates",
          "Buy/Sell items",
          "Study materials",
        ]);
      }
      _suggestions = _suggestions.take(3).toList();
    });
  }

  void _startVoiceRecording() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRecording = true;
      _voiceText = 'Listening... Speak now';
    });

    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      _stopVoiceRecording();
    }
  }

  void _stopVoiceRecording() async {
    setState(() {
      _isRecording = false;
      _isVoiceProcessing = true;
      _voiceText = 'Processing your voice...';
    });

    await Future.delayed(const Duration(seconds: 2));

    final mockVoiceResults = [
      "I'm looking for a bicycle under 200 dollars",
      "Need a room for rent near college campus",
      "Want to buy second hand engineering books",
      "Looking for part time job on weekends",
      "Selling my old smartphone in good condition",
      "Want to find a roommate near university",
      "Looking to buy a used laptop for studies",
    ];

    final randomResult =
        mockVoiceResults[DateTime.now().millisecondsSinceEpoch %
            mockVoiceResults.length];

    setState(() {
      _isVoiceProcessing = false;
      _voiceText = randomResult;
      _intentController.text = randomResult;
    });

    await Future.delayed(const Duration(milliseconds: 500));
    _processIntent();
  }

  Future<void> _processWithIntent(String intent) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final result = await _intentService.processIntentAndMatch(intent);

      if (!mounted) return;

      if (result['success'] == true) {
        final matches = List<Map<String, dynamic>>.from(
          result['matches'] ?? [],
        );

        for (final match in matches) {
          final userProfile = match['userProfile'] ?? {};
          final userId = match['userId'];
          final photoUrl = userProfile['photoUrl'];

          if (userId != null && photoUrl != null) {
            _photoCache.cachePhotoUrl(userId, photoUrl);
          }
        }

        setState(() {
          _currentIntent = result['intent'];
          _matches = matches;
          _isProcessing = false;
        });

        if (_matches.isNotEmpty) {
          setState(() {
            _conversation.add({
              'text':
                  'Found ${_matches.length} potential matches for you! Tap below to view them.',
              'isUser': false,
              'timestamp': DateTime.now(),
            });
          });
        }

        _loadUserIntents();
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to process request';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isProcessing = false;
      });
    }
  }

  String _formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).toStringAsFixed(0)}m away';
    } else if (distanceInKm < 10) {
      return '${distanceInKm.toStringAsFixed(1)}km away';
    } else {
      return '${distanceInKm.toStringAsFixed(0)}km away';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: false,
          title: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: isDarkMode
                  ? [Colors.white, Colors.grey[400]!]
                  : [Colors.black, Colors.grey[800]!],
            ).createShader(bounds),
            child: const Text(
              'Supper',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 24,
                letterSpacing: 0.5,
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileWithHistoryScreen(),
                    ),
                  ).then((_) => _loadUserProfile());
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(2),
                  child: UserAvatar(
                    profileImageUrl: _auth.currentUser?.photoURL,
                    radius: 20,
                    fallbackText: _currentUserName,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Background
          Container(color: Colors.grey.shade700),
          const Positioned.fill(child: FloatingParticles(particleCount: 12)),

          // Main content
          Column(
            children: [
              Expanded(
                child: _isProcessing
                    ? _buildChatState(isDarkMode)
                    : _matches.isNotEmpty
                    ? _buildMatchesList(isDarkMode)
                    : _buildChatState(isDarkMode),
              ),

              // Bottom input section
              _buildInputSection(isDarkMode),
            ],
          ),

          // Voice recording overlay - ABOVE EVERYTHING
          if (_isRecording || _isVoiceProcessing)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.9),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated voice waves
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_isRecording) ...[
                          _buildVoiceWave(120, 0.3, 0),
                          _buildVoiceWave(100, 0.5, 500),
                          _buildVoiceWave(80, 0.7, 1000),
                        ],
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isRecording ? Colors.red : Colors.blue,
                            boxShadow: [
                              BoxShadow(
                                color: (_isRecording ? Colors.red : Colors.blue)
                                    .withOpacity(0.5),
                                blurRadius: 15,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isRecording ? Icons.mic : Icons.auto_awesome,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Status text
                    Text(
                      _voiceText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    // Additional guidance
                    if (_isRecording)
                      Text(
                        'Tap anywhere to stop recording',
                        style: TextStyle(color: Colors.grey[400], fontSize: 16),
                      ),

                    if (_isVoiceProcessing)
                      const Column(
                        children: [
                          SizedBox(height: 20),
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                            strokeWidth: 3,
                          ),
                        ],
                      ),

                    const Spacer(),

                    // Close button
                    if (_isRecording)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 30),
                        child: GestureDetector(
                          onTap: _stopVoiceRecording,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Text(
                              'Stop Recording',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVoiceWave(double size, double opacity, int delay) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOut,
      builder: (context, double value, child) {
        return Opacity(
          opacity: opacity * (1 - value),
          child: Container(
            width: size + (value * 100),
            height: size + (value * 100),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red.withOpacity(0.5), width: 2),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputSection(bool isDarkMode) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 16,
      ),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _intentController.text = _suggestions[index];
                        _processIntent();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).primaryColor.withOpacity(0.2),
                              Theme.of(context).primaryColor.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _suggestions[index],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Input container
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: Colors.grey[900],
              border: Border.all(
                color: _isSearchFocused
                    ? const Color.fromARGB(255, 146, 146, 146)
                    : const Color.fromARGB(255, 146, 146, 146),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isSearchFocused
                      ? const Color.fromARGB(255, 146, 146, 146)
                      : Colors.transparent,
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                // Text field
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: TextStyle(
                      color: _isSearchFocused ? Colors.white : Colors.grey[400],
                      fontSize: _isSearchFocused ? 16 : 15,
                      fontWeight: _isSearchFocused
                          ? FontWeight.w500
                          : FontWeight.w400,
                      height: 1.4,
                    ),
                    child: TextField(
                      controller: _intentController,
                      focusNode: _searchFocusNode,
                      textInputAction: TextInputAction.send,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: null,
                      cursorColor: Colors.white,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ask me anything... What do you need?',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.transparent,
                      ),
                      onChanged: (value) {
                        if (value.length >= 2) {
                          _loadSuggestions(value);
                        } else {
                          setState(() => _suggestions = []);
                        }
                      },
                      onSubmitted: (_) => _processIntent(),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Mic button
                GestureDetector(
                  onTap: _isRecording
                      ? _stopVoiceRecording
                      : _startVoiceRecording,
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(left: 6, bottom: 7.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording ? Colors.red : Colors.grey[800],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Send button
                GestureDetector(
                  onTap: _isProcessing ? null : _processIntent,
                  child: Container(
                    width: 50,
                    height: 50,
                    margin: const EdgeInsets.only(right: 6, bottom: 7.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[800],
                    ),
                    child: _isProcessing
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatState(bool isDarkMode) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            builder: (context, double value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Text(
              'Hello ${_currentUserName.split(' ')[0].toUpperCase()}',
              style: const TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            reverse: false,
            itemCount: _conversation.length,
            itemBuilder: (context, index) {
              final message = _conversation[index];
              return _buildMessageBubble(message, isDarkMode);
            },
          ),
        ),

        if (_conversation.length <= 1)
          AnimatedOpacity(
            opacity: _visible ? 1.0 : 0.5,
            duration: const Duration(milliseconds: 300),
            child: Lottie.asset(
              'assets/animation.json',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              animate: true,
              repeat: true,
            ),
          ),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isDarkMode) {
    final isUser = message['isUser'] as bool;
    final text = message['text'] as String;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Colors.blue, Colors.purple]),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).primaryColor
                    : Colors.grey[800]!.withOpacity(0.8),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isUser
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: isUser ? FontWeight.w500 : FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),
          ),

          if (isUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8, top: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: _auth.currentUser?.photoURL != null
                    ? DecorationImage(
                        image: NetworkImage(_auth.currentUser!.photoURL!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: _auth.currentUser?.photoURL == null ? Colors.grey : null,
              ),
              child: _auth.currentUser?.photoURL == null
                  ? const Icon(Icons.person, color: Colors.white, size: 16)
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _buildMatchesList(bool isDarkMode) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(color: Colors.green.withOpacity(0.2)),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.people, color: Colors.green[600]),
              const SizedBox(width: 8),
              Text(
                '${_matches.length} Matches Found',
                style: TextStyle(
                  color: Colors.green[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _matches.clear();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _matches.length,
            itemBuilder: (context, index) {
              return _buildMatchCard(_matches[index], isDarkMode);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match, bool isDarkMode) {
    final userProfile = match['userProfile'] ?? {};
    final matchScore = (match['matchScore'] ?? 0.0) * 100;
    final userName = userProfile['name'] ?? 'Unknown User';
    final userId = match['userId'];

    final cachedPhoto = userId != null
        ? _photoCache.getCachedPhotoUrl(userId)
        : null;
    final photoUrl = cachedPhoto ?? userProfile['photoUrl'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      color: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () async {
          HapticFeedback.lightImpact();

          final otherUser = UserProfile.fromMap(userProfile, match['userId']);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EnhancedChatScreen(otherUser: otherUser),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(
                    profileImageUrl: photoUrl,
                    radius: 24,
                    fallbackText: userName,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            userName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: Colors.blue[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${matchScore.toStringAsFixed(0)}% match',
                                style: TextStyle(
                                  color: Colors.blue[600],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (userProfile['city'] != null &&
                            userProfile['city'].toString().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.green[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  userProfile['city'].toString(),
                                  style: TextStyle(
                                    color: Colors.green[600],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (match['distance'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.near_me,
                                  size: 14,
                                  color: Colors.orange[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDistance(match['distance'] as double),
                                  style: TextStyle(
                                    color: Colors.orange[600],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Posted:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      match['title'] ??
                          match['description'] ??
                          'Looking for match',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (match['description'] != null &&
                        match['description'] != match['title'])
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          match['description'],
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (match['lookingFor'] != null &&
                  match['lookingFor'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Matches your search',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

//
