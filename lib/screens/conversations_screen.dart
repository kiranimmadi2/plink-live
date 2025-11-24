import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:timeago/timeago.dart' as timeago;
import '../models/conversation_model.dart';
import '../models/user_profile.dart';
import '../services/conversation_service.dart';
import 'enhanced_chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({Key? key}) : super(key: key);

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  final ConversationService _conversationService = ConversationService();

  late TabController _tabController;
  bool _isSearching = false;
  String _searchQuery = '';
  bool _isCleaningUp = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);  // Changed to 1 tab only
    _runCleanup();
  }

  /// Run cleanup for orphaned conversations
  /// Deferred to run AFTER first frame to prevent frame drops
  Future<void> _runCleanup() async {
    // Defer cleanup to after UI is rendered to prevent frame skipping
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    try {
      setState(() {
        _isCleaningUp = true;
      });

      final deletedCount = await _conversationService.deleteOrphanedConversations();

      if (deletedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleaned up $deletedCount invalid conversation${deletedCount > 1 ? 's' : ''}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error during cleanup: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCleaningUp = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _getLastSeenText(dynamic lastSeen) {
    if (lastSeen == null) return 'Offline';
    
    if (lastSeen is Timestamp) {
      final lastSeenTime = lastSeen.toDate();
      final difference = DateTime.now().difference(lastSeenTime);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return 'Offline';
      }
    }
    
    return 'Offline';
  }


  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF000000) : Colors.white,
      appBar: _buildAppBar(isDarkMode),
      body: Column(
        children: [
          if (_isSearching) _buildSearchBar(isDarkMode),
          Expanded(
            child: _buildChatsList(isDarkMode),  // Direct chat list without TabBar
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChatDialog,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDarkMode) {
    return AppBar(
      backgroundColor: isDarkMode ? const Color(0xFF000000) : Colors.white,
      elevation: 0,
      title: Text(
        'Messages',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close : Icons.search,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
                _searchQuery = '';
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDarkMode ? const Color(0xFF000000) : Colors.white,
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          hintStyle: TextStyle(
            color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
          ),
          filled: true,
          fillColor: isDarkMode
              ? Colors.grey[900]
              : Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
      ),
    );
  }

  

  Widget _buildChatsList(bool isDarkMode) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return const Center(child: Text('Please login to see conversations'));
    }

    // Show loading indicator while cleaning up orphaned conversations
    if (_isCleaningUp) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Checking conversations...',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[600] : Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        // Debug logging disabled for production performance
        // Uncomment for debugging: debugPrint('ConversationsScreen: rebuild, state=${snapshot.connectionState}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          // Log the error for debugging
          debugPrint('ConversationsScreen: Error: ${snapshot.error}');

          // Handle permission errors gracefully
          final error = snapshot.error.toString();
          if (error.contains('permission-denied') || error.contains('PERMISSION_DENIED')) {
            // Show error with option to retry instead of just empty state
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Permission Error',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Unable to load conversations. Please try logging out and logging back in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[600] : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {}); // Trigger rebuild to retry
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
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

          // For other errors, show a more detailed error message
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error Loading Conversations',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    error.length > 100 ? '${error.substring(0, 100)}...' : error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[600] : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {}); // Trigger rebuild to retry
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _showNewChatDialog,
                      icon: const Icon(Icons.message),
                      label: const Text('New Chat'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(isDarkMode);
        }

        // Parse and sort conversations manually
        final List<ConversationModel> conversations = [];

        for (var doc in snapshot.data!.docs) {
          try {
            final conv = ConversationModel.fromFirestore(doc);

            // Note: Orphaned conversations (where user doesn't exist) are handled:
            // 1. On app start via _runCleanup()
            // 2. When user taps the conversation (it will be deleted gracefully)
            // This keeps the UI responsive without async validation in the builder

            // Show all conversations, even those without messages
            if (_searchQuery.isEmpty) {
              conversations.add(conv);
            } else {
              final displayName = conv.getDisplayName(currentUserId);
              if (displayName.toLowerCase().contains(_searchQuery)) {
                conversations.add(conv);
              }
            }
          } catch (e) {
            debugPrint('ConversationsScreen: Error parsing conversation ${doc.id}: $e');
          }
        }

        // Sort by lastMessageTime
        conversations.sort((a, b) {
          if (a.lastMessageTime == null) return 1;
          if (b.lastMessageTime == null) return -1;
          return b.lastMessageTime!.compareTo(a.lastMessageTime!);
        });

        if (conversations.isEmpty) {
          return _buildEmptyState(isDarkMode);
        }

        return ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            return _buildConversationTile(conversation, isDarkMode);
          },
        );
      },
    );
  }

  Widget _buildConversationTile(ConversationModel conversation, bool isDarkMode) {
    final currentUserId = _auth.currentUser!.uid;
    final otherUserId = conversation.getOtherParticipantId(currentUserId);
    
    // Skip rendering if otherUserId is empty (invalid conversation)
    if (otherUserId.isEmpty && !conversation.isGroup) {
      return const SizedBox.shrink();
    }
    
    // Get display name from conversation model or fallback to fetching from users collection
    String displayName = conversation.getDisplayName(currentUserId);
    final displayPhoto = conversation.getDisplayPhoto(currentUserId);
    final unreadCount = conversation.getUnreadCount(currentUserId);
    final isTyping = conversation.isUserTyping(otherUserId);
    
    // If the name is "Unknown User", try to fetch it from the users collection
    if (displayName == 'Unknown User' && otherUserId.isNotEmpty) {
      return FutureBuilder<DocumentSnapshot>(
        future: _firestore.collection('users').doc(otherUserId).get(),
        builder: (context, userSnapshot) {
          String finalDisplayName = displayName;
          String? finalDisplayPhoto = displayPhoto;
          
          if (userSnapshot.hasData && userSnapshot.data!.exists) {
            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            finalDisplayName = userData['name'] ?? 'Unknown User';
            finalDisplayPhoto = displayPhoto ?? userData['photoUrl'];
          }
          
          return _buildConversationTileContent(
            conversation: conversation,
            otherUserId: otherUserId,
            displayName: finalDisplayName,
            displayPhoto: finalDisplayPhoto,
            unreadCount: unreadCount,
            isTyping: isTyping,
            isDarkMode: isDarkMode,
          );
        },
      );
    }
    
    return _buildConversationTileContent(
      conversation: conversation,
      otherUserId: otherUserId,
      displayName: displayName,
      displayPhoto: displayPhoto,
      unreadCount: unreadCount,
      isTyping: isTyping,
      isDarkMode: isDarkMode,
    );
  }
  
  Widget _buildConversationTileContent({
    required ConversationModel conversation,
    required String otherUserId,
    required String displayName,
    String? displayPhoto,
    required int unreadCount,
    required bool isTyping,
    required bool isDarkMode,
  }) {
    return InkWell(
      onTap: () async {
        HapticFeedback.lightImpact();

        try {
          final otherUserDoc = await _firestore
              .collection('users')
              .doc(otherUserId)
              .get();

          if (otherUserDoc.exists) {
            final otherUser = UserProfile.fromMap(
              otherUserDoc.data()!,
              otherUserId,
            );

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EnhancedChatScreen(
                  otherUser: otherUser,
                ),
              ),
            );
          } else {
            // User no longer exists - delete this orphaned conversation
            // Delete the orphaned conversation
            await _firestore
                .collection('conversations')
                .doc(conversation.id)
                .delete();

            // Show a friendly message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('This conversation is no longer available'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('Error loading user data: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Unable to load conversation'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: displayPhoto != null
                      ? CachedNetworkImageProvider(displayPhoto)
                      : null,
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  child: displayPhoto == null
                      ? Text(
                          displayName[0].toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: otherUserId.isNotEmpty 
                    ? StreamBuilder<DocumentSnapshot>(
                        stream: _firestore
                            .collection('users')
                            .doc(otherUserId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          bool isOnline = false;
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final userData = snapshot.data!.data() as Map<String, dynamic>;
                            final showOnlineStatus = userData['showOnlineStatus'] ?? true;
                            
                            // Only show online if user allows it and they're actually online
                            if (showOnlineStatus) {
                              isOnline = userData['isOnline'] ?? false;
                              
                              // Also check if lastSeen is recent
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
                                  // No lastSeen timestamp, consider offline
                                  isOnline = false;
                                }
                              }
                            }
                          }
                          
                          if (!isOnline) return const SizedBox.shrink();
                          
                          return Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDarkMode ? Colors.black : Colors.white,
                                width: 2,
                              ),
                            ),
                          );
                        },
                      )
                    : const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.lastMessageTime != null)
                        Text(
                          timeago.format(conversation.lastMessageTime!),
                          style: TextStyle(
                            fontSize: 12,
                            color: unreadCount > 0
                                ? Theme.of(context).primaryColor
                                : (isDarkMode ? Colors.grey[600] : Colors.grey),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isTyping
                              ? 'Typing...'
                              : conversation.lastMessage ?? 'Start a conversation',
                          style: TextStyle(
                            fontSize: 14,
                            color: isTyping
                                ? Theme.of(context).primaryColor
                                : (unreadCount > 0
                                    ? (isDarkMode ? Colors.white : Colors.black87)
                                    : (isDarkMode ? Colors.grey[600] : Colors.grey)),
                            fontWeight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                            fontStyle: isTyping ? FontStyle.italic : FontStyle.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  

  Widget _buildActiveUserCard(
    Map<String, dynamic> userData,
    String userId,
    bool isDarkMode,
  ) {
    final name = userData['name'] ?? 'Unknown';
    final photoUrl = userData['photoUrl'];

    return InkWell(
      onTap: () async {
        HapticFeedback.lightImpact();
        
        final userProfile = UserProfile.fromMap(userData, userId);
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EnhancedChatScreen(
              otherUser: userProfile,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundImage: photoUrl != null
                    ? CachedNetworkImageProvider(photoUrl)
                    : null,
                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                child: photoUrl == null
                    ? Text(
                        name[0].toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDarkMode ? Colors.black : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name.split(' ')[0],
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new conversation',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[600] : Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showNewChatDialog,
            icon: const Icon(Icons.message),
            label: const Text('New Message'),
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

  void _showNewChatDialog() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          
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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'New Message',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('users').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final users = snapshot.data!.docs
                          .where((doc) => doc.id != _auth.currentUser!.uid)
                          .toList();

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final userData = users[index].data() as Map<String, dynamic>;
                          final userId = users[index].id;
                          final name = userData['name'] ?? 'Unknown';
                          final photoUrl = userData['photoUrl'];
                          final showOnlineStatus = userData['showOnlineStatus'] ?? true;
                          var isOnline = false;
                          
                          // Only show online if user allows it
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

                          return ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundImage: photoUrl != null
                                      ? CachedNetworkImageProvider(photoUrl)
                                      : null,
                                  child: photoUrl == null
                                      ? Text(name[0].toUpperCase())
                                      : null,
                                ),
                                if (isOnline)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDarkMode ? Colors.black : Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            subtitle: Text(
                              isOnline 
                                ? 'Active now' 
                                : (!showOnlineStatus 
                                    ? 'Status hidden' 
                                    : _getLastSeenText(userData['lastSeen'])),
                              style: TextStyle(
                                color: isOnline
                                    ? Colors.green
                                    : (isDarkMode ? Colors.grey[600] : Colors.grey),
                              ),
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              
                              final userProfile = UserProfile.fromMap(userData, userId);
                              
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EnhancedChatScreen(
                                    otherUser: userProfile,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}