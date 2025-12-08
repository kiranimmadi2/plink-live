import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../models/message_model.dart';
import '../services/notification_service.dart';
import '../services/conversation_service.dart';
import '../services/hybrid_chat_service.dart';
import '../providers/app_providers.dart';
import 'profile/profile_view_screen.dart';

class EnhancedChatScreen extends ConsumerStatefulWidget {
  final UserProfile otherUser;
  final String? initialMessage;
  final String? chatId; // Optional chatId from Live Connect

  const EnhancedChatScreen({
    super.key,
    required this.otherUser,
    this.initialMessage,
    this.chatId, // Accept chatId from Live Connect
  });

  @override
  ConsumerState<EnhancedChatScreen> createState() => _EnhancedChatScreenState();
}

class _EnhancedChatScreenState extends ConsumerState<EnhancedChatScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final ConversationService _conversationService = ConversationService();
  final HybridChatService _hybridChatService = HybridChatService();

  // Helper getter for current user ID from provider
  String? get _currentUserId => ref.read(currentUserIdProvider);

  String? _conversationId;
  bool _isTyping = false;
  bool _showEmojiPicker = false;
  Timer? _typingTimer;
  MessageModel? _replyToMessage;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showScrollButton = false;
  final int _unreadCount = 0;

  // Search related variables
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<MessageModel> _searchResults = [];
  int _currentSearchIndex = 0;
  List<MessageModel> _allMessages = [];

  // Pagination variables
  static const int _messagesPerPage = 20;
  final List<DocumentSnapshot> _loadedMessages = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMoreMessages = true;
  bool _isLoadingMore = false;

  // Single stream for user status (avoid duplicate queries)
  Stream<DocumentSnapshot>? _userStatusStream;

  // Chat theme - gradient colors for sent message bubbles
  String _currentTheme = 'default';
  static const Map<String, List<Color>> chatThemes = {
    'default': [Color(0xFF007AFF), Color(0xFF5856D6)],  // iOS Blue-Purple
    'sunset': [Color(0xFFFF6B6B), Color(0xFFFF8E53)],   // Red-Orange
    'ocean': [Color(0xFF00B4DB), Color(0xFF0083B0)],    // Cyan-Blue
    'forest': [Color(0xFF56AB2F), Color(0xFFA8E063)],   // Green gradient
    'berry': [Color(0xFF8E2DE2), Color(0xFF4A00E0)],    // Purple
    'midnight': [Color(0xFF232526), Color(0xFF414345)], // Dark gray
    'rose': [Color(0xFFFF0844), Color(0xFFFFB199)],     // Pink-Peach
    'golden': [Color(0xFFF7971E), Color(0xFFFFD200)],   // Orange-Gold
  };

  @override
  void initState() {
    super.initState();

    // Initialize single user status stream
    _userStatusStream = _firestore
        .collection('users')
        .doc(widget.otherUser.uid)
        .snapshots();
    // Verbose logging disabled for production
    // debugPrint('EnhancedChatScreen initialized with user: ${widget.otherUser.name} (${widget.otherUser.uid})');
    WidgetsBinding.instance.addObserver(this);

    // Defer non-critical initialization to after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await _initializeConversation();
      if (mounted) {
        _markMessagesAsRead();

        // Sync messages from Firebase to local database in background
        _syncMessagesInBackground();

        // If there's an initial message, set it in the message controller
        if (widget.initialMessage != null) {
          _messageController.text = widget.initialMessage!;
          FocusScope.of(context).requestFocus(_messageFocusNode);
        }

        // Listen for incoming messages for sound/vibration feedback
        _listenForIncomingMessages();
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
            .listen(
              (snapshot) {
                if (snapshot.docs.isNotEmpty && mounted) {
                  final latestMessage = snapshot.docs.first.data();
                  // Check if it's an incoming message in memory
                  if (latestMessage['receiverId'] == _currentUserId! &&
                      latestMessage['senderId'] != _currentUserId!) {
                    HapticFeedback.mediumImpact();
                  }
                }
              },
              onError: (error) {
                // Silently handle any errors
                debugPrint('Error listening for messages: $error');
              },
            );
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

    // Load more messages when user scrolls near the top (pagination)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      if (_hasMoreMessages && !_isLoadingMore && !_isSearching) {
        _loadMoreMessages();
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _conversationId == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      Query query = _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(_messagesPerPage);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMoreMessages = false;
          _isLoadingMore = false;
        });
        return;
      }

      setState(() {
        _loadedMessages.addAll(snapshot.docs);
        _lastDocument = snapshot.docs.last;
        _hasMoreMessages = snapshot.docs.length == _messagesPerPage;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('Error loading more messages: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _initializeConversation() async {
    try {
      // If chatId is provided from Live Connect, use it directly
      // Otherwise, use ConversationService to get or create conversation
      final conversationId =
          widget.chatId ??
          await _conversationService.getOrCreateConversation(widget.otherUser);

      if (mounted) {
        setState(() {
          _conversationId = conversationId;
        });
      }
      _markMessagesAsRead();

      // Load saved chat theme
      await _loadChatTheme();

      // debugPrint('EnhancedChatScreen: Conversation initialized with ID: $conversationId');
    } catch (e) {
      debugPrint('Error initializing conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading conversation: $e')),
        );
      }
    }
  }

  Future<void> _loadChatTheme() async {
    if (_conversationId == null) return;

    try {
      final doc = await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        final theme = data?['chatTheme'] as String?;
        if (theme != null && chatThemes.containsKey(theme)) {
          setState(() {
            _currentTheme = theme;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading chat theme: $e');
    }
  }

  Future<void> _saveChatTheme(String theme) async {
    if (_conversationId == null || !mounted) return;

    try {
      await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .update({'chatTheme': theme});

      setState(() {
        _currentTheme = theme;
      });
    } catch (e) {
      debugPrint('Error saving chat theme: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save theme')),
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
      backgroundColor: isDarkMode ? const Color(0xFF000000) : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_rounded,
          color: isDarkMode ? Colors.white : const Color(0xFF007AFF),
          size: 22,
        ),
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
                        backgroundImage:
                            widget.otherUser.profileImageUrl != null
                            ? CachedNetworkImageProvider(
                                widget.otherUser.profileImageUrl!,
                              )
                            : null,
                        child: widget.otherUser.profileImageUrl == null
                            ? Text(widget.otherUser.name[0].toUpperCase())
                            : null,
                      ),
                      StreamBuilder<DocumentSnapshot>(
                        stream: _userStatusStream,
                        builder: (context, snapshot) {
                          bool isOnline = false;
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final userData =
                                snapshot.data!.data() as Map<String, dynamic>;
                            final showOnlineStatus =
                                userData['showOnlineStatus'] ?? true;

                            // Only show online if user allows it and they're actually online
                            if (showOnlineStatus) {
                              isOnline = userData['isOnline'] ?? false;

                              // Check if lastSeen is recent
                              if (isOnline) {
                                final lastSeen = userData['lastSeen'];
                                if (lastSeen != null && lastSeen is Timestamp) {
                                  final lastSeenTime = lastSeen.toDate();
                                  final difference = DateTime.now().difference(
                                    lastSeenTime,
                                  );
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
                                  color: isDarkMode
                                      ? const Color(0xFF1A1A1A)
                                      : Colors.white,
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
                          widget.otherUser.name.isNotEmpty
                              ? widget.otherUser.name
                              : 'Unknown User',
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
                              : const Stream.empty(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final data =
                                  snapshot.data!.data() as Map<String, dynamic>;
                              final isTyping =
                                  data['isTyping']?[widget.otherUser.uid] ??
                                  false;

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
                              stream: _userStatusStream,
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data!.exists) {
                                  final userData =
                                      snapshot.data!.data()
                                          as Map<String, dynamic>;
                                  final showOnlineStatus =
                                      userData['showOnlineStatus'] ?? true;

                                  if (!showOnlineStatus) {
                                    return Text(
                                      'Status hidden',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDarkMode
                                            ? Colors.grey[600]
                                            : Colors.grey,
                                      ),
                                    );
                                  }

                                  var isOnline = userData['isOnline'] ?? false;

                                  // Check if lastSeen is recent
                                  if (isOnline) {
                                    final lastSeen = userData['lastSeen'];
                                    if (lastSeen != null &&
                                        lastSeen is Timestamp) {
                                      final lastSeenTime = lastSeen.toDate();
                                      final difference = DateTime.now()
                                          .difference(lastSeenTime);
                                      // Consider offline if last seen more than 5 minutes ago
                                      if (difference.inMinutes > 5) {
                                        isOnline = false;
                                      }
                                    } else {
                                      isOnline = false;
                                    }
                                  }

                                  if (isOnline) {
                                    return const Text(
                                      'Active now',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green,
                                      ),
                                    );
                                  } else if (userData['lastSeen'] != null) {
                                    final lastSeen =
                                        (userData['lastSeen'] as Timestamp)
                                            .toDate();
                                    return Text(
                                      'Active ${timeago.format(lastSeen)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDarkMode
                                            ? Colors.grey[600]
                                            : Colors.grey,
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
            icon: Icon(
              Icons.search_rounded,
              color: isDarkMode ? Colors.white70 : const Color(0xFF007AFF),
              size: 24,
            ),
            onPressed: _toggleSearch,
          ),
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close_rounded : Icons.more_horiz_rounded,
            color: isDarkMode ? Colors.white70 : const Color(0xFF007AFF),
            size: 24,
          ),
          onPressed: _isSearching ? _toggleSearch : _showChatInfo,
        ),
      ],
    );
  }

  Widget _buildMessagesList(bool isDarkMode) {
    if (_conversationId == null) {
      return _buildEmptyChatState(isDarkMode);
    }

    // Use StreamBuilder for real-time updates from Firebase with pagination
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(_messagesPerPage)
          .snapshots(),
      builder: (context, snapshot) {
        // Skip loading indicator - show content immediately for faster UX
        if (snapshot.connectionState == ConnectionState.waiting &&
            _allMessages.isEmpty) {
          return _buildEmptyChatState(isDarkMode);
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading messages',
              style: TextStyle(color: Colors.red[400]),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyChatState(isDarkMode);
        }

        // Convert Firestore documents to MessageModel
        final messages = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return MessageModel(
            id: doc.id,
            senderId: data['senderId'] as String? ?? '',
            receiverId: data['receiverId'] as String? ?? '',
            chatId: _conversationId!,
            text: data['text'] as String?,
            mediaUrl:
                data['mediaUrl'] as String? ?? data['imageUrl'] as String?,
            timestamp: data['timestamp'] != null
                ? (data['timestamp'] as Timestamp).toDate()
                : DateTime.now(),
            status: _parseMessageStatusFromInt(data['status']),
            type: _parseMessageType(data['type']),
            replyToMessageId: data['replyToMessageId'] as String?,
            isEdited: data['isEdited'] ?? false,
            reactions: data['reactions'] != null
                ? List<String>.from(data['reactions'])
                : null,
          );
        }).toList();

        // Update _allMessages after build using post-frame callback to avoid state mutation in build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _allMessages.length != messages.length) {
            _allMessages = List.from(messages);
          }
        });

        // Combine stream messages with paginated older messages
        final allDisplayMessages = <MessageModel>[...messages];

        // Add older loaded messages (avoiding duplicates)
        for (final doc in _loadedMessages) {
          final data = doc.data() as Map<String, dynamic>;
          final messageId = doc.id;
          if (!allDisplayMessages.any((m) => m.id == messageId)) {
            allDisplayMessages.add(MessageModel(
              id: messageId,
              senderId: data['senderId'] as String? ?? '',
              receiverId: data['receiverId'] as String? ?? '',
              chatId: _conversationId!,
              text: data['text'] as String?,
              mediaUrl: data['mediaUrl'] as String? ?? data['imageUrl'] as String?,
              timestamp: data['timestamp'] != null
                  ? (data['timestamp'] as Timestamp).toDate()
                  : DateTime.now(),
              status: _parseMessageStatusFromInt(data['status']),
              type: _parseMessageType(data['type']),
              replyToMessageId: data['replyToMessageId'] as String?,
              isEdited: data['isEdited'] ?? false,
              reactions: data['reactions'] != null
                  ? List<String>.from(data['reactions'])
                  : null,
            ));
          }
        }

        // Sort by timestamp descending
        allDisplayMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return _buildMessageListView(isDarkMode, allDisplayMessages);
      },
    );
  }

  // Empty chat state with premium iOS-style illustration
  Widget _buildEmptyChatState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Premium avatar with glow effect
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: isDarkMode
                  ? const Color(0xFF1C1C1E)
                  : const Color(0xFFE5E5EA),
              backgroundImage: widget.otherUser.profileImageUrl != null
                  ? CachedNetworkImageProvider(
                      widget.otherUser.profileImageUrl!,
                    )
                  : null,
              child: widget.otherUser.profileImageUrl == null
                  ? Text(
                      widget.otherUser.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF007AFF),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.otherUser.name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // Helper to parse message type
  MessageType _parseMessageType(dynamic type) {
    if (type == null) return MessageType.text;
    if (type is int) {
      return MessageType.values[type.clamp(0, MessageType.values.length - 1)];
    }
    return MessageType.text;
  }

  // Helper to parse message status from int
  MessageStatus _parseMessageStatusFromInt(dynamic status) {
    if (status == null) return MessageStatus.sent;
    if (status is int) {
      return MessageStatus.values[status.clamp(
        0,
        MessageStatus.values.length - 1,
      )];
    }
    return MessageStatus.sent;
  }

  // Helper to parse message status from string
  // ignore: unused_element
  MessageStatus _parseMessageStatus(String? status) {
    switch (status) {
      case 'sending':
        return MessageStatus.sending;
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }

  Widget _buildMessageListView(bool isDarkMode, List<MessageModel> messages) {
    // Filter messages if searching
    final displayMessages = _isSearching && _searchQuery.isNotEmpty
        ? messages
              .where(
                (msg) =>
                    msg.text != null &&
                    msg.text!.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList()
        : messages;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Loading indicator for pagination
          if (_isLoadingMore)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: displayMessages.length,
              itemBuilder: (context, index) {
                final message = displayMessages[index];
                final isMe = message.senderId == _currentUserId!;
                final showAvatar =
                    !isMe &&
                    (index == displayMessages.length - 1 ||
                        displayMessages[index + 1].senderId !=
                            message.senderId);

                final isHighlighted =
                    _isSearching &&
                    _searchResults.contains(message) &&
                    _searchResults.indexOf(message) == _currentSearchIndex;

                // Check if we need to show date separator
                Widget? dateSeparator;
                if (index == displayMessages.length - 1 ||
                    !_isSameDay(
                      message.timestamp,
                      displayMessages[index + 1].timestamp,
                    )) {
                  dateSeparator = _buildDateSeparator(
                    message.timestamp,
                    isDarkMode,
                  );
                }

                return Column(
                  children: [
                    if (dateSeparator != null) dateSeparator,
                    _buildMessageBubble(
                      message,
                      isMe,
                      showAvatar,
                      isDarkMode,
                      isHighlighted: isHighlighted,
                      searchQuery: _isSearching ? _searchQuery : null,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Check if two dates are the same day
  bool _isSameDay(DateTime? date1, DateTime? date2) {
    if (date1 == null || date2 == null) return false;
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Build date separator widget - Premium iOS style
  Widget _buildDateSeparator(DateTime? date, bool isDarkMode) {
    if (date == null) return const SizedBox.shrink();

    String dateText;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == yesterday) {
      dateText = 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      // Day of the week for last 7 days
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      dateText = days[date.weekday - 1];
    } else {
      // Full date for older messages - iOS style format
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      dateText = '${months[date.month - 1]} ${date.day}, ${date.year}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF1C1C1E).withValues(alpha: 0.8)
                : const Color(0xFF000000).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? const Color(0xFF8E8E93)
                  : const Color(0xFF8E8E93),
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
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
    // Format timestamp - show actual time
    String formattedTime = _formatMessageTime(message.timestamp);

    // Get theme gradient colors for sent messages
    final sentGradientColors = chatThemes[_currentTheme] ?? chatThemes['default']!;

    // Received message background - subtle glass effect
    final receivedBgColor = isDarkMode
        ? const Color(0xFF1C1C1E) // iOS dark mode gray
        : const Color(0xFFE9E9EB); // iOS light mode gray

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message, isMe),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: Opacity(opacity: value, child: child),
          );
        },
        child: Padding(
          padding: EdgeInsets.only(
            bottom: 6,
            left: isMe ? 60 : 0,
            right: isMe ? 0 : 60,
          ),
          child: Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe && showAvatar)
                Container(
                  margin: const EdgeInsets.only(right: 8, bottom: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
                    backgroundImage: widget.otherUser.profileImageUrl != null
                        ? CachedNetworkImageProvider(
                            widget.otherUser.profileImageUrl!,
                          )
                        : null,
                    child: widget.otherUser.profileImageUrl == null
                        ? Text(
                            widget.otherUser.name[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF007AFF),
                            ),
                          )
                        : null,
                  ),
                )
              else if (!isMe)
                const SizedBox(width: 40),
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (message.replyToMessageId != null)
                      _buildReplyBubble(
                        message.replyToMessageId!,
                        isMe,
                        isDarkMode,
                      ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: message.type == MessageType.image ? 4 : 14,
                        vertical: message.type == MessageType.image ? 4 : 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: isMe
                            ? LinearGradient(
                                colors: sentGradientColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isMe ? null : receivedBgColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                        border: isHighlighted
                            ? Border.all(color: Colors.orange, width: 2)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: isMe
                                ? sentGradientColors[0].withValues(alpha: 0.25)
                                : Colors.black.withValues(alpha:
                                    isDarkMode ? 0.2 : 0.06,
                                  ),
                            blurRadius: isMe ? 12 : 6,
                            offset: const Offset(0, 3),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.type == MessageType.image &&
                              message.mediaUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: CachedNetworkImage(
                                imageUrl: message.mediaUrl!,
                                fit: BoxFit.cover,
                                memCacheWidth: 400,
                                memCacheHeight: 400,
                                placeholder: (context, url) => Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.grey[800]
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        const Color(
                                          0xFF007AFF,
                                        ).withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                    ),
                              ),
                            ),
                          if (message.text != null && message.text!.isNotEmpty)
                            Padding(
                              padding: message.type == MessageType.image
                                  ? const EdgeInsets.only(
                                      left: 10,
                                      right: 10,
                                      top: 8,
                                      bottom: 4,
                                    )
                                  : EdgeInsets.zero,
                              child:
                                  searchQuery != null && searchQuery.isNotEmpty
                                  ? _buildHighlightedText(
                                      message.text!,
                                      searchQuery,
                                      TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : (isDarkMode
                                                  ? Colors.white
                                                  : const Color(0xFF1C1C1E)),
                                        fontSize: 16,
                                        height: 1.35,
                                        letterSpacing: -0.2,
                                      ),
                                    )
                                  : Text(
                                      message.text!,
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : (isDarkMode
                                                  ? Colors.white
                                                  : const Color(0xFF1C1C1E)),
                                        fontSize: 16,
                                        height: 1.35,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                            ),
                          Padding(
                            padding: message.type == MessageType.image
                                ? const EdgeInsets.only(
                                    left: 10,
                                    right: 10,
                                    bottom: 4,
                                  )
                                : const EdgeInsets.only(top: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (message.isEdited == true) ...[
                                  Text(
                                    'edited ',
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white.withValues(alpha: 0.55)
                                          : (isDarkMode
                                                ? Colors.grey[500]
                                                : Colors.grey[600]),
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                Text(
                                  formattedTime,
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white.withValues(alpha: 0.65)
                                        : (isDarkMode
                                              ? Colors.grey[500]
                                              : Colors.grey[600]),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  _buildMessageStatusIcon(message.status, isMe),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (message.reactions != null &&
                        message.reactions!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF2C2C2E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          message.reactions!.join(' '),
                          style: const TextStyle(fontSize: 16),
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

  // Format message time - always show actual time (HH:MM AM/PM)
  String _formatMessageTime(DateTime? timestamp) {
    if (timestamp == null) return '';

    // Always show actual time like WhatsApp/iMessage
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  // Build message status icon with premium visuals
  Widget _buildMessageStatusIcon(MessageStatus status, bool isMe) {
    IconData icon;
    Color color;

    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withValues(alpha: 0.5),
            ),
          ),
        );
      case MessageStatus.sent:
        icon = Icons.check_rounded;
        color = Colors.white.withValues(alpha: 0.65);
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all_rounded;
        color = Colors.white.withValues(alpha: 0.65);
        break;
      case MessageStatus.read:
        icon = Icons.done_all_rounded;
        color = const Color(0xFF34C759); // iOS green for read
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline_rounded;
        color = const Color(0xFFFF3B30); // iOS red
        break;
    }

    return Icon(icon, size: 14, color: color);
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
            color:
                (isMe
                        ? Theme.of(context).primaryColor
                        : (isDarkMode ? Colors.grey[900]! : Colors.grey[200]!))
                    .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: Theme.of(context).primaryColor, width: 3),
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
                  'Replying to ${_replyToMessage!.senderId == _currentUserId! ? 'yourself' : widget.otherUser.name}',
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
            icon: Icon(
              Icons.close,
              color: isDarkMode ? Colors.grey[600] : Colors.grey,
            ),
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
          : const Stream.empty(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final isTyping = data['isTyping']?[widget.otherUser.uid] ?? false;

        if (!isTyping) return const SizedBox.shrink();

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isDarkMode
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFFE5E5EA),
                backgroundImage: widget.otherUser.profileImageUrl != null
                    ? CachedNetworkImageProvider(
                        widget.otherUser.profileImageUrl!,
                      )
                    : null,
                child: widget.otherUser.profileImageUrl == null
                    ? Text(
                        widget.otherUser.name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF007AFF),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF1C1C1E)
                      : const Color(0xFFE9E9EB),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTypingDot(0, isDarkMode),
                    const SizedBox(width: 3),
                    _buildTypingDot(1, isDarkMode),
                    const SizedBox(width: 3),
                    _buildTypingDot(2, isDarkMode),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypingDot(int index, bool isDarkMode) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 150)),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color:
                (isDarkMode ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93))
                    .withValues(alpha: value),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildMessageInput(bool isDarkMode) {
    final hasText = _messageController.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Input Area - Premium iMessage style
        Container(
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 8,
            bottom: _showEmojiPicker
                ? 8
                : MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF000000)
                : const Color(0xFFF6F6F6),
            border: Border(
              top: BorderSide(
                color: isDarkMode
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFFE5E5EA),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment button - iOS style
                GestureDetector(
                  onTap: _showAttachmentOptions,
                  child: Container(
                    height: 36,
                    width: 36,
                    margin: const EdgeInsets.only(bottom: 2, right: 4),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF1C1C1E)
                          : const Color(0xFFE5E5EA),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: isDarkMode
                          ? const Color(0xFF007AFF)
                          : const Color(0xFF007AFF),
                      size: 22,
                    ),
                  ),
                ),
                // Camera button - iOS style
                GestureDetector(
                  onTap: _takePhoto,
                  child: Container(
                    height: 36,
                    width: 36,
                    margin: const EdgeInsets.only(bottom: 2, right: 6),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                      size: 24,
                    ),
                  ),
                ),
                // Message input field - Premium rounded design
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF1C1C1E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDarkMode
                            ? const Color(0xFF38383A)
                            : const Color(0xFFE5E5EA),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _messageFocusNode,
                            maxLines: 5,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            autofocus: false,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF1C1C1E),
                              fontSize: 17,
                              height: 1.3,
                              letterSpacing: -0.4,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Message',
                              hintStyle: TextStyle(
                                color: isDarkMode
                                    ? const Color(0xFF8E8E93)
                                    : const Color(0xFF8E8E93),
                                fontSize: 17,
                                letterSpacing: -0.4,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            onChanged: (text) {
                              setState(() {
                                _updateTypingStatus(text.isNotEmpty);
                              });
                            },
                            onTap: () {
                              if (_showEmojiPicker) {
                                setState(() => _showEmojiPicker = false);
                              }
                            },
                          ),
                        ),
                        // Emoji button - iOS style
                        Padding(
                          padding: const EdgeInsets.only(right: 4, bottom: 6),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showEmojiPicker = !_showEmojiPicker;
                                if (_showEmojiPicker) {
                                  _messageFocusNode.unfocus();
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _showEmojiPicker
                                    ? const Color(0xFF007AFF).withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                _showEmojiPicker
                                    ? Icons.keyboard_rounded
                                    : Icons.emoji_emotions_outlined,
                                color: _showEmojiPicker
                                    ? const Color(0xFF007AFF)
                                    : (isDarkMode
                                          ? const Color(0xFF8E8E93)
                                          : const Color(0xFF8E8E93)),
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Send / Mic button - Premium animated
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                  child: hasText
                      ? GestureDetector(
                          key: const ValueKey('send'),
                          onTap: _sendMessage,
                          child: Builder(
                            builder: (context) {
                              final themeColors = chatThemes[_currentTheme] ?? chatThemes['default']!;
                              return Container(
                                height: 36,
                                width: 36,
                                margin: const EdgeInsets.only(bottom: 2),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: themeColors,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: themeColors[0].withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              );
                            },
                          ),
                        )
                      : GestureDetector(
                          key: const ValueKey('mic'),
                          onTap: _recordVoice,
                          child: Container(
                            height: 36,
                            width: 36,
                            margin: const EdgeInsets.only(bottom: 2),
                            child: Icon(
                              Icons.mic_rounded,
                              color: isDarkMode
                                  ? Colors.grey[500]
                                  : Colors.grey[600],
                              size: 26,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        // Emoji Picker - Premium styling with dynamic height
        if (_showEmojiPicker)
          Builder(
            builder: (context) {
              // Calculate dynamic height based on screen size (max 35% of screen height)
              final screenHeight = MediaQuery.of(context).size.height;
              final emojiPickerHeight = (screenHeight * 0.35).clamp(200.0, 350.0);

              return Container(
                height: emojiPickerHeight,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF000000)
                      : const Color(0xFFF6F6F6),
                  border: Border(
                    top: BorderSide(
                      color: isDarkMode
                          ? const Color(0xFF1C1C1E)
                          : const Color(0xFFE5E5EA),
                      width: 0.5,
                    ),
                  ),
                ),
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    _messageController.text += emoji.emoji;
                    _messageController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _messageController.text.length),
                    );
                    setState(() {});
                  },
                  onBackspacePressed: () {
                    _messageController.text = _messageController.text.characters
                        .skipLast(1)
                        .toString();
                    setState(() {});
                  },
                  config: Config(
                    height: emojiPickerHeight,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  columns: 8,
                  emojiSizeMax: 32,
                  verticalSpacing: 0,
                  horizontalSpacing: 0,
                  gridPadding: const EdgeInsets.symmetric(horizontal: 8),
                  backgroundColor: isDarkMode
                      ? const Color(0xFF000000)
                      : const Color(0xFFF6F6F6),
                  recentsLimit: 28,
                  noRecents: Text(
                    'No Recents',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                  loadingIndicator: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF007AFF),
                    ),
                  ),
                  buttonMode: ButtonMode.MATERIAL,
                ),
                skinToneConfig: const SkinToneConfig(),
                categoryViewConfig: CategoryViewConfig(
                  initCategory: Category.RECENT,
                  backgroundColor: isDarkMode
                      ? const Color(0xFF000000)
                      : const Color(0xFFF6F6F6),
                  indicatorColor: const Color(0xFF007AFF),
                  iconColor: const Color(0xFF8E8E93),
                  iconColorSelected: const Color(0xFF007AFF),
                  categoryIcons: const CategoryIcons(),
                ),
                bottomActionBarConfig: BottomActionBarConfig(
                  backgroundColor: isDarkMode
                      ? const Color(0xFF000000)
                      : const Color(0xFFF6F6F6),
                  buttonColor: const Color(0xFF007AFF),
                  buttonIconColor: Colors.white,
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: isDarkMode
                      ? const Color(0xFF1C1C1E)
                      : Colors.white,
                  buttonIconColor: const Color(0xFF007AFF),
                ),
              ),
            ),
          );
        },
      ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        width: 40,
        margin: const EdgeInsets.only(bottom: 2),
        child: Icon(
          icon,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          size: 24,
        ),
      ),
    );
  }

  Widget _buildScrollToBottomButton() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      bottom: 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: _showScrollButton ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: () {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          },
          child: Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF1C1C1E).withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.95),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: isDarkMode
                    ? const Color(0xFF38383A)
                    : const Color(0xFFE5E5EA),
                width: 0.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF007AFF),
                  size: 24,
                ),
                if (_unreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Removed: Empty chat state UI with "Say Hello" button
  // Now returns an empty widget instead

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _conversationId == null) {
      return;
    }

    final text = _messageController.text.trim();
    final replyToMessage = _replyToMessage;

    _messageController.clear();
    setState(() {
      _replyToMessage = null;
    });
    _updateTypingStatus(false);

    // Haptic feedback for sending
    HapticFeedback.lightImpact();

    try {
      // Use HybridChatService - saves to local SQLite first (instant!)
      // then uploads to Firebase for delivery
      await _hybridChatService.sendMessage(
        conversationId: _conversationId!,
        receiverId: widget.otherUser.uid,
        text: text,
        replyToMessageId: replyToMessage?.id,
        replyToText: replyToMessage?.text,
        replyToSenderId: replyToMessage?.senderId,
      );

      // Reload messages to show the new message instantly
      setState(() {});

      // Send push notification to the other user
      final currentUserProfile = ref.read(currentUserProfileProvider).valueOrNull;
      final currentUserName = currentUserProfile?.name ?? 'Someone';

      NotificationService().sendMessageNotification(
        recipientToken: widget.otherUser.fcmToken ?? '',
        senderName: currentUserName,
        message: text,
        conversationId: _conversationId,
      );
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }

  void _updateTypingStatus(bool isTyping) {
    if (_conversationId == null) return;

    _typingTimer?.cancel();

    if (isTyping != _isTyping) {
      _isTyping = isTyping;
      _firestore.collection('conversations').doc(_conversationId!).update({
        'isTyping.${_currentUserId!}': isTyping,
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
      // Use HybridChatService - updates both local DB and Firebase
      await _hybridChatService.markMessagesAsRead(_conversationId!);

      // Update conversation unread count
      await _firestore.collection('conversations').doc(_conversationId!).update(
        {'unreadCount.${_currentUserId!}': 0},
      );
    } catch (e) {
      // Only log non-critical errors, don't show to user
      debugPrint('Error marking messages as read: $e');
      // Silently fail - this is not critical for chat functionality
    }
  }

  // Sync messages from Firebase to local database in background
  Future<void> _syncMessagesInBackground() async {
    if (_conversationId == null) return;

    try {
      await _hybridChatService.syncMessages(_conversationId!);

      // Refresh UI with synced messages
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Non-fatal - messages will sync next time
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
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
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
    if (_conversationId == null || !mounted) return;

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
      debugPrint('Error adding reaction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add reaction')),
        );
      }
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
            decoration: const InputDecoration(hintText: 'Enter new message'),
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
                  if (!context.mounted) return;
                  // ignore: use_build_context_synchronously
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

                  debugPrint('Remaining messages count: ${allMessages.docs.length}');

                  // Update the conversation's lastMessage fields
                  if (allMessages.docs.isNotEmpty) {
                    // Find the most recent message
                    final lastMessageDoc = allMessages.docs.first;
                    final lastMessageData = lastMessageDoc.data();

                    debugPrint('Last message data: $lastMessageData');

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

                    debugPrint(
                      'Updating conversation with last message: $lastMessageText',
                    );

                    // Force update with merge to ensure it happens
                    await _firestore
                        .collection('conversations')
                        .doc(_conversationId!)
                        .set({
                          'lastMessage': lastMessageText,
                          'lastMessageTime':
                              lastMessageData['timestamp'] ??
                              FieldValue.serverTimestamp(),
                          'lastMessageSenderId': lastMessageData['senderId'],
                        }, SetOptions(merge: true));

                    debugPrint('Conversation updated successfully');
                  } else {
                    debugPrint('No messages left, clearing conversation');

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
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message deleted'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error deleting message: $e');
                  if (mounted) {
                    // ignore: use_build_context_synchronously
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
    final hadFocus = _messageFocusNode.hasFocus; // ignore: unused_local_variable

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
      imageQuality: 95, // High quality to prevent blur
      maxWidth: 1920, // Max width for optimization
      maxHeight: 1920, // Max height for optimization
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
      imageQuality: 95, // High quality to prevent blur
      maxWidth: 1920, // Max width for optimization
      maxHeight: 1920, // Max height for optimization
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
    if (_conversationId == null || !mounted) return;

    try {
      final ref = _storage.ref().child(
        'chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;

      if (!mounted) return;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (!mounted) return;

      await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .add({
            'senderId': _currentUserId!,
            'receiverId': widget.otherUser.uid,
            'chatId': _conversationId,
            'text': '',
            'type': MessageType.image.index,
            'mediaUrl': downloadUrl,
            'status': MessageStatus.sent.index,
            'timestamp': FieldValue.serverTimestamp(),
            'isEdited': false,
          });

      await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .update({
            'lastMessage': '📷 Photo',
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastMessageSenderId': _currentUserId!,
            'unreadCount.${widget.otherUser.uid}': FieldValue.increment(1),
          });
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send image: $e')));
    }
  }

  void _shareLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location sharing coming soon!')),
    );
  }

  void _pickFile() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('File sharing coming soon!')));
  }

  void _recordVoice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice messages coming soon!')),
    );
  }

  void _showUserProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileViewScreen(userProfile: widget.otherUser),
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
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
                            backgroundImage:
                                widget.otherUser.profileImageUrl != null
                                ? CachedNetworkImageProvider(
                                    widget.otherUser.profileImageUrl!,
                                  )
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
                          trailing: Switch(value: false, onChanged: (value) {}),
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
                          onTap: _showThemeSelector,
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
        _searchResults = _allMessages
            .where(
              (message) =>
                  message.text != null &&
                  message.text!.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
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
      final position =
          (_allMessages.length - index - 1) * 100.0; // Approximate item height

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
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }

      if (index > start) {
        spans.add(
          TextSpan(text: text.substring(start, index), style: baseStyle),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: baseStyle.copyWith(
            backgroundColor: Colors.yellow.withValues(alpha: 0.5),
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + query.length;
    }

    return RichText(text: TextSpan(children: spans));
  }

  void _showThemeSelector() {
    Navigator.pop(context); // Close the chat info sheet first

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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Chat Theme',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: chatThemes.length,
                  itemBuilder: (context, index) {
                    final themeName = chatThemes.keys.elementAt(index);
                    final themeColors = chatThemes[themeName]!;
                    final isSelected = themeName == _currentTheme;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _saveChatTheme(themeName);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: themeColors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: themeColors[0].withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 28,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _capitalizeThemeName(themeName),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  String _capitalizeThemeName(String name) {
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1);
  }
}
