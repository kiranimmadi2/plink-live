import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../services/profile_service.dart';

class EditProfileBottomSheet extends StatefulWidget {
  final Map<String, dynamic> currentProfile;
  final Function()? onProfileUpdated;

  const EditProfileBottomSheet({
    super.key,
    required this.currentProfile,
    this.onProfileUpdated,
  });

  @override
  State<EditProfileBottomSheet> createState() => _EditProfileBottomSheetState();
}

class _EditProfileBottomSheetState extends State<EditProfileBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final ProfileService _profileService = ProfileService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  Uint8List? _imageBytes;

  // Profile data
  List<String> _selectedInterests = [];
  List<String> _selectedConnectionTypes = [];
  List<String> _selectedActivities = [];

  // Available options
  final List<String> _availableInterests = [
    'Fitness',
    'Hiking',
    'Nutrition',
    'Wellness',
    'Running',
    'Tech',
    'Business',
    'Travel',
    'Music',
    'Movies',
    'Cooking',
    'Wine',
    'Food Photography',
    'Culture',
    'Design',
    'Art',
    'Photography',
    'Gaming',
    'Sports',
    'Reading',
    'Writing',
    'Dancing',
    'Yoga',
    'Meditation',
  ];

  final List<String> _connectionTypeOptions = [
    'Dating',
    'Friendship',
    'Casual Hangout',
    'Travel Buddy',
    'Nightlife Partner',
    'Networking',
    'Mentorship',
    'Business Partner',
    'Career Advice',
    'Collaboration',
    'Workout Partner',
    'Sports Partner',
    'Hobby Partner',
    'Event Companion',
    'Study Group',
    'Language Exchange',
    'Skill Sharing',
    'Book Club',
    'Learning Partner',
    'Creative Workshop',
    'Music Jam',
    'Art Collaboration',
    'Photography',
    'Content Creation',
    'Performance',
    'Roommate',
    'Pet Playdate',
    'Community Service',
    'Gaming',
    'Online Friends',
  ];

  final List<String> _activityOptions = [
    'Tennis',
    'Badminton',
    'Basketball',
    'Football',
    'Volleyball',
    'Golf',
    'Table Tennis',
    'Squash',
    'Running',
    'Gym',
    'Yoga',
    'Pilates',
    'CrossFit',
    'Cycling',
    'Swimming',
    'Dance',
    'Hiking',
    'Rock Climbing',
    'Camping',
    'Kayaking',
    'Surfing',
    'Mountain Biking',
    'Trail Running',
    'Photography',
    'Painting',
    'Music',
    'Writing',
    'Cooking',
    'Crafts',
    'Gaming',
  ];

  String? _getPhotoUrl() {
    try {
      final photoUrl = widget.currentProfile['photoUrl'];
      if (photoUrl is String && photoUrl.isNotEmpty) {
        return photoUrl;
      }
      // Try profileImageUrl as fallback
      final profileImageUrl = widget.currentProfile['profileImageUrl'];
      if (profileImageUrl is String && profileImageUrl.isNotEmpty) {
        return profileImageUrl;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting photo URL: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();

    try {
      // Safely load text fields
      final name = widget.currentProfile['name'];
      if (name != null && name is String) {
        _nameController.text = name;
      } else if (name != null) {
        _nameController.text = name.toString();
      }

      final bio = widget.currentProfile['bio'];
      if (bio != null && bio is String) {
        _bioController.text = bio;
      } else if (bio != null) {
        _bioController.text = bio.toString();
      }

      final location = widget.currentProfile['location'];
      if (location != null && location is String) {
        _locationController.text = location;
      } else if (location != null) {
        _locationController.text = location.toString();
      }

      // Load existing interests, connection types, and activities with safe type conversion
      final interests = widget.currentProfile['interests'];
      if (interests is List) {
        _selectedInterests = interests.map((e) => e.toString()).toList();
      }

      final connectionTypes = widget.currentProfile['connectionTypes'];
      if (connectionTypes is List) {
        _selectedConnectionTypes = connectionTypes
            .map((e) => e.toString())
            .toList();
      }

      final activities = widget.currentProfile['activities'];
      if (activities is List) {
        _selectedActivities = activities.map((e) {
          // Handle different formats: String, Map (old format), or Activity object
          if (e is String) {
            return e;
          } else if (e is Map) {
            return e['name']?.toString() ?? 'Unknown';
          } else {
            return e.toString();
          }
        }).toList();
      }
    } catch (e) {
      debugPrint('Error loading profile data in EditProfileBottomSheet: $e');
      debugPrint('Profile data: ${widget.currentProfile}');
      // Initialize with empty values on error
      _nameController.text = '';
      _bioController.text = '';
      _locationController.text = '';
      _selectedInterests = [];
      _selectedConnectionTypes = [];
      _selectedActivities = [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Not authenticated');

      // Upload photo if changed
      String? photoUrl = _getPhotoUrl();
      if (_imageBytes != null) {
        photoUrl = await _profileService.updateProfilePhoto(
          userId: userId,
          imageBytes: _imageBytes,
        );
      }

      // Update profile
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'location': _locationController.text.trim(),
        if (photoUrl != null) 'photoUrl': photoUrl,
        'interests': _selectedInterests,
        'connectionTypes': _selectedConnectionTypes,
        'activities': _selectedActivities,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        widget.onProfileUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Profile',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Profile Photo
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _imageBytes != null
                          ? MemoryImage(_imageBytes!)
                          : _getPhotoUrl() != null
                          ? NetworkImage(_getPhotoUrl()!)
                          : null,
                      child: _getPhotoUrl() == null && _imageBytes == null
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: IconButton(
                          icon: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed: _pickImage,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Bio
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                  hintText: 'Tell us about yourself...',
                ),
                maxLines: 3,
                maxLength: 150,
              ),
              const SizedBox(height: 16),

              // Location
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                  hintText: 'City, Country',
                ),
              ),
              const SizedBox(height: 24),

              // Interests & Hobbies Section
              const Text(
                'Interests & Hobbies',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableInterests.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(interest),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedInterests.add(interest);
                        } else {
                          _selectedInterests.remove(interest);
                        }
                      });
                    },
                    backgroundColor: Colors.grey[800],
                    selectedColor: const Color(0xFF00D67D),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[300],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Connection Types Section
              const Text(
                'Connection Types',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _connectionTypeOptions.map((type) {
                  final isSelected = _selectedConnectionTypes.contains(type);
                  return FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(type),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
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
                    backgroundColor: Colors.grey[800],
                    selectedColor: const Color(0xFF00D67D),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[300],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Activities Section
              const Text(
                'Activities',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _activityOptions.map((activity) {
                  final isSelected = _selectedActivities.contains(activity);
                  return FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(activity),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedActivities.add(activity);
                        } else {
                          _selectedActivities.remove(activity);
                        }
                      });
                    },
                    backgroundColor: Colors.grey[800],
                    selectedColor: const Color(0xFF00D67D),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[300],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
