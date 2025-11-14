import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/glassmorphic_container.dart';
import 'profile_edit_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserProfile? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final doc = await _firestore.collection('users').doc(widget.userId).get();
      if (doc.exists) {
        setState(() {
          _userProfile = UserProfile(
            uid: doc.id,
            id: doc.id,
            name: doc.data()?['name'] ?? '',
            email: doc.data()?['email'] ?? '',
            phone: doc.data()?['phone'],
            location: doc.data()?['location'],
            profileImageUrl: doc.data()?['profileImageUrl'],
            bio: doc.data()?['bio'] ?? '',
            interests: List<String>.from(doc.data()?['interests'] ?? []),
            isVerified: doc.data()?['isVerified'] ?? false,
            createdAt: (doc.data()?['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            lastSeen: (doc.data()?['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = widget.userId == FirebaseAuth.instance.currentUser?.uid;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text(_userProfile?.name ?? 'Profile'),
        backgroundColor: themeProvider.isGlassmorphism 
            ? Colors.white.withValues(alpha: 0.9)
            : null,
        actions: [
          if (isCurrentUser) ...[
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userProfile == null
              ? const Center(child: Text('User not found'))
              : Stack(
                  children: [
                    // Gradient background for glassmorphism
                    if (themeProvider.isGlassmorphism)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              ThemeProvider.glassmorphismBackground[0].withValues(alpha: 0.5),
                              ThemeProvider.glassmorphismBackground[1].withValues(alpha: 0.3),
                              ThemeProvider.glassmorphismBackground[2].withValues(alpha: 0.2),
                            ],
                          ),
                        ),
                      ),
                    
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Profile header card
                          AnimatedGlassmorphicContainer(
                            padding: const EdgeInsets.all(24),
                            borderRadius: 24,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        ThemeProvider.iosPurple.withValues(alpha: 0.8),
                                        ThemeProvider.iosBlue.withValues(alpha: 0.8),
                                      ],
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 60,
                                    backgroundColor: isDark ? Colors.black : Colors.white,
                                    backgroundImage: _userProfile!.profileImageUrl != null
                                        ? CachedNetworkImageProvider(_userProfile!.profileImageUrl!)
                                        : null,
                                    child: _userProfile!.profileImageUrl == null
                                        ? Text(
                                            _userProfile!.name.isNotEmpty 
                                                ? _userProfile!.name[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              fontSize: 40,
                                              color: isDark ? Colors.white : Colors.black,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _userProfile!.name,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    if (_userProfile!.isVerified)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: Icon(
                                          Icons.verified,
                                          color: ThemeProvider.iosBlue,
                                          size: 24,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _userProfile!.email,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                                if (_userProfile!.location != null && _userProfile!.location!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.location_fill,
                                        size: 16,
                                        color: ThemeProvider.iosBlue,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _userProfile!.location!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDark ? Colors.white70 : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          
                          if (_userProfile!.bio.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            GlassmorphicCard(
                              padding: const EdgeInsets.all(20),
                              borderRadius: 20,
                              blur: 15,
                              opacity: isDark ? 0.1 : 0.05,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.quote_bubble_fill,
                                        size: 20,
                                        color: ThemeProvider.iosPurple,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'About',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _userProfile!.bio,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          if (_userProfile!.interests.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            GlassmorphicCard(
                              padding: const EdgeInsets.all(20),
                              borderRadius: 20,
                              blur: 15,
                              opacity: isDark ? 0.1 : 0.05,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.heart_fill,
                                        size: 20,
                                        color: ThemeProvider.iosPink,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Interests',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _userProfile!.interests.map((interest) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              ThemeProvider.iosBlue.withValues(alpha: 0.2),
                                              ThemeProvider.iosPurple.withValues(alpha: 0.2),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isDark 
                                                ? Colors.white.withValues(alpha: 0.1)
                                                : Colors.black.withValues(alpha: 0.1),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          interest,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}