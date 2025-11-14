import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/universal_intent_service.dart';
import '../services/progressive_intent_service.dart';
import '../models/user_profile.dart';
import 'enhanced_chat_screen.dart';
import '../widgets/user_avatar.dart';
import '../widgets/simple_intent_dialog.dart';
import '../widgets/conversational_clarification_dialog.dart';
import '../widgets/match_card_with_actions.dart';
import '../services/unified_intent_processor.dart';
import '../services/realtime_matching_service.dart';
import 'profile_with_history_screen.dart';
import '../services/photo_cache_service.dart';

class UniversalMatchingScreen extends StatefulWidget {
  const UniversalMatchingScreen({Key? key}) : super(key: key);

  @override
  State<UniversalMatchingScreen> createState() => _UniversalMatchingScreenState();
}

class _UniversalMatchingScreenState extends State<UniversalMatchingScreen> {
  final UniversalIntentService _intentService = UniversalIntentService();
  final ProgressiveIntentService _progressiveService = ProgressiveIntentService();
  final UnifiedIntentProcessor _unifiedProcessor = UnifiedIntentProcessor();
  final RealtimeMatchingService _realtimeService = RealtimeMatchingService();
  final TextEditingController _intentController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PhotoCacheService _photoCache = PhotoCacheService();
  
  bool _isProcessing = false;
  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _userIntents = [];
  Map<String, dynamic>? _currentIntent;
  String? _errorMessage;
  String _currentUserName = '';
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _loadUserIntents();
    _loadUserProfile();
    _realtimeService.initialize();
  }

  @override
  void dispose() {
    _intentController.dispose();
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
    final clarification = await _unifiedProcessor.checkClarificationNeeded(intent);
    
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
        final clarifiedIntent = _buildClarifiedIntent(intent, answer, clarification['question']);
        await _processWithIntent(clarifiedIntent);
      }
    } else {
      // Direct processing without dialog for immediate results
      await _processWithIntent(intent);
    }
  }

  String _buildClarifiedIntent(String original, String answer, String question) {
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
        final matches = List<Map<String, dynamic>>.from(result['matches'] ?? []);
        
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
          print('Match: ${match['userProfile']?['name']} - Score: ${match['matchScore']}');
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
    if (input.length < 2) {
      setState(() {
        _suggestions = [];
      });
      return;
    }
    
    try {
      final suggestions = await _progressiveService.getSmartSuggestions(input);
      setState(() {
        _suggestions = suggestions;
      });
    } catch (e) {
      print('Error loading suggestions: $e');
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
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        centerTitle: false,
        title: Text(
          'Supper',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileWithHistoryScreen(),
                  ),
                ).then((_) => _loadUserProfile());
              },
              child: UserAvatar(
                profileImageUrl: _auth.currentUser?.photoURL,
                radius: 18,
                fallbackText: _currentUserName,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Main content area
          Expanded(
            child: _isProcessing
                ? const Center(
                    child: CircularProgressIndicator(),
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
              bottom: MediaQuery.of(context).padding.bottom + 20,
              top: 16,
            ),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.black : Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Suggestions
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              _intentController.text = _suggestions[index];
                              _processIntent();
                            },
                            child: Chip(
                              label: Text(
                                _suggestions[index],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                
                // Search input
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextField(
                    controller: _intentController,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Find Anything Supper',
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      suffixIcon: GestureDetector(
                        onTap: _isProcessing ? null : _processIntent,
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: Theme.of(context).primaryColor,
                            child: _isProcessing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.arrow_upward,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Hello ${_currentUserName.split(' ')[0].toUpperCase()},',
            style: TextStyle(
              fontSize: 20,
              color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Find Your Need',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
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
    final cachedPhoto = userId != null ? _photoCache.getCachedPhotoUrl(userId) : null;
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
          
          final otherUser = UserProfile.fromMap(
            userProfile,
            match['userId'],
          );
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EnhancedChatScreen(
                otherUser: otherUser,
              ),
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
                        if (userProfile['city'] != null && userProfile['city'].toString().isNotEmpty)
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
                      match['title'] ?? match['description'] ?? 'Looking for match',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (match['description'] != null && match['description'] != match['title'])
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          match['description'],
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              // Why it matches
              if (match['lookingFor'] != null && match['lookingFor'].toString().isNotEmpty)
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