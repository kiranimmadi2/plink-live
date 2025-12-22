import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../res/config/app_colors.dart';
import '../../widgets/other widgets/glass_text_field.dart';
import '../../models/user_profile.dart';
import '../../res/utils/photo_url_helper.dart';
import 'messenger_chat_screen.dart';

class MessageserScreen extends StatefulWidget {
  const MessageserScreen({super.key});

  @override
  State<MessageserScreen> createState() => _MessageserScreenState();
}

class _MessageserScreenState extends State<MessageserScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _buildGlassAppBar(),
      body: Stack(
        children: [
          // Grey glass background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.iosGraySecondary,
                  AppColors.iosGrayDark,
                  Color(0xFF1a1a1a),
                ],
              ),
            ),
          ),
          // Glass overlay effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.iosGray.withValues(alpha: 0.2),
                      AppColors.iosGraySecondary.withValues(alpha: 0.3),
                      AppColors.iosGrayDark.withValues(alpha: 0.4),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Subtle noise texture overlay for glass effect
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.5,
                  colors: [
                    Colors.white.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(child: _buildBody()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildGlassAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 10),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.whiteAlpha(alpha: 0.1),
                  AppColors.iosGraySecondary.withValues(alpha: 0.3),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.whiteAlpha(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: AppBar(
              backgroundColor: AppColors.transparent,
              elevation: 0,
              title: _isSearching
                  ? GlassTextField(
                      controller: _searchController,
                      autofocus: true,
                      hintText: 'Search messages...',
                      showBlur: false,
                      decoration: const BoxDecoration(),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                    )
                  : const Text(
                      'Messages',
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 24,
                        letterSpacing: 0.5,
                      ),
                    ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: AppColors.whiteAlpha(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isSearching ? Icons.close : Icons.search,
                      color: Colors.white,
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
                ),
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: AppColors.whiteAlpha(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {
                      _showOptionsMenu();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.grey.shade800.withValues(alpha: 0.8),
                    Colors.grey.shade900.withValues(alpha: 0.9),
                  ],
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.whiteAlpha(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.iosBlue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.mark_chat_read,
                          color: AppColors.iosBlue,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Mark all as read',
                        style: TextStyle(
                          color: AppColors.textPrimaryDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _markAllAsRead();
                      },
                    ),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.iosGray.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Settings',
                        style: TextStyle(
                          color: AppColors.textPrimaryDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _markAllAsRead() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All messages marked as read'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _openChat(String otherUserId, String conversationId) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(otherUserId)
          .get();

      if (!userDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final otherUser = UserProfile.fromMap(userData, otherUserId);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MessengerChatScreen(
              otherUser: otherUser,
              chatId: conversationId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildBody() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(
        child: Text(
          'Please login to view messages',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError) {
          debugPrint('MessageserScreen Error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading messages',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    '${snapshot.error}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        // Sort by lastMessageTime on client side
        final conversations = (snapshot.data?.docs ?? [])
          ..sort((a, b) {
            final aTime =
                (a.data() as Map<String, dynamic>)['lastMessageTime']
                    as Timestamp?;
            final bTime =
                (b.data() as Map<String, dynamic>)['lastMessageTime']
                    as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime); // Descending order
          });

        // Filter by search query
        final filteredConversations = _searchQuery.isEmpty
            ? conversations
            : conversations.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final lastMessage = (data['lastMessage'] ?? '')
                    .toString()
                    .toLowerCase();
                return lastMessage.contains(_searchQuery);
              }).toList();

        if (filteredConversations.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filteredConversations.length,
          itemBuilder: (context, index) {
            final doc = filteredConversations[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildConversationTile(doc.id, data, currentUser.uid);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.message_outlined, size: 80, color: Colors.grey.shade600),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No messages yet' : 'No messages found',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Start a conversation with someone!'
                : 'Try a different search term',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(
    String conversationId,
    Map<String, dynamic> data,
    String currentUserId,
  ) {
    final participants = List<String>.from(data['participants'] ?? []);
    final otherUserId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    final lastMessage = data['lastMessage'] ?? '';
    final lastMessageTime = data['lastMessageTime'] as Timestamp?;
    final unreadCount = (data['unreadCount']?[currentUserId] ?? 0) as int;

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(otherUserId).get(),
      builder: (context, userSnapshot) {
        String userName = 'Unknown User';
        String? userPhoto;
        bool isOnline = false;

        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          userName = userData['name'] ?? 'Unknown User';
          userPhoto = userData['photoUrl'];
          isOnline = userData['isOnline'] ?? false;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: unreadCount > 0
                      ? Colors.blue.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey.shade700,
                        backgroundImage: PhotoUrlHelper.isValidUrl(userPhoto)
                            ? CachedNetworkImageProvider(userPhoto!)
                            : null,
                        child: !PhotoUrlHelper.isValidUrl(userPhoto)
                            ? Text(
                                userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: AppColors.textPrimaryDark,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      if (isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey.shade800,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    userName,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: unreadCount > 0
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unreadCount > 0
                                ? Colors.white70
                                : Colors.grey.shade500,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        lastMessageTime != null
                            ? timeago.format(
                                lastMessageTime.toDate(),
                                locale: 'en_short',
                              )
                            : '',
                        style: TextStyle(
                          color: unreadCount > 0
                              ? Colors.blue
                              : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.iosBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: AppColors.textPrimaryDark,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _openChat(otherUserId, conversationId);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
