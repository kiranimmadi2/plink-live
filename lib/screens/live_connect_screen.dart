import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/user_profile.dart';
import '../services/chat_service.dart';
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
  final ChatService _chatService = ChatService();

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;

  // Filter options
  bool _filterByExactLocation = false;
  bool _filterByInterests = false;
  List<String> _selectedInterests = [];

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

      // Query for all users
      Query query = _firestore.collection('users').where('uid', isNotEqualTo: userId);
      final snapshot = await query.limit(100).get();

      List<Map<String, dynamic>> users = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        users.add(data);
      }

      // Sort by last seen (most recent first)
      users.sort((a, b) {
        final aTime = a['lastSeen'] as Timestamp?;
        final bTime = b['lastSeen'] as Timestamp?;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _allUsers = users;
          _isLoading = false;
        });
        await _applyFilters();
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

  Future<void> _applyFilters() async {
    print('LiveConnect: Applying filters - Location: $_filterByExactLocation, Interests: $_filterByInterests');
    List<Map<String, dynamic>> filtered = List.from(_allUsers);
    print('LiveConnect: Total users before filtering: ${_allUsers.length}');

    // Get current user data for filtering
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();

      // Filter by exact location
      if (_filterByExactLocation && userData != null) {
        final userCity = userData['city'];
        print('LiveConnect: Filtering by city: $userCity');
        if (userCity != null) {
          filtered = filtered.where((user) => user['city'] == userCity).toList();
          print('LiveConnect: Users after location filter: ${filtered.length}');
        }
      }

      // Filter by interests
      if (_filterByInterests && _selectedInterests.isNotEmpty) {
        print('LiveConnect: Filtering by interests: $_selectedInterests');
        filtered = filtered.where((user) {
          final userInterests = List<String>.from(user['interests'] ?? []);
          return userInterests.any((interest) => _selectedInterests.contains(interest));
        }).toList();
        print('LiveConnect: Users after interest filter: ${filtered.length}');
      }
    }

    if (mounted) {
      setState(() {
        _filteredUsers = filtered;
      });
    }
    print('LiveConnect: Final filtered users count: ${_filteredUsers.length}');
  }

  void _showFilterDialog() async {
    // Get current user's interests
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data();
    final allInterests = List<String>.from(userData?['interests'] ?? []);

    // Temporary filter values
    bool tempFilterByLocation = _filterByExactLocation;
    bool tempFilterByInterests = _filterByInterests;
    List<String> tempSelectedInterests = List.from(_selectedInterests);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFF2A2A2A),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Options',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Filter by Exact Location
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Filter by Exact Location',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Only show people in your exact city/area',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: tempFilterByLocation,
                        onChanged: (value) {
                          setModalState(() {
                            tempFilterByLocation = value;
                          });
                        },
                        activeColor: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Filter by Interests
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Filter by Interests',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Only show people with common interests',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: tempFilterByInterests,
                        onChanged: (value) {
                          setModalState(() {
                            tempFilterByInterests = value;
                          });
                        },
                        activeColor: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Selected Interests
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selected Interests:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          _showInterestSelector(
                            allInterests,
                            tempSelectedInterests,
                            (selected) {
                              setModalState(() {
                                tempSelectedInterests = selected;
                              });
                            },
                          );
                        },
                        icon: Icon(
                          Icons.edit,
                          size: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                        label: Text(
                          'Change',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tempSelectedInterests.isEmpty
                        ? [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey[600]!,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'No interests selected',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ),
                          ]
                        : tempSelectedInterests.map((interest) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).primaryColor,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                interest,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                  ),
                  const SizedBox(height: 32),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              _filterByExactLocation = tempFilterByLocation;
                              _filterByInterests = tempFilterByInterests;
                              _selectedInterests = tempSelectedInterests;
                            });
                            Navigator.pop(context);
                            await _applyFilters();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Apply',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showInterestSelector(
    List<String> allInterests,
    List<String> currentSelected,
    Function(List<String>) onChanged,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        List<String> tempSelected = List.from(currentSelected);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2A2A2A),
              title: const Text(
                'Select Interests',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: allInterests.map((interest) {
                    final isSelected = tempSelected.contains(interest);
                    return CheckboxListTile(
                      title: Text(
                        interest,
                        style: const TextStyle(color: Colors.white),
                      ),
                      value: isSelected,
                      activeColor: Theme.of(context).primaryColor,
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            tempSelected.add(interest);
                          } else {
                            tempSelected.remove(interest);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    onChanged(tempSelected);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 4️⃣ OPEN OR CREATE CHAT - NAVIGATION LOGIC
  // ═══════════════════════════════════════════════════════════════

  /// Opens an existing chat or creates a new one with the selected user
  ///
  /// This function:
  /// 1. Shows a loading indicator
  /// 2. Calls ChatService.getOrCreateChat()
  /// 3. Navigates to the chat screen with the chatId
  /// 4. Handles errors gracefully
  Future<void> _openOrCreateChat(Map<String, dynamic> userData) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      final otherUserId = userData['uid'];

      if (currentUserId == null || otherUserId == null) {
        throw Exception('User ID not found');
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get or create chat using ChatService
      final chatId = await _chatService.getOrCreateChat(
        currentUserId,
        otherUserId,
        otherUserName: userData['name'] ?? 'Unknown',
        otherUserPhoto: userData['photoUrl'],
      );

      // Close loading indicator
      if (mounted) {
        Navigator.pop(context);
      }

      // Create UserProfile for the other user
      final otherUserProfile = UserProfile.fromMap(userData, otherUserId);

      // Navigate to chat screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EnhancedChatScreen(
              otherUser: otherUserProfile,
              chatId: chatId, // Pass the chatId directly
            ),
          ),
        );
      }

      print('LiveConnect: Opened chat $chatId with user ${userData['name']}');

    } catch (e) {
      print('LiveConnect ERROR opening chat: $e');

      // Close loading indicator if open
      if (mounted) {
        Navigator.pop(context);
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildUserCard(Map<String, dynamic> userData) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final name = userData['name'] ?? 'Unknown User';
    final photoUrl = userData['photoUrl'];
    final location = userData['displayLocation'] ?? userData['city'] ?? userData['location'];
    final interests = List<String>.from(userData['interests'] ?? []);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Profile Image
          CircleAvatar(
            radius: 28,
            backgroundColor: photoUrl == null ? Theme.of(context).primaryColor : null,
            backgroundImage: photoUrl != null
                ? CachedNetworkImageProvider(photoUrl)
                : null,
            child: photoUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                : null,
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
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (location != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
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
                          border: Border.all(
                            color: Theme.of(context).primaryColor,
                            width: 1,
                          ),
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
          // Chat Icon
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            color: Theme.of(context).primaryColor,
            onPressed: () => _openOrCreateChat(userData),
            tooltip: 'Start Chat',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : const Color(0xFF121212),
        title: const Text(
          'Live Connect',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.menu),
              color: Colors.white,
              onPressed: _showFilterDialog,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLiveUsers,
              child: _buildUsersList(),
            ),
    );
  }

  Widget _buildUsersList() {
    final users = _filteredUsers;

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
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
      padding: const EdgeInsets.only(top: 8),
      itemCount: users.length,
      itemBuilder: (context, index) {
        return _buildUserCard(users[index]);
      },
    );
  }
}
