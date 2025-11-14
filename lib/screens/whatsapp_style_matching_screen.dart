import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../services/universal_intent_service.dart';
import '../widgets/user_avatar.dart';
import 'enhanced_chat_screen.dart';
import 'profile_with_history_screen.dart';

class WhatsAppStyleMatchingScreen extends StatefulWidget {
  const WhatsAppStyleMatchingScreen({Key? key}) : super(key: key);

  @override
  State<WhatsAppStyleMatchingScreen> createState() => _WhatsAppStyleMatchingScreenState();
}

class _WhatsAppStyleMatchingScreenState extends State<WhatsAppStyleMatchingScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UniversalIntentService _intentService = UniversalIntentService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<ChatMessage> _messages = [];
  List<QuickReply> _quickReplies = [];
  List<UserProfile> _matches = [];
  bool _isProcessing = false;
  String _currentUserName = '';
  String? _currentIntent;
  Map<String, dynamic> _intentContext = {};
  
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _initializeChat();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _currentUserName = doc.data()?['name'] ?? user.displayName ?? '';
        });
      }
    }
  }

  void _initializeChat() {
    // Add welcome message
    _addBotMessage(
      "👋 Hi! I'm your Supper assistant. Tell me what you're looking for and I'll help you find the perfect match!",
    );
    
    // Add initial quick replies
    _setQuickReplies([
      QuickReply(text: '🛍️ Buy something', value: 'product'),
      QuickReply(text: '💼 Find a job', value: 'job'),
      QuickReply(text: '🏠 Find a place', value: 'housing'),
      QuickReply(text: '🔧 Need a service', value: 'service'),
    ]);
  }

  void _addBotMessage(String text, {List<UserProfile>? matches}) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
        matches: matches,
      ));
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _setQuickReplies(List<QuickReply> replies) {
    setState(() {
      _quickReplies = replies;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleUserInput(String input) async {
    if (input.trim().isEmpty) return;
    
    _addUserMessage(input);
    _messageController.clear();
    _setQuickReplies([]);
    
    setState(() => _isProcessing = true);
    
    try {
      // Process based on current context
      if (_currentIntent == null) {
        // Initial intent detection
        await _detectIntent(input);
      } else {
        // Continue conversation based on context
        await _processContextualResponse(input);
      }
    } catch (e) {
      _addBotMessage("Sorry, I couldn't process that. Please try again.");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _detectIntent(String input) async {
    // Smart intent detection
    final lowercaseInput = input.toLowerCase();
    
    if (lowercaseInput.contains('iphone') || lowercaseInput.contains('phone') || 
        lowercaseInput.contains('laptop') || lowercaseInput.contains('buy')) {
      _currentIntent = 'product';
      _intentContext['category'] = 'electronics';
      
      _addBotMessage("I see you're looking for a product! What's your budget range?");
      _setQuickReplies([
        QuickReply(text: 'Under \$500', value: 'budget_low'),
        QuickReply(text: '\$500-\$1000', value: 'budget_mid'),
        QuickReply(text: 'Above \$1000', value: 'budget_high'),
        QuickReply(text: 'No budget limit', value: 'budget_none'),
      ]);
    } else if (lowercaseInput.contains('job') || lowercaseInput.contains('work') || 
               lowercaseInput.contains('hire') || lowercaseInput.contains('employ')) {
      _currentIntent = 'job';
      
      _addBotMessage("Great! Are you looking for a job or hiring someone?");
      _setQuickReplies([
        QuickReply(text: 'Looking for a job', value: 'job_seeker'),
        QuickReply(text: 'Hiring someone', value: 'employer'),
      ]);
    } else if (lowercaseInput.contains('rent') || lowercaseInput.contains('apartment') || 
               lowercaseInput.contains('house') || lowercaseInput.contains('room')) {
      _currentIntent = 'housing';
      
      _addBotMessage("I'll help you find a place! What type of accommodation?");
      _setQuickReplies([
        QuickReply(text: '🏠 Entire place', value: 'entire_place'),
        QuickReply(text: '🛏️ Private room', value: 'private_room'),
        QuickReply(text: '👥 Shared room', value: 'shared_room'),
      ]);
    } else {
      // For anything else, ask one clarifying question
      _addBotMessage("Got it! Let me find the best matches for: \"$input\"");
      await _searchMatches(input);
    }
  }

  Future<void> _processContextualResponse(String input) async {
    // Process based on current intent context
    if (_currentIntent == 'product' && !_intentContext.containsKey('budget')) {
      // Process budget response
      if (input.contains('low') || input.contains('500')) {
        _intentContext['budget'] = 'under_500';
      } else if (input.contains('mid') || input.contains('1000')) {
        _intentContext['budget'] = '500_1000';
      } else if (input.contains('high') || input.contains('above')) {
        _intentContext['budget'] = 'above_1000';
      } else {
        _intentContext['budget'] = 'flexible';
      }
      
      _addBotMessage("Perfect! Is this for personal use or business?");
      _setQuickReplies([
        QuickReply(text: '👤 Personal', value: 'personal'),
        QuickReply(text: '💼 Business', value: 'business'),
        QuickReply(text: '🎁 Gift', value: 'gift'),
      ]);
    } else if (_currentIntent == 'product' && !_intentContext.containsKey('usage')) {
      _intentContext['usage'] = input;
      // Now search for matches
      await _searchMatchesWithContext();
    } else if (_currentIntent == 'job' && !_intentContext.containsKey('role')) {
      if (input.contains('seeker')) {
        _intentContext['role'] = 'job_seeker';
        _addBotMessage("What field are you interested in?");
        _setQuickReplies([
          QuickReply(text: '💻 Tech', value: 'tech'),
          QuickReply(text: '🏥 Healthcare', value: 'healthcare'),
          QuickReply(text: '📚 Education', value: 'education'),
          QuickReply(text: '🎨 Creative', value: 'creative'),
          QuickReply(text: 'Other', value: 'other'),
        ]);
      } else {
        _intentContext['role'] = 'employer';
        _addBotMessage("What position are you hiring for?");
        // Let them type freely
      }
    } else {
      // Final step - search for matches
      await _searchMatchesWithContext();
    }
  }

  Future<void> _searchMatches(String query) async {
    try {
      final result = await _intentService.processIntentAndMatch(query);
      
      // Extract matches from the result
      final matchesData = result['matches'] as List<dynamic>? ?? [];
      final matches = <UserProfile>[];
      
      // Convert matches data to UserProfile objects
      for (var match in matchesData) {
        if (match is Map<String, dynamic>) {
          final userData = match['userData'] as Map<String, dynamic>?;
          if (userData != null) {
            matches.add(UserProfile.fromMap(userData, match['userId'] ?? ''));
          }
        }
      }
      
      if (matches.isNotEmpty) {
        setState(() => _matches = matches);
        _addBotMessage(
          "Found ${matches.length} perfect matches for you! 🎯",
          matches: matches,
        );
        
        // Offer to refine
        _setQuickReplies([
          QuickReply(text: '🔄 Search again', value: 'new_search'),
          QuickReply(text: '📍 Filter by location', value: 'filter_location'),
          QuickReply(text: '✨ Show more', value: 'show_more'),
        ]);
      } else {
        _addBotMessage("No matches found. Let's try something different!");
        _setQuickReplies([
          QuickReply(text: '🔄 Try again', value: 'new_search'),
          QuickReply(text: '💡 Get suggestions', value: 'suggestions'),
        ]);
      }
    } catch (e) {
      _addBotMessage("Something went wrong. Please try again!");
    }
  }

  Future<void> _searchMatchesWithContext() async {
    // Build search query from context
    String searchQuery = _currentIntent ?? '';
    _intentContext.forEach((key, value) {
      searchQuery += ' $value';
    });
    
    await _searchMatches(searchQuery);
    
    // Reset context for next search
    _currentIntent = null;
    _intentContext = {};
  }

  void _handleQuickReply(QuickReply reply) {
    if (reply.value == 'new_search') {
      setState(() {
        _currentIntent = null;
        _intentContext = {};
        _matches = [];
      });
      _addUserMessage("Start new search");
      _addBotMessage("What are you looking for?");
      _initializeChat();
    } else if (reply.value == 'suggestions') {
      _addBotMessage("Here are some popular searches:");
      _setQuickReplies([
        QuickReply(text: 'iPhone 15', value: 'iphone_15'),
        QuickReply(text: 'Apartment for rent', value: 'apartment'),
        QuickReply(text: 'Remote job', value: 'remote_job'),
        QuickReply(text: 'Freelance developer', value: 'freelancer'),
      ]);
    } else {
      _handleUserInput(reply.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0B141A) : const Color(0xFFE5DDD5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1F2C33) : const Color(0xFF075E54),
        title: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Supper Assistant',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileWithHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF0B141A) : const Color(0xFFE5DDD5),
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _buildMessage(message, isDarkMode);
                },
              ),
            ),
          ),
          
          // Quick replies
          if (_quickReplies.isNotEmpty)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: isDarkMode ? const Color(0xFF1F2C33) : Colors.white,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _quickReplies.length,
                itemBuilder: (context, index) {
                  final reply = _quickReplies[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton(
                      onPressed: () => _handleQuickReply(reply),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
                        side: BorderSide(color: Theme.of(context).primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(reply.text),
                    ),
                  );
                },
              ),
            ),
          
          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: isDarkMode ? const Color(0xFF1F2C33) : Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF2A3942) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: _handleUserInput,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  radius: 24,
                  child: IconButton(
                    icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isProcessing 
                      ? null 
                      : () => _handleUserInput(_messageController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message, bool isDarkMode) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8, left: 80),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF00A884),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Text(
            message.text,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      );
    } else {
      return Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 8, right: 80),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2A3942) : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            ),
            
            // Show matches if available
            if (message.matches != null && message.matches!.isNotEmpty)
              Container(
                height: 120,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 8),
                  itemCount: message.matches!.length,
                  itemBuilder: (context, index) {
                    final match = message.matches![index];
                    return _buildMatchCard(match, isDarkMode);
                  },
                ),
              ),
          ],
        ),
      );
    }
  }

  Widget _buildMatchCard(UserProfile user, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EnhancedChatScreen(otherUser: user),
          ),
        );
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A3942) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            UserAvatar(
              profileImageUrl: user.profileImageUrl,
              radius: 30,
              fallbackText: user.name,
            ),
            const SizedBox(height: 8),
            Text(
              user.name.split(' ')[0],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (user.location != null)
              Text(
                user.location!,
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<UserProfile>? matches;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.matches,
  });
}

class QuickReply {
  final String text;
  final String value;

  QuickReply({required this.text, required this.value});
}