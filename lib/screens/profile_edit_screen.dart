import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/firebase_storage_service.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/user_manager.dart';
import '../services/location_service.dart';
import '../widgets/user_avatar.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({Key? key}) : super(key: key);

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final AuthService _authService = AuthService();
  final UserManager _userManager = UserManager();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final ImagePicker _imagePicker = ImagePicker();
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  
  User? user;
  String? _currentPhotoUrl;
  File? _selectedImage;
  bool _isLoading = false;
  bool _isUpdating = false;
  bool _isUpdatingLocation = false;

  @override
  void initState() {
    super.initState();
    user = _authService.currentUser;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (user == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Get profile from UserManager
      final profileData = _userManager.cachedProfile ?? 
                          await _userManager.loadUserProfile(user!.uid);
      
      if (profileData != null) {
        _nameController.text = profileData['name'] ?? '';
        // _phoneController.text = profileData['phone'] ?? ''; // Phone field hidden
        // Use city field if available, fallback to location field
        _locationController.text = profileData['city'] ?? profileData['location'] ?? '';
        _currentPhotoUrl = profileData['photoUrl'];
      } else {
        // Fallback to Auth data
        _nameController.text = user!.displayName ?? '';
        _currentPhotoUrl = user!.photoURL;
      }
      
      print('Loaded profile - Name: ${_nameController.text}, Photo URL: $_currentPhotoUrl');
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createInitialProfile() async {
    if (user == null) return;
    
    try {
      await _firestore.collection('users').doc(user!.uid).set({
        'uid': user!.uid,
        'name': user!.displayName ?? user!.email?.split('@')[0] ?? 'User',
        'email': user!.email ?? '',
        'photoUrl': user!.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      });
    } catch (e) {
      print('Error creating initial profile: $e');
    }
  }



  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate() || user == null) return;
    
    setState(() => _isUpdating = true);
    
    try {
      // Handle photo upload if new image selected
      String? photoUrl = _currentPhotoUrl ?? user!.photoURL;
      
      if (_selectedImage != null) {
        print('Uploading new profile image...');
        final uploadedUrl = await _storageService.uploadProfileImage(_selectedImage!, user!.uid);
        if (uploadedUrl != null) {
          photoUrl = uploadedUrl;
          print('New profile image uploaded: $uploadedUrl');
        } else {
          print('Failed to upload profile image');
        }
      }
      
      // Update Firebase Auth profile (name and photo)
      await user!.updateProfile(
        displayName: _nameController.text.trim(),
        photoURL: photoUrl,
      );
      
      // Reload user to get updated data
      await user!.reload();
      user = _authService.currentUser;
      
      // Update Firestore directly
      await _firestore.collection('users').doc(user!.uid).set({
        'uid': user!.uid,
        'name': _nameController.text.trim(),
        'email': user!.email ?? '',
        'photoUrl': photoUrl,
        // 'phone': _phoneController.text.trim(), // Phone field hidden
        'location': _locationController.text.trim(),
        'city': _locationController.text.trim(), // Save to both fields for compatibility
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      }, SetOptions(merge: true));
      
      // Also update via UserManager for cache
      await _userManager.updateProfile({
        'name': _nameController.text.trim(),
        'photoUrl': photoUrl,
        // 'phone': _phoneController.text.trim(), // Phone field hidden
        'location': _locationController.text.trim(),
        'city': _locationController.text.trim(),
      });
      
      print('Profile updated successfully');
      
      // Update local state with new photo URL and clear selected image
      if (photoUrl != null) {
        setState(() {
          _currentPhotoUrl = photoUrl;
          _selectedImage = null; // Clear selected image after successful upload
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload profile to ensure everything is synced
        await _loadUserProfile();
        
        Navigator.pop(context, true); // Return true to indicate profile was updated
      }
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }


  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,  // High quality to prevent blur
        maxWidth: 1920,    // Max resolution for optimization
        maxHeight: 1920,
      );
      
      if (image != null && mounted) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pick image'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,  // High quality to prevent blur
        maxWidth: 1920,    // Max resolution for optimization
        maxHeight: 1920,
      );
      
      if (photo != null && mounted) {
        setState(() {
          _selectedImage = File(photo.path);
        });
      }
    } catch (e) {
      print('Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to take photo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _takePhoto();
                },
              ),
              if (_selectedImage != null || _currentPhotoUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Photo'),
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _selectedImage = null;
                      _currentPhotoUrl = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateLocation() async {
    setState(() {
      _isUpdatingLocation = true;
    });

    try {
      print('ProfileEditScreen: Getting GPS location (user-initiated)...');
      // User manually clicked location button, so NOT silent mode
      final position = await _locationService.getCurrentLocation(silent: false);

      if (position != null) {
        print('ProfileEditScreen: Got GPS position: ${position.latitude}, ${position.longitude}');
        final addressData = await _locationService.getCityFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (addressData != null &&
            addressData['city'] != null &&
            addressData['city'].toString().isNotEmpty &&
            mounted) {
          // Only show real location with valid city name
          final locationString = addressData['display'] ?? addressData['city'];
          print('ProfileEditScreen: Got real location: $locationString');
          setState(() {
            _locationController.text = locationString;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location detected: $locationString'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          print('ProfileEditScreen: Geocoding failed or returned invalid data');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not get address from GPS coordinates. Please check internet connection.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        print('ProfileEditScreen: Could not get GPS position');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied or GPS is disabled. Please enable in settings.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('ProfileEditScreen: Error updating location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error detecting location: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingLocation = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (!_isUpdating)
            TextButton(
              onPressed: _updateProfile,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Profile Image Section (Clickable)
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _showImagePickerOptions,
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey.shade300,
                              child: _selectedImage != null
                                  ? ClipOval(
                                      child: Image.file(
                                        _selectedImage!,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : _buildProfileImage(),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _showImagePickerOptions,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Email Field (Read-only)
                    TextFormField(
                      initialValue: user?.email ?? '',
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      enabled: false,
                    ),
                    const SizedBox(height: 16),
                    
                    // Location Field
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        prefixIcon: const Icon(Icons.location_on),
                        border: const OutlineInputBorder(),
                        suffixIcon: _isUpdatingLocation
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.my_location),
                                onPressed: _updateLocation,
                                tooltip: 'Detect my location',
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Update Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isUpdating ? null : _updateProfile,
                        child: _isUpdating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Update Profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileImage() {
    if (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty) {
      // Show current profile image from URL (Google Sign-In)
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: _currentPhotoUrl!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          placeholder: (context, url) => const CircularProgressIndicator(),
          errorWidget: (context, url, error) {
            print('Error loading profile image in edit screen: $error');
            return Icon(
              Icons.person,
              size: 60,
              color: Colors.grey.shade600,
            );
          },
        ),
      );
    } else {
      // Show default person icon
      return Icon(
        Icons.person,
        size: 60,
        color: Colors.grey.shade600,
      );
    }
  }
}