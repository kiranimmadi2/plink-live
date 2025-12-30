import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/location services/location_service.dart';
import '../../widgets/other widgets/user_avatar.dart';
import '../../providers/other providers/theme_provider.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_assets.dart';
import '../login/choose_account_type_screen.dart';
import '../profile/profile_view_screen.dart';
import '../profile/settings_screen.dart';
import '../profile/profile_edit_screen.dart';
import '../chat/enhanced_chat_screen.dart';
import '../../models/user_profile.dart';

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
  final LocationService _locationService = LocationService();
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

  // Active status
  bool _showOnlineStatus = true;
  bool _isStatusLoading = false;

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
          // Load active status preference
          _showOnlineStatus = userData?['showOnlineStatus'] ?? true;

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
        // debugPrint('User profile loaded: city=${userData?['city']}, location=${userData?['location']}, interests=$_selectedInterests');

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
        debugPrint('Error loading search history: $e');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
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
      // userLocation available for future geo-filtering

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
      debugPrint('Error loading nearby people: $e');
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
      debugPrint('Error updating interests: $e');
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

  Future<void> _updateOnlineStatusPreference(bool value) async {
    setState(() {
      _isStatusLoading = true;
    });

    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      try {
        await _firestore.collection('users').doc(userId).update({
          'showOnlineStatus': value,
          'isOnline': value ? true : false,
        });
        if (mounted) {
          setState(() {
            _showOnlineStatus = value;
            _isStatusLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: value
                            ? [
                                Colors.white.withValues(alpha: 0.25),
                                Colors.greenAccent.withValues(alpha: 0.15),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.25),
                                Colors.orangeAccent.withValues(alpha: 0.15),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          value ? Icons.visibility : Icons.visibility_off,
                          color: value ? Colors.greenAccent : Colors.orangeAccent,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            value
                                ? 'Your active status is now visible to others'
                                : 'Your active status is now hidden',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              behavior: SnackBarBehavior.floating,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isStatusLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update status: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
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

  // ignore: unused_element
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
          MaterialPageRoute(builder: (_) => const ChooseAccountTypeScreen()),
          (route) => false,
        );
      }
    }
  }

  // ignore: unused_element
  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  // ignore: unused_element
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
      debugPrint('Error updating profile: $e');
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
              backgroundColor: Colors.black.withValues(alpha: 0.3),
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () {
                  // Navigate back to home screen (Home tab)
                  // Pop until we reach the MainNavigationScreen (first route)
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
              ),
              centerTitle: true,
              title: const Text(
                'Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: const [
                SizedBox(width: 48), // Balance the back button
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Image (same as Feed screen)
          Positioned.fill(
            child: Image.asset(
              AppAssets.homeBackgroundImage,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.grey.shade900, Colors.black],
                    ),
                  ),
                );
              },
            ),
          ),

          // Dark overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),

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
                          const SizedBox(height: kToolbarHeight + 60),
                          // Profile Header - Card with glassmorphism
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    children: [
                                      // Profile Photo - Centered
                                      UserAvatar(
                                        profileImageUrl:
                                            _userProfile?['profileImageUrl'] ??
                                            _userProfile?['photoUrl'],
                                        radius: 60,
                                        fallbackText:
                                            _userProfile?['name'] ?? 'User',
                                      ),
                                      const SizedBox(height: 20),

                                      // Name - Centered
                                      Text(
                                        _userProfile?['name'] ?? 'Unknown User',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),

                                      const SizedBox(height: 8),

                                      // Email - Centered
                                      Text(
                                        _userProfile?['email'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withValues(alpha: 0.7),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),

                                      const SizedBox(height: 12),

                                      // Location - Centered
                                      GestureDetector(
                                        onTap: () async {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Updating location...'),
                                            ),
                                          );
                                          try {
                                            final success = await _locationService
                                                .updateUserLocation(silent: false);
                                            if (!mounted) return;
                                            if (success) {
                                              await Future.delayed(
                                                const Duration(milliseconds: 500),
                                              );
                                              if (!mounted) return;
                                              _loadUserData();
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Location updated successfully'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            } else {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Could not update location'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            debugPrint('Error during manual location update: $e');
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Location update failed'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.location_on_rounded,
                                              color: Colors.white.withValues(alpha: 0.7),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                _userProfile?['displayLocation'] ??
                                                    _userProfile?['city'] ??
                                                    _userProfile?['location'] ??
                                                    'Tap to set location',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white.withValues(alpha: 0.7),
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Edit Profile Card
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  title: const Text(
                                    'Edit Profile',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    size: 16,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ProfileEditScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          // Account Type Card
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Builder(
                                  builder: (context) {
                                    final accountType = _userProfile?['accountType']?.toString().toLowerCase() ?? 'personal';
                                    final isBusiness = accountType == 'business';
                                    debugPrint('Account Type from Firestore: ${_userProfile?['accountType']} -> isBusiness: $isBusiness');
                                    return ListTile(
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          isBusiness ? Icons.business : Icons.person,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                      title: const Text(
                                        'Account Type',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          isBusiness ? 'Business' : 'Personal',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          // Settings Card
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.settings,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  title: const Text(
                                    'Settings',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    size: 16,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SettingsScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          // Active Status Card
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _showOnlineStatus
                                          ? AppColors.iosGreen.withValues(alpha: 0.2)
                                          : Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _showOnlineStatus
                                          ? CupertinoIcons.circle_fill
                                          : CupertinoIcons.circle,
                                      color: _showOnlineStatus
                                          ? AppColors.iosGreen
                                          : Colors.white.withValues(alpha: 0.7),
                                      size: 22,
                                    ),
                                  ),
                                  title: const Text(
                                    'Active Status',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: Transform.scale(
                                    scale: 0.9,
                                    child: CupertinoSwitch(
                                      value: _showOnlineStatus,
                                      onChanged: _isStatusLoading
                                          ? null
                                          : _updateOnlineStatusPreference,
                                      activeTrackColor: AppColors.iosGreen,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  // ignore: unused_element
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

  // ignore: unused_element
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
                                  // ignore: use_build_context_synchronously
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Deleted $activity'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  // ignore: use_build_context_synchronously
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

  // ignore: unused_element
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

  // ignore: unused_element
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
    // Migration no longer needed - show info message
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Migration Complete'),
        content: const Text(
          'Activity migration has already been completed.\n\n'
          'Your activities are up to date.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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

  // ignore: unused_element
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
        // matchScore available but not currently displayed

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

  // ignore: unused_element
  Color _getMatchColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.blue;
  }
}
