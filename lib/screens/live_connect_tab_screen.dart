import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../widgets/user_avatar.dart';
import '../providers/theme_provider.dart';
import 'enhanced_chat_screen.dart';
import 'profile_view_screen.dart';
import '../models/user_profile.dart';

class LiveConnectTabScreen extends StatefulWidget {
  const LiveConnectTabScreen({Key? key}) : super(key: key);

  @override
  State<LiveConnectTabScreen> createState() => _LiveConnectTabScreenState();
}

class _LiveConnectTabScreenState extends State<LiveConnectTabScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userProfile;
  List<String> _selectedInterests = [];
  List<Map<String, dynamic>> _nearbyPeople = [];
  bool _isLoadingPeople = false;

  // Filter options
  bool _filterByExactLocation = false;
  bool _filterByInterests = false;

  // Common interests for users to choose from
  final List<String> _availableInterests = [
    'Dating', 'Friendship', 'Business', 'Roommate', 'Job Seeker',
    'Hiring', 'Selling', 'Buying', 'Lost & Found', 'Events',
    'Sports', 'Travel', 'Food', 'Music', 'Movies', 'Gaming',
    'Fitness', 'Art', 'Technology', 'Photography', 'Fashion',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Load user profile
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && mounted) {
        final userData = userDoc.data();
        setState(() {
          _userProfile = userData;
          // Load user's saved interests
          _selectedInterests = List<String>.from(userData?['interests'] ?? []);
        });

        // Always load nearby people (filters can be applied via filter dialog)
        _loadNearbyPeople();
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> _loadNearbyPeople() async {
    if (!mounted) return;

    // If interest filter is on but no interests selected, return early
    if (_filterByInterests && _selectedInterests.isEmpty) return;

    setState(() {
      _isLoadingPeople = true;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userCity = _userProfile?['city'];
      final userLocation = _userProfile?['location'];

      // Build query based on filters
      Query<Map<String, dynamic>> usersQuery = _firestore.collection('users');

      // Apply interest filter if enabled
      if (_filterByInterests && _selectedInterests.isNotEmpty) {
        usersQuery = usersQuery.where('interests', arrayContainsAny: _selectedInterests);
      }

      // Apply exact location filter if enabled
      if (_filterByExactLocation && userCity != null && userCity.isNotEmpty) {
        usersQuery = usersQuery.where('city', isEqualTo: userCity);
      }

      usersQuery = usersQuery.limit(50);
      final usersSnapshot = await usersQuery.get();

      List<Map<String, dynamic>> people = [];
      for (var doc in usersSnapshot.docs) {
        if (doc.id == userId) continue; // Skip current user

        final userData = doc.data();
        final userInterests = List<String>.from(userData['interests'] ?? []);
        final otherUserCity = userData['city'];

        // Additional location check if filter is enabled (for cases where query didn't filter)
        if (_filterByExactLocation) {
          if (userCity != null && userCity.isNotEmpty) {
            if (otherUserCity == null || otherUserCity != userCity) {
              continue; // Skip if not in same city
            }
          }
        }

        // Calculate common interests
        List<String> commonInterests = [];
        double matchScore = 1.0; // Default match score when interest filter is off

        if (_filterByInterests && _selectedInterests.isNotEmpty) {
          commonInterests = _selectedInterests
              .where((interest) => userInterests.contains(interest))
              .toList();

          // Skip if no common interests when filter is on
          if (commonInterests.isEmpty) continue;

          matchScore = commonInterests.length / _selectedInterests.length;
        } else {
          // When interest filter is off, show all their interests as "common"
          commonInterests = userInterests;
        }

        // Add user with match data
        people.add({
          'userId': doc.id,
          'userData': userData,
          'commonInterests': commonInterests,
          'matchScore': matchScore,
        });
      }

      // Sort by match score (highest first)
      people.sort((a, b) => (b['matchScore'] as double).compareTo(a['matchScore'] as double));

      if (mounted) {
        setState(() {
          _nearbyPeople = people;
          _isLoadingPeople = false;
        });
      }
    } catch (e) {
      print('Error loading nearby people: $e');
      if (mounted) {
        setState(() {
          _isLoadingPeople = false;
        });
      }
    }
  }

  Future<void> _updateInterests() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'interests': _selectedInterests,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interests updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload nearby people
      _loadNearbyPeople();
    } catch (e) {
      print('Error updating interests: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update interests'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showInterestsDialog() {
    HapticFeedback.lightImpact();

    showDialog(
      context: context,
      builder: (context) {
        List<String> tempSelected = List.from(_selectedInterests);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Your Interests'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableInterests.length,
                  itemBuilder: (context, index) {
                    final interest = _availableInterests[index];
                    final isSelected = tempSelected.contains(interest);

                    return CheckboxListTile(
                      title: Text(interest),
                      value: isSelected,
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
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedInterests = tempSelected;
                    });
                    Navigator.pop(context);
                    _updateInterests();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter Options'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: const Text('Filter by Exact Location'),
                      subtitle: Text(
                        'Only show people in your exact city/area',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      value: _filterByExactLocation,
                      onChanged: (value) {
                        setDialogState(() {
                          _filterByExactLocation = value;
                        });
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Filter by Interests'),
                      subtitle: Text(
                        'Only show people with common interests',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      value: _filterByInterests,
                      onChanged: (value) {
                        setDialogState(() {
                          _filterByInterests = value;
                        });
                      },
                    ),
                    // Show selected interests
                    if (_filterByInterests) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Selected Interests:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showInterestsDialog();
                                  },
                                  icon: Icon(
                                    _selectedInterests.isEmpty ? Icons.add : Icons.edit,
                                    size: 16,
                                  ),
                                  label: Text(
                                    _selectedInterests.isEmpty ? 'Select' : 'Change',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_selectedInterests.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Select interests to find matching people',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _selectedInterests.map((interest) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      interest,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      // State is already updated from setDialogState
                    });
                    Navigator.pop(context);
                    // Reload nearby people with new filters
                    _loadNearbyPeople();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openChat(Map<String, dynamic> userData, String userId) {
    // Create UserProfile from userData
    final userProfile = UserProfile.fromMap(userData, userId);

    // Navigate to chat screen
    // EnhancedChatScreen handles conversation creation internally
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedChatScreen(
          otherUser: userProfile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final isGlass = themeProvider.isGlassmorphism;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              elevation: 0,
              backgroundColor: isGlass
                  ? Colors.white.withValues(alpha: 0.7)
                  : (isDarkMode ? Colors.black.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95)),
              automaticallyImplyLeading: false,
              title: Text(
                'Live Connect',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                // Filter Icon Button
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: (_filterByExactLocation || _filterByInterests)
                        ? Theme.of(context).primaryColor
                        : (isGlass
                            ? Colors.white.withValues(alpha: 0.7)
                            : (isDarkMode ? Colors.grey[900] : Colors.grey[100])),
                    borderRadius: BorderRadius.circular(12),
                    border: isGlass
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          )
                        : null,
                  ),
                  child: IconButton(
                    onPressed: _showFilterDialog,
                    icon: Icon(
                      Icons.filter_list,
                      color: (_filterByExactLocation || _filterByInterests)
                          ? Colors.white
                          : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                    ),
                    tooltip: 'Filter',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // iOS 16 Glassmorphism gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isGlass
                    ? [
                        const Color(0xFFE3F2FD).withValues(alpha: 0.8),
                        const Color(0xFFF3E5F5).withValues(alpha: 0.6),
                        const Color(0xFFE8F5E9).withValues(alpha: 0.4),
                        const Color(0xFFFFF3E0).withValues(alpha: 0.3),
                      ]
                    : isDarkMode
                        ? [
                            Colors.black,
                            const Color(0xFF1C1C1E),
                          ]
                        : [
                            const Color(0xFFF5F5F7),
                            Colors.white,
                          ],
              ),
            ),
          ),

          // Floating glass circles for depth
          if (isGlass) ...[
            Positioned(
              top: 150,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ThemeProvider.iosPurple.withValues(alpha: 0.2),
                      ThemeProvider.iosPurple.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 200,
              left: -100,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ThemeProvider.iosBlue.withValues(alpha: 0.15),
                      ThemeProvider.iosBlue.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Main content
          SafeArea(
            child: _buildContent(isDarkMode, isGlass),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDarkMode, bool isGlass) {
    // Show empty state only if interest filter is on AND no interests selected
    if (_filterByInterests && _selectedInterests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              'Connect with People',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Select your interests to find people with similar interests, or disable the interest filter to see everyone',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _showInterestsDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Select Interests'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _showFilterDialog,
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Filters'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_isLoadingPeople) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_nearbyPeople.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 60,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No matches found',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[600] : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try selecting different interests',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[700] : Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _nearbyPeople.length,
      itemBuilder: (context, index) {
        final person = _nearbyPeople[index];
        final userData = person['userData'] as Map<String, dynamic>;
        final commonInterests = person['commonInterests'] as List<String>;
        final matchScore = person['matchScore'] as double;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isGlass
                ? Colors.white.withValues(alpha: 0.7)
                : (isDarkMode ? Colors.grey[850] : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: isGlass
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  )
                : null,
            boxShadow: isGlass
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: isGlass
                  ? ImageFilter.blur(sigmaX: 10, sigmaY: 10)
                  : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: UserAvatar(
                  profileImageUrl: userData['profileImageUrl'] ?? userData['photoUrl'],
                  radius: 28,
                  fallbackText: userData['name'] ?? 'User',
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    color: Theme.of(context).primaryColor,
                  ),
                  onPressed: () => _openChat(userData, person['userId']),
                  tooltip: 'Start Chat',
                ),
                title: Text(
                  userData['name'] ?? 'Unknown User',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (userData['location'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              userData['location'],
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: commonInterests.take(3).map((interest) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            interest,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                onTap: () async {
                  // Navigate to their profile
                  final userProfile = UserProfile.fromMap(userData, person['userId']);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileViewScreen(
                        userProfile: userProfile,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
