import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/conversation_model.dart';
import '../models/user_profile.dart';
import '../providers/conversation_providers.dart';
import '../providers/app_providers.dart';
import '../utils/photo_url_helper.dart';
import 'enhanced_chat_screen.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenState = ref.watch(conversationsScreenProvider);

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF000000) : Colors.white,
      appBar: _buildAppBar(isDarkMode),
      body: Column(
        children: [
          if (screenState.isSearching) _buildSearchBar(isDarkMode),
          Expanded(
            child: _buildChatsList(isDarkMode),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChatDialog,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDarkMode) {
    final screenState = ref.watch(conversationsScreenProvider);

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
            Icons.group_add,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          tooltip: 'Create Group',
          onPressed: _createGroup,
        ),
        IconButton(
          icon: Icon(
            screenState.isSearching ? Icons.close : Icons.search,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () {
            ref.read(conversationsScreenProvider.notifier).toggleSearch();
            if (!screenState.isSearching) {
              _searchController.clear();
            }
          },
        ),
      ],
    );
  }

  void _createGroup() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
    );
    if (result != null && result is String) {
      _openGroupChat(result);
    }
  }

  void _openGroupChat(String groupId) async {
    try {
      final groupDoc = await _firestore.collection('conversations').doc(groupId).get();
      if (groupDoc.exists) {
        final data = groupDoc.data()!;
        if (data['isGroup'] == true) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupChatScreen(
                groupId: groupId,
                groupName: data['groupName'] ?? 'Group',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening group: $e');
    }
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
          fillColor: isDarkMode ? Colors.grey[900] : Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onChanged: (value) {
          ref.read(conversationsScreenProvider.notifier).setSearchQuery(value);
        },
      ),
    );
  }

  Widget _buildChatsList(bool isDarkMode) {
    final currentUserId = ref.watch(currentUserIdProvider);
    if (currentUserId == null) {
      return const Center(child: Text('Please login to see conversations'));
    }

    final filteredConversations = ref.watch(filteredConversationsProvider);

    return filteredConversations.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        debugPrint('ConversationsScreen: Error: $error');

        final errorStr = error.toString();
        if (errorStr.contains('permission-denied') ||
            errorStr.contains('PERMISSION_DENIED')) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
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
                    ref.invalidate(conversationsStreamProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
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
                  errorStr.length > 100
                      ? '${errorStr.substring(0, 100)}...'
                      : errorStr,
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
                      ref.invalidate(conversationsStreamProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
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
      },
      data: (conversations) {
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

  Widget _buildConversationTile(
    ConversationModel conversation,
    bool isDarkMode,
  ) {
    final currentUserId = ref.watch(currentUserIdProvider) ?? '';
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

        // Handle group conversations
        if (conversation.isGroup) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupChatScreen(
                groupId: conversation.id,
                groupName: conversation.groupName ?? 'Group',
              ),
            ),
          );
          return;
        }

        // Handle direct messages
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

            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EnhancedChatScreen(otherUser: otherUser),
              ),
            );
          } else {
            // User no longer exists - delete this orphaned conversation
            await _firestore
                .collection('conversations')
                .doc(conversation.id)
                .delete();

            // Show a friendly message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('This conversation is no longer available'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('Error loading user data: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to load conversation'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
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
                Builder(
                  builder: (context) {
                    // Handle group conversations
                    if (conversation.isGroup) {
                      return CircleAvatar(
                        radius: 28,
                        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                        child: Icon(
                          Icons.group,
                          color: Theme.of(context).primaryColor,
                          size: 28,
                        ),
                      );
                    }

                    // Handle individual conversations with safe image loading
                    final fixedPhotoUrl = PhotoUrlHelper.fixGooglePhotoUrl(displayPhoto);
                    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

                    Widget buildFallbackAvatar() {
                      return CircleAvatar(
                        radius: 28,
                        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        child: Text(
                          initial,
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }

                    if (fixedPhotoUrl == null || fixedPhotoUrl.isEmpty) {
                      return buildFallbackAvatar();
                    }

                    return ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: fixedPhotoUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => buildFallbackAvatar(),
                        errorWidget: (context, url, error) {
                          if (error.toString().contains('429')) {
                            PhotoUrlHelper.markAsRateLimited(url);
                          }
                          return buildFallbackAvatar();
                        },
                      ),
                    );
                  },
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: otherUserId.isNotEmpty && !conversation.isGroup
                      ? StreamBuilder<DocumentSnapshot>(
                          stream: _firestore
                              .collection('users')
                              .doc(otherUserId)
                              .snapshots(),
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

                                // Also check if lastSeen is recent
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
                                  color: isDarkMode
                                      ? Colors.black
                                      : Colors.white,
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
                              : conversation.lastMessage ??
                                    'Start a conversation',
                          style: TextStyle(
                            fontSize: 14,
                            color: isTyping
                                ? Theme.of(context).primaryColor
                                : (unreadCount > 0
                                      ? (isDarkMode
                                            ? Colors.white
                                            : Colors.black87)
                                      : (isDarkMode
                                            ? Colors.grey[600]
                                            : Colors.grey)),
                            fontWeight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                            fontStyle: isTyping
                                ? FontStyle.italic
                                : FontStyle.normal,
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

  // ignore: unused_element
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
            builder: (context) => EnhancedChatScreen(otherUser: userProfile),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              Builder(
                builder: (context) {
                  final fixedPhotoUrl = PhotoUrlHelper.fixGooglePhotoUrl(photoUrl);
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                  Widget buildFallbackAvatar() {
                    return CircleAvatar(
                      radius: 35,
                      backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }

                  if (fixedPhotoUrl == null || fixedPhotoUrl.isEmpty) {
                    return buildFallbackAvatar();
                  }

                  return ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: fixedPhotoUrl,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => buildFallbackAvatar(),
                      errorWidget: (context, url, error) {
                        if (error.toString().contains('429')) {
                          PhotoUrlHelper.markAsRateLimited(url);
                        }
                        return buildFallbackAvatar();
                      },
                    ),
                  );
                },
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
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NewMessageSheet(
        currentUserId: currentUserId,
        firestore: _firestore,
      ),
    );
  }

}

// Separate StatefulWidget for the New Message sheet to handle contacts loading
class _NewMessageSheet extends StatefulWidget {
  final String currentUserId;
  final FirebaseFirestore firestore;

  const _NewMessageSheet({
    required this.currentUserId,
    required this.firestore,
  });

  @override
  State<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<_NewMessageSheet> {
  List<Contact> _phoneContacts = [];
  bool _loadingContacts = false;
  bool _contactsPermissionDenied = false;
  Set<String> _registeredPhoneNumbers = {};

  @override
  void initState() {
    super.initState();
    _loadPhoneContacts();
    _loadRegisteredPhoneNumbers();
  }

  Future<void> _loadRegisteredPhoneNumbers() async {
    try {
      final usersSnapshot = await widget.firestore.collection('users').get();
      final phoneNumbers = <String>{};
      for (var doc in usersSnapshot.docs) {
        final phone = doc.data()['phone'] as String?;
        if (phone != null && phone.isNotEmpty) {
          // Normalize phone number (remove spaces, dashes, etc.)
          phoneNumbers.add(_normalizePhoneNumber(phone));
        }
      }
      if (mounted) {
        setState(() {
          _registeredPhoneNumbers = phoneNumbers;
        });
      }
    } catch (e) {
      debugPrint('Error loading registered phone numbers: $e');
    }
  }

  String _normalizePhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  Future<void> _loadPhoneContacts() async {
    setState(() {
      _loadingContacts = true;
    });

    try {
      // Request permission
      final permission = await Permission.contacts.request();

      if (permission.isGranted) {
        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: true,
        );
        if (mounted) {
          setState(() {
            _phoneContacts = contacts;
            _loadingContacts = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _contactsPermissionDenied = true;
            _loadingContacts = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading contacts: $e');
      if (mounted) {
        setState(() {
          _loadingContacts = false;
        });
      }
    }
  }

  bool _isContactRegistered(Contact contact) {
    for (var phone in contact.phones) {
      final normalized = _normalizePhoneNumber(phone.number);
      if (_registeredPhoneNumbers.contains(normalized)) {
        return true;
      }
    }
    return false;
  }

  void _inviteContact(Contact contact) {
    final inviteMessage =
        'Hey ${contact.displayName}! Join me on Supper - the AI-powered matching app. '
        'Connect with people for dating, friendship, business, and more! '
        'Download now: https://supper.app/download';

    Share.share(inviteMessage, subject: 'Join me on Supper!');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
                child: _buildContent(isDarkMode, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(bool isDarkMode, ScrollController scrollController) {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.firestore
          .collection('conversations')
          .where('participants', arrayContains: widget.currentUserId)
          .where('isGroup', isEqualTo: false)
          .snapshots(),
      builder: (context, convSnapshot) {
        if (convSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Extract other user IDs from conversations
        final Set<String> otherUserIds = {};
        if (convSnapshot.hasData) {
          for (var doc in convSnapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final participants = List<String>.from(data['participants'] ?? []);
            for (var participant in participants) {
              if (participant != widget.currentUserId) {
                otherUserIds.add(participant);
              }
            }
          }
        }

        // Fetch user details for registered users
        return FutureBuilder<List<DocumentSnapshot>>(
          future: otherUserIds.isNotEmpty
              ? Future.wait(
                  otherUserIds.map((id) =>
                      widget.firestore.collection('users').doc(id).get()),
                )
              : Future.value([]),
          builder: (context, usersSnapshot) {
            final validUsers = usersSnapshot.hasData
                ? usersSnapshot.data!.where((doc) => doc.exists).toList()
                : <DocumentSnapshot>[];

            return ListView(
              controller: scrollController,
              children: [
                // Section: Registered Users (App Contacts)
                if (validUsers.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'ON SUPPER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  ...validUsers.map((userDoc) {
                    final userData = userDoc.data() as Map<String, dynamic>;
                    final userId = userDoc.id;
                    final name = userData['name'] ?? 'Unknown';
                    final photoUrl = userData['photoUrl'];

                    return ListTile(
                      leading: Builder(
                        builder: (context) {
                          final fixedPhotoUrl = PhotoUrlHelper.fixGooglePhotoUrl(photoUrl);
                          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                          Widget buildFallbackAvatar() {
                            return CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                              child: Text(
                                initial,
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }

                          if (fixedPhotoUrl == null || fixedPhotoUrl.isEmpty) {
                            return buildFallbackAvatar();
                          }

                          return ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: fixedPhotoUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => buildFallbackAvatar(),
                              errorWidget: (context, url, error) {
                                if (error.toString().contains('429')) {
                                  PhotoUrlHelper.markAsRateLimited(url);
                                }
                                return buildFallbackAvatar();
                              },
                            ),
                          );
                        },
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        final userProfile = UserProfile.fromMap(userData, userId);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EnhancedChatScreen(otherUser: userProfile),
                          ),
                        );
                      },
                    );
                  }),
                ],

                // Section: Phone Contacts
                if (_loadingContacts)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_contactsPermissionDenied)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.contacts_outlined,
                          size: 48,
                          color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Enable contacts to invite friends',
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => openAppSettings(),
                          child: const Text('Open Settings'),
                        ),
                      ],
                    ),
                  )
                else if (_phoneContacts.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'INVITE TO SUPPER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  ..._phoneContacts
                      .where((contact) => !_isContactRegistered(contact))
                      .take(50) // Limit to first 50 contacts
                      .map((contact) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: contact.photo != null
                            ? MemoryImage(contact.photo!)
                            : null,
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        child: contact.photo == null
                            ? Text(
                                contact.displayName.isNotEmpty
                                    ? contact.displayName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        contact.displayName,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: TextButton.icon(
                        onPressed: () => _inviteContact(contact),
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('Invite'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).primaryColor,
                        ),
                      ),
                    );
                  }),
                ],

                // Empty state
                if (validUsers.isEmpty &&
                    _phoneContacts.isEmpty &&
                    !_loadingContacts)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No contacts yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start chatting with people from Discover or invite your friends',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.grey[600] : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
