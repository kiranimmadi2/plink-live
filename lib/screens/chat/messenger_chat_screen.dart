import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:io';

import '../../res/config/app_text_styles.dart';
import '../../widgets/other widgets/glass_text_field.dart';
import '../../models/user_profile.dart';
import '../../res/utils/photo_url_helper.dart';

class MessengerChatScreen extends StatefulWidget {
  final UserProfile otherUser;
  final String? chatId;

  const MessengerChatScreen({super.key, required this.otherUser, this.chatId});

  @override
  State<MessengerChatScreen> createState() => _MessengerChatScreenState();
}

class _MessengerChatScreenState extends State<MessengerChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  String? _conversationId;
  bool _showScrollButton = false;
  File? _selectedImage;
  bool _isSending = false;

  // Voice recording state
  bool _isRecording = false;
  bool _isVoiceProcessing = false;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.chatId;
    _initConversation();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _startVoiceRecording() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRecording = true;
    });

    // Auto stop after 3 seconds
    _recordingTimer?.cancel();
    _recordingTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isRecording) {
        _stopVoiceRecording();
      }
    });
  }

  void _stopVoiceRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    if (!_isRecording) return;

    setState(() {
      _isRecording = false;
      _isVoiceProcessing = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    // Send voice message directly
    await _sendVoiceMessage();

    setState(() {
      _isVoiceProcessing = false;
    });
  }

  Future<void> _sendVoiceMessage() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Create conversation if doesn't exist
      if (_conversationId == null) {
        final docRef = await _firestore.collection('conversations').add({
          'participants': [currentUser.uid, widget.otherUser.uid],
          'lastMessage': '🎤 Voice message',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount': {currentUser.uid: 0, widget.otherUser.uid: 1},
          'createdAt': FieldValue.serverTimestamp(),
        });
        setState(() => _conversationId = docRef.id);
      }

      // Add voice message
      await _firestore
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .add({
            'senderId': currentUser.uid,
            'text': '',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'type': 'voice',
            'duration': 3, // Mock duration in seconds
          });

      // Update conversation
      await _firestore.collection('conversations').doc(_conversationId).update({
        'lastMessage': '🎤 Voice message',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount.${widget.otherUser.uid}': FieldValue.increment(1),
      });

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending voice message: $e')),
        );
      }
    }
  }

  void _onScroll() {
    if (_scrollController.offset > 200 && !_showScrollButton) {
      setState(() => _showScrollButton = true);
    } else if (_scrollController.offset <= 200 && _showScrollButton) {
      setState(() => _showScrollButton = false);
    }
  }

  Future<void> _initConversation() async {
    if (_conversationId != null) {
      _markMessagesAsRead();
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Find existing conversation
    final query = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUser.uid)
        .get();

    for (var doc in query.docs) {
      final participants = List<String>.from(doc['participants'] ?? []);
      if (participants.contains(widget.otherUser.uid)) {
        setState(() => _conversationId = doc.id);
        _markMessagesAsRead();
        return;
      }
    }
  }

  void _markMessagesAsRead() async {
    if (_conversationId == null) return;
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore.collection('conversations').doc(_conversationId).update({
      'unreadCount.${currentUser.uid}': 0,
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;
    if (_isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() => _isSending = false);
      return;
    }

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        final ref = _storage.ref().child(
          'chat_images/${DateTime.now().millisecondsSinceEpoch}_${currentUser.uid}.jpg',
        );
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
        setState(() => _selectedImage = null);
      }

      // Create conversation if doesn't exist
      if (_conversationId == null) {
        final docRef = await _firestore.collection('conversations').add({
          'participants': [currentUser.uid, widget.otherUser.uid],
          'lastMessage': text.isNotEmpty ? text : '📷 Photo',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount': {currentUser.uid: 0, widget.otherUser.uid: 1},
          'createdAt': FieldValue.serverTimestamp(),
        });
        setState(() => _conversationId = docRef.id);
      }

      // Add message
      await _firestore
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .add({
            'senderId': currentUser.uid,
            'text': text,
            'imageUrl': imageUrl,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'type': imageUrl != null ? 'image' : 'text',
          });

      // Update conversation
      await _firestore.collection('conversations').doc(_conversationId).update({
        'lastMessage': text.isNotEmpty ? text : '📷 Photo',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount.${widget.otherUser.uid}': FieldValue.increment(1),
      });

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage() async {
    Navigator.pop(context);
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _takePhoto() async {
    Navigator.pop(context);
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  void _showAttachmentOptions() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Camera option
                GestureDetector(
                  onTap: _takePhoto,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0084FF), Color(0xFF0066CC)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Camera',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Gallery option
                GestureDetector(
                  onTap: _pickImage,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.photo_library,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Gallery',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Grey glass background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey.shade800,
                  Colors.grey.shade900,
                  const Color(0xFF1a1a1a),
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
                      Colors.grey.shade700.withValues(alpha: 0.2),
                      Colors.grey.shade800.withValues(alpha: 0.3),
                      Colors.grey.shade900.withValues(alpha: 0.4),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Subtle highlight for glass effect
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

          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildMessagesList()),
                if (_selectedImage != null) _buildImagePreview(),
                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade800.withValues(alpha: 0.5),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(
            children: [
              // Back button
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: () => Navigator.pop(context),
              ),

              // Profile picture with online indicator
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey.shade700,
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
                                  ? widget.otherUser.name[0].toUpperCase()
                                  : '?',
                              style: AppTextStyles.titleLarge.copyWith(
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                  // Online indicator
                  StreamBuilder<DocumentSnapshot>(
                    stream: _firestore
                        .collection('users')
                        .doc(widget.otherUser.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      bool isOnline = false;
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data =
                            snapshot.data!.data() as Map<String, dynamic>;
                        isOnline = data['isOnline'] ?? false;
                      }
                      return Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.shade800,
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

              // Name and status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUser.name,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    StreamBuilder<DocumentSnapshot>(
                      stream: _firestore
                          .collection('users')
                          .doc(widget.otherUser.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        String status = 'Offline';
                        Color statusColor = Colors.grey;

                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>;
                          final isOnline = data['isOnline'] ?? false;
                          if (isOnline) {
                            status = 'Active now';
                            statusColor = Colors.green;
                          } else if (data['lastSeen'] != null) {
                            final lastSeen = (data['lastSeen'] as Timestamp)
                                .toDate();
                            status = 'Active ${timeago.format(lastSeen)}';
                          }
                        }

                        return Text(
                          status,
                          style: AppTextStyles.caption.copyWith(
                            color: statusColor,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Action buttons
              IconButton(
                icon: const Icon(Icons.phone, color: Colors.blue, size: 24),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  // TODO: Voice call
                },
              ),
              IconButton(
                icon: const Icon(Icons.videocam, color: Colors.blue, size: 26),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  // TODO: Video call
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_conversationId == null) {
      return _buildEmptyChat();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blue),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyChat();
        }

        final messages = snapshot.data!.docs;
        final currentUserId = _auth.currentUser?.uid;

        return Stack(
          children: [
            ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index].data() as Map<String, dynamic>;
                final isMe = message['senderId'] == currentUserId;
                final showAvatar =
                    !isMe &&
                    (index == messages.length - 1 ||
                        (messages[index + 1].data()
                                as Map<String, dynamic>)['senderId'] !=
                            message['senderId']);

                return _buildMessageBubble(message, isMe, showAvatar);
              },
            ),

            // Scroll to bottom button
            if (_showScrollButton)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.small(
                  backgroundColor: Colors.blue,
                  onPressed: _scrollToBottom,
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withValues(alpha: 0.1),
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey.shade700,
              backgroundImage:
                  PhotoUrlHelper.isValidUrl(widget.otherUser.profileImageUrl)
                  ? CachedNetworkImageProvider(
                      widget.otherUser.profileImageUrl!,
                    )
                  : null,
              child:
                  !PhotoUrlHelper.isValidUrl(widget.otherUser.profileImageUrl)
                  ? Text(
                      widget.otherUser.name.isNotEmpty
                          ? widget.otherUser.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.otherUser.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.waving_hand, color: Colors.amber),
            label: const Text(
              'Say Hi! 👋',
              style: TextStyle(color: Colors.white),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> message,
    bool isMe,
    bool showAvatar,
  ) {
    final text = message['text'] ?? '';
    final imageUrl = message['imageUrl'];
    final timestamp = message['timestamp'] as Timestamp?;
    final messageType = message['type'] ?? 'text';
    final duration = message['duration'] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Other user's avatar
          if (!isMe && showAvatar)
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey.shade700,
              backgroundImage:
                  PhotoUrlHelper.isValidUrl(widget.otherUser.profileImageUrl)
                  ? CachedNetworkImageProvider(
                      widget.otherUser.profileImageUrl!,
                    )
                  : null,
              child:
                  !PhotoUrlHelper.isValidUrl(widget.otherUser.profileImageUrl)
                  ? Text(
                      widget.otherUser.name.isNotEmpty
                          ? widget.otherUser.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    )
                  : null,
            )
          else if (!isMe)
            const SizedBox(width: 28),

          const SizedBox(width: 8),

          // Message bubble
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageOptions(message),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: imageUrl != null
                    ? const EdgeInsets.all(4)
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(
                          colors: [Color(0xFF0084FF), Color(0xFF0066CC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMe ? null : Colors.grey.shade800,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 200,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 200,
                            height: 150,
                            color: Colors.grey.shade700,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      ),
                    // Voice message UI
                    if (messageType == 'voice')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow,
                            color: isMe ? Colors.white : Colors.white70,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          // Wave visualization
                          Row(
                            children: List.generate(8, (index) {
                              return Container(
                                width: 3,
                                height:
                                    6.0 +
                                    (index % 3 == 0
                                        ? 12.0
                                        : (index % 2 == 0 ? 8.0 : 4.0)),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.white70
                                      : Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '0:${duration.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: isMe
                                  ? Colors.white70
                                  : Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    if (text.isNotEmpty && messageType != 'voice')
                      Text(
                        text,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timestamp != null
                              ? _formatTime(timestamp.toDate())
                              : '',
                          style: TextStyle(
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.grey.shade500,
                            fontSize: 10,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message['read'] == true
                                ? Icons.done_all
                                : Icons.done,
                            size: 14,
                            color: message['read'] == true
                                ? Colors.lightBlueAccent
                                : Colors.white.withValues(alpha: 0.7),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}';
    }
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white),
              title: const Text('Copy', style: TextStyle(color: Colors.white)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message['text'] ?? ''));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.white),
              title: const Text('Reply', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Reply functionality
              },
            ),
            if (message['senderId'] == _auth.currentUser?.uid)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Delete message
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(8),
      color: Colors.grey.shade900,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(_selectedImage!, height: 84, fit: BoxFit.cover),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => setState(() => _selectedImage = null),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3)),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Attachment button (camera + gallery)
                GestureDetector(
                  onTap: _showAttachmentOptions,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade800,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 22),
                  ),
                ),

                const SizedBox(width: 10),

                // Input container like HomeScreen
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      color: Colors.grey.shade900,
                      border: Border.all(
                        color: const Color.fromARGB(255, 100, 100, 100),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        // SMS icon
                        Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Icon(
                            Icons.sms_outlined,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                        ),

                        // Text field
                        Expanded(
                          child: GlassTextField(
                            controller: _messageController,
                            hintText: 'Message...',
                            textCapitalization: TextCapitalization.sentences,
                            maxLines: 4,
                            minLines: 1,
                            showBlur: false,
                            decoration: const BoxDecoration(),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 12,
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Mic button with recording animation inside
                GestureDetector(
                  onTap: (_isRecording || _isVoiceProcessing)
                      ? _stopVoiceRecording
                      : _startVoiceRecording,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: (_isRecording || _isVoiceProcessing) ? 56 : 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: (_isRecording || _isVoiceProcessing)
                          ? Colors.red
                          : Colors.grey.shade800,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording || _isVoiceProcessing)
                              ? Colors.red.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.1),
                          blurRadius: (_isRecording || _isVoiceProcessing)
                              ? 8
                              : 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: (_isRecording || _isVoiceProcessing)
                        ? _RecordingIndicator(isRecording: _isRecording)
                        : const Icon(Icons.mic, color: Colors.white, size: 22),
                  ),
                ),

                const SizedBox(width: 8),

                // Send button
                GestureDetector(
                  onTap: _isSending ? null : _sendMessage,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade800,
                    ),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Separate widget for recording animation to avoid full screen rebuild
class _RecordingIndicator extends StatefulWidget {
  final bool isRecording;

  const _RecordingIndicator({required this.isRecording});

  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator> {
  bool _visible = true;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _startBlinking();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  void _startBlinking() {
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() => _visible = !_visible);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated recording indicator dot
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _visible
                ? Colors.white
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(width: 6),
        // Wave bars inside mic button
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 3,
              height: _visible
                  ? (8.0 + (index == 1 ? 10.0 : 4.0))
                  : (8.0 + (index == 1 ? 4.0 : 10.0)),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ],
    );
  }
}
