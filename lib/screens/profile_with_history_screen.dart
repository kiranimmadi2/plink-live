import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/universal_intent_service.dart';
import '../services/location_service.dart';
import '../services/activity_migration_service.dart';
import '../widgets/user_avatar.dart';
import '../providers/theme_provider.dart';
import 'login_screen.dart';
import 'profile_edit_screen.dart';
import 'profile_view_screen.dart';
import 'settings_screen.dart';
import 'enhanced_chat_screen.dart';
import '../models/user_profile.dart';

class ProfileWithHistoryScreen extends ConsumerStatefulWidget {
  const ProfileWithHistoryScreen({super.key});

  @override
  ConsumerState<ProfileWithHistoryScreen> createState() =>
      _ProfileWithHistoryScreenState();
}

class _ProfileWithHistoryScreenState
    extends ConsumerState<ProfileWithHistoryScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UniversalIntentService _intentService = UniversalIntentService();
  final LocationService _locationService = LocationService();
  final ActivityMigrationService _migrationService = ActivityMigrationService();

  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _searchHistory = [];
  List<String> _selectedInterests = [];
  List<Map<String, dynamic>> _nearbyPeople = [];
  bool _isLoading = true;
  bool _isLoadingPeople = false;
  String? _error;

  // Filter options
  bool _filterByExactLocation = false;
  bool _filterByInterests = false;

  StreamSubscription<DocumentSnapshot>? _profileSubscription;

  // Profile edit mode
  bool _isEditMode = false;
  List<String> _selectedConnectionTypes = [];
  List<String> _selectedActivities = []; // Store only activity names, no level
  String _aboutMe = '';
  final TextEditingController _aboutMeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupProfileListener(); // Listen for real-time profile updates

    // Use addPostFrameCallback to defer location update until after initial frame
    // This prevents blocking the UI during widget initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateLocationIfNeeded();
      }
    });
  }

  void _setupProfileListener() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Listen for real-time profile changes (like location updates from background service)
    // Use distinct() to prevent unnecessary rebuilds when data hasn't actually changed
    _profileSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          if (snapshot.exists) {
            final userData = snapshot.data();

            // OPTIMIZATION: Only call setState if data actually changed
            // This prevents unnecessary rebuilds that cause frame drops
            final newCity = userData?['city'];
            final newLocation = userData?['location'];
            final newInterests = List<String>.from(
              userData?['interests'] ?? [],
            );

            final oldCity = _userProfile?['city'];
            final oldLocation = _userProfile?['location'];

            // Check if anything meaningful changed
            final cityChanged = newCity != oldCity;
            final locationChanged = newLocation != oldLocation;
            final interestsChanged = !_listEquals(
              newInterests,
              _selectedInterests,
            );

            if (cityChanged ||
                locationChanged ||
                interestsChanged ||
                _userProfile == null) {
              setState(() {
                _userProfile = userData;
                _selectedInterests = newInterests;
              });

              // Only log in debug mode
              // debugPrint('ProfileScreen: Profile updated - city=$newCity');
            }
          }
        });
  }

  // Helper to compare lists
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _aboutMeController.dispose();
    super.dispose();
  }

  Future<void> _updateLocationIfNeeded() async {
    try {
      // Check if widget is still mounted before proceeding
      if (!mounted) return;

      // Check if user's location needs updating
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userDoc = await _firestore.collection('users').doc(userId).get();

      // Check mounted again after async operation
      if (!mounted) return;

      if (userDoc.exists) {
        final data = userDoc.data();

        // Update location if it's not set or if it says generic location
        if (data?['displayLocation'] == null ||
            data?['displayLocation'] == 'Location detected' ||
            data?['displayLocation'] == 'Location detected (Web)' ||
            (data?['city'] == null ||
                data?['city'] == 'Location not set' ||
                data?['city'] == '' ||
                data?['city'] == 'Location detected' ||
                data?['city'] == 'Location detected (Web)')) {
          // Update location SILENTLY in background without blocking UI
          // Run this as fire-and-forget to prevent blocking
          _locationService
              .updateUserLocation(silent: true)
              .then((success) {
                if (!mounted) return; // Check mounted before continuing

                if (success) {
                  // Short delay to let Firestore propagate, then reload
                  Future.delayed(const Duration(milliseconds: 500)).then((_) {
                    if (mounted) {
                      _loadUserData();
                    }
                  });
                }
              })
              .catchError((error) {
                debugPrint('ProfileScreen: Location update error: $error');
              });
        }
      } else {
        // Document doesn't exist, create it with location
        // Update location SILENTLY in background
        _locationService
            .updateUserLocation(silent: true)
            .then((success) {
              if (!mounted) return;

              if (success) {
                Future.delayed(const Duration(milliseconds: 500)).then((_) {
                  if (mounted) {
                    _loadUserData();
                  }
                });
              }
            })
            .catchError((error) {
              debugPrint('ProfileScreen: Location creation error: $error');
            });
      }
    } catch (e) {
      debugPrint('ProfileScreen: Error updating location: $e');
      // Don't crash the app, just log the error
    }
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      // Load user profile
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && mounted) {
        final userData = userDoc.data();
        setState(() {
          _userProfile = userData;
          // Load user's saved interests
          _selectedInterests = List<String>.from(userData?['interests'] ?? []);
          // Load connection types, activities, and about me
          _selectedConnectionTypes = List<String>.from(
            userData?['connectionTypes'] ?? [],
          );
          _aboutMe = userData?['aboutMe'] ?? '';
          _aboutMeController.text = _aboutMe;

          // Load activities
          final activitiesData = userData?['activities'] as List<dynamic>?;
          if (activitiesData != null) {
            _selectedActivities = activitiesData.map((item) {
              // Extract only the activity name
              if (item is Map) {
                return item['name']?.toString() ?? '';
              } else if (item is String) {
                return item;
              } else {
                return item.toString();
              }
            }).toList();
          }
        });

        // Debug logging disabled for production
        // print('User profile loaded: city=${userData?['city']}, location=${userData?['location']}, interests=$_selectedInterests');

        // Always load nearby people (filters can be applied via filter dialog)
        _loadNearbyPeople();
      }

      // Load search history
      try {
        final intentsQuery = _firestore
            .collection('user_intents')
            .where('userId', isEqualTo: userId);

        final intents = await intentsQuery.limit(20).get();

        if (mounted) {
          setState(() {
            _searchHistory = intents.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList();

            // Sort by createdAt if available
            _searchHistory.sort((a, b) {
              final aTime = a['createdAt'];
              final bTime = b['createdAt'];
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return (bTime as Timestamp).compareTo(aTime as Timestamp);
            });
          });
        }
      } catch (e) {
        print('Error loading search history: $e');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _error = 'Error loading profile data';
          _isLoading = false;
        });
      }
    }
  }

  // Common interests for users to choose from
  final List<String> _availableInterests = [
    'Dating',
    'Friendship',
    'Business',
    'Roommate',
    'Job Seeker',
    'Hiring',
    'Selling',
    'Buying',
    'Lost & Found',
    'Events',
    'Sports',
    'Travel',
    'Food',
    'Music',
    'Movies',
    'Gaming',
    'Fitness',
    'Art',
    'Technology',
    'Photography',
    'Fashion',
  ];

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
        usersQuery = usersQuery.where(
          'interests',
          arrayContainsAny: _selectedInterests,
        );
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
        double matchScore =
            1.0; // Default match score when interest filter is off

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
      people.sort(
        (a, b) =>
            (b['matchScore'] as double).compareTo(a['matchScore'] as double),
      );

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
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                                    _selectedInterests.isEmpty
                                        ? Icons.add
                                        : Icons.edit,
                                    size: 16,
                                  ),
                                  label: Text(
                                    _selectedInterests.isEmpty
                                        ? 'Select'
                                        : 'Change',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                                  border: Border.all(
                                    color: Colors.orange.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: Colors.orange.shade700,
                                    ),
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withValues(alpha: 0.3),
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

  Future<void> _logout() async {
    HapticFeedback.mediumImpact();

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  Future<void> _saveProfile() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // Activities are already simple strings
      final activitiesData = _selectedActivities;

      await _firestore.collection('users').doc(userId).update({
        'connectionTypes': _selectedConnectionTypes,
        'activities': activitiesData,
        'aboutMe': _aboutMeController.text.trim(),
        'interests': _selectedInterests,
      });

      if (mounted) {
        setState(() {
          _isEditMode = false;
          _aboutMe = _aboutMeController.text.trim();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload profile
        _loadUserData();
      }
    } catch (e) {
      print('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Available connection types
  final List<String> _availableConnectionTypes = [
    'Friendship',
    'Dating',
    'Professional Networking',
    'Activity Partner',
    'Event Companion',
  ];

  // Available activities
  final List<String> _availableActivities = [
    'Gym',
    'Hiking',
    'Coding',
    'Running',
    'Swimming',
    'Cycling',
    'Yoga',
    'Reading',
    'Photography',
    'Cooking',
    'Dancing',
    'Music',
    'Gaming',
    'Travel',
    'gaming',
  ];

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final isDarkMode = themeState.isDarkMode;
    final isGlass = themeState.isGlassmorphism;

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
                  : (isDarkMode
                        ? Colors.black.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.95)),
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                onPressed: () {
                  // Navigate back to home screen (Discover tab)
                  // Pop until we reach the MainNavigationScreen (first route)
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
              ),
              title: Text(
                'Profile',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.settings,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
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
                    ? [Colors.black, const Color(0xFF1C1C1E)]
                    : [const Color(0xFFF5F5F7), Colors.white],
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
                      AppColors.iosPurple.withValues(alpha: 0.2),
                      AppColors.iosPurple.withValues(alpha: 0.0),
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
                      AppColors.iosBlue.withValues(alpha: 0.15),
                      AppColors.iosBlue.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],

          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUserData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: kToolbarHeight + 30),
                          // Profile Header
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isGlass
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : (isDarkMode
                                        ? Colors.grey[900]
                                        : Colors.white),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isGlass
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.08,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                              border: isGlass
                                  ? Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // Profile Photo
                                    UserAvatar(
                                      profileImageUrl:
                                          _userProfile?['profileImageUrl'] ??
                                          _userProfile?['photoUrl'],
                                      radius: 50,
                                      fallbackText:
                                          _userProfile?['name'] ?? 'User',
                                    ),
                                    const SizedBox(width: 20),
                                    // User Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _userProfile?['name'] ??
                                                'Unknown User',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : Colors.black,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.email_outlined,
                                                size: 16,
                                                color: isDarkMode
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  _userProfile?['email'] ??
                                                      _auth
                                                          .currentUser
                                                          ?.email ??
                                                      'No email',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: isDarkMode
                                                        ? Colors.grey[400]
                                                        : Colors.grey[600],
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          GestureDetector(
                                            onTap: () async {
                                              // Manual location update
                                              if (!mounted) return;

                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Updating location...',
                                                  ),
                                                ),
                                              );

                                              try {
                                                // User manually clicked to update location, so NOT silent
                                                final success =
                                                    await _locationService
                                                        .updateUserLocation(
                                                          silent: false,
                                                        );

                                                // Check mounted after async operation
                                                if (!mounted) return;

                                                if (success) {
                                                  // Short delay for Firestore propagation
                                                  await Future.delayed(
                                                    const Duration(
                                                      milliseconds: 500,
                                                    ),
                                                  );

                                                  // Check mounted again after delay
                                                  if (!mounted) return;

                                                  _loadUserData();

                                                  if (mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Location updated successfully',
                                                        ),
                                                        backgroundColor:
                                                            Colors.green,
                                                      ),
                                                    );
                                                  }
                                                } else {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Could not update location',
                                                        ),
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                    );
                                                  }
                                                }
                                              } catch (e) {
                                                print(
                                                  'Error during manual location update: $e',
                                                );
                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Location update failed',
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .location_on_outlined,
                                                      size: 16,
                                                      color: isDarkMode
                                                          ? Colors.grey[400]
                                                          : Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        _userProfile?['displayLocation'] ??
                                                            _userProfile?['city'] ??
                                                            _userProfile?['location'] ??
                                                            'Tap to set location',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color:
                                                              (_userProfile?['displayLocation'] ==
                                                                      null &&
                                                                  _userProfile?['city'] ==
                                                                      null &&
                                                                  _userProfile?['location'] ==
                                                                      null)
                                                              ? Theme.of(
                                                                  context,
                                                                ).primaryColor
                                                              : isDarkMode
                                                              ? Colors.grey[400]
                                                              : Colors
                                                                    .grey[600],
                                                          decoration:
                                                              (_userProfile?['displayLocation'] ==
                                                                      null &&
                                                                  _userProfile?['city'] ==
                                                                      null &&
                                                                  _userProfile?['location'] ==
                                                                      null)
                                                              ? TextDecoration
                                                                    .underline
                                                              : null,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                // Location freshness indicator
                                                if (_userProfile?['locationUpdatedAt'] !=
                                                    null)
                                                  FutureBuilder<int?>(
                                                    future: _locationService
                                                        .getLocationAgeInHours(),
                                                    builder: (context, snapshot) {
                                                      if (snapshot.hasData &&
                                                          snapshot.data !=
                                                              null) {
                                                        final hours =
                                                            snapshot.data!;
                                                        String timeText;
                                                        Color indicatorColor;

                                                        if (hours < 1) {
                                                          timeText =
                                                              'Updated recently';
                                                          indicatorColor =
                                                              Colors.green;
                                                        } else if (hours < 24) {
                                                          timeText =
                                                              'Updated ${hours}h ago';
                                                          indicatorColor =
                                                              Colors.green;
                                                        } else if (hours < 48) {
                                                          timeText =
                                                              'Updated 1 day ago';
                                                          indicatorColor =
                                                              Colors.orange;
                                                        } else {
                                                          final days =
                                                              (hours / 24)
                                                                  .floor();
                                                          timeText =
                                                              'Updated $days days ago';
                                                          indicatorColor =
                                                              Colors.red;
                                                        }

                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                left: 22,
                                                                top: 4,
                                                              ),
                                                          child: Row(
                                                            children: [
                                                              Container(
                                                                width: 7,
                                                                height: 7,
                                                                decoration: BoxDecoration(
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  color:
                                                                      indicatorColor,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 6,
                                                              ),
                                                              Text(
                                                                timeText,
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color:
                                                                      isDarkMode
                                                                      ? Colors
                                                                            .grey[500]
                                                                      : Colors
                                                                            .grey[500],
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }
                                                      return const SizedBox.shrink();
                                                    },
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Profile Detail Sections removed
                        ],
                      ),
                    ),

                    // History Content
                    ..._buildHistorySliver(isDarkMode, isGlass),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildConnectionTypesSection(bool isDarkMode, bool isGlass) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isGlass
            ? Colors.white.withValues(alpha: 0.7)
            : (isDarkMode ? Colors.grey[900] : Colors.white),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isGlass
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
        border: isGlass
            ? Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite_outline,
                size: 20,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Looking to connect for:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isEditMode)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableConnectionTypes.map((type) {
                final isSelected = _selectedConnectionTypes.contains(type);
                return FilterChip(
                  label: Text(type),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedConnectionTypes.add(type);
                      } else {
                        _selectedConnectionTypes.remove(type);
                      }
                    });
                  },
                  selectedColor: Theme.of(
                    context,
                  ).primaryColor.withValues(alpha: 0.3),
                  checkmarkColor: Theme.of(context).primaryColor,
                );
              }).toList(),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedConnectionTypes.map((type) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getConnectionTypeColor(type),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    type,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildActivitiesSection(bool isDarkMode, bool isGlass) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isGlass
            ? Colors.white.withValues(alpha: 0.7)
            : (isDarkMode ? Colors.grey[900] : Colors.white),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isGlass
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
        border: isGlass
            ? Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sports_soccer,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Activities:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              if (_isEditMode)
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () => _showAddActivityDialog(),
                  tooltip: 'Add Activity',
                ),
              // Migration button - always visible to fix old data
              IconButton(
                icon: const Icon(Icons.cleaning_services, size: 20),
                onPressed: () => _migrateActivities(),
                tooltip: 'Fix Activities (Remove Level)',
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isEditMode)
            ..._selectedActivities.map((activity) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF9B59B6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF9B59B6)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        activity,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.red,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedActivities.remove(activity);
                        });
                      },
                    ),
                  ],
                ),
              );
            })
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedActivities.map((activity) {
                return GestureDetector(
                  onLongPress: () {
                    // Show delete confirmation
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Activity'),
                        content: Text('Remove "$activity" from activities?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              setState(() {
                                _selectedActivities.remove(activity);
                              });
                              // Update Firestore
                              try {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(FirebaseAuth.instance.currentUser?.uid)
                                    .update({
                                      'activities': _selectedActivities,
                                    });
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Deleted $activity'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error deleting activity: $e',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B59B6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      activity,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(bool isDarkMode, bool isGlass) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isGlass
            ? Colors.white.withValues(alpha: 0.7)
            : (isDarkMode ? Colors.grey[900] : Colors.white),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isGlass
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
        border: isGlass
            ? Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          if (_isEditMode)
            TextField(
              controller: _aboutMeController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Tell us about yourself...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
              ),
              style: TextStyle(
                fontSize: 15,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            )
          else
            Text(
              _aboutMe,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInterestsSection(bool isDarkMode, bool isGlass) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isGlass
            ? Colors.white.withValues(alpha: 0.7)
            : (isDarkMode ? Colors.grey[900] : Colors.white),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isGlass
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
        border: isGlass
            ? Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Interests & Hobbies:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              if (_isEditMode)
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: _showInterestsDialog,
                  tooltip: 'Edit Interests',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedInterests.map((interest) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D67D),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  interest,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showAddActivityDialog() {
    String? selectedActivity;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Activity'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Activity',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: selectedActivity,
                    items: _availableActivities.map((activity) {
                      return DropdownMenuItem(
                        value: activity,
                        child: Text(activity),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedActivity = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedActivity != null) {
                      setState(() {
                        _selectedActivities.add(selectedActivity!);
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _migrateActivities() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Migrating activities...'),
          ],
        ),
      ),
    );

    try {
      final result = await _migrationService.migrateCurrentUserActivities();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        if (result['success']) {
          // Reload profile data
          await _loadUserData();

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Migration Complete'),
              content: Text(
                'Successfully migrated ${result['migrated']} activities.\n\n'
                'Activities are now in the new format without level information.\n\n'
                'Please restart the app to see the changes.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Migration Failed'),
              content: Text(result['message']),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to migrate activities: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Color _getConnectionTypeColor(String type) {
    switch (type) {
      case 'Professional Networking':
        return const Color(0xFF4A90E2);
      case 'Activity Partner':
        return const Color(0xFF00D67D);
      case 'Event Companion':
        return const Color(0xFFFFB800);
      case 'Friendship':
        return const Color(0xFFFF6B9D);
      case 'Dating':
        return const Color(0xFFFF4444);
      default:
        return const Color(0xFF00D67D);
    }
  }

  List<Widget> _buildHistorySliver(bool isDarkMode, bool isGlass) {
    if (_searchHistory.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 100),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 60,
                  color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'No search history',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.grey[600] : Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your searches will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final intent = _searchHistory[index];
            final createdAt = intent['createdAt'];
            String timeAgo = 'Recently';

            if (createdAt != null && createdAt is Timestamp) {
              timeAgo = timeago.format(createdAt.toDate());
            }

            return Dismissible(
              key: Key(intent['id']),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Delete Search History'),
                      content: Text(
                        'Are you sure you want to delete "${intent['title'] ?? intent['embeddingText'] ?? 'this search'}"? This action cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              onDismissed: (direction) async {
                final success = await _intentService.deleteIntent(intent['id']);

                if (!mounted) return;

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Search history deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadUserData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete search history'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  _loadUserData();
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isGlass
                        ? [
                            Colors.white.withValues(alpha: 0.7),
                            Colors.white.withValues(alpha: 0.5),
                          ]
                        : isDarkMode
                        ? [const Color(0xFF2D2D2D), const Color(0xFF252525)]
                        : [Colors.white, const Color(0xFFFAFAFA)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isGlass
                        ? Colors.white.withValues(alpha: 0.3)
                        : (isDarkMode ? Colors.grey[800]! : Colors.grey[200]!),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D67D).withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDarkMode ? 0.3 : 0.08,
                      ),
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
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            intent['title'] ??
                                intent['embeddingText'] ??
                                'Search',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 6),

                          // Time with icon
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: isDarkMode
                                    ? Colors.grey[500]
                                    : Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
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
          }, childCount: _searchHistory.length),
        ),
      ),
    ];
  }

  Widget _buildHistoryTab(bool isDarkMode, bool isGlass) {
    // This method is kept for compatibility but uses the sliver version
    return const SizedBox.shrink();
  }

  Widget _buildLiveConnectTab(bool isDarkMode, bool isGlass) {
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _showFilterDialog,
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Filters'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
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
                  profileImageUrl:
                      userData['profileImageUrl'] ?? userData['photoUrl'],
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
                            color: isDarkMode
                                ? Colors.grey[500]
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              userData['location'],
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.grey[500]
                                    : Colors.grey[600],
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.3),
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
                  final userProfile = UserProfile.fromMap(
                    userData,
                    person['userId'],
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfileViewScreen(userProfile: userProfile),
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

  void _openChat(Map<String, dynamic> userData, String userId) {
    // Create UserProfile from userData
    final userProfile = UserProfile.fromMap(userData, userId);

    // Navigate to chat screen
    // EnhancedChatScreen handles conversation creation internally
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedChatScreen(otherUser: userProfile),
      ),
    );
  }

  Color _getMatchColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.blue;
  }
}
