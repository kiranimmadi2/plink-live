import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_chat_bubble/chat_bubble.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/user_profile.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import '../services/notification_service.dart';
import '../services/conversation_service.dart';
import 'profile_view_screen.dart';
// Call feature removed

class EnhancedChatScreen extends StatefulWidget {
  final UserProfile otherUser;
  final String? initialMessage;

  const EnhancedChatScreen({
    Key? key,
    required this.otherUser,
    this.initialMessage,
  }) : super(key: key);

  @override
  State<EnhancedChatScreen> createState() => _EnhancedChatScreenState();
}

class _EnhancedChatScreenState extends State<EnhancedChatScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final ConversationService _conversationService = ConversationService();
  
  String? _conversationId;
  bool _isTyping = false;
  Timer? _typingTimer;
  MessageModel? _replyToMessage;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showScrollButton = false;
  int _unreadCount = 0;
  
  // Search related variables
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<MessageModel> _searchResults = [];
  int _currentSearchIndex = 0;
  List<MessageModel> _allMessages = [];

  @override
  void initState() {
    super.initState();
    print('EnhancedChatScreen initialized with user: ${widget.otherUser.name} (${widget.otherUser.uid})');
    WidgetsBinding.instance.addObserver(this);
    
    // Defer non-critical initialization to after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      await _initializeConversation();
      if (mounted) {
        _markMessagesAsRead();
        
        // If there's an initial message, set it in the message controller
        if (widget.initialMessage != null) {
          _messageController.text = widget.initialMessage!;
          FocusScope.of(context).requestFocus(_messageFocusNode);
        }
        
        // Listen for incoming messages for sound/vibration feedback
        _listenForIncomingMessages();
        
        // Pre-initialize call service in background for faster call start
        _initializeCallService();
      }
    });
    
    _setupAnimations();
    _scrollController.addListener(_scrollListener);
  }
  
  void _listenForIncomingMessages() {
    // Add a slight delay to avoid triggering on initial load
    Future.delayed(const Duration(seconds: 2), () {
      if (_conversationId != null && mounted) {
        // Simplified query without compound where clause to avoid index requirement
        _firestore
            .collection('conversations')
            .doc(_conversationId!)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .snapshots()
            .listen((snapshot) {
          if (snapshot.docs.isNotEmpty && mounted) {
            final latestMessage = snapshot.docs.first.data();
            // Check if it's an incoming message in memory
            if (latestMessage['receiverId'] == _auth.currentUser!.uid &&
                latestMessage['senderId'] != _auth.currentUser!.uid) {
              HapticFeedback.mediumImpact();
            }
          }
        }, onError: (error) {
          // Silently handle any errors
          print('Error listening for messages: $error');
        });
      }
    });
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  void _scrollListener() {
    // Debounce scroll events to reduce rebuilds
    if (!_scrollController.hasClients) return;
    
    final shouldShow = _scrollController.position.pixels > 500;
    if (shouldShow != _showScrollButton) {
      setState(() => _showScrollButton = shouldShow);
    }
  }

  Future<void> _initializeConversation() async {
    try {
      // Use ConversationService to get or create conversation
      final conversationId = await _conversationService.getOrCreateConversation(widget.otherUser);
      if (mounted) {
        setState(() {
          _conversationId = conversationId;
        });
      }
      _markMessagesAsRead();
    } catch (e) {
      print('Error initializing conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading conversation: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _updateTypingStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markMessagesAsRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF000000) : Colors.white,
      appBar: _buildAppBar(isDarkMode),
      body: Stack(
        children: [
          Column(
            children: [
              if (_isSearching) _buildSearchResultsBar(isDarkMode),
              Expanded(
                child: Stack(
                  children: [
                    _buildMessagesList(isDarkMode),
                    if (_showScrollButton) _buildScrollToBottomButton(),
                  ],
                ),
              ),
              if (_replyToMessage != null) _buildReplyPreview(isDarkMode),
              _buildTypingIndicator(isDarkMode),
              _buildMessageInput(isDarkMode),
            ],
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDarkMode) {
    return AppBar(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios,
            color: isDarkMode ? Colors.white : Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: _isSearching 
        ? _buildSearchField(isDarkMode) 
        : InkWell(
        onTap: _showUserProfile,
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: widget.otherUser.profileImageUrl != null
                      ? CachedNetworkImageProvider(widget.otherUser.profileImageUrl!)
                      : null,
                  child: widget.otherUser.profileImageUrl == null
                      ? Text(widget.otherUser.name[0].toUpperCase())
                      : null,
                ),
                StreamBuilder<DocumentSnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(widget.otherUser.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    bool isOnline = false;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final userData = snapshot.data!.data() as Map<String, dynamic>;
                      final showOnlineStatus = userData['showOnlineStatus'] ?? true;
                      
                      // Only show online if user allows it and they're actually online
                      if (showOnlineStatus) {
                        isOnline = userData['isOnline'] ?? false;
                        
                        // Check if lastSeen is recent
                        if (isOnline) {
                          final lastSeen = userData['lastSeen'];
                          if (lastSeen != null && lastSeen is Timestamp) {
                            final lastSeenTime = lastSeen.toDate();
                            final difference = DateTime.now().difference(lastSeenTime);
                            // Consider offline if last seen more than 5 minutes ago
                            if (difference.inMinutes > 5) {
                              isOnline = false;
                            }
                          } else {
                            isOnline = false;
                          }
                        }
                      }
                    }
                    
                    if (!isOnline) return const SizedBox.shrink();
                    
                    return Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUser.name.isNotEmpty ? widget.otherUser.name : 'Unknown User',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  StreamBuilder<DocumentSnapshot>(
                    stream: _conversationId != null
                        ? _firestore
                            .collection('conversations')
                            .doc(_conversationId!)
                            .snapshots()
                        : Stream.empty(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>;
                        final isTyping = data['isTyping']?[widget.otherUser.uid] ?? false;
                        
                        if (isTyping) {
                          return Text(
                            'Typing...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).primaryColor,
                              fontStyle: FontStyle.italic,
                            ),
                          );
                        }
                      }
                      
                      return StreamBuilder<DocumentSnapshot>(
                        stream: _firestore
                            .collection('users')
                            .doc(widget.otherUser.uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final userData = snapshot.data!.data() as Map<String, dynamic>;
                            final showOnlineStatus = userData['showOnlineStatus'] ?? true;
                            
                            if (!showOnlineStatus) {
                              return Text(
                                'Status hidden',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.grey[600] : Colors.grey,
                                ),
                              );
                            }
                            
                            var isOnline = userData['isOnline'] ?? false;
                            
                            // Check if lastSeen is recent
                            if (isOnline) {
                              final lastSeen = userData['lastSeen'];
                              if (lastSeen != null && lastSeen is Timestamp) {
                                final lastSeenTime = lastSeen.toDate();
                                final difference = DateTime.now().difference(lastSeenTime);
                                // Consider offline if last seen more than 5 minutes ago
                                if (difference.inMinutes > 5) {
                                  isOnline = false;
                                }
                              } else {
                                isOnline = false;
                              }
                            }
                            
                            if (isOnline) {
                              return Text(
                                'Active now',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              );
                            } else if (userData['lastSeen'] != null) {
                              final lastSeen = (userData['lastSeen'] as Timestamp).toDate();
                              return Text(
                                'Active ${timeago.format(lastSeen)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.grey[600] : Colors.grey,
                                ),
                              );
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!_isSearching)
          IconButton(
            icon: Icon(Icons.search,
                color: isDarkMode ? Colors.white : Colors.black),
            onPressed: _toggleSearch,
          ),
        if (!_isSearching)
          IconButton(
            icon: Icon(Icons.phone_outlined,
                color: isDarkMode ? Colors.white : Colors.black),
            onPressed: _makeVoiceCall,
          ),
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.info_outline,
              color: isDarkMode ? Colors.white : Colors.black),
          onPressed: _isSearching ? _toggleSearch : _showChatInfo,
        ),
      ],
    );
  }

  Widget _buildMessagesList(bool isDarkMode) {
    if (_conversationId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data!.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList();
        
        // Store all messages for searching
        _allMessages = messages;

        if (messages.isEmpty) {
          return _buildEmptyChat(isDarkMode);
        }
        
        // Filter messages if searching
        final displayMessages = _isSearching && _searchQuery.isNotEmpty 
            ? messages.where((msg) => 
                msg.text != null && 
                msg.text!.toLowerCase().contains(_searchQuery.toLowerCase())
              ).toList()
            : messages;

        return FadeTransition(
          opacity: _fadeAnimation,
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: displayMessages.length,
            itemBuilder: (context, index) {
              final message = displayMessages[index];
              final isMe = message.senderId == _auth.currentUser!.uid;
              final showAvatar = !isMe && (index == displayMessages.length - 1 ||
                  displayMessages[index + 1].senderId != message.senderId);
              
              final isHighlighted = _isSearching && 
                  _searchResults.contains(message) &&
                  _searchResults.indexOf(message) == _currentSearchIndex;
              
              return _buildMessageBubble(
                message, 
                isMe, 
                showAvatar, 
                isDarkMode,
                isHighlighted: isHighlighted,
                searchQuery: _isSearching ? _searchQuery : null,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(
    MessageModel message,
    bool isMe,
    bool showAvatar,
    bool isDarkMode, {
    bool isHighlighted = false,
    String? searchQuery,
  }) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message, isMe),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: 8,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe && showAvatar)
              CircleAvatar(
                radius: 16,
                backgroundImage: widget.otherUser.profileImageUrl != null
                    ? CachedNetworkImageProvider(widget.otherUser.profileImageUrl!)
                    : null,
                child: widget.otherUser.profileImageUrl == null
                    ? Text(widget.otherUser.name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 12))
                    : null,
              )
            else if (!isMe)
              const SizedBox(width: 32),
            if (!isMe) const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (message.replyToMessageId != null)
                    _buildReplyBubble(message.replyToMessageId!, isMe, isDarkMode),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Theme.of(context).primaryColor
                          : (isDarkMode ? Colors.grey[900] : Colors.grey[200]),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      border: isHighlighted
                          ? Border.all(
                              color: Colors.orange,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.type == MessageType.image && message.mediaUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: message.mediaUrl!,
                              placeholder: (context, url) => Container(
                                width: 200,
                                height: 200,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                            ),
                          ),
                        if (message.text != null && message.text!.isNotEmpty)
                          searchQuery != null && searchQuery.isNotEmpty
                              ? _buildHighlightedText(
                                  message.text!,
                                  searchQuery,
                                  TextStyle(
                                    color: isMe
                                        ? Colors.white
                                        : (isDarkMode ? Colors.white : Colors.black87),
                                    fontSize: 15,
                                  ),
                                )
                              : Text(
                                  message.text!,
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white
                                        : (isDarkMode ? Colors.white : Colors.black87),
                                    fontSize: 15,
                                  ),
                                ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeago.format(message.timestamp),
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : (isDarkMode
                                        ? Colors.grey[600]
                                        : Colors.grey[600]),
                                fontSize: 11,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                message.status == MessageStatus.read
                                    ? Icons.done_all
                                    : message.status == MessageStatus.delivered
                                        ? Icons.done_all
                                        : Icons.done,
                                size: 14,
                                color: message.status == MessageStatus.read
                                    ? Colors.blue[300]
                                    : Colors.white.withValues(alpha: 0.7),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (message.reactions != null && message.reactions!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.grey[900]
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        message.reactions!.join(' '),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyBubble(String messageId, bool isMe, bool isDarkMode) {
    if (_conversationId == null) return const SizedBox.shrink();
    
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .doc(messageId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final replyData = snapshot.data!.data() as Map<String, dynamic>?;
        if (replyData == null) return const SizedBox.shrink();
        
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isMe
                    ? Theme.of(context).primaryColor
                    : (isDarkMode ? Colors.grey[900]! : Colors.grey[200]!))
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 3,
              ),
            ),
          ),
          child: Text(
            replyData['text'] ?? 'Message',
            style: TextStyle(
              fontSize: 12,
              color: isMe
                  ? Colors.white.withValues(alpha: 0.8)
                  : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }

  Widget _buildReplyPreview(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyToMessage!.senderId == _auth.currentUser!.uid ? 'yourself' : widget.otherUser.name}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _replyToMessage!.text ?? 'Message',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close,
                color: isDarkMode ? Colors.grey[600] : Colors.grey),
            onPressed: () {
              setState(() {
                _replyToMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDarkMode) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _conversationId != null 
          ? _firestore
              .collection('conversations')
              .doc(_conversationId!)
              .snapshots()
          : Stream.empty(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final isTyping = data['isTyping']?[widget.otherUser.uid] ?? false;
        
        if (!isTyping) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundImage: widget.otherUser.profileImageUrl != null
                    ? CachedNetworkImageProvider(widget.otherUser.profileImageUrl!)
                    : null,
                child: widget.otherUser.profileImageUrl == null
                    ? Text(widget.otherUser.name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 10))
                    : null,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildTypingDot(0),
                    const SizedBox(width: 4),
                    _buildTypingDot(1),
                    const SizedBox(width: 4),
                    _buildTypingDot(2),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.3 + (value * 0.7)),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {
        setState(() {});
      },
    );
  }

  Widget _buildMessageInput(bool isDarkMode) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.add_circle_outline,
                color: Theme.of(context).primaryColor),
            onPressed: _showAttachmentOptions,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              autofocus: false,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: 'Message...',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.grey[600] : Colors.grey,
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                suffixIcon: _messageController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.send,
                          color: Theme.of(context).primaryColor,
                        ),
                        onPressed: _sendMessage,
                      )
                    : null,
              ),
              onChanged: (text) {
                setState(() {
                  _updateTypingStatus(text.isNotEmpty);
                });
              },
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  _sendMessage();
                }
              },
              onTap: () {
                // Ensure keyboard stays open
                if (!_messageFocusNode.hasFocus) {
                  FocusScope.of(context).requestFocus(_messageFocusNode);
                }
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.camera_alt_outlined,
                color: Theme.of(context).primaryColor),
            onPressed: _takePhoto,
          ),
          IconButton(
            icon: Icon(Icons.mic_outlined,
                color: Theme.of(context).primaryColor),
            onPressed: _recordVoice,
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToBottomButton() {
    return Positioned(
      bottom: 80,
      right: 16,
      child: AnimatedOpacity(
        opacity: _showScrollButton ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: FloatingActionButton.small(
          onPressed: () {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          },
          backgroundColor: Theme.of(context).primaryColor,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              if (_unreadCount > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChat(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: widget.otherUser.profileImageUrl != null
                ? CachedNetworkImageProvider(widget.otherUser.profileImageUrl!)
                : null,
            child: widget.otherUser.profileImageUrl == null
                ? Text(
                    widget.otherUser.name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 32),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation with ${widget.otherUser.name}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to begin chatting',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[600] : Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _messageController.text = 'Hey ${widget.otherUser.name.split(' ')[0]}! 👋';
              _sendMessage();
            },
            icon: const Icon(Icons.waving_hand),
            label: const Text('Say Hello'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _conversationId == null) return;
    
    final text = _messageController.text.trim();
    final replyToId = _replyToMessage?.id;
    
    _messageController.clear();
    setState(() {
      _replyToMessage = null;
    });
    _updateTypingStatus(false);
    
    // Haptic feedback for sending
    HapticFeedback.lightImpact();
    
    try {
      final messageDoc = await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .add({
        'senderId': _auth.currentUser!.uid,
        'receiverId': widget.otherUser.uid,
        'chatId': _conversationId,
        'text': text,
        'type': MessageType.text.index,
        'status': MessageStatus.sent.index,
        'timestamp': FieldValue.serverTimestamp(),
        'replyToMessageId': replyToId,
        'isEdited': false,
      });
      
      await _firestore.collection('conversations').doc(_conversationId!).update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': _auth.currentUser!.uid,
        'unreadCount.${widget.otherUser.uid}': FieldValue.increment(1),
      });
      
      // Send push notification to the other user
      final currentUserName = _auth.currentUser!.displayName ?? 
                             _auth.currentUser!.email?.split('@')[0] ?? 
                             'Someone';
      
      NotificationService().sendMessageNotification(
        recipientToken: widget.otherUser.fcmToken ?? '',
        senderName: currentUserName,
        message: text,
        conversationId: _conversationId,
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  void _updateTypingStatus(bool isTyping) {
    if (_conversationId == null) return;
    
    _typingTimer?.cancel();
    
    if (isTyping != _isTyping) {
      _isTyping = isTyping;
      _firestore.collection('conversations').doc(_conversationId!).update({
        'isTyping.${_auth.currentUser!.uid}': isTyping,
      });
    }
    
    if (isTyping) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _updateTypingStatus(false);
      });
    }
  }

  void _markMessagesAsRead() async {
    if (_conversationId == null) return;
    
    try {
      final batch = _firestore.batch();
      
      // Use orderBy instead of multiple where clauses to avoid index requirement
      // This is more efficient and doesn't require a composite index
      final messages = await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .where('receiverId', isEqualTo: _auth.currentUser!.uid)
          .get();
      
      // Filter in memory for unread messages
      final unreadMessages = messages.docs.where((doc) {
        final data = doc.data();
        final status = data['status'] ?? 0;
        return status < MessageStatus.read.index;
      }).toList();
      
      for (var doc in unreadMessages) {
        batch.update(doc.reference, {'status': MessageStatus.read.index});
      }
      
      if (unreadMessages.isNotEmpty) {
        batch.update(
          _firestore.collection('conversations').doc(_conversationId!),
          {'unreadCount.${_auth.currentUser!.uid}': 0},
        );
      }
      
      if (unreadMessages.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      // Only log non-critical errors, don't show to user
      print('Error marking messages as read: $e');
      // Silently fail - this is not critical for chat functionality
    }
  }

  void _showMessageOptions(MessageModel message, bool isMe) {
    HapticFeedback.lightImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _replyToMessage = message;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.emoji_emotions_outlined),
                title: const Text('React'),
                onTap: () {
                  Navigator.pop(context);
                  _showReactionPicker(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: message.text ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
              if (isMe) ...[
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(context);
                    _editMessage(message);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(message);
                  },
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showReactionPicker(MessageModel message) {
    final reactions = ['❤️', '😂', '😮', '😢', '😡', '👍', '👎'];
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.all(8),
          content: Wrap(
            children: reactions.map((reaction) {
              return IconButton(
                icon: Text(reaction, style: const TextStyle(fontSize: 24)),
                onPressed: () {
                  Navigator.pop(context);
                  _addReaction(message, reaction);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _addReaction(MessageModel message, String reaction) async {
    if (_conversationId == null) return;
    
    try {
      final messageRef = _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .doc(message.id);
      
      await messageRef.update({
        'reactions': FieldValue.arrayUnion([reaction]),
      });
    } catch (e) {
      print('Error adding reaction: $e');
    }
  }

  void _editMessage(MessageModel message) {
    final controller = TextEditingController(text: message.text);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextField(
            controller: controller,
            maxLines: null,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter new message',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                
                try {
                  await _firestore
                      .collection('conversations')
                      .doc(_conversationId!)
                      .collection('messages')
                      .doc(message.id)
                      .update({
                    'text': controller.text,
                    'isEdited': true,
                    'editedAt': FieldValue.serverTimestamp(),
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to edit message: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteMessage(MessageModel message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Are you sure you want to delete this message?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                
                try {
                  // First, delete the message
                  await _firestore
                      .collection('conversations')
                      .doc(_conversationId!)
                      .collection('messages')
                      .doc(message.id)
                      .delete();
                  
                  // Small delay to ensure deletion is processed
                  await Future.delayed(const Duration(milliseconds: 100));
                  
                  // Get ALL remaining messages to find the actual last one
                  final allMessages = await _firestore
                      .collection('conversations')
                      .doc(_conversationId!)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .get();
                  
                  print('Remaining messages count: ${allMessages.docs.length}');
                  
                  // Update the conversation's lastMessage fields
                  if (allMessages.docs.isNotEmpty) {
                    // Find the most recent message
                    final lastMessageDoc = allMessages.docs.first;
                    final lastMessageData = lastMessageDoc.data();
                    
                    print('Last message data: $lastMessageData');
                    
                    // Determine the last message text based on message type
                    String lastMessageText = '';
                    final messageType = lastMessageData['type'] ?? 0;
                    
                    if (messageType == MessageType.text.index) {
                      lastMessageText = lastMessageData['text'] ?? '';
                    } else if (messageType == MessageType.image.index) {
                      lastMessageText = '📷 Photo';
                    } else if (messageType == MessageType.video.index) {
                      lastMessageText = '📹 Video';
                    } else if (messageType == MessageType.audio.index) {
                      lastMessageText = '🎵 Audio';
                    } else if (messageType == MessageType.file.index) {
                      lastMessageText = '📎 File';
                    } else {
                      lastMessageText = lastMessageData['text'] ?? '';
                    }
                    
                    print('Updating conversation with last message: $lastMessageText');
                    
                    // Force update with merge to ensure it happens
                    await _firestore
                        .collection('conversations')
                        .doc(_conversationId!)
                        .set({
                      'lastMessage': lastMessageText,
                      'lastMessageTime': lastMessageData['timestamp'] ?? FieldValue.serverTimestamp(),
                      'lastMessageSenderId': lastMessageData['senderId'],
                    }, SetOptions(merge: true));
                    
                    print('Conversation updated successfully');
                  } else {
                    print('No messages left, clearing conversation');
                    
                    // No messages left, clear the last message fields
                    await _firestore
                        .collection('conversations')
                        .doc(_conversationId!)
                        .set({
                      'lastMessage': '',
                      'lastMessageTime': FieldValue.serverTimestamp(),
                      'lastMessageSenderId': '',
                    }, SetOptions(merge: true));
                  }
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message deleted'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  print('Error deleting message: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete message: $e')),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showAttachmentOptions() {
    HapticFeedback.lightImpact();
    
    // Keep keyboard focus while showing attachment options
    final hadFocus = _messageFocusNode.hasFocus;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentOption(
                    Icons.image,
                    'Gallery',
                    Colors.purple,
                    _pickImage,
                  ),
                  _buildAttachmentOption(
                    Icons.camera_alt,
                    'Camera',
                    Colors.red,
                    _takePhoto,
                  ),
                  _buildAttachmentOption(
                    Icons.location_on,
                    'Location',
                    Colors.green,
                    _shareLocation,
                  ),
                  _buildAttachmentOption(
                    Icons.insert_drive_file,
                    'File',
                    Colors.blue,
                    _pickFile,
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _pickImage() async {
    Navigator.pop(context); // Close attachment options
    
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,  // High quality to prevent blur
      maxWidth: 1920,    // Max width for optimization
      maxHeight: 1920,   // Max height for optimization
    );
    
    if (image != null) {
      _uploadAndSendImage(File(image.path));
    }
    
    // Restore focus to message input
    if (mounted) {
      FocusScope.of(context).requestFocus(_messageFocusNode);
    }
  }

  void _takePhoto() async {
    Navigator.pop(context); // Close attachment options
    
    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,  // High quality to prevent blur
      maxWidth: 1920,    // Max width for optimization
      maxHeight: 1920,   // Max height for optimization
    );
    
    if (photo != null) {
      _uploadAndSendImage(File(photo.path));
    }
    
    // Restore focus to message input
    if (mounted) {
      FocusScope.of(context).requestFocus(_messageFocusNode);
    }
  }

  void _uploadAndSendImage(File imageFile) async {
    if (_conversationId == null) return;
    
    try {
      final ref = _storage.ref().child('chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .add({
        'senderId': _auth.currentUser!.uid,
        'receiverId': widget.otherUser.uid,
        'chatId': _conversationId,
        'text': '',
        'type': MessageType.image.index,
        'mediaUrl': downloadUrl,
        'status': MessageStatus.sent.index,
        'timestamp': FieldValue.serverTimestamp(),
        'isEdited': false,
      });
      
      await _firestore.collection('conversations').doc(_conversationId!).update({
        'lastMessage': '📷 Photo',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': _auth.currentUser!.uid,
        'unreadCount.${widget.otherUser.uid}': FieldValue.increment(1),
      });
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send image: $e')),
      );
    }
  }

  void _shareLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location sharing coming soon!')),
    );
  }

  void _pickFile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File sharing coming soon!')),
    );
  }

  void _recordVoice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice messages coming soon!')),
    );
  }
  
  // REMOVED: Call feature disabled
  Future<void> _initializeCallService() async {
    // Call service removed - do nothing
  }

  void _makeVoiceCall() async {
    // REMOVED: Call feature disabled
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Call feature is currently unavailable'),
        backgroundColor: Colors.orange,
      ),
    );
  }


  void _showUserProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileViewScreen(
          userProfile: widget.otherUser,
        ),
      ),
    );
  }

  void _showChatInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        Center(
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: widget.otherUser.profileImageUrl != null
                                ? CachedNetworkImageProvider(widget.otherUser.profileImageUrl!)
                                : null,
                            child: widget.otherUser.profileImageUrl == null
                                ? Text(
                                    widget.otherUser.name[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 32),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            widget.otherUser.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        ListTile(
                          leading: const Icon(Icons.notifications_off),
                          title: const Text('Mute Notifications'),
                          trailing: Switch(
                            value: false,
                            onChanged: (value) {},
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.search),
                          title: const Text('Search in Conversation'),
                          onTap: () {
                            Navigator.pop(context);
                            _toggleSearch();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.color_lens),
                          title: const Text('Change Theme'),
                          onTap: () {},
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo),
                          title: const Text('Shared Media'),
                          onTap: () {},
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.block, color: Colors.red),
                          title: const Text(
                            'Block User',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () {},
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete, color: Colors.red),
                          title: const Text(
                            'Delete Conversation',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  // Search-related methods
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
        _searchResults.clear();
        _currentSearchIndex = 0;
      } else {
        // Request focus for search field after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(context).requestFocus(_searchFocusNode);
        });
      }
    });
  }
  
  Widget _buildSearchField(bool isDarkMode) {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      autofocus: true,
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        hintText: 'Search messages...',
        hintStyle: TextStyle(
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: (value) {
        _performSearch(value);
      },
    );
  }
  
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _searchResults.clear();
        _currentSearchIndex = 0;
      } else {
        _searchResults = _allMessages.where((message) =>
          message.text != null &&
          message.text!.toLowerCase().contains(query.toLowerCase())
        ).toList();
        _currentSearchIndex = _searchResults.isNotEmpty ? 0 : -1;
        
        // Scroll to first result if found
        if (_searchResults.isNotEmpty) {
          _scrollToMessage(_searchResults[_currentSearchIndex]);
        }
      }
    });
  }
  
  Widget _buildSearchResultsBar(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.grey[100],
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            _searchResults.isEmpty && _searchQuery.isNotEmpty
                ? 'No results'
                : _searchResults.isEmpty
                    ? 'Type to search'
                    : '${_currentSearchIndex + 1} of ${_searchResults.length}',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              fontSize: 14,
            ),
          ),
          const Spacer(),
          if (_searchResults.isNotEmpty) ...[
            IconButton(
              icon: Icon(
                Icons.keyboard_arrow_up,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              ),
              onPressed: _searchResults.isEmpty ? null : _previousSearchResult,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              ),
              onPressed: _searchResults.isEmpty ? null : _nextSearchResult,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
  
  void _previousSearchResult() {
    if (_searchResults.isEmpty) return;
    
    setState(() {
      if (_currentSearchIndex > 0) {
        _currentSearchIndex--;
      } else {
        _currentSearchIndex = _searchResults.length - 1;
      }
    });
    _scrollToMessage(_searchResults[_currentSearchIndex]);
  }
  
  void _nextSearchResult() {
    if (_searchResults.isEmpty) return;
    
    setState(() {
      if (_currentSearchIndex < _searchResults.length - 1) {
        _currentSearchIndex++;
      } else {
        _currentSearchIndex = 0;
      }
    });
    _scrollToMessage(_searchResults[_currentSearchIndex]);
  }
  
  void _scrollToMessage(MessageModel targetMessage) {
    // Find the index of the message in the full list
    final index = _allMessages.indexOf(targetMessage);
    if (index != -1) {
      // Calculate approximate scroll position (reverse list)
      final position = (_allMessages.length - index - 1) * 100.0; // Approximate item height
      
      _scrollController.animateTo(
        position.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  Widget _buildHighlightedText(String text, String query, TextStyle baseStyle) {
    if (query.isEmpty) return Text(text, style: baseStyle);
    
    final matches = query.toLowerCase();
    final textLower = text.toLowerCase();
    
    if (!textLower.contains(matches)) {
      return Text(text, style: baseStyle);
    }
    
    final spans = <TextSpan>[];
    int start = 0;
    
    while (start < text.length) {
      final index = textLower.indexOf(matches, start);
      if (index == -1) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: baseStyle,
        ));
        break;
      }
      
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: baseStyle,
        ));
      }
      
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: baseStyle.copyWith(
          backgroundColor: Colors.yellow.withValues(alpha: 0.5),
          fontWeight: FontWeight.bold,
        ),
      ));
      
      start = index + query.length;
    }
    
    return RichText(text: TextSpan(children: spans));
  }
}