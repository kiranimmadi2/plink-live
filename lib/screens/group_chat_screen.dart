import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../services/group_chat_service.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GroupChatService _groupChatService = GroupChatService();

  // Message pagination
  static const int _messagesPerPage = 50;
  bool _hasMoreMessages = true;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;

  bool _isSending = false;
  String _currentGroupName = '';
  String? _groupPhoto;
  Map<String, String> _memberNames = {};
  Map<String, String?> _memberPhotos = {};
  List<String> _admins = [];
  String? _createdBy;
  bool _isAdmin = false;

  // Optimistic messages (shown immediately before server confirms)
  final List<Map<String, dynamic>> _optimisticMessages = [];

  // Typing indicator
  List<String> _typingUsers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentGroupName = widget.groupName;
    _groupChatService.markAsRead(widget.groupId);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    // Clear typing status on dispose
    _groupChatService.clearTypingStatus(widget.groupId);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Clear typing status when app goes to background
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _groupChatService.clearTypingStatus(widget.groupId);
    }
  }

  void _onScroll() {
    // Load more messages when scrolling to top
    if (_scrollController.position.pixels <= 100 && !_isLoadingMore && _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _lastDocument == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final query = _firestore
          .collection('conversations')
          .doc(widget.groupId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_messagesPerPage);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() => _hasMoreMessages = false);
      } else {
        _lastDocument = snapshot.docs.last;
      }
    } catch (e) {
      debugPrint('Error loading more messages: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    // Clear input immediately
    _messageController.clear();

    // Add optimistic message
    final optimisticMessage = {
      'id': 'optimistic_${DateTime.now().millisecondsSinceEpoch}',
      'senderId': currentUserId,
      'text': text,
      'timestamp': Timestamp.now(),
      'isSystemMessage': false,
      'isOptimistic': true,
    };

    setState(() {
      _optimisticMessages.add(optimisticMessage);
      _isSending = true;
    });

    // Scroll to bottom for new message
    _scrollToBottom();

    // Clear typing status
    _groupChatService.setTyping(widget.groupId, false);

    try {
      final messageId = await _groupChatService.sendMessage(
        groupId: widget.groupId,
        text: text,
      );

      if (messageId != null && mounted) {
        // Remove optimistic message (real one will come from stream)
        setState(() {
          _optimisticMessages.removeWhere((m) => m['id'] == optimisticMessage['id']);
        });
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      // Remove failed optimistic message
      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m['id'] == optimisticMessage['id']);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGroupInfoSheet(),
    );
  }

  Widget _buildGroupInfoSheet() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor:
                          Theme.of(context).primaryColor.withValues(alpha: 0.15),
                      backgroundImage: _groupPhoto != null
                          ? CachedNetworkImageProvider(_groupPhoto!)
                          : null,
                      child: _groupPhoto == null
                          ? Icon(
                              Icons.group,
                              color: Theme.of(context).primaryColor,
                              size: 32,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentGroupName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            '${_memberNames.length} members',
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[600] : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Members',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const Spacer(),
                    // Only show Add button if user is admin
                    if (_isAdmin)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddMembersSheet();
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _groupChatService.getGroupMembers(widget.groupId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final members = snapshot.data!;
                    final currentUserId = _auth.currentUser?.uid;

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final memberId = member['id'] as String;
                        final isAdmin = member['isAdmin'] ?? false;
                        final isCreator = member['isCreator'] ?? false;
                        final isCurrentUser = memberId == currentUserId;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: member['photoUrl'] != null
                                ? CachedNetworkImageProvider(member['photoUrl'])
                                : null,
                            child: member['photoUrl'] == null
                                ? Text(
                                    (member['name'] ?? 'U')[0].toUpperCase(),
                                  )
                                : null,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${member['name'] ?? 'Unknown'}${isCurrentUser ? ' (You)' : ''}',
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCreator)
                                Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Creator',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              else if (isAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .primaryColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Admin',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onLongPress: _isAdmin && !isCurrentUser && !isCreator
                              ? () => _showMemberOptions(member)
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _leaveGroup(),
                      icon: const Icon(Icons.exit_to_app, color: Colors.red),
                      label: const Text(
                        'Leave Group',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMemberOptions(Map<String, dynamic> member) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final memberId = member['id'] as String;
    final memberName = member['name'] ?? 'Unknown';
    final isAdmin = member['isAdmin'] ?? false;
    final isCreator = _auth.currentUser?.uid == _createdBy;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
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
                memberName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            const Divider(height: 1),
            if (isCreator && !isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.blue),
                title: const Text('Make Admin'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  final success = await _groupChatService.makeAdmin(
                    groupId: widget.groupId,
                    memberId: memberId,
                  );
                  if (success && mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('$memberName is now an admin')),
                    );
                  }
                },
              ),
            if (isCreator && isAdmin)
              ListTile(
                leading: const Icon(Icons.remove_moderator, color: Colors.orange),
                title: const Text('Remove Admin'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  final success = await _groupChatService.removeAdmin(
                    groupId: widget.groupId,
                    memberId: memberId,
                  );
                  if (success && mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('$memberName is no longer an admin')),
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.remove_circle, color: Colors.red),
              title: const Text('Remove from Group', style: TextStyle(color: Colors.red)),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final parentContext = this.context;
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: parentContext,
                  builder: (context) => AlertDialog(
                    title: const Text('Remove Member?'),
                    content: Text('Remove $memberName from this group?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Remove', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  final success = await _groupChatService.removeMember(
                    groupId: widget.groupId,
                    memberId: memberId,
                  );
                  if (success && mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('$memberName removed from group')),
                    );
                  } else if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Failed to remove member. Only the creator can remove admins.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddMembersSheet() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final selectedUsers = <String>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
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
                        child: Row(
                          children: [
                            Text(
                              'Add Members',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            const Spacer(),
                            if (selectedUsers.isNotEmpty)
                              ElevatedButton(
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final navigator = Navigator.of(context);
                                  final success =
                                      await _groupChatService.addMembers(
                                    groupId: widget.groupId,
                                    newMemberIds: selectedUsers.toList(),
                                  );
                                  if (success && mounted) {
                                    navigator.pop();
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Members added successfully'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else if (mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Failed to add members. Only admins can add members.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                child: Text('Add (${selectedUsers.length})'),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _firestore.collection('users').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            final currentMembers = _memberNames.keys.toSet();
                            final users = snapshot.data!.docs
                                .where(
                                    (doc) => !currentMembers.contains(doc.id))
                                .toList();

                            if (users.isEmpty) {
                              return Center(
                                child: Text(
                                  'No more users to add',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.grey[600]
                                        : Colors.grey,
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              controller: scrollController,
                              itemCount: users.length,
                              itemBuilder: (context, index) {
                                final userData =
                                    users[index].data() as Map<String, dynamic>;
                                final userId = users[index].id;
                                final name = userData['name'] ?? 'Unknown';
                                final photoUrl = userData['photoUrl'];
                                final isSelected =
                                    selectedUsers.contains(userId);

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: photoUrl != null
                                        ? CachedNetworkImageProvider(photoUrl)
                                        : null,
                                    child: photoUrl == null
                                        ? Text(name[0].toUpperCase())
                                        : null,
                                  ),
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? Icon(
                                          Icons.check_circle,
                                          color: Theme.of(context).primaryColor,
                                        )
                                      : Icon(
                                          Icons.circle_outlined,
                                          color: isDarkMode
                                              ? Colors.grey[600]
                                              : Colors.grey,
                                        ),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setSheetState(() {
                                      if (isSelected) {
                                        selectedUsers.remove(userId);
                                      } else {
                                        selectedUsers.add(userId);
                                      }
                                    });
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
            );
          },
        );
      },
    );
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group?'),
        content: const Text(
          'Are you sure you want to leave this group? You will no longer receive messages from this group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _groupChatService.leaveGroup(widget.groupId);
      if (success && mounted) {
        Navigator.pop(context); // Close info sheet if open
        Navigator.pop(context); // Go back from chat
      }
    }
  }

  String _getTypingText() {
    if (_typingUsers.isEmpty) return '';

    final currentUserId = _auth.currentUser?.uid;
    final typingNames = _typingUsers
        .where((id) => id != currentUserId)
        .map((id) => _memberNames[id]?.split(' ').first ?? 'Someone')
        .toList();

    if (typingNames.isEmpty) return '';
    if (typingNames.length == 1) return '${typingNames[0]} is typing...';
    if (typingNames.length == 2) return '${typingNames.join(' and ')} are typing...';
    return '${typingNames.length} people are typing...';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF000000) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF000000) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('conversations').doc(widget.groupId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              _currentGroupName = data['groupName'] ?? widget.groupName;
              _groupPhoto = data['groupPhoto'];
              _memberNames = Map<String, String>.from(data['participantNames'] ?? {});
              _memberPhotos = Map<String, String?>.from(data['participantPhotos'] ?? {});
              _admins = List<String>.from(data['admins'] ?? []);
              _createdBy = data['createdBy'];
              _isAdmin = _admins.contains(currentUserId);

              // Get typing users
              final isTypingMap = Map<String, bool>.from(data['isTyping'] ?? {});
              _typingUsers = isTypingMap.entries
                  .where((e) => e.value == true && e.key != currentUserId)
                  .map((e) => e.key)
                  .toList();
            }

            final typingText = _getTypingText();

            return GestureDetector(
              onTap: _showGroupInfo,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        Theme.of(context).primaryColor.withValues(alpha: 0.15),
                    backgroundImage: _groupPhoto != null
                        ? CachedNetworkImageProvider(_groupPhoto!)
                        : null,
                    child: _groupPhoto == null
                        ? Icon(
                            Icons.group,
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentGroupName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          typingText.isNotEmpty
                              ? typingText
                              : '${_memberNames.length} members',
                          style: TextStyle(
                            fontSize: 12,
                            color: typingText.isNotEmpty
                                ? Theme.of(context).primaryColor
                                : (isDarkMode ? Colors.grey[600] : Colors.grey),
                            fontStyle: typingText.isNotEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            onPressed: _showGroupInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list with pagination
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('conversations')
                  .doc(widget.groupId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .limitToLast(_messagesPerPage) // Pagination: limit to last N messages
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data?.docs ?? [];

                // Store last document for pagination
                if (messages.isNotEmpty) {
                  _lastDocument = messages.first;
                  _hasMoreMessages = messages.length >= _messagesPerPage;
                }

                // Combine real messages with optimistic messages
                final allMessages = [
                  ...messages.map((doc) => {
                    'id': doc.id,
                    ...doc.data() as Map<String, dynamic>,
                  }),
                  ..._optimisticMessages,
                ];

                if (allMessages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group,
                          size: 80,
                          color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: isDarkMode ? Colors.grey[600] : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Mark as read when viewing messages
                _groupChatService.markAsRead(widget.groupId);

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_isLoadingMore) {
                    _scrollToBottom();
                  }
                });

                return Column(
                  children: [
                    // Loading indicator for pagination
                    if (_isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    // Load more indicator
                    if (_hasMoreMessages && messages.length >= _messagesPerPage)
                      TextButton(
                        onPressed: _loadMoreMessages,
                        child: Text(
                          'Load earlier messages',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: allMessages.length,
                        itemBuilder: (context, index) {
                          final messageData = allMessages[index];
                          final senderId = messageData['senderId'] as String;
                          final text = messageData['text'] as String? ?? '';
                          final timestamp = messageData['timestamp'] as Timestamp?;
                          final isSystemMessage = messageData['isSystemMessage'] ?? false;
                          final isOptimistic = messageData['isOptimistic'] ?? false;
                          final isMe = senderId == currentUserId;
                          final readBy = List<String>.from(messageData['readBy'] ?? []);

                          if (isSystemMessage) {
                            return _buildSystemMessage(text, isDarkMode);
                          }

                          return _buildMessageBubble(
                            text: text,
                            senderId: senderId,
                            isMe: isMe,
                            timestamp: timestamp,
                            isDarkMode: isDarkMode,
                            isOptimistic: isOptimistic,
                            readBy: readBy,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Message input
          Container(
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
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.grey[600] : Colors.grey,
                      ),
                      filled: true,
                      fillColor:
                          isDarkMode ? Colors.grey[900] : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (text) {
                      _groupChatService.setTyping(
                        widget.groupId,
                        text.isNotEmpty,
                      );
                    },
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(String text, bool isDarkMode) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required String senderId,
    required bool isMe,
    Timestamp? timestamp,
    required bool isDarkMode,
    bool isOptimistic = false,
    List<String> readBy = const [],
  }) {
    final senderName = _memberNames[senderId] ?? 'Unknown';
    final senderPhoto = _memberPhotos[senderId];
    final totalMembers = _memberNames.length;
    final readCount = readBy.length;

    return Opacity(
      opacity: isOptimistic ? 0.7 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                radius: 16,
                backgroundImage: senderPhoto != null
                    ? CachedNetworkImageProvider(senderPhoto)
                    : null,
                backgroundColor:
                    Theme.of(context).primaryColor.withValues(alpha: 0.1),
                child: senderPhoto == null
                    ? Text(
                        senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).primaryColor,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 4),
                      child: Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Theme.of(context).primaryColor
                          : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        color: isMe
                            ? Colors.white
                            : (isDarkMode ? Colors.white : Colors.black),
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12, right: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (timestamp != null)
                          Text(
                            DateFormat('h:mm a').format(timestamp.toDate()),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDarkMode ? Colors.grey[600] : Colors.grey,
                            ),
                          ),
                        // Read receipts for sent messages
                        if (isMe && !isOptimistic) ...[
                          const SizedBox(width: 4),
                          if (readCount >= totalMembers)
                            Icon(
                              Icons.done_all,
                              size: 14,
                              color: Theme.of(context).primaryColor,
                            )
                          else if (readCount > 1)
                            Icon(
                              Icons.done_all,
                              size: 14,
                              color: isDarkMode ? Colors.grey[600] : Colors.grey,
                            )
                          else
                            Icon(
                              Icons.done,
                              size: 14,
                              color: isDarkMode ? Colors.grey[600] : Colors.grey,
                            ),
                        ],
                        if (isOptimistic) ...[
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: isDarkMode ? Colors.grey[600] : Colors.grey,
                            ),
                          ),
                        ],
                      ],
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
}
