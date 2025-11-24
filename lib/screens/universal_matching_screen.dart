import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/universal_intent_service.dart';
import '../models/user_profile.dart';
import 'enhanced_chat_screen.dart';
import '../widgets/user_avatar.dart';
import '../widgets/conversational_clarification_dialog.dart';
import '../widgets/match_card_with_actions.dart';
import '../services/unified_intent_processor.dart';
import '../services/realtime_matching_service.dart';
import 'profile_with_history_screen.dart';
import '../services/photo_cache_service.dart';
import '../widgets/floating_particles.dart';
import '../widgets/liquid_wave_orb.dart';

class UniversalMatchingScreen extends StatefulWidget {
  const UniversalMatchingScreen({super.key});

  @override
  State<UniversalMatchingScreen> createState() =>
      _UniversalMatchingScreenState();
}

class _UniversalMatchingScreenState extends State<UniversalMatchingScreen> {
  final UniversalIntentService _intentService = UniversalIntentService();
  final UnifiedIntentProcessor _unifiedProcessor = UnifiedIntentProcessor();
  final RealtimeMatchingService _realtimeService = RealtimeMatchingService();
  final TextEditingController _intentController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PhotoCacheService _photoCache = PhotoCacheService();

  bool _isProcessing = false;
  bool _isSearchFocused = false;
  bool _hasText = false;
  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _userIntents = [];
  Map<String, dynamic>? _currentIntent;
  String? _errorMessage;
  String _currentUserName = '';
  List<String> _suggestions = [];

  // Voice orb state management
  VoiceOrbState _voiceOrbState = VoiceOrbState.idle;
  String _voiceTranscription = '';
  int _voiceConversationIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserIntents();
    _loadUserProfile();
    _realtimeService.initialize();

    // Listen to focus changes
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        HapticFeedback.selectionClick();
      }
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });

    // Listen to text changes
    _intentController.addListener(() {
      setState(() {
        _hasText = _intentController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _intentController.dispose();
    _searchFocusNode.dispose();
    _realtimeService.dispose();
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

  Future<void> _processIntent() async {
    final intent = _intentController.text.trim();
    if (intent.isEmpty) {
      setState(() {
        _errorMessage = 'Please describe what you\'re looking for';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    // Check if clarification is needed
    final clarification = await _unifiedProcessor.checkClarificationNeeded(
      intent,
    );

    if (clarification != null && clarification['needsClarification'] == true) {
      // Show clarification dialog
      final answer = await ConversationalClarificationDialog.show(
        context,
        originalInput: intent,
        question: clarification['question'],
        options: List<String>.from(clarification['options']),
        reason: clarification['reason'],
      );

      if (answer != null) {
        // Process with clarified intent
        final clarifiedIntent = _buildClarifiedIntent(
          intent,
          answer,
          clarification['question'],
        );
        await _processWithIntent(clarifiedIntent);
      }
    } else {
      // Direct processing without dialog for immediate results
      await _processWithIntent(intent);
    }
  }

  String _buildClarifiedIntent(
    String original,
    String answer,
    String question,
  ) {
    if (question.contains('buy or sell')) {
      if (answer.toLowerCase().contains('buy')) {
        return 'I want to buy $original';
      } else {
        return 'I want to sell $original';
      }
    } else if (question.contains('rent or offering')) {
      if (answer.toLowerCase().contains('looking')) {
        return 'Looking for $original to rent';
      } else {
        return 'Offering $original for rent';
      }
    } else if (question.contains('hiring')) {
      if (answer.toLowerCase().contains('hiring')) {
        return 'Hiring a $original';
      } else {
        return 'Looking for $original job';
      }
    } else if (question.contains('prefer')) {
      return '$original, preference: $answer';
    }
    return '$original - $answer';
  }

  Future<void> _processWithIntent(String intent) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _matches.clear();
    });

    try {
      final result = await _intentService.processIntentAndMatch(intent);

      if (!mounted) return;

      if (result['success'] == true) {
        final matches = List<Map<String, dynamic>>.from(
          result['matches'] ?? [],
        );

        // Cache user photos
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

        print('UniversalMatchingScreen: Found ${matches.length} matches');
        for (var match in matches) {
          print(
            'Match: ${match['userProfile']?['name']} - Score: ${match['matchScore']}',
          );
        }

        // Reload user intents
        _loadUserIntents();

        // Clear the input after successful search
        _intentController.clear();

        // Show success message if matches found
        if (_matches.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${_matches.length} matches for you!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
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

  // Load smart suggestions as user types
  Future<void> _loadSuggestions(String input) async {
    // Suggestions disabled - progressive_intent_service removed
    setState(() {
      _suggestions = [];
    });
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

  // Handle voice orb tap - all interaction happens inline
  void _handleVoiceOrbTap() {
    HapticFeedback.mediumImpact();

    if (_voiceOrbState == VoiceOrbState.idle) {
      // Start listening
      setState(() {
        _voiceOrbState = VoiceOrbState.listening;
        _voiceTranscription = '';
      });

      // Simulate listening for 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _voiceOrbState == VoiceOrbState.listening) {
          _processVoiceInput();
        }
      });
    } else if (_voiceOrbState == VoiceOrbState.listening) {
      // Stop listening early
      _processVoiceInput();
    } else {
      // Reset to idle
      setState(() {
        _voiceOrbState = VoiceOrbState.idle;
        _voiceTranscription = '';
        _voiceConversationIndex = 0;
      });
    }
  }

  // Process voice input (mock demo)
  void _processVoiceInput() {
    setState(() {
      _voiceOrbState = VoiceOrbState.processing;
    });

    // Simulate processing
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _showVoiceResponse();
      }
    });
  }

  // Show voice response (mock demo)
  void _showVoiceResponse() {
    // Mock conversation
    final List<Map<String, String>> mockConversation = [
      {
        'user': 'Hello, I need help',
        'ai': 'Hi! What can I help you find today?',
      },
      {'user': 'Looking for a bike', 'ai': 'Great! What\'s your budget?'},
      {
        'user': 'Under 200 dollars',
        'ai': 'Perfect! Searching for bikes under \$200...',
      },
    ];

    if (_voiceConversationIndex < mockConversation.length) {
      final conversation = mockConversation[_voiceConversationIndex];

      setState(() {
        _voiceOrbState = VoiceOrbState.speaking;
        _voiceTranscription = conversation['ai']!;
      });

      _voiceConversationIndex++;

      // Return to idle after response
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _voiceOrbState = VoiceOrbState.idle;
          });

          // Clear transcription after a bit
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _voiceTranscription = '';
              });
            }
          });
        }
      });
    } else {
      // Conversation finished
      setState(() {
        _voiceOrbState = VoiceOrbState.idle;
        _voiceTranscription = 'All done! Tap again to restart.';
        _voiceConversationIndex = 0;
      });

      // Clear after a moment
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _voiceTranscription = '';
          });
        }
      });
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
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withValues(alpha: 0.6),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
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
          // Pure black background
          Container(color: Colors.black),
          // Subtle floating particles
          const Positioned.fill(child: FloatingParticles(particleCount: 12)),
          // Main content
          Column(
            children: [
              // Main content area
              Expanded(
                child: _isProcessing
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: CircularProgressIndicator(
                            color: Theme.of(context).primaryColor,
                            strokeWidth: 3,
                          ),
                        ),
                      )
                    : _matches.isNotEmpty
                    ? _buildMatchesList(isDarkMode)
                    : _buildHomeState(isDarkMode),
              ),

              // Search input at bottom
              Container(
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
                    // Suggestions
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
                                        Theme.of(
                                          context,
                                        ).primaryColor.withValues(alpha: 0.2),
                                        Theme.of(
                                          context,
                                        ).primaryColor.withValues(alpha: 0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).primaryColor.withValues(alpha: 0.3),
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

                    // Search input with auto-expanding design
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      constraints: const BoxConstraints(
                        minHeight: 52,
                        maxHeight: 120,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: _isSearchFocused
                              ? Theme.of(context).primaryColor
                              : Colors.blue.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const SizedBox(width: 20),
                          Expanded(
                            child: TextField(
                              controller: _intentController,
                              focusNode: _searchFocusNode,
                              textInputAction: TextInputAction.newline,
                              keyboardType: TextInputType.multiline,
                              minLines: 1,
                              maxLines: null,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                              cursorColor: Theme.of(context).primaryColor,
                              decoration: InputDecoration(
                                hintText: 'Find Anything Supper',
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                fillColor: Colors.transparent,
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                isDense: true,
                              ),
                              onChanged: (value) {
                                if (value.length >= 2) {
                                  _loadSuggestions(value);
                                } else {
                                  setState(() {
                                    _suggestions = [];
                                  });
                                }
                              },
                              onSubmitted: (_) => _processIntent(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Send button
                          GestureDetector(
                            onTap: _isProcessing
                                ? null
                                : () {
                                    HapticFeedback.mediumImpact();
                                    _processIntent();
                                  },
                            child: Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.only(
                                right: 6,
                                bottom: 6,
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).primaryColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _isProcessing
                                  ? const Padding(
                                      padding: EdgeInsets.all(11),
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.arrow_upward_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
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
        ],
      ),
    );
  }

  Widget _buildHomeState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Greeting with subtle animation
            TweenAnimationBuilder(
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
                style: TextStyle(
                  fontSize: 22,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Voice Orb - Interactive element (all states happen here)
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, double value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.7 + (0.3 * value),
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                onTap: _handleVoiceOrbTap,
                child: LiquidWaveOrb(state: _voiceOrbState, size: 250),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 32),
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 400),
                builder: (context, double value, child) {
                  return Opacity(opacity: value, child: child);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.withValues(alpha: 0.15),
                        Colors.red.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.red[400],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red[400],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMatchesList(bool isDarkMode) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _matches.length,
      itemBuilder: (context, index) {
        return _buildMatchCard(_matches[index], isDarkMode);
      },
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match, bool isDarkMode) {
    final userProfile = match['userProfile'] ?? {};
    final matchScore = (match['matchScore'] ?? 0.0) * 100;
    final userName = userProfile['name'] ?? 'Unknown User';
    final userId = match['userId'];

    // Try to get cached photo first
    final cachedPhoto = userId != null
        ? _photoCache.getCachedPhotoUrl(userId)
        : null;
    final photoUrl = cachedPhoto ?? userProfile['photoUrl'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      color: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
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
              // User info row with avatar and match percentage
              Row(
                children: [
                  // User avatar with photo
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
                        // Name badge
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
                        // Match percentage
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
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
                        // Location badge if available
                        if (userProfile['city'] != null &&
                            userProfile['city'].toString().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
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
                        // Distance badge if available
                        if (match['distance'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
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
              // What they posted
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
              // Why it matches
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
