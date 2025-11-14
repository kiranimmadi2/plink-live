import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/user_profile.dart';
import 'profile_view_screen.dart';
import 'enhanced_chat_screen.dart';

class LiveConnectScreen extends StatefulWidget {
  const LiveConnectScreen({Key? key}) : super(key: key);

  @override
  State<LiveConnectScreen> createState() => _LiveConnectScreenState();
}

class _LiveConnectScreenState extends State<LiveConnectScreen>
    with AutomaticKeepAliveClientMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _onlineUsers = [];
  List<Map<String, dynamic>> _nearbyUsers = [];
  bool _isLoading = true;
  bool _showOnlineOnly = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadLiveUsers();
  }

  Future<void> _loadLiveUsers() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get current user's location
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final userCity = userData?['city'];

      // Query for users
      Query query = _firestore.collection('users').where('uid', isNotEqualTo: userId);

      final snapshot = await query.limit(100).get();

      List<Map<String, dynamic>> online = [];
      List<Map<String, dynamic>> nearby = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final isOnline = data['isOnline'] == true;
        final lastSeen = data['lastSeen'] as Timestamp?;
        final userCityMatch = userCity != null && data['city'] == userCity;

        // Check if user was online in last 5 minutes
        final isRecentlyActive = lastSeen != null &&
            DateTime.now().difference(lastSeen.toDate()).inMinutes < 5;

        if (isOnline || isRecentlyActive) {
          online.add(data);
        }

        if (userCityMatch) {
          nearby.add(data);
        }
      }

      // Sort online users by last seen (most recent first)
      online.sort((a, b) {
        final aTime = a['lastSeen'] as Timestamp?;
        final bTime = b['lastSeen'] as Timestamp?;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _onlineUsers = online;
          _nearbyUsers = nearby;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading live users: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildUserCard(Map<String, dynamic> userData) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isOnline = userData['isOnline'] == true;
    final lastSeen = userData['lastSeen'] as Timestamp?;
    final name = userData['name'] ?? 'Unknown User';
    final photoUrl = userData['photoUrl'];
    final location = userData['displayLocation'] ?? userData['city'] ?? userData['location'];
    final interests = List<String>.from(userData['interests'] ?? []);

    String statusText = '';
    if (isOnline) {
      statusText = 'Online now';
    } else if (lastSeen != null) {
      statusText = 'Active ${timeago.format(lastSeen.toDate())}';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          try {
            final userId = userData['uid'] ?? '';
            final userProfile = UserProfile.fromMap(userData, userId);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileViewScreen(
                  userProfile: userProfile,
                ),
              ),
            );
          } catch (e) {
            print('Error navigating to profile: $e');
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Profile Image with Online Indicator
              Stack(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: photoUrl != null
                        ? CachedNetworkImageProvider(photoUrl)
                        : null,
                    child: photoUrl == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 24,
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
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (statusText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isOnline ? Colors.green : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 13,
                              color: isOnline ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (location != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (interests.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: interests.take(3).map((interest) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              interest,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              // Action Buttons
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    color: Theme.of(context).primaryColor,
                    onPressed: () {
                      try {
                        final userId = userData['uid'] ?? '';
                        final userProfile = UserProfile.fromMap(userData, userId);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EnhancedChatScreen(
                              otherUser: userProfile,
                            ),
                          ),
                        );
                      } catch (e) {
                        print('Error opening chat: $e');
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Connect',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLiveUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                FilterChip(
                  label: Text('Online Now (${_onlineUsers.length})'),
                  selected: _showOnlineOnly,
                  onSelected: (selected) {
                    setState(() {
                      _showOnlineOnly = true;
                    });
                  },
                  selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                  checkmarkColor: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: Text('Nearby (${_nearbyUsers.length})'),
                  selected: !_showOnlineOnly,
                  onSelected: (selected) {
                    setState(() {
                      _showOnlineOnly = false;
                    });
                  },
                  selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                  checkmarkColor: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Users List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadLiveUsers,
                    child: _buildUsersList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    final users = _showOnlineOnly ? _onlineUsers : _nearbyUsers;

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showOnlineOnly ? Icons.person_off_outlined : Icons.location_off_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _showOnlineOnly
                  ? 'No users online right now'
                  : 'No nearby users found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pull down to refresh',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        return _buildUserCard(users[index]);
      },
    );
  }
}
