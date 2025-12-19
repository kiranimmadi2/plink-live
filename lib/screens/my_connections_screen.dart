import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connection_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/chat_common.dart';
import '../models/user_profile.dart';
import '../providers/app_providers.dart';
import 'enhanced_chat_screen.dart';

class MyConnectionsScreen extends ConsumerStatefulWidget {
  const MyConnectionsScreen({super.key});

  @override
  ConsumerState<MyConnectionsScreen> createState() => _MyConnectionsScreenState();
}

class _MyConnectionsScreenState extends ConsumerState<MyConnectionsScreen> {
  final ConnectionService _connectionService = ConnectionService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper getter for current user ID from provider
  String? get _currentUserId => ref.read(currentUserIdProvider);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Connections'),
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Pending Connection Requests
            _buildPendingRequestsSection(isDarkMode),

            const SizedBox(height: 24),

            // Section 2: Established Connections
            _buildEstablishedConnectionsSection(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRequestsSection(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pending_outlined,
                color: Color(0xFF9C27B0),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Pending Requests',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _connectionService.getPendingRequestsStream(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _connectionService.getPendingRequestsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: Color(0xFF9C27B0)),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load requests',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final requests = snapshot.data ?? [];

              if (requests.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.pending_outlined,
                        size: 60,
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No pending requests',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode
                              ? Colors.grey[500]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return _buildRequestCard(request, isDarkMode);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEstablishedConnectionsSection(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: Color(0xFF00D67D), size: 24),
              const SizedBox(width: 12),
              const Text(
                'My Connections',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              FutureBuilder<int>(
                future: _connectionService.getConnectionsCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D67D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<String>>(
            future: _connectionService.getUserConnections(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: Color(0xFF00D67D)),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load connections',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final connectionIds = snapshot.data ?? [];

              if (connectionIds.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 80,
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No connections yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start connecting with people on Live Connect!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode
                              ? Colors.grey[600]
                              : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: connectionIds.length,
                itemBuilder: (context, index) {
                  final userId = connectionIds[index];
                  return FutureBuilder<DocumentSnapshot>(
                    future: _firestore.collection('users').doc(userId).get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return const SizedBox.shrink();
                      }

                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>?;
                      if (userData == null) return const SizedBox.shrink();

                      return _buildConnectionCard(userId, userData, isDarkMode);
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, bool isDarkMode) {
    final requestId = request['id'] as String?;
    final senderId = request['senderId'] as String?;
    final senderName = request['senderName'] as String? ?? 'Unknown User';
    final senderPhoto = request['senderPhoto'] as String?;
    final message = request['message'] as String?;
    final createdAt = request['createdAt'];

    if (requestId == null || senderId == null) return const SizedBox.shrink();

    // Format time ago
    String timeAgo = '';
    if (createdAt != null) {
      final timestamp = createdAt.toDate();
      final difference = DateTime.now().difference(timestamp);
      if (difference.inDays > 0) {
        timeAgo = '${difference.inDays}d';
      } else if (difference.inHours > 0) {
        timeAgo = '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        timeAgo = '${difference.inMinutes}m';
      } else {
        timeAgo = 'now';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDarkMode ? const Color(0xFF333333) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with avatar and info
            Row(
              children: [
                UserAvatar(
                  profileImageUrl: senderPhoto,
                  fallbackText: senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                  radius: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatDisplayName(senderName),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          if (timeAgo.isNotEmpty)
                            Text(
                              timeAgo,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message ?? 'Wants to connect with you',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Action buttons - Instagram style
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptRequest(requestId, senderName),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0095F6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _rejectRequest(requestId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode
                          ? const Color(0xFF363636)
                          : const Color(0xFFEFEFEF),
                      foregroundColor: isDarkMode ? Colors.white : Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 14,
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
    );
  }

  Widget _buildConnectionCard(
    String userId,
    Map<String, dynamic> userData,
    bool isDarkMode,
  ) {
    final name = userData['name'] ?? 'Unknown User';
    final photoUrl = userData['photoUrl'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDarkMode ? const Color(0xFF333333) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            UserAvatar(
              profileImageUrl: photoUrl,
              fallbackText: name.isNotEmpty ? name[0].toUpperCase() : 'U',
              radius: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDisplayName(name),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Connected',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF00D67D),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Action buttons
            IconButton(
              onPressed: () => _openChat(userId, userData),
              icon: const Icon(Icons.message_outlined),
              tooltip: 'Message',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF00D67D).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFF00D67D),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => _removeConnection(userId, name),
              icon: const Icon(Icons.person_remove_outlined),
              tooltip: 'Remove',
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.1),
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptRequest(String requestId, String senderName) async {
    try {
      final result = await _connectionService.acceptConnectionRequest(requestId);

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('You and ${formatDisplayName(senderName)} are now connected!'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF00D67D),
              duration: const Duration(seconds: 3),
            ),
          );
          // Refresh the connections list
          setState(() {});
        } else {
          throw Exception(result['message'] ?? 'Failed to accept request');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      final result = await _connectionService.rejectConnectionRequest(requestId);

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Request removed'),
                ],
              ),
              backgroundColor: Colors.grey,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          throw Exception(result['message'] ?? 'Failed to delete request');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeConnection(String userId, String userName) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : Colors.white,
        title: const Text('Remove Connection'),
        content: Text(
          'Are you sure you want to remove $userName from your connections?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) return;

      // Remove connection from both users
      await _firestore.collection('users').doc(currentUserId).update({
        'connections': FieldValue.arrayRemove([userId]),
        'connectionCount': FieldValue.increment(-1),
      });

      await _firestore.collection('users').doc(userId).update({
        'connections': FieldValue.arrayRemove([currentUserId]),
        'connectionCount': FieldValue.increment(-1),
      });

      if (mounted) {
        setState(() {}); // Refresh the list

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.person_remove, color: Colors.white),
                SizedBox(width: 12),
                Text('Connection removed'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openChat(String userId, Map<String, dynamic> userData) {
    try {
      // Validate user ID
      if (userId.isEmpty) {
        throw Exception('Invalid user ID');
      }

      // Validate required fields
      if (userData['name'] == null || userData['name'].toString().isEmpty) {
        throw Exception('User profile is incomplete (missing name)');
      }

      // Ensure userData has required fields with safe defaults
      final safeUserData = {
        'name': userData['name'] ?? 'Unknown User',
        'email': userData['email'] ?? '',
        'profileImageUrl': userData['profileImageUrl'] ?? userData['photoUrl'],
        'photoUrl': userData['photoUrl'] ?? userData['profileImageUrl'],
        'phone': userData['phone'],
        'location': userData['location'] ?? userData['city'],
        'latitude': userData['latitude'],
        'longitude': userData['longitude'],
        'createdAt': userData['createdAt'],
        'lastSeen': userData['lastSeen'],
        'isOnline': userData['isOnline'] ?? false,
        'isVerified': userData['isVerified'] ?? false,
        'showOnlineStatus': userData['showOnlineStatus'] ?? true,
        'bio': userData['bio'] ?? '',
        'interests': userData['interests'] ?? [],
        'fcmToken': userData['fcmToken'],
        'additionalInfo': userData['additionalInfo'],
      };

      // Create UserProfile with validated data
      final userProfile = UserProfile.fromMap(safeUserData, userId);

      // Navigate to chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedChatScreen(otherUser: userProfile),
        ),
      );

      debugPrint(
        'MyConnections: Successfully opened chat with ${userData['name']}',
      );
    } catch (e) {
      debugPrint('MyConnections ERROR opening chat: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.toString().replaceAll('Exception: ', ''),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }
}
