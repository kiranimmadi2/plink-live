import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/conversation_service.dart';
import '../models/conversation_model.dart';
import '../models/user_profile.dart';
import 'enhanced_chat_screen.dart';

class ChatHomeScreen extends StatefulWidget {
  const ChatHomeScreen({super.key});

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final ConversationService _conversationService = ConversationService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  User? user;
  String? _photoUrl;
  final List<Map<String, dynamic>> _messages = [];
  Stream<List<ConversationModel>>? _conversationsStream;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late StreamSubscription<User?> _authSubscription;

  @override
  void initState() {
    super.initState();
    user = _authService.currentUser;
    _loadUserProfile();
    _conversationsStream = _conversationService.getUserConversations();
    
    
    // Listen to auth state changes to update user profile
    _authSubscription = _authService.authStateChanges.listen((User? newUser) {
      if (mounted) {
        setState(() {
          user = newUser;
        });
        // Reload user to ensure we have the latest profile data including photoURL
        user?.reload().then((_) {
          if (mounted) {
            setState(() {
              user = _authService.currentUser;
            });
            _loadUserProfile();
          }
        });
      }
    });
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadUserProfile() async {
    if (user == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _photoUrl = data['photoUrl'] ?? user!.photoURL;
        });
      }
    } catch (e) {
      // Silently handle error
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    
    HapticFeedback.lightImpact();
    setState(() {
      _messages.add({
        'text': _messageController.text,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
    });
    
    _messageController.clear();
    
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
    
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _messages.add({
          'text': 'This is a demo response. The actual AI integration will be implemented soon!',
          'isUser': false,
          'timestamp': DateTime.now(),
        });
      });
      
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    });
  }

  Future<void> _signOut() async {
    HapticFeedback.lightImpact();
    bool? confirmSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmSignOut == true) {
      try {
        await _authService.signOut();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign out failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Theme(
      data: ThemeData(
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10A37F),
          brightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8),
        endDrawer: _buildDrawer(isDarkMode),
        body: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildAppBar(isDarkMode),
                    Expanded(
                      child: _messages.isEmpty
                          ? _buildWelcomeScreen(isDarkMode)
                          : _buildChatMessages(isDarkMode),
                    ),
                    _buildInputArea(isDarkMode),
                  ],
                ),
              ),
              if (MediaQuery.of(context).size.width > 768)
                Container(
                  width: 260,
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF202020) : Colors.white,
                    border: Border(
                      left: BorderSide(
                        color: isDarkMode 
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                  ),
                  child: _buildSidebarContent(isDarkMode),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF202020) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode 
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Supper AI Assistant',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.add_rounded,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _messages.clear();
              });
            },
            tooltip: 'New Chat',
          ),
          if (MediaQuery.of(context).size.width <= 768)
            IconButton(
              icon: Icon(
                Icons.menu_rounded,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              onPressed: () {
                _scaffoldKey.currentState?.openEndDrawer();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDrawer(bool isDarkMode) {
    return Drawer(
      backgroundColor: isDarkMode ? const Color(0xFF202020) : Colors.white,
      child: _buildSidebarContent(isDarkMode),
    );
  }

  Widget _buildSidebarContent(bool isDarkMode) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF10A37F),
                    child: (_photoUrl ?? user?.photoURL) != null
                        ? ClipOval(
                            child: Image.network(
                              _photoUrl ?? user!.photoURL!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person,
                                  size: 24,
                                  color: Colors.white,
                                );
                              },
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 24,
                            color: Colors.white,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? user?.email?.split('@')[0] ?? 'User',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode 
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.black.withValues(alpha: 0.5),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _messages.clear();
                    });
                    if (MediaQuery.of(context).size.width <= 768) {
                      Navigator.pop(context);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: isDarkMode 
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'New Chat',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: isDarkMode 
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Recent Chats',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode 
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    // Force refresh conversations
                    setState(() {
                      _conversationsStream = _conversationService.getUserConversations();
                    });
                  },
                  child: StreamBuilder<List<ConversationModel>>(
                    stream: _conversationsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Error loading chats',
                                style: TextStyle(
                                  color: isDarkMode 
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : Colors.black.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${snapshot.error}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode 
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : Colors.black.withValues(alpha: 0.3),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      final conversations = snapshot.data ?? [];
                      
                      if (conversations.isEmpty) {
                        return ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.3,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 64,
                                      color: isDarkMode 
                                          ? Colors.white.withValues(alpha: 0.2)
                                          : Colors.black.withValues(alpha: 0.2),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No conversations yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: isDarkMode 
                                            ? Colors.white.withValues(alpha: 0.5)
                                            : Colors.black.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Start a chat from the Matching screen',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDarkMode 
                                            ? Colors.white.withValues(alpha: 0.3)
                                            : Colors.black.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: conversations.length,
                        itemBuilder: (context, index) {
                          final conversation = conversations[index];
                          return _buildConversationItem(conversation, isDarkMode);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: isDarkMode 
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: Icon(
                  Icons.settings_outlined,
                  size: 20,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
                title: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: Icon(
                  Icons.logout_outlined,
                  size: 20,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
                title: Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: _signOut,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConversationItem(ConversationModel conversation, bool isDarkMode) {
    final currentUserId = user?.uid ?? '';
    final otherUserId = conversation.participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    final otherUserName = conversation.participantNames[otherUserId] ?? 'User';
    final otherUserPhoto = conversation.participantPhotos[otherUserId];
    
    String timeText = '';
    if (conversation.lastMessageTime != null) {
      final messageTime = conversation.lastMessageTime!;
      final now = DateTime.now();
      final difference = now.difference(messageTime);
      
      if (difference.inMinutes < 1) {
        timeText = 'Just now';
      } else if (difference.inHours < 1) {
        timeText = '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        timeText = '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        timeText = '${difference.inDays}d ago';
      } else {
        timeText = '${messageTime.day}/${messageTime.month}';
      }
    }
    
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: isDarkMode 
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
        child: otherUserPhoto != null
            ? ClipOval(
                child: Image.network(
                  otherUserPhoto,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.person,
                      size: 20,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    );
                  },
                ),
              )
            : Icon(
                Icons.person,
                size: 20,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
      ),
      title: Text(
        otherUserName,
        style: TextStyle(
          fontSize: 14,
          fontWeight: conversation.unreadCount[currentUserId] != null && 
                     conversation.unreadCount[currentUserId]! > 0 
                     ? FontWeight.w600 
                     : FontWeight.normal,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: conversation.lastMessage != null
          ? Text(
              conversation.lastMessage!,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode 
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.4),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: timeText.isNotEmpty
          ? Text(
              timeText,
              style: TextStyle(
                fontSize: 11,
                color: isDarkMode 
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.4),
              ),
            )
          : null,
      onTap: () async {
        HapticFeedback.lightImpact();
        
        // Navigate to the chat screen
        final otherUserData = await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUserId)
            .get();
            
        if (otherUserData.exists && mounted) {
          final userData = otherUserData.data()!;
          final otherUserProfile = UserProfile(
            uid: otherUserId,
            name: userData['name'] ?? otherUserName,
            email: userData['email'] ?? '',
            profileImageUrl: userData['photoUrl'] ?? otherUserPhoto,
            bio: userData['bio'] ?? '',
            interests: List<String>.from(userData['interests'] ?? []),
            isOnline: userData['isOnline'] ?? false,
            lastSeen: userData['lastSeen'] != null 
                ? (userData['lastSeen'] as Timestamp).toDate()
                : DateTime.now(),
            createdAt: userData['createdAt'] != null 
                ? (userData['createdAt'] as Timestamp).toDate()
                : DateTime.now(),
            location: userData['location'],
            phone: userData['phone'],
            latitude: userData['latitude']?.toDouble(),
            longitude: userData['longitude']?.toDouble(),
            isVerified: userData['isVerified'] ?? false,
            fcmToken: userData['fcmToken'],
            additionalInfo: userData['additionalInfo'],
          );
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EnhancedChatScreen(
                otherUser: otherUserProfile,
              ),
            ),
          ).then((_) {
            // Refresh conversations after returning from chat
            if (mounted) {
              setState(() {
                // This will trigger a rebuild and the StreamBuilder will update
              });
            }
          });
        }
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      hoverColor: isDarkMode 
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.03),
    );
  }

  Widget _buildWelcomeScreen(bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10A37F), Color(0xFF3DD598)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10A37F).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Hello, ${user?.displayName ?? user?.email?.split('@')[0] ?? 'there'}!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'How can I help you today?',
                style: TextStyle(
                  fontSize: 18,
                  color: isDarkMode 
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.black.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 48),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _buildSuggestionCard(
                    'Write code',
                    'Help me write a function',
                    Icons.code_rounded,
                    const Color(0xFF6366F1),
                    isDarkMode,
                  ),
                  _buildSuggestionCard(
                    'Analyze data',
                    'Process and visualize data',
                    Icons.analytics_outlined,
                    const Color(0xFFEC4899),
                    isDarkMode,
                  ),
                  _buildSuggestionCard(
                    'Get creative',
                    'Generate ideas and content',
                    Icons.palette_outlined,
                    const Color(0xFFF59E0B),
                    isDarkMode,
                  ),
                  _buildSuggestionCard(
                    'Learn something',
                    'Explain complex topics',
                    Icons.school_outlined,
                    const Color(0xFF10B981),
                    isDarkMode,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool isDarkMode,
  ) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _messageController.text = subtitle;
        _sendMessage();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode 
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode 
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode 
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatMessages(bool isDarkMode) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isUser = message['isUser'] as bool;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: isUser 
                ? MainAxisAlignment.end 
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10A37F), Color(0xFF3DD598)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser 
                        ? const Color(0xFF10A37F)
                        : isDarkMode 
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: !isUser ? Border.all(
                      color: isDarkMode 
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ) : null,
                  ),
                  child: Text(
                    message['text'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      color: isUser 
                          ? Colors.white
                          : isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isDarkMode 
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  child: (_photoUrl ?? user?.photoURL) != null
                      ? ClipOval(
                          child: Image.network(
                            _photoUrl ?? user!.photoURL!,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.person,
                                size: 18,
                                color: isDarkMode ? Colors.white70 : Colors.black54,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: 18,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputArea(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF202020) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode 
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDarkMode 
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDarkMode 
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Send a message...',
                        hintStyle: TextStyle(
                          color: isDarkMode 
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.attach_file_rounded,
                      size: 20,
                      color: isDarkMode 
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.5),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10A37F), Color(0xFF3DD598)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.send_rounded,
                size: 20,
                color: Colors.white,
              ),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}