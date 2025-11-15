import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/extended_user_profile.dart';
import '../widgets/profile_detail_bottom_sheet.dart';
import '../models/live_connect_filter.dart';

/// Demo screen to test Live Connect enhanced features
/// This is a standalone screen for testing before integration
class LiveConnectDemoScreen extends StatefulWidget {
  const LiveConnectDemoScreen({Key? key}) : super(key: key);

  @override
  State<LiveConnectDemoScreen> createState() => _LiveConnectDemoScreenState();
}

class _LiveConnectDemoScreenState extends State<LiveConnectDemoScreen> {
  final LiveConnectFilter _filter = LiveConnectFilter();
  List<ExtendedUserProfile> _mockUsers = [];

  @override
  void initState() {
    super.initState();
    _createMockUsers();
  }

  void _createMockUsers() {
    _mockUsers = [
      ExtendedUserProfile(
        uid: 'user1',
        name: 'Sarah Johnson',
        photoUrl: null,
        city: 'New York',
        location: 'Manhattan, New York',
        latitude: 40.7128,
        longitude: -74.0060,
        interests: ['Fitness', 'Hiking', 'Nutrition', 'Wellness', 'Running'],
        verified: true,
        connectionTypes: ['Activity Partner', 'Friendship'],
        activities: [
          Activity(name: 'Gym', level: 'advanced'),
          Activity(name: 'Hiking', level: 'intermediate'),
          Activity(name: 'Rock Climbing', level: 'intermediate'),
        ],
        aboutMe:
            'Fitness coach and outdoor enthusiast. Building healthy habits and helping others do the same. Let\'s hit the gym or go for a hike!',
        isOnline: true,
        distance: 2.3,
      ),
      ExtendedUserProfile(
        uid: 'user2',
        name: 'Mike Chen',
        photoUrl: null,
        city: 'San Francisco',
        location: 'Downtown SF',
        latitude: 37.7749,
        longitude: -122.4194,
        interests: ['Tech', 'Business', 'Travel', 'Music'],
        verified: true,
        connectionTypes: ['Professional Networking', 'Friendship'],
        activities: [
          Activity(name: 'Tennis', level: 'beginner'),
          Activity(name: 'Swimming', level: 'intermediate'),
        ],
        aboutMe:
            'Software engineer at a startup. Love building products that matter. Always up for coffee and tech talks!',
        isOnline: false,
        distance: 5.7,
      ),
      ExtendedUserProfile(
        uid: 'user3',
        name: 'Julia Rodriguez',
        photoUrl: null,
        city: 'Los Angeles',
        location: 'Venice Beach',
        latitude: 34.0522,
        longitude: -118.2437,
        interests: ['Cooking', 'Travel', 'Wine', 'Food Photography', 'Culture'],
        verified: false,
        connectionTypes: ['Activity Partner', 'Event Companion', 'Dating'],
        activities: [
          Activity(name: 'Cooking Classes', level: 'advanced'),
          Activity(name: 'Wine Tasting', level: 'intermediate'),
          Activity(name: 'Food Tours', level: 'advanced'),
        ],
        aboutMe:
            'Professional chef exploring culinary arts. Food is my love language! Looking for foodies, event companions, and meaningful connections.',
        isOnline: true,
        distance: 1.2,
      ),
      ExtendedUserProfile(
        uid: 'user4',
        name: 'Alex Thompson',
        photoUrl: null,
        city: 'New York',
        location: 'Brooklyn, NY',
        latitude: 40.6782,
        longitude: -73.9442,
        interests: ['Design', 'Art', 'Photography', 'Music', 'Travel'],
        verified: true,
        connectionTypes: ['Professional Networking', 'Friendship', 'Event Companion'],
        activities: [
          Activity(name: 'Photography', level: 'advanced'),
          Activity(name: 'Art Galleries', level: 'intermediate'),
        ],
        aboutMe:
            'Creative director and photographer. Capturing moments and creating visual stories. Let\'s collaborate or explore the city!',
        isOnline: true,
        distance: 3.8,
      ),
    ];
  }

  void _showProfileDetail(ExtendedUserProfile user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileDetailBottomSheet(
        user: user,
        onConnect: () {
          Navigator.pop(context);
          _showMessage('Sent connection request to ${user.name}');
        },
        onMessage: () {
          Navigator.pop(context);
          _showMessage('Opening chat with ${user.name}');
        },
        onPin: () {
          Navigator.pop(context);
          _showMessage('Saved ${user.name} to your favorites');
        },
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  void _showAdvancedFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E1E)
                  : const Color(0xFF2A2A2A),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Advanced Filters',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (_filter.hasActiveFilters)
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _filter.reset();
                            });
                          },
                          child: const Text('Reset'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Discovery Mode Toggle
                  _buildDiscoveryModeCard(setModalState),
                  const SizedBox(height: 16),

                  const Divider(color: Colors.grey),
                  const SizedBox(height: 16),

                  // Distance Filter
                  _buildDistanceFilter(setModalState),
                  const SizedBox(height: 24),

                  // Location Type
                  _buildLocationTypeFilter(setModalState),
                  const SizedBox(height: 24),

                  // Connection Types
                  _buildConnectionTypeFilter(setModalState),
                  const SizedBox(height: 32),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {}); // Refresh the main screen
                        _showMessage('Filters applied!');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D67D),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Discover Connections',
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiscoveryModeCard(StateSetter setModalState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.8),
            Theme.of(context).primaryColor.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility, color: Colors.white),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discovery Mode',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'You\'re visible and discoverable',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _filter.discoveryModeEnabled,
            onChanged: (value) {
              setModalState(() {
                _filter.discoveryModeEnabled = value;
              });
            },
            activeColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceFilter(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Distance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_filter.maxDistance.round()} km',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Theme.of(context).primaryColor,
            inactiveTrackColor: Colors.grey[600],
            thumbColor: Theme.of(context).primaryColor,
            overlayColor: Theme.of(context).primaryColor.withOpacity(0.2),
          ),
          child: Slider(
            value: _filter.maxDistance,
            min: 1,
            max: 100,
            divisions: 99,
            onChanged: (value) {
              setModalState(() {
                _filter.maxDistance = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLocationTypeFilter(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.map, color: Colors.white70, size: 20),
            SizedBox(width: 8),
            Text(
              'Location Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: LiveConnectFilter.locationTypes.entries.map((entry) {
            final isSelected = _filter.locationType == entry.key;
            return GestureDetector(
              onTap: () {
                setModalState(() {
                  _filter.locationType = entry.key;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF00D67D)
                      : Colors.grey[800],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey[400],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildConnectionTypeFilter(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.people_outline, color: Colors.white70, size: 20),
            SizedBox(width: 8),
            Text(
              'Connection Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Select what you\'re looking for:',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: LiveConnectFilter.availableConnectionTypes.map((type) {
            final isSelected = _filter.connectionTypes.contains(type);
            return GestureDetector(
              onTap: () {
                setModalState(() {
                  if (isSelected) {
                    _filter.connectionTypes.remove(type);
                  } else {
                    _filter.connectionTypes.add(type);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _getConnectionTypeColor(type)
                      : Colors.grey[800],
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? null
                      : Border.all(color: Colors.grey[600]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _getConnectionTypeIcon(type),
                    const SizedBox(width: 6),
                    Text(
                      type,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
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

  Widget _getConnectionTypeIcon(String type) {
    IconData icon;
    switch (type) {
      case 'Professional Networking':
        icon = Icons.business_center;
        break;
      case 'Activity Partner':
        icon = Icons.sports_soccer;
        break;
      case 'Event Companion':
        icon = Icons.event;
        break;
      case 'Friendship':
        icon = Icons.people;
        break;
      case 'Dating':
        icon = Icons.favorite;
        break;
      default:
        icon = Icons.person;
    }
    return Icon(icon, size: 16, color: Colors.white);
  }

  Widget _buildUserCard(ExtendedUserProfile user) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showProfileDetail(user),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFF3A3A3A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Profile Image with online indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: user.photoUrl == null
                      ? Theme.of(context).primaryColor
                      : null,
                  backgroundImage: user.photoUrl != null
                      ? CachedNetworkImageProvider(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                if (user.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D67D),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.verified) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.verified,
                          size: 18,
                          color: Theme.of(context).primaryColor,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Distance
                  if (user.formattedDistance != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.formattedDistance!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),

                  // Interests (limit to 2)
                  if (user.interests.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: user.interests.take(2).map((interest) {
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
              ),
            ),

            // Arrow icon
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : const Color(0xFF121212),
        title: const Text(
          'Live Connect (Demo)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        actions: [
          // Filter badge with count
          Stack(
            children: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _filter.hasActiveFilters
                      ? Theme.of(context).primaryColor
                      : Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.tune),
                  color: Colors.white,
                  onPressed: _showAdvancedFilters,
                ),
              ),
              if (_filter.activeFilterCount > 0)
                Positioned(
                  right: 12,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_filter.activeFilterCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Tap on any user card to view their full profile',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Users list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: _mockUsers.length,
              itemBuilder: (context, index) {
                return _buildUserCard(_mockUsers[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
