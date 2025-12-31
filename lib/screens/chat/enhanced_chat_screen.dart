import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_text_styles.dart';
import '../../res/config/app_assets.dart';
import '../../widgets/other widgets/glass_text_field.dart';
import '../../models/user_profile.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../models/message_model.dart';
import '../../services/notification_service.dart';
import '../../services/chat services/conversation_service.dart';
import '../../services/hybrid_chat_service.dart';
import '../../providers/other providers/app_providers.dart';
import '../call/voice_call_screen.dart';
import '../../res/utils/snackbar_helper.dart';

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

  // Cached user ID for use during dispose (when ref is no longer available)
  String? _cachedUserId;

  String? _conversationId;
  bool _isTyping = false;
  bool _showEmojiPicker = false;
  Timer? _typingTimer;
  MessageModel? _replyToMessage;
  MessageModel? _editingMessage;

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

  // Voice recording variables
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  bool _isRecording = false;
  bool _isRecorderInitialized = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;

  // Voice playback variables
  final FlutterSoundPlayer _audioPlayer = FlutterSoundPlayer();
  bool _isPlayerInitialized = false;
  String? _currentlyPlayingMessageId;
  bool _isPlaying = false;
  double _playbackProgress = 0.0;
  StreamSubscription? _playerSubscription;

  @override
  void initState() {
    super.initState();

    // Cache user ID for use during dispose
    _cachedUserId = ref.read(currentUserIdProvider);

    // Initialize single user status stream
    _userStatusStream = _firestore
        .collection('users')
        .doc(widget.otherUser.uid)
        .snapshots();

    WidgetsBinding.instance.addObserver(this);

    // Initialize conversation IMMEDIATELY for faster loading
    _initializeConversation();

    _setupAnimations();
    _scrollController.addListener(_scrollListener);

    // Defer non-critical tasks to after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      _markMessagesAsRead();

      // If there's an initial message, set it in the message controller
      if (widget.initialMessage != null) {
        _messageController.text = widget.initialMessage!;
        FocusScope.of(context).requestFocus(_messageFocusNode);
      }

      // Listen for incoming messages for sound/vibration feedback
      _listenForIncomingMessages();

      // Sync messages from Firebase to local database in background (low priority)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _syncMessagesInBackground();
      });
    });
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
                if (snapshot.docs.isNotEmpty &&
                    mounted &&
                    _currentUserId != null) {
                  final latestMessage = snapshot.docs.first.data();
                  // Check if it's an incoming message in memory
                  if (latestMessage['receiverId'] == _currentUserId &&
                      latestMessage['senderId'] != _currentUserId) {
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
    } catch (e) {
      debugPrint('Error initializing conversation: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Error loading conversation: $e');
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
    // Dispose audio recorder
    _recordingTimer?.cancel();
    _audioRecorder.closeRecorder();
    // Dispose audio player
    _playerSubscription?.cancel();
    _audioPlayer.closePlayer();
    // Update typing status directly without using ref (which is disposed)
    _clearTypingStatusOnDispose();
    super.dispose();
  }

  void _clearTypingStatusOnDispose() {
    // Only clear if we have both conversation and user IDs cached
    if (_conversationId == null || _cachedUserId == null) return;

    _firestore
        .collection('conversations')
        .doc(_conversationId!)
        .update({'isTyping.$_cachedUserId': false})
        .catchError((_) {
          // Ignore errors during dispose
        });
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

    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSearching) {
          _toggleSearch();
        }
      },
      child: Scaffold(
        backgroundColor: isDarkMode ? AppColors.backgroundDark : Colors.white,
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(isDarkMode),
        body: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset(
                AppAssets.homeBackgroundImage,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),

            // Dark overlay with opacity like home screen
            Positioned.fill(
              child: Container(color: AppColors.darkOverlay(alpha: 0.6)),
            ),

            // Main content
            SafeArea(
              child: Column(
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
                  if (_editingMessage != null) _buildEditPreview(isDarkMode),
                  _buildTypingIndicator(isDarkMode),
                  _buildMessageInput(isDarkMode),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDarkMode) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 0.5,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_rounded,
          color: isDarkMode ? Colors.white : AppColors.iosBlue,
          size: 22,
        ),
        onPressed: () {
          if (_isSearching) {
            _toggleSearch();
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: _isSearching
          ? _buildSearchField(isDarkMode)
          : Row(
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.7),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundImage:
                            PhotoUrlHelper.isValidUrl(
                              widget.otherUser.profileImageUrl,
                            )
                            ? CachedNetworkImageProvider(
                                widget.otherUser.profileImageUrl!,
                              )
                            : null,
                        child:
                            !PhotoUrlHelper.isValidUrl(
                              widget.otherUser.profileImageUrl,
                            )
                            ? Text(widget.otherUser.name[0].toUpperCase())
                            : null,
                      ),
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
                                    ? AppColors.darkCard
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
                        style: AppTextStyles.bodyLarge.copyWith(
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
                                style: AppTextStyles.caption.copyWith(
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
                                    style: AppTextStyles.caption.copyWith(
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
                                  return Text(
                                    'Active now',
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.green,
                                    ),
                                  );
                                } else if (userData['lastSeen'] != null) {
                                  final lastSeen =
                                      (userData['lastSeen'] as Timestamp)
                                          .toDate();
                                  return Text(
                                    'Active ${timeago.format(lastSeen)}',
                                    style: AppTextStyles.caption.copyWith(
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
      actions: [
        if (!_isSearching) ...[
          // Video call button
          IconButton(
            icon: Icon(
              Icons.videocam_rounded,
              color: isDarkMode ? Colors.white70 : AppColors.iosBlue,
              size: 24,
            ),
            onPressed: _startVideoCall,
          ),
          // Audio call button
          IconButton(
            icon: Icon(
              Icons.call_rounded,
              color: isDarkMode ? Colors.white70 : AppColors.iosBlue,
              size: 24,
            ),
            onPressed: _startAudioCall,
          ),
        ],
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close_rounded : Icons.more_vert_rounded,
            color: isDarkMode ? Colors.white70 : AppColors.iosBlue,
            size: 24,
          ),
          onPressed: _isSearching ? _toggleSearch : _showChatInfo,
        ),
      ],
    );
  }

  Widget _buildMessagesList(bool isDarkMode) {
    if (_conversationId == null) {
      // Show minimal loading state instead of profile icon
      return const Center(child: SizedBox.shrink());
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
        // Show nothing while loading - prevents profile icon flash
        if (snapshot.connectionState == ConnectionState.waiting &&
            _allMessages.isEmpty) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading messages',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.red[400]),
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
            audioUrl: data['audioUrl'] as String?,
            audioDuration: data['audioDuration'] as int?,
            timestamp: data['timestamp'] != null
                ? (data['timestamp'] as Timestamp).toDate()
                : DateTime.now(),
            status: _parseMessageStatusFromInt(
              data['status'],
              isRead: data['read'] == true || data['isRead'] == true,
            ),
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
            allDisplayMessages.add(
              MessageModel(
                id: messageId,
                senderId: data['senderId'] as String? ?? '',
                receiverId: data['receiverId'] as String? ?? '',
                chatId: _conversationId!,
                text: data['text'] as String?,
                mediaUrl:
                    data['mediaUrl'] as String? ?? data['imageUrl'] as String?,
                audioUrl: data['audioUrl'] as String?,
                audioDuration: data['audioDuration'] as int?,
                timestamp: data['timestamp'] != null
                    ? (data['timestamp'] as Timestamp).toDate()
                    : DateTime.now(),
                status: _parseMessageStatusFromInt(
                  data['status'],
                  isRead: data['read'] == true || data['isRead'] == true,
                ),
                type: _parseMessageType(data['type']),
                replyToMessageId: data['replyToMessageId'] as String?,
                isEdited: data['isEdited'] ?? false,
                reactions: data['reactions'] != null
                    ? List<String>.from(data['reactions'])
                    : null,
              ),
            );
          }
        }

        // Sort by timestamp descending
        allDisplayMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return _buildMessageListView(isDarkMode, allDisplayMessages);
      },
    );
  }

  // Empty chat state - simple message icon
  Widget _buildEmptyChatState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Simple chat bubble icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to start the conversation',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
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

  // Helper to parse message status from int, string, or isRead field
  MessageStatus _parseMessageStatusFromInt(dynamic status, {bool? isRead}) {
    debugPrint('📩 Parsing status: $status (type: ${status.runtimeType}), isRead: $isRead');

    // If isRead is explicitly true, return read status
    if (isRead == true) {
      debugPrint('📩 Status: READ (from isRead flag)');
      return MessageStatus.read;
    }

    if (status == null) {
      debugPrint('📩 Status: SENT (null status)');
      return MessageStatus.sent;
    }

    // Handle int status
    if (status is int) {
      final result = MessageStatus.values[status.clamp(0, MessageStatus.values.length - 1)];
      debugPrint('📩 Status: $result (from int $status)');
      return result;
    }

    // Handle string status
    if (status is String) {
      MessageStatus result;
      switch (status.toLowerCase()) {
        case 'sending':
          result = MessageStatus.sending;
          break;
        case 'sent':
          result = MessageStatus.sent;
          break;
        case 'delivered':
          result = MessageStatus.delivered;
          break;
        case 'read':
          result = MessageStatus.read;
          break;
        case 'failed':
          result = MessageStatus.failed;
          break;
        default:
          result = MessageStatus.sent;
      }
      debugPrint('📩 Status: $result (from string "$status")');
      return result;
    }

    debugPrint('📩 Status: SENT (default fallback)');
    return MessageStatus.sent;
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
                final currentUserId = _currentUserId;
                final isMe =
                    currentUserId != null && message.senderId == currentUserId;
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
                ? AppColors.iosGrayDark.withValues(alpha: 0.8)
                : AppColors.backgroundDark.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? AppColors.iosGray : AppColors.iosGray,
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

    return Dismissible(
      key: Key(message.id),
      direction: DismissDirection.startToEnd, // Swipe right to reply
      confirmDismiss: (direction) async {
        // Trigger reply and don't actually dismiss
        HapticFeedback.lightImpact();
        setState(() {
          // Clear edit first - only one action at a time
          _editingMessage = null;
          _messageController.clear();
          _replyToMessage = message;
        });
        FocusScope.of(context).requestFocus(_messageFocusNode);
        return false; // Don't dismiss the message
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(
          Icons.reply,
          color: Colors.white.withValues(alpha: 0.7),
          size: 24,
        ),
      ),
      child: GestureDetector(
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
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7),
                        width: 2,
                      ),
                      // boxShadow: [
                      //   BoxShadow(
                      //     color: Colors.black.withValues(alpha: 0.15),
                      //     blurRadius: 8,
                      //     offset: const Offset(0, 2),
                      //   ),
                      // ],
                    ),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.iosBlue.withValues(
                        alpha: 0.15,
                      ),
                      backgroundImage:
                          PhotoUrlHelper.isValidUrl(
                            widget.otherUser.profileImageUrl,
                          )
                          ? CachedNetworkImageProvider(
                              widget.otherUser.profileImageUrl!,
                            )
                          : null,
                      child:
                          !PhotoUrlHelper.isValidUrl(
                            widget.otherUser.profileImageUrl,
                          )
                          ? Text(
                              widget.otherUser.name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.iosBlue,
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
                      ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isMe ? 20 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 20),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: message.type == MessageType.image
                                  ? 4
                                  : 16,
                              vertical: message.type == MessageType.image
                                  ? 4
                                  : 12,
                            ),
                            decoration: BoxDecoration(
                              gradient:
                                  isMe && message.type != MessageType.audio
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF5856D6),
                                        Color(0xFF007AFF),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,

                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isMe ? 18 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 18),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (message.type == MessageType.image &&
                                    message.mediaUrl != null)
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 180,
                                      maxWidth: 220,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: CachedNetworkImage(
                                        imageUrl: message.mediaUrl!,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 400,
                                        memCacheHeight: 400,
                                        placeholder: (context, url) => Container(
                                          width: 180,
                                          height: 150,
                                          decoration: BoxDecoration(
                                            color: isDarkMode
                                                ? Colors.grey[800]
                                                : Colors.grey[200],
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
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
                                  ),
                                // Audio message player UI
                                if (message.type == MessageType.audio &&
                                    message.audioUrl != null)
                                  _buildAudioMessagePlayer(message, isMe),
                                if (message.text != null &&
                                    message.text!.isNotEmpty)
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
                                        searchQuery != null &&
                                            searchQuery.isNotEmpty
                                        ? _buildHighlightedText(
                                            message.text!,
                                            searchQuery,
                                            TextStyle(
                                              color: isMe
                                                  ? Colors.white
                                                  : (isDarkMode
                                                        ? Colors.white
                                                        : AppColors
                                                              .iosGrayDark),
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
                                                        : AppColors
                                                              .iosGrayDark),
                                              fontSize: 16,
                                              height: 1.35,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                  ),
                                // Time and status row (skip for audio - it has its own)
                                if (message.type != MessageType.audio)
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
                                                ? Colors.white.withValues(
                                                    alpha: 0.55,
                                                  )
                                                : (isDarkMode
                                                      ? Colors.grey[500]
                                                      : Colors.grey[600]),
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                      // Time
                                      Text(
                                        _formatMessageTime(message.timestamp),
                                        style: TextStyle(
                                          color: isMe
                                              ? Colors.white.withValues(alpha: 0.55)
                                              : (isDarkMode
                                                    ? Colors.grey[500]
                                                    : Colors.grey[600]),
                                          fontSize: 11,
                                        ),
                                      ),
                                      // Status tick (only for my messages)
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
                                ? AppColors.backgroundDarkTertiary
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
  // Single tick = sent, Double tick grey = delivered, Double tick blue = read
  Widget _buildMessageStatusIcon(MessageStatus status, bool isMe) {
    debugPrint('🔵 Building status icon: $status, isMe: $isMe');
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
        // Single tick - message sent to server
        return Icon(
          Icons.check_rounded,
          size: 16,
          color: Colors.white.withValues(alpha: 0.7),
        );
      case MessageStatus.delivered:
        // Double tick grey - message delivered but not read
        return Icon(
          Icons.done_all_rounded,
          size: 16,
          color: Colors.white.withValues(alpha: 0.7),
        );
      case MessageStatus.read:
        // Double tick blue - message seen/read
        return const Icon(
          Icons.done_all_rounded,
          size: 16,
          color: Colors.blue, // Blue tick for read
        );
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: AppColors.iosRed,
        );
    }
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

        // Determine who sent the original message
        final replySenderId = replyData['senderId'] as String?;
        final bool isReplyToSelf = replySenderId == _currentUserId;
        final String replyToName = isReplyToSelf
            ? 'You'
            : widget.otherUser.name;
        final Color accentColor = isReplyToSelf
            ? Colors.purple
            : Theme.of(context).primaryColor;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: isMe
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.grey[800]?.withValues(alpha: 0.5) ??
                      Colors.grey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Colored left bar
              Container(
                width: 4,
                height: 45,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
              ),
              // Reply content
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        replyToName,
                        style: TextStyle(
                          fontSize: 12,
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        replyData['text'] ?? 'Message',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReplyPreview(bool isDarkMode) {
    final bool isReplyingToSelf = _replyToMessage!.senderId == _currentUserId;
    final Color accentColor = isReplyingToSelf
        ? Colors.purple
        : Theme.of(context).primaryColor;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.5,
        margin: const EdgeInsets.only(left: 12, bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isReplyingToSelf ? 'You' : widget.otherUser.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _replyToMessage!.text ?? 'Message',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _replyToMessage = null;
                });
              },
              child: Icon(
                Icons.close,
                size: 18,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditPreview(bool isDarkMode) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.5,
        margin: const EdgeInsets.only(left: 12, bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Editing',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _editingMessage!.text ?? 'Message',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _cancelEdit,
              child: Icon(
                Icons.close,
                size: 18,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
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
                    ? AppColors.iosGrayDark
                    : AppColors.iosGrayLight,
                backgroundImage:
                    PhotoUrlHelper.isValidUrl(widget.otherUser.profileImageUrl)
                    ? CachedNetworkImageProvider(
                        widget.otherUser.profileImageUrl!,
                      )
                    : null,
                child:
                    !PhotoUrlHelper.isValidUrl(widget.otherUser.profileImageUrl)
                    ? Text(
                        widget.otherUser.name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.iosBlue,
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
                      ? AppColors.iosGrayDark
                      : AppColors.iosGrayTertiary,
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
            color: (isDarkMode ? AppColors.iosGray : AppColors.iosGray)
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
          decoration: const BoxDecoration(color: Colors.transparent),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Camera/Gallery button - iOS style
                GestureDetector(
                  onTap: _showCameraGalleryOptions,
                  child: Container(
                    height: 48,
                    width: 48,
                    margin: const EdgeInsets.only(bottom: 0, right: 8),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.add_circle,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 40,
                    ),
                  ),
                ),
                // Message input field - Premium rounded design
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: GlassTextField(
                            controller: _messageController,
                            focusNode: _messageFocusNode,
                            maxLines: 5,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            autofocus: false,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.send,
                            hintText: 'Message',
                            showBlur: false,
                            decoration: const BoxDecoration(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
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
                              if (_showEmojiPicker) {
                                setState(() => _showEmojiPicker = false);
                              }
                            },
                          ),
                        ),
                        // Emoji button
                        Padding(
                          padding: const EdgeInsets.only(right: 4, bottom: 12),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _showEmojiPicker = !_showEmojiPicker;
                                if (_showEmojiPicker) {
                                  _messageFocusNode.unfocus();
                                } else {
                                  FocusScope.of(
                                    context,
                                  ).requestFocus(_messageFocusNode);
                                }
                              });
                            },
                            child: Icon(
                              _showEmojiPicker
                                  ? Icons.keyboard_rounded
                                  : Icons.emoji_emotions_outlined,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 24,
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
                          child: Container(
                            height: 36,
                            width: 36,
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF5856D6), Color(0xFF007AFF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_upward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        )
                      : GestureDetector(
                          key: const ValueKey('mic'),
                          // Tap to toggle recording
                          onTap: () async {
                            if (_isRecording) {
                              // Show confirmation popup
                              await _showVoiceRecordingPopup();
                            } else {
                              // Start recording
                              await _startRecording();
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 42,
                            width: _isRecording ? 90 : 42,
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? Colors.red
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(21),
                              boxShadow: _isRecording
                                  ? [
                                      BoxShadow(
                                        color: Colors.red.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: _isRecording
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Recording timer
                                        Text(
                                          _formatRecordingTime(
                                            _recordingDuration,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 1),
                                        // Stop icon
                                        const Icon(
                                          Icons.stop_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ],
                                    )
                                  : Icon(
                                      Icons.mic_rounded,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      size: 28,
                                    ),
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
              final emojiPickerHeight = (screenHeight * 0.35).clamp(
                200.0,
                350.0,
              );

              return Container(
                height: emojiPickerHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: EmojiPicker(
                        onEmojiSelected: (category, emoji) {
                          _messageController.text += emoji.emoji;
                          _messageController.selection =
                              TextSelection.fromPosition(
                                TextPosition(
                                  offset: _messageController.text.length,
                                ),
                              );
                          setState(() {});
                        },
                        onBackspacePressed: () {
                          if (_messageController.text.isNotEmpty) {
                            _messageController.text = _messageController
                                .text
                                .characters
                                .skipLast(1)
                                .toString();
                            setState(() {});
                          }
                        },
                        config: Config(
                          height: emojiPickerHeight - 20,
                          checkPlatformCompatibility: true,
                          emojiViewConfig: EmojiViewConfig(
                            columns: 8,
                            emojiSizeMax: 28,
                            verticalSpacing: 0,
                            horizontalSpacing: 0,
                            gridPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            backgroundColor: Colors.white,
                            recentsLimit: 28,
                            noRecents: Text(
                              'No Recents',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            loadingIndicator: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.iosBlue,
                              ),
                            ),
                            buttonMode: ButtonMode.MATERIAL,
                          ),
                          skinToneConfig: const SkinToneConfig(),
                          categoryViewConfig: const CategoryViewConfig(
                            initCategory: Category.RECENT,
                            backgroundColor: Colors.white,
                            indicatorColor: AppColors.iosBlue,
                            iconColor: Colors.grey,
                            iconColorSelected: AppColors.iosBlue,
                            categoryIcons: CategoryIcons(),
                          ),
                          bottomActionBarConfig: const BottomActionBarConfig(
                            enabled: false,
                          ),
                          searchViewConfig: const SearchViewConfig(
                            backgroundColor: Colors.white,
                            buttonIconColor: AppColors.iosBlue,
                            hintText: 'Search emoji...',
                          ),
                        ),
                      ),
                    ),
                  ],
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
                  ? AppColors.iosGrayDark.withValues(alpha: 0.9)
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
                    ? AppColors.iosGraySecondary
                    : AppColors.iosGrayLight,
                width: 0.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.iosBlue,
                  size: 24,
                ),
                if (_unreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.iosRed,
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

    // Check if we're editing a message
    if (_editingMessage != null) {
      _saveEditedMessage();
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
      final currentUserProfile = ref
          .read(currentUserProfileProvider)
          .valueOrNull;
      final currentUserName = currentUserProfile?.name ?? 'Someone';

      NotificationService().sendNotificationToUser(
        userId: widget.otherUser.uid,
        title: 'New Message from $currentUserName',
        body: text,
        type: 'message',
        data: {'conversationId': _conversationId},
      );
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      SnackBarHelper.showError(context, 'Failed to send message: $e');
    }
  }

  void _updateTypingStatus(bool isTyping) {
    if (_conversationId == null || _currentUserId == null) return;

    _typingTimer?.cancel();

    if (isTyping != _isTyping) {
      _isTyping = isTyping;
      _firestore.collection('conversations').doc(_conversationId!).update({
        'isTyping.$_currentUserId': isTyping,
      });
    }

    if (isTyping) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _updateTypingStatus(false);
      });
    }
  }

  void _markMessagesAsRead() async {
    if (_conversationId == null || _currentUserId == null) return;

    try {
      // Use HybridChatService - updates both local DB and Firebase
      await _hybridChatService.markMessagesAsRead(_conversationId!);

      // Update conversation unread count
      await _firestore.collection('conversations').doc(_conversationId!).update(
        {'unreadCount.$_currentUserId': 0},
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
    HapticFeedback.mediumImpact();

    final hasText = message.text != null && message.text!.isNotEmpty;
    final hasImage = message.mediaUrl != null && message.mediaUrl!.isNotEmpty;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Prevent closing when tapping on popup
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reply option
                      _buildPopupOption(
                        icon: Icons.reply,
                        label: 'Reply',
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            // Clear other actions first
                            _editingMessage = null;
                            _messageController.clear();
                            _replyToMessage = message;
                          });
                          FocusScope.of(
                            this.context,
                          ).requestFocus(_messageFocusNode);
                        },
                      ),

                      // Forward option
                      _buildPopupOption(
                        icon: Icons.forward,
                        label: 'Forward',
                        onTap: () {
                          Navigator.pop(context);
                          // Clear other actions first
                          setState(() {
                            _editingMessage = null;
                            _replyToMessage = null;
                            _messageController.clear();
                          });
                          _forwardMessage(message);
                        },
                      ),

                      // Copy option (only if has text)
                      if (hasText)
                        _buildPopupOption(
                          icon: Icons.copy,
                          label: 'Copy',
                          onTap: () {
                            Navigator.pop(context);
                            Clipboard.setData(
                              ClipboardData(text: message.text ?? ''),
                            );
                            SnackBarHelper.showSuccess(
                              this.context,
                              'Copied to clipboard',
                            );
                          },
                        ),

                      // Save Image option (only if has image)
                      if (hasImage)
                        _buildPopupOption(
                          icon: Icons.download,
                          label: 'Save Image',
                          onTap: () {
                            Navigator.pop(context);
                            _saveImage(message.mediaUrl!);
                          },
                        ),

                      // Edit option (only for own text messages)
                      if (isMe && hasText)
                        _buildPopupOption(
                          icon: Icons.edit,
                          label: 'Edit',
                          onTap: () {
                            Navigator.pop(context);
                            // Clear other actions first
                            setState(() {
                              _replyToMessage = null;
                            });
                            _editMessage(message);
                          },
                        ),

                      // Delete option (only for own messages)
                      if (isMe)
                        _buildPopupOption(
                          icon: Icons.delete,
                          label: 'Delete',
                          isDestructive: true,
                          onTap: () {
                            Navigator.pop(context);
                            _showDeleteConfirmation(message);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopupOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : Colors.white,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isDestructive ? Colors.red : Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _forwardMessage(MessageModel message) async {
    // Show WhatsApp-style forward screen
    final result = await Navigator.push<List<UserProfile>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _ForwardMessageScreen(currentUserId: _currentUserId!),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      // Forward message to all selected contacts
      int successCount = 0;
      for (final recipient in result) {
        try {
          await _sendForwardedMessage(recipient, message);
          successCount++;
        } catch (e) {
          debugPrint('Failed to forward to ${recipient.name}: $e');
        }
      }

      if (mounted) {
        if (successCount == result.length) {
          SnackBarHelper.showSuccess(
            context,
            'Forwarded to ${result.length} ${result.length == 1 ? 'chat' : 'chats'}',
          );
        } else {
          SnackBarHelper.showWarning(
            context,
            'Forwarded to $successCount of ${result.length} chats',
          );
        }
      }
    }
  }

  Future<void> _sendForwardedMessage(
    UserProfile recipient,
    MessageModel originalMessage,
  ) async {
    try {
      // Get or create conversation with recipient
      final conversationId = await _conversationService.getOrCreateConversation(
        recipient,
      );

      // Prepare forwarded message
      String? forwardedText = originalMessage.text;
      if (forwardedText != null && forwardedText.isNotEmpty) {
        forwardedText = forwardedText;
      }

      // Send message to new conversation
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
            'senderId': _currentUserId,
            'receiverId': recipient.uid,
            'text': forwardedText,
            'mediaUrl': originalMessage.mediaUrl,
            'type': originalMessage.type.index,
            'timestamp': FieldValue.serverTimestamp(),
            'status': MessageStatus.delivered.index, // Double grey tick
            'read': false,
            'isRead': false,
            'isForwarded': true, // Mark as forwarded
          });

      // Update conversation metadata
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage':
            forwardedText ?? (originalMessage.mediaUrl != null ? ' Photo' : ''),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': _currentUserId,
      });
    } catch (e) {
      debugPrint('Failed to forward message: $e');
      rethrow;
    }
  }

  Future<void> _saveImage(String imageUrl) async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        // Try photos permission for Android 13+
        final photosStatus = await Permission.photos.request();
        if (!photosStatus.isGranted) {
          if (mounted) {
            SnackBarHelper.showError(
              context,
              'Storage permission required to save image',
            );
          }
          return;
        }
      }

      if (mounted) {
        SnackBarHelper.showInfo(context, 'Saving image...');
      }

      // Download image using Dio
      final response = await Dio().get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      // Get the Pictures directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Pictures/Plink');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      // Create directory if not exists
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Save file
      final fileName = 'plink_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(response.data);

      // Notify media scanner on Android to show in gallery
      if (Platform.isAndroid) {
        await Process.run('am', [
          'broadcast',
          '-a',
          'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
          '-d',
          'file://$filePath',
        ]);
      }

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Image saved to Pictures/Plink');
      }
    } catch (e) {
      debugPrint('Failed to save image: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to save image: $e');
      }
    }
  }

  void _editMessage(MessageModel message) {
    setState(() {
      // Clear reply first - only one action at a time
      _replyToMessage = null;
      _editingMessage = message;
      _messageController.text = message.text ?? '';
    });
    FocusScope.of(context).requestFocus(_messageFocusNode);
  }

  void _cancelEdit() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
  }

  Future<void> _saveEditedMessage() async {
    if (_editingMessage == null || _messageController.text.trim().isEmpty) {
      return;
    }

    final newText = _messageController.text.trim();
    final messageId = _editingMessage!.id;

    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });

    try {
      await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .doc(messageId)
          .update({
            'text': newText,
            'isEdited': true,
            'editedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to edit message: $e');
      }
    }
  }

  void _showDeleteConfirmation(MessageModel message) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Delete icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Delete Message',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Are you sure you want to delete this message?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white.withValues(alpha: 0.15),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _deleteMessage(message);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.redAccent,
                            ),
                            child: const Center(
                              child: Text(
                                'Delete',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteMessage(MessageModel message) async {
    try {
      debugPrint('=== DELETE MESSAGE DEBUG ===');
      debugPrint('Conversation ID: $_conversationId');
      debugPrint('Message ID: ${message.id}');
      debugPrint('Message text: ${message.text}');

      if (_conversationId == null || _conversationId!.isEmpty) {
        debugPrint('ERROR: Conversation ID is null or empty!');
        SnackBarHelper.showError(
          context,
          'Cannot delete: Invalid conversation',
        );
        return;
      }

      if (message.id.isEmpty) {
        debugPrint('ERROR: Message ID is empty!');
        SnackBarHelper.showError(context, 'Cannot delete: Invalid message');
        return;
      }

      // First, delete the message
      await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .doc(message.id)
          .delete();

      debugPrint('Message deleted from Firestore successfully');

      // Remove from local cached messages to update UI immediately
      _loadedMessages.removeWhere((doc) => doc.id == message.id);
      _allMessages.removeWhere((m) => m.id == message.id);

      // Force UI rebuild
      if (mounted) {
        setState(() {});
      }

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
          lastMessageText = ' Photo';
        } else if (messageType == MessageType.video.index) {
          lastMessageText = ' Video';
        } else if (messageType == MessageType.audio.index) {
          lastMessageText = ' Audio';
        } else if (messageType == MessageType.file.index) {
          lastMessageText = ' File';
        } else {
          lastMessageText = lastMessageData['text'] ?? '';
        }

        debugPrint('Updating conversation with last message: $lastMessageText');

        // Force update with merge to ensure it happens
        await _firestore.collection('conversations').doc(_conversationId!).set({
          'lastMessage': lastMessageText,
          'lastMessageTime':
              lastMessageData['timestamp'] ?? FieldValue.serverTimestamp(),
          'lastMessageSenderId': lastMessageData['senderId'],
        }, SetOptions(merge: true));

        debugPrint('Conversation updated successfully');
      } else {
        debugPrint('No messages left, clearing conversation');

        // No messages left, clear the last message fields
        await _firestore.collection('conversations').doc(_conversationId!).set({
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSenderId': '',
        }, SetOptions(merge: true));
      }

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Message deleted');
      }
    } catch (e) {
      debugPrint('Error deleting message: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to delete message: $e');
      }
    }
  }

  void _showCameraGalleryOptions() {
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Prevent closing when tapping on popup
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Camera option
                      _buildPopupOption(
                        icon: Icons.camera_alt,
                        label: 'Camera',
                        onTap: () {
                          Navigator.pop(context);
                          _takePhoto();
                        },
                      ),
                      // Gallery option
                      _buildPopupOption(
                        icon: Icons.image,
                        label: 'Gallery',
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _pickImage() async {
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
    if (_conversationId == null || _currentUserId == null || !mounted) return;

    try {
      final storageRef = _storage.ref().child(
        'chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask;

      if (!mounted) return;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (!mounted) return;

      await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .add({
            'senderId': _currentUserId,
            'receiverId': widget.otherUser.uid,
            'chatId': _conversationId,
            'text': '',
            'type': MessageType.image.index,
            'mediaUrl': downloadUrl,
            'status': MessageStatus.delivered.index,
            'timestamp': FieldValue.serverTimestamp(),
            'isEdited': false,
            'read': false,
            'isRead': false,
          });

      await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .update({
            'lastMessage': ' Photo',
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastMessageSenderId': _currentUserId,
            'unreadCount.${widget.otherUser.uid}': FieldValue.increment(1),
          });

      // Send push notification for image
      if (mounted) {
        final currentUserProfile = ref
            .read(currentUserProfileProvider)
            .valueOrNull;
        final currentUserName = currentUserProfile?.name ?? 'Someone';

        NotificationService().sendNotificationToUser(
          userId: widget.otherUser.uid,
          title: 'New Photo from $currentUserName',
          body: ' Photo',
          type: 'message',
          data: {'conversationId': _conversationId},
        );
      }
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      SnackBarHelper.showError(context, 'Failed to send image: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      // Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (mounted) {
          SnackBarHelper.showError(
            context,
            'Microphone permission is required for voice messages',
          );
        }
        return;
      }

      // Initialize recorder if not already
      if (!_isRecorderInitialized) {
        await _audioRecorder.openRecorder();
        _isRecorderInitialized = true;
      }

      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${tempDir.path}/voice_message_$timestamp.aac';

      // Start recording
      await _audioRecorder.startRecorder(
        toFile: _recordingPath!,
        codec: Codec.aacADTS,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      // Start timer to track duration
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration++;
          });
        }
      });

      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Error starting recording: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to start recording');
      }
    }
  }

  Future<void> _showVoiceRecordingPopup() async {
    // Stop the timer but keep recording state
    _recordingTimer?.cancel();
    _recordingTimer = null;

    final duration = _recordingDuration;

    // Stop recorder and get path
    final path = await _audioRecorder.stopRecorder();

    setState(() {
      _isRecording = false;
      _recordingDuration = 0;
    });

    if (path == null || path.isEmpty) return;

    // Show small centered popup with audio preview
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _VoicePreviewPopup(
        audioPath: path,
        duration: duration,
        audioPlayer: _audioPlayer,
        isPlayerInitialized: _isPlayerInitialized,
        onInitializePlayer: () async {
          if (!_isPlayerInitialized) {
            await _audioPlayer.openPlayer();
            await _audioPlayer.setSubscriptionDuration(const Duration(milliseconds: 100));
            _isPlayerInitialized = true;
          }
        },
        onSend: () async {
          Navigator.pop(context);
          await _sendVoiceMessage(path, duration);
        },
        onCancel: () {
          Navigator.pop(context);
          try {
            File(path).deleteSync();
          } catch (_) {}
        },
      ),
    );
  }

  String _formatRecordingTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _sendVoiceMessage(String filePath, int audioDuration) async {
    if (_conversationId == null || _currentUserId == null) return;

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        if (mounted) {
          SnackBarHelper.showError(context, 'Recording file not found');
        }
        return;
      }

      // Create message document reference first for immediate UI feedback
      final messageRef = _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .doc();

      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch;

      // Create placeholder message with "sending" status immediately
      final placeholderData = {
        'id': messageRef.id,
        'senderId': _currentUserId,
        'receiverId': widget.otherUser.uid,
        'text': '',
        'audioUrl': '', // Will be updated after upload
        'audioDuration': audioDuration,
        'type': MessageType.audio.index,
        'status': MessageStatus.sending.index,
        'timestamp': Timestamp.fromDate(now),
        'read': false,
      };

      // Set placeholder immediately for instant UI feedback
      await messageRef.set(placeholderData);

      // Scroll to bottom immediately
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      // Upload to Firebase Storage in background
      final fileName = 'voice_${_currentUserId}_$timestamp.aac';
      final storageRef = _storage
          .ref()
          .child('voice_messages')
          .child(_conversationId!)
          .child(fileName);

      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(contentType: 'audio/aac'),
      );

      final snapshot = await uploadTask;
      final audioUrl = await snapshot.ref.getDownloadURL();

      // Update message with actual audio URL and delivered status
      await messageRef.update({
        'audioUrl': audioUrl,
        'status': MessageStatus.delivered.index, // Double grey tick - delivered to server
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Run these in parallel for faster completion
      await Future.wait([
        // Update conversation metadata
        _firestore.collection('conversations').doc(_conversationId!).update({
          'lastMessage': '🎤 Voice message',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSenderId': _currentUserId,
        }),
        // Send notification to receiver
        NotificationService().sendNotificationToUser(
          userId: widget.otherUser.uid,
          title: 'New Voice Message',
          body: 'You received a voice message',
          type: 'message',
          data: {'conversationId': _conversationId},
        ),
        // Delete local file
        file.delete(),
      ]);

      // Reset recording duration
      _recordingDuration = 0;
    } catch (e) {
      debugPrint('Error sending voice message: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to send voice message');
      }
    }
  }

  // Audio playback methods
  Future<void> _playAudio(String messageId, String audioUrl) async {
    try {
      // If same message is playing, toggle pause/resume
      if (_currentlyPlayingMessageId == messageId && _isPlaying) {
        await _audioPlayer.pausePlayer();
        setState(() {
          _isPlaying = false;
        });
        return;
      }

      // If different message or not playing, stop current and play new
      if (_isPlaying) {
        await _audioPlayer.stopPlayer();
      }

      // Initialize player if needed
      if (!_isPlayerInitialized) {
        await _audioPlayer.openPlayer();
        _isPlayerInitialized = true;
      }

      // Set fast subscription for smooth waveform animation
      await _audioPlayer.setSubscriptionDuration(const Duration(milliseconds: 50));

      // Subscribe to playback progress BEFORE starting
      _playerSubscription?.cancel();
      _playerSubscription = _audioPlayer.onProgress!.listen((e) {
        if (mounted && e.duration.inMilliseconds > 0) {
          setState(() {
            _playbackProgress =
                e.position.inMilliseconds / e.duration.inMilliseconds;
          });
        }
      });

      setState(() {
        _currentlyPlayingMessageId = messageId;
        _isPlaying = true;
        _playbackProgress = 0.0;
      });

      await _audioPlayer.startPlayer(
        fromURI: audioUrl,
        codec: Codec.aacADTS,
        whenFinished: () {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _currentlyPlayingMessageId = null;
              _playbackProgress = 0.0;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Error playing audio: $e');
      setState(() {
        _isPlaying = false;
        _currentlyPlayingMessageId = null;
      });
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to play audio');
      }
    }
  }

  Future<void> _stopAudio() async {
    try {
      await _audioPlayer.stopPlayer();
      setState(() {
        _isPlaying = false;
        _currentlyPlayingMessageId = null;
        _playbackProgress = 0.0;
      });
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  Widget _buildAudioMessagePlayer(MessageModel message, bool isMe) {
    final isSending =
        message.status == MessageStatus.sending ||
        (message.audioUrl == null || message.audioUrl!.isEmpty);
    final isCurrentlyPlaying =
        _currentlyPlayingMessageId == message.id && _isPlaying;
    final isThisMessage = _currentlyPlayingMessageId == message.id;
    final progress = isThisMessage ? _playbackProgress : 0.0;
    final duration = message.audioDuration ?? 0;

    // Format duration
    String formatDuration(int seconds) {
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }

    // Format time
    final hour = message.timestamp.hour;
    final minute = message.timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeString = '$hour12:$minute $period';

    // Waveform bar heights pattern (same as popup)
    final heights = [8.0, 14.0, 10.0, 18.0, 12.0, 20.0, 14.0, 16.0, 10.0, 22.0,
                    18.0, 12.0, 20.0, 8.0, 16.0, 14.0, 18.0, 10.0, 14.0, 12.0];

    // Audio player matching popup style
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button with gradient
          GestureDetector(
            onTap: isSending
                ? null
                : () => _playAudio(message.id, message.audioUrl!),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: isSending
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF5856D6), Color(0xFF007AFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: isSending ? Colors.white.withValues(alpha: 0.2) : null,
                shape: BoxShape.circle,
                boxShadow: isSending
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFF5856D6).withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isCurrentlyPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Waveform and info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Waveform
              SizedBox(
                width: 120,
                height: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(20, (index) {
                    final barProgress = index / 20;
                    final isActive = barProgress <= progress;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 3,
                      height: heights[index],
                      decoration: BoxDecoration(
                        color: isSending
                            ? Colors.white.withValues(alpha: 0.3)
                            : (isActive
                                  ? const Color(0xFF5856D6)
                                  : Colors.white24),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 4),
              // Duration, time and status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Duration
                  Text(
                    isSending ? 'Sending...' : formatDuration(duration),
                    style: TextStyle(
                      color: isSending
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Time
                  Text(
                    timeString,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                  // Status tick (only for sent messages by me, skip if sending - button has loader)
                  if (isMe && !isSending) ...[
                    const SizedBox(width: 4),
                    _buildMessageStatusIcon(message.status, isMe),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Mic icon
          Icon(
            Icons.mic,
            color: isSending ? Colors.orange : Colors.white38,
            size: 20,
          ),
        ],
      ),
    );
  }

  void _startVideoCall() {
    SnackBarHelper.showInfo(context, 'Video call coming soon!');
  }

  void _startAudioCall() async {
    final currentUserProfile = ref.read(currentUserProfileProvider).valueOrNull;

    debugPrint('  ====== INITIATING CALL ======');
    debugPrint('  Caller ID (me): $_currentUserId');
    debugPrint('  Receiver ID (other): ${widget.otherUser.uid}');
    debugPrint('  Caller name: ${currentUserProfile?.name ?? 'Unknown'}');
    debugPrint('  Receiver name: ${widget.otherUser.name}');

    // Create a call document in Firestore
    final callDoc = await _firestore.collection('calls').add({
      'callerId': _currentUserId,
      'receiverId': widget.otherUser.uid,
      'callerName': currentUserProfile?.name ?? 'Unknown',
      'callerPhoto': currentUserProfile?.photoUrl,
      'receiverName': widget.otherUser.name,
      'receiverPhoto': widget.otherUser.photoUrl,
      'status': 'calling',
      'type': 'audio',
      'timestamp':
          FieldValue.serverTimestamp(), // Used for checking call freshness
      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint('  Call document created: ${callDoc.id}');

    if (!mounted) return;

    // Navigate to voice call screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceCallScreen(
          callId: callDoc.id,
          otherUser: widget.otherUser,
          isOutgoing: true,
        ),
      ),
    );
  }

  void _showChatInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ChatInfoScreen(
          otherUser: widget.otherUser,
          conversationId: _conversationId!,
          onSearchTap: () {
            Navigator.pop(context);
            _toggleSearch();
          },
          onThemeTap: () {
            Navigator.pop(context);
          },
          onDeleteConversation: () {
            // Close info screen and show dialog on chat screen
            Navigator.of(context).pop();
            // Use post frame callback to ensure info screen is fully popped
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showDeleteConversationDialog();
              }
            });
          },
          onNavigateToMessage: (messageId) {
            // Close info screen first
            Navigator.of(context).pop();
            // Scroll to the message after navigation completes
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _scrollToMessageById(messageId);
              }
            });
          },
        ),
      ),
    );
  }

  void _scrollToMessageById(String messageId) {
    // Find the message in the list by ID
    final targetMessage = _allMessages
        .where((m) => m.id == messageId)
        .firstOrNull;
    if (targetMessage != null) {
      _scrollToMessage(targetMessage);
    }
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
    return GlassTextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      autofocus: true,
      hintText: 'Search messages...',
      showBlur: false,
      decoration: const BoxDecoration(),
      contentPadding: EdgeInsets.zero,
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
      decoration: const BoxDecoration(color: Colors.transparent),
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

  void _showDeleteConversationDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Conversation?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This will permanently delete all messages with ${widget.otherUser.name}. This action cannot be undone.',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteConversation();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteConversation() async {
    if (_conversationId == null) return;

    try {
      // Delete all messages in the conversation
      final messagesSnapshot = await _firestore
          .collection('conversations')
          .doc(_conversationId!)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the conversation document
      batch.delete(
        _firestore.collection('conversations').doc(_conversationId!),
      );

      await batch.commit();

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Conversation deleted');
        // Stay on chat screen - messages will be empty now
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to delete conversation');
      }
    }
  }
}

/// Full-page Chat Info Screen with feed-like background
class _ChatInfoScreen extends StatefulWidget {
  final UserProfile otherUser;
  final String conversationId;
  final VoidCallback onSearchTap;
  final VoidCallback onThemeTap;
  final VoidCallback onDeleteConversation;
  final void Function(String messageId) onNavigateToMessage;

  const _ChatInfoScreen({
    required this.otherUser,
    required this.conversationId,
    required this.onSearchTap,
    required this.onThemeTap,
    required this.onDeleteConversation,
    required this.onNavigateToMessage,
  });

  @override
  State<_ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<_ChatInfoScreen> {
  bool _isMuted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMuteStatus();
  }

  Future<void> _loadMuteStatus() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _isMuted = doc.data()?['isMuted'] ?? false;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleMute(bool value) async {
    setState(() {
      _isMuted = value;
    });

    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({'isMuted': value});
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isMuted = !value;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Image (same as feed screen)
          Positioned.fill(
            child: Image.asset(
              AppAssets.homeBackgroundImage,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // Dark overlay with more opacity
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Chat Info',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Spacer to balance the back button
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Divider line
                Container(
                  height: 0.5,
                  color: Colors.white.withValues(alpha: 0.2),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        // Profile Card with avatar, name, and location
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Column(
                                children: [
                                  // Profile avatar
                                  CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.grey[800],
                                    backgroundImage:
                                        PhotoUrlHelper.isValidUrl(
                                          widget.otherUser.profileImageUrl,
                                        )
                                        ? CachedNetworkImageProvider(
                                            widget.otherUser.profileImageUrl!,
                                          )
                                        : null,
                                    child:
                                        !PhotoUrlHelper.isValidUrl(
                                          widget.otherUser.profileImageUrl,
                                        )
                                        ? Text(
                                            widget.otherUser.name.isNotEmpty
                                                ? widget.otherUser.name[0]
                                                      .toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              fontSize: 48,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),

                                  const SizedBox(height: 20),

                                  // Name
                                  Text(
                                    widget.otherUser.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),

                                  if (widget.otherUser.location != null &&
                                      widget
                                          .otherUser
                                          .location!
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.location_on_rounded,
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            widget.otherUser.location!,
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                              fontSize: 16,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Options
                        _buildOptionTile(
                          icon: _isMuted
                              ? Icons.notifications_off_rounded
                              : Icons.notifications_rounded,
                          title: _isMuted
                              ? 'Unmute Notifications'
                              : 'Mute Notifications',
                          trailing: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.iosBlue,
                                  ),
                                )
                              : Switch(
                                  value: _isMuted,
                                  onChanged: _toggleMute,
                                  activeTrackColor: AppColors.iosBlue
                                      .withValues(alpha: 0.5),
                                  activeThumbColor: AppColors.iosBlue,
                                ),
                        ),

                        _buildOptionTile(
                          icon: Icons.search_rounded,
                          title: 'Search in Conversation',
                          onTap: widget.onSearchTap,
                        ),

                        _buildOptionTile(
                          icon: Icons.color_lens_rounded,
                          title: 'Change Theme',
                          onTap: widget.onThemeTap,
                        ),

                        _buildOptionTile(
                          icon: Icons.photo_library_rounded,
                          title: 'Shared Media',
                          onTap: () async {
                            final nav = Navigator.of(context);
                            final messageId = await nav.push<String>(
                              MaterialPageRoute(
                                builder: (context) => _SharedMediaScreen(
                                  conversationId: widget.conversationId,
                                  otherUserName: widget.otherUser.name,
                                ),
                              ),
                            );
                            // If a messageId was returned, navigate to that message
                            if (messageId != null && mounted) {
                              nav.pop(); // Close info screen
                              widget.onNavigateToMessage(messageId);
                            }
                          },
                        ),

                        const SizedBox(height: 20),

                        // Danger options (white text like others)
                        _buildOptionTile(
                          icon: Icons.block_rounded,
                          title: 'Block User',
                          onTap: () => _showBlockUserDialog(),
                        ),

                        _buildOptionTile(
                          icon: Icons.delete_rounded,
                          title: 'Delete Conversation',
                          onTap: widget.onDeleteConversation,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    Color? iconColor,
    Color? textColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ListTile(
            leading: Icon(
              icon,
              color: iconColor ?? Colors.white.withValues(alpha: 0.8),
            ),
            title: Text(
              title,
              style: TextStyle(color: textColor ?? Colors.white, fontSize: 16),
            ),
            trailing:
                trailing ??
                (onTap != null
                    ? Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.5),
                      )
                    : null),
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  void _showBlockUserDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_rounded,
                  color: AppColors.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Block ${widget.otherUser.name}?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Blocked users cannot send you messages or see your profile. You can unblock them later from settings.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _blockUser();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Block',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _blockUser() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Add to blocked_users collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(widget.otherUser.uid)
          .set({
            'blockedUserId': widget.otherUser.uid,
            'blockedUserName': widget.otherUser.name,
            'blockedUserPhoto': widget.otherUser.profileImageUrl,
            'blockedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        SnackBarHelper.showSuccess(
          context,
          '${widget.otherUser.name} has been blocked',
        );
        // Go back to chat screen
        Navigator.pop(context); // Close info screen
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to block user');
      }
    }
  }
}

// WhatsApp-style Forward Message Screen
class _ForwardMessageScreen extends StatefulWidget {
  final String currentUserId;

  const _ForwardMessageScreen({required this.currentUserId});

  @override
  State<_ForwardMessageScreen> createState() => _ForwardMessageScreenState();
}

class _ForwardMessageScreenState extends State<_ForwardMessageScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final Set<UserProfile> _selectedUsers = {};
  String _searchQuery = '';
  List<Map<String, dynamic>> _allContacts = [];
  bool _isLoading = true;

  // Voice search
  bool _isListening = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  Timer? _silenceTimer;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _initSpeech();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _silenceTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          if (mounted && _isListening) {
            _stopVoiceSearch();
          }
        }
      },
      onError: (error) {
        debugPrint('Speech error: $error');
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
      },
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _startVoiceSearch() async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();

    // Request microphone permission first
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      debugPrint('Microphone permission denied');
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Microphone permission is required for voice search',
        );
      }
      return;
    }

    // Check if speech is available
    if (!_speechEnabled) {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
        },
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          if (mounted && _isListening) {
            _silenceTimer?.cancel();
            setState(() {
              _isListening = false;
            });
          }
        },
      );
      if (!_speechEnabled) {
        debugPrint('Speech recognition not available');
        return;
      }
    }

    setState(() {
      _isListening = true;
    });

    // Start 5-second silence timer
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isListening && _searchController.text.isEmpty) {
        _stopVoiceSearch();
      }
    });

    // Start listening
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          if (result.recognizedWords.isNotEmpty) {
            _silenceTimer?.cancel();
          }

          // Update search controller text and move cursor to end
          _searchController.text = result.recognizedWords;
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: _searchController.text.length),
          );

          // Update search query and force rebuild
          setState(() {
            _searchQuery = result.recognizedWords;
          });

          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _stopVoiceSearch();
          }
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_IN',
    );
  }

  void _stopVoiceSearch() async {
    if (!mounted) return;

    _silenceTimer?.cancel();
    await _speech.stop();

    setState(() {
      _isListening = false;
    });
  }

  Future<void> _loadContacts() async {
    try {
      // Query without orderBy to avoid composite index requirement
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: widget.currentUserId)
          .limit(50)
          .get();

      // Sort locally by lastMessageTime
      final sortedDocs = conversationsSnapshot.docs.toList()
        ..sort((a, b) {
          final aTime =
              (a.data()['lastMessageTime'] as Timestamp?)?.toDate() ??
              DateTime(2000);
          final bTime =
              (b.data()['lastMessageTime'] as Timestamp?)?.toDate() ??
              DateTime(2000);
          return bTime.compareTo(aTime); // Descending order
        });

      final contacts = <Map<String, dynamic>>[];

      for (final doc in sortedDocs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final otherUserId = participants.firstWhere(
          (id) => id != widget.currentUserId,
          orElse: () => '',
        );

        if (otherUserId.isEmpty) continue;

        final userDoc = await _firestore
            .collection('users')
            .doc(otherUserId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          contacts.add({
            'uid': otherUserId,
            'name': userData['name'] ?? 'Unknown',
            'photoUrl': userData['photoUrl'] ?? userData['profileImageUrl'],
            'email': userData['email'] ?? '',
          });
        }
      }

      if (mounted) {
        setState(() {
          _allContacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading contacts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredContacts {
    // Filter out current user so they can't forward to themselves
    final contactsWithoutSelf = _allContacts.where((contact) {
      return contact['uid'] != widget.currentUserId;
    }).toList();

    if (_searchQuery.isEmpty) return contactsWithoutSelf;
    return contactsWithoutSelf.where((contact) {
      final name = (contact['name'] as String).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _toggleSelection(Map<String, dynamic> contact) {
    setState(() {
      final userProfile = UserProfile(
        uid: contact['uid'],
        name: contact['name'],
        email: contact['email'] ?? '',
        profileImageUrl: contact['photoUrl'],
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      final existingUser = _selectedUsers
          .where((u) => u.uid == contact['uid'])
          .firstOrNull;
      if (existingUser != null) {
        _selectedUsers.remove(existingUser);
      } else {
        _selectedUsers.add(userProfile);
      }
    });
  }

  bool _isSelected(String uid) {
    return _selectedUsers.any((u) => u.uid == uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              AppAssets.homeBackgroundImage,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.7)),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Forward to...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_selectedUsers.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_selectedUsers.length} selected',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 48), // Balance the back button
                    ],
                  ),
                ),

                // Divider
                Container(
                  height: 0.5,
                  color: Colors.white.withValues(alpha: 0.2),
                ),

                // Search bar - Glass style with mic
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GlassSearchField(
                    controller: _searchController,
                    hintText: 'Search...',
                    showMic: true,
                    isListening: _isListening,
                    onMicTap: _startVoiceSearch,
                    onStopListening: _stopVoiceSearch,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    onClear: () {
                      setState(() => _searchQuery = '');
                    },
                  ),
                ),

                // Selected users chips
                if (_selectedUsers.isNotEmpty)
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _selectedUsers.length,
                      itemBuilder: (context, index) {
                        final user = _selectedUsers.elementAt(index);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            backgroundColor: Colors.green.withValues(
                              alpha: 0.2,
                            ),
                            side: BorderSide(
                              color: Colors.green.withValues(alpha: 0.5),
                            ),
                            avatar: CircleAvatar(
                              radius: 12,
                              backgroundImage:
                                  PhotoUrlHelper.isValidUrl(
                                    user.profileImageUrl,
                                  )
                                  ? CachedNetworkImageProvider(
                                      user.profileImageUrl!,
                                    )
                                  : null,
                              child:
                                  !PhotoUrlHelper.isValidUrl(
                                    user.profileImageUrl,
                                  )
                                  ? Text(
                                      user.name[0].toUpperCase(),
                                      style: const TextStyle(fontSize: 10),
                                    )
                                  : null,
                            ),
                            label: Text(
                              user.name.split(' ').first,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            deleteIcon: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white70,
                            ),
                            onDeleted: () {
                              setState(() => _selectedUsers.remove(user));
                            },
                          ),
                        );
                      },
                    ),
                  ),

                if (_selectedUsers.isNotEmpty) const SizedBox(height: 8),

                // Contacts list
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : _filteredContacts.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'No conversations yet'
                                : 'No results found',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _filteredContacts.length,
                          itemBuilder: (context, index) {
                            final contact = _filteredContacts[index];
                            final isSelected = _isSelected(contact['uid']);

                            return ListTile(
                              onTap: () => _toggleSelection(contact),
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.grey[800],
                                    backgroundImage:
                                        PhotoUrlHelper.isValidUrl(
                                          contact['photoUrl'],
                                        )
                                        ? CachedNetworkImageProvider(
                                            contact['photoUrl'],
                                          )
                                        : null,
                                    child:
                                        !PhotoUrlHelper.isValidUrl(
                                          contact['photoUrl'],
                                        )
                                        ? Text(
                                            (contact['name'] as String)[0]
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(
                                contact['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : Icon(
                                      Icons.circle_outlined,
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Bottom send button
          if (_selectedUsers.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                  ),
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context, _selectedUsers.toList());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Forward to ${_selectedUsers.length} ${_selectedUsers.length == 1 ? 'chat' : 'chats'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Plink-style Media Gallery Screen
class _SharedMediaScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;

  const _SharedMediaScreen({
    required this.conversationId,
    required this.otherUserName,
  });

  @override
  State<_SharedMediaScreen> createState() => _SharedMediaScreenState();
}

class _SharedMediaScreenState extends State<_SharedMediaScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _selectedFilter = 0; // 0: All, 1: Photos, 2: Links, 3: Files

  List<Map<String, dynamic>> _mediaItems = [];
  List<Map<String, dynamic>> _linkItems = [];
  List<Map<String, dynamic>> _docItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    try {
      final messagesSnapshot = await _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .get();

      final List<Map<String, dynamic>> media = [];
      final List<Map<String, dynamic>> links = [];
      final List<Map<String, dynamic>> docs = [];

      for (final doc in messagesSnapshot.docs) {
        final data = doc.data();
        final mediaUrl =
            data['mediaUrl'] as String? ?? data['imageUrl'] as String?;
        final text = data['text'] as String?;
        final type = data['type'] as int? ?? 0;
        final timestamp = data['timestamp'] as Timestamp?;

        // Check for media (images/videos)
        if (mediaUrl != null && mediaUrl.isNotEmpty) {
          if (type == MessageType.image.index ||
              mediaUrl.contains('.jpg') ||
              mediaUrl.contains('.jpeg') ||
              mediaUrl.contains('.png') ||
              mediaUrl.contains('.gif') ||
              mediaUrl.contains('.webp')) {
            media.add({
              'url': mediaUrl,
              'timestamp': timestamp?.toDate() ?? DateTime.now(),
              'type': 'image',
              'id': doc.id,
            });
          } else if (type == MessageType.video.index ||
              mediaUrl.contains('.mp4') ||
              mediaUrl.contains('.mov') ||
              mediaUrl.contains('.avi')) {
            media.add({
              'url': mediaUrl,
              'timestamp': timestamp?.toDate() ?? DateTime.now(),
              'type': 'video',
              'id': doc.id,
            });
          } else if (type == MessageType.file.index ||
              mediaUrl.contains('.pdf') ||
              mediaUrl.contains('.doc') ||
              mediaUrl.contains('.xls')) {
            docs.add({
              'url': mediaUrl,
              'timestamp': timestamp?.toDate() ?? DateTime.now(),
              'name': data['fileName'] ?? 'Document',
              'size': data['fileSize'],
              'id': doc.id,
            });
          }
        }

        // Check for links in text
        if (text != null && text.isNotEmpty) {
          final urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);
          final matches = urlRegex.allMatches(text);
          for (final match in matches) {
            links.add({
              'url': match.group(0),
              'timestamp': timestamp?.toDate() ?? DateTime.now(),
              'text': text,
              'id': doc.id,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _mediaItems = media;
          _linkItems = links;
          _docItems = docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading media: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              AppAssets.homeBackgroundImage,
              fit: BoxFit.cover,
            ),
          ),

          // Dark overlay
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.7)),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Media Gallery',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Empty space to balance the back button
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Divider line below AppBar
                Container(
                  height: 1,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  color: Colors.white.withValues(alpha: 0.2),
                ),

                // Segmented Control
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildSegment('All', 0),
                      _buildSegment('Photos', 1),
                      _buildSegment('Links', 2),
                      _buildSegment('Files', 3),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Content
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF2563EB),
                          ),
                        )
                      : _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(String label, int index) {
    final isSelected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedFilter) {
      case 1:
        return _buildMediaGrid();
      case 2:
        return _buildLinksList();
      case 3:
        return _buildDocsList();
      default:
        return _buildAllContent();
    }
  }

  Widget _buildAllContent() {
    if (_mediaItems.isEmpty && _linkItems.isEmpty && _docItems.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_open_rounded,
        title: 'No Shared Content',
        subtitle: 'Media, links and files shared in this chat will appear here',
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Photos section
        if (_mediaItems.isNotEmpty) ...[
          _buildSectionHeader(
            'Photos',
            _mediaItems.length,
            Icons.image_outlined,
          ),
          const SizedBox(height: 12),
          _buildMediaGridCompact(),
          const SizedBox(height: 24),
        ],

        // Links section
        if (_linkItems.isNotEmpty) ...[
          _buildSectionHeader('Links', _linkItems.length, Icons.link_rounded),
          const SizedBox(height: 12),
          ..._linkItems.take(3).map((item) => _buildLinkItem(item)),
          if (_linkItems.length > 3)
            _buildShowMoreButton(() => setState(() => _selectedFilter = 2)),
          const SizedBox(height: 24),
        ],

        // Files section
        if (_docItems.isNotEmpty) ...[
          _buildSectionHeader(
            'Files',
            _docItems.length,
            Icons.insert_drive_file_outlined,
          ),
          const SizedBox(height: 12),
          ..._docItems.take(3).map((item) => _buildDocItem(item)),
          if (_docItems.length > 3)
            _buildShowMoreButton(() => setState(() => _selectedFilter = 3)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildShowMoreButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Show more',
              style: TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF2563EB)),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGridCompact() {
    final displayItems = _mediaItems.take(6).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: displayItems.length,
      itemBuilder: (context, index) {
        return _buildMediaTile(displayItems[index], index);
      },
    );
  }

  Widget _buildMediaGrid() {
    if (_mediaItems.isEmpty) {
      return _buildEmptyState(
        icon: Icons.image_outlined,
        title: 'No Photos',
        subtitle: 'Photos shared in this chat will appear here',
      );
    }

    // Group media by date
    final groupedMedia = <String, List<Map<String, dynamic>>>{};
    for (final item in _mediaItems) {
      final date = item['timestamp'] as DateTime;
      final key = _getDateKey(date);
      groupedMedia.putIfAbsent(key, () => []).add(item);
    }

    // Sort keys to maintain order (most recent first)
    final sortedKeys = groupedMedia.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final items = groupedMedia[key]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header like WhatsApp
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                key,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: items.length,
              itemBuilder: (context, gridIndex) {
                final item = items[gridIndex];
                return _buildMediaTile(item, _mediaItems.indexOf(item));
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildMediaTile(Map<String, dynamic> item, int index) {
    final isVideo = item['type'] == 'video';

    return GestureDetector(
      onTap: () => _openMediaViewer(index),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withValues(alpha: 0.1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: item['url'],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.white.withValues(alpha: 0.1),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.white.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                  ),
                ),
              ),
              if (isVideo)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkItem(Map<String, dynamic> item) {
    final url = item['url'] as String;
    final timestamp = item['timestamp'] as DateTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.link_rounded,
            color: Color(0xFF2563EB),
            size: 20,
          ),
        ),
        title: Text(
          url,
          style: const TextStyle(color: Color(0xFF2563EB), fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatDate(timestamp),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
        onTap: () => _openLink(url),
      ),
    );
  }

  Widget _buildDocItem(Map<String, dynamic> item) {
    final name = item['name'] as String;
    final timestamp = item['timestamp'] as DateTime;
    final size = item['size'] as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.iosOrange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.insert_drive_file_outlined,
            color: AppColors.iosOrange,
            size: 20,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${size != null ? '${_formatFileSize(size)} • ' : ''}${_formatDate(timestamp)}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
        onTap: () => _downloadDoc(item),
      ),
    );
  }

  Widget _buildLinksList() {
    if (_linkItems.isEmpty) {
      return _buildEmptyState(
        icon: Icons.link_off_rounded,
        title: 'No Links',
        subtitle: 'Links shared in this chat will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _linkItems.length,
      itemBuilder: (context, index) {
        final item = _linkItems[index];
        final url = item['url'] as String;
        final timestamp = item['timestamp'] as DateTime;
        final messageId = item['id'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ),
                title: Text(
                  url,
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _formatDate(timestamp),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (messageId != null)
                      IconButton(
                        icon: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        onPressed: () => _navigateToMessage(messageId),
                        tooltip: 'Go to message',
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.open_in_new_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      onPressed: () => _openLink(url),
                      tooltip: 'Open link',
                    ),
                  ],
                ),
                onTap: () => _openLink(url),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocsList() {
    if (_docItems.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_off_rounded,
        title: 'No Documents',
        subtitle: 'Documents shared in this chat will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _docItems.length,
      itemBuilder: (context, index) {
        final item = _docItems[index];
        final name = item['name'] as String;
        final timestamp = item['timestamp'] as DateTime;
        final size = item['size'] as int?;
        final messageId = item['id'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.iosOrange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: AppColors.iosOrange,
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${size != null ? '${_formatFileSize(size)} • ' : ''}${_formatDate(timestamp)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (messageId != null)
                      IconButton(
                        icon: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        onPressed: () => _navigateToMessage(messageId),
                        tooltip: 'Go to message',
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.download_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      onPressed: () => _downloadDoc(item),
                      tooltip: 'Download',
                    ),
                  ],
                ),
                onTap: () => _downloadDoc(item),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _openMediaViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenMediaViewer(
          mediaItems: _mediaItems,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _openLink(String url) async {
    // Ensure URL has proper scheme
    String urlToLaunch = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      urlToLaunch = 'https://$url';
    }

    final uri = Uri.parse(urlToLaunch);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: copy to clipboard if can't launch
        await Clipboard.setData(ClipboardData(text: url));
        if (mounted) {
          SnackBarHelper.showWarning(
            context,
            'Could not open link. Copied to clipboard.',
          );
        }
      }
    } catch (e) {
      // Error fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        SnackBarHelper.showError(
          context,
          'Failed to open link. Copied to clipboard.',
        );
      }
    }
  }

  void _downloadDoc(Map<String, dynamic> item) async {
    final url = item['url'] as String;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Document link copied to clipboard'),
          backgroundColor: const Color(0xFF2563EB),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _navigateToMessage(String messageId) {
    // Pop back to chat screen with the messageId to scroll to
    Navigator.pop(context, messageId);
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
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

    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];

    if (dateOnly == today) {
      return 'Today, $dayName';
    } else if (dateOnly == yesterday) {
      return 'Yesterday, $dayName';
    } else if (date.year == now.year) {
      // Same year - show day name, date and month
      return '$dayName, ${date.day} $monthName';
    } else {
      // Different year - show full date with year
      return '$dayName, ${date.day} $monthName ${date.year}';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Full-screen media viewer with swipe navigation
class _FullScreenMediaViewer extends StatefulWidget {
  final List<Map<String, dynamic>> mediaItems;
  final int initialIndex;

  const _FullScreenMediaViewer({
    required this.mediaItems,
    required this.initialIndex,
  });

  @override
  State<_FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<_FullScreenMediaViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} of ${widget.mediaItems.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: () => _saveCurrentImage(),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () => _shareCurrentImage(),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.mediaItems.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final item = widget.mediaItems[index];
          final isVideo = item['type'] == 'video';

          if (isVideo) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Video playback coming soon',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: item['url'],
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        color: Colors.black.withValues(alpha: 0.5),
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: Text(
            _formatTimestamp(widget.mediaItems[_currentIndex]['timestamp']),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime date) {
    final months = [
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
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} at ${hour == 0 ? 12 : hour}:${date.minute.toString().padLeft(2, '0')} $amPm';
  }

  Future<void> _saveCurrentImage() async {
    try {
      final url = widget.mediaItems[_currentIndex]['url'] as String;

      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        final photosStatus = await Permission.photos.request();
        if (!photosStatus.isGranted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Storage permission required'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          return;
        }
      }

      // Download image
      final response = await Dio().get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      // Get the Pictures directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Pictures/Plink');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Save the file
      final fileName = 'plink_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(response.data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Image saved to gallery'),
            backgroundColor: AppColors.iosGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save image'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _shareCurrentImage() async {
    final url = widget.mediaItems[_currentIndex]['url'] as String;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Image link copied to clipboard'),
          backgroundColor: const Color(0xFF2563EB),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}

// Voice Recording Preview Popup with audio playback
class _VoicePreviewPopup extends StatefulWidget {
  final String audioPath;
  final int duration;
  final FlutterSoundPlayer audioPlayer;
  final bool isPlayerInitialized;
  final Future<void> Function() onInitializePlayer;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  const _VoicePreviewPopup({
    required this.audioPath,
    required this.duration,
    required this.audioPlayer,
    required this.isPlayerInitialized,
    required this.onInitializePlayer,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<_VoicePreviewPopup> createState() => _VoicePreviewPopupState();
}

class _VoicePreviewPopupState extends State<_VoicePreviewPopup> {
  bool _isPlaying = false;
  double _playbackProgress = 0.0;
  StreamSubscription? _playerSubscription;

  @override
  void dispose() {
    _stopPreview();
    _playerSubscription?.cancel();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        await widget.audioPlayer.stopPlayer();
        setState(() {
          _isPlaying = false;
          _playbackProgress = 0.0;
        });
      } else {
        // Initialize player if needed
        await widget.onInitializePlayer();

        // Set fast subscription for smooth waveform animation
        await widget.audioPlayer.setSubscriptionDuration(const Duration(milliseconds: 50));

        // Subscribe to progress BEFORE starting
        _playerSubscription?.cancel();
        _playerSubscription = widget.audioPlayer.onProgress!.listen((e) {
          if (mounted && e.duration.inMilliseconds > 0) {
            setState(() {
              _playbackProgress =
                  e.position.inMilliseconds / e.duration.inMilliseconds;
            });
          }
        });

        setState(() {
          _isPlaying = true;
          _playbackProgress = 0.0;
        });

        await widget.audioPlayer.startPlayer(
          fromURI: widget.audioPath,
          codec: Codec.aacADTS,
          whenFinished: () {
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _playbackProgress = 0.0;
              });
            }
          },
        );
      }
    } catch (e) {
      debugPrint('Error playing preview: $e');
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _stopPreview() async {
    try {
      if (_isPlaying) {
        await widget.audioPlayer.stopPlayer();
      }
    } catch (_) {}
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Audio Player UI - WhatsApp style
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Play/Pause button
                    GestureDetector(
                      onTap: _togglePlayback,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5856D6), Color(0xFF007AFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF5856D6,
                              ).withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Waveform / Progress bar
                    SizedBox(
                      width: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Waveform visualization with animation
                          SizedBox(
                            height: 24,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(20, (index) {
                                final isActive =
                                    index / 20 <= _playbackProgress;
                                final heights = [
                                  8.0,
                                  14.0,
                                  10.0,
                                  18.0,
                                  12.0,
                                  20.0,
                                  14.0,
                                  16.0,
                                  10.0,
                                  22.0,
                                  18.0,
                                  12.0,
                                  20.0,
                                  8.0,
                                  16.0,
                                  14.0,
                                  18.0,
                                  10.0,
                                  14.0,
                                  12.0,
                                ];
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 3,
                                  height: heights[index],
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? const Color(0xFF5856D6)
                                        : Colors.white24,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Duration text
                          Text(
                            _formatTime(widget.duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Mic icon
                    const Icon(Icons.mic, color: Colors.white38, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Delete button
                  GestureDetector(
                    onTap: () async {
                      await _stopPreview();
                      widget.onCancel();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_rounded,
                            color: Colors.redAccent,
                            size: 22,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Send button
                  GestureDetector(
                    onTap: () async {
                      await _stopPreview();
                      widget.onSend();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5856D6), Color(0xFF007AFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF5856D6,
                            ).withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Send',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
