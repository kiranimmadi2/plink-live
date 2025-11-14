import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/theme_provider.dart';
import '../widgets/glassmorphic_container.dart';
import '../services/auth_service.dart';
import 'profile_edit_screen.dart';
import 'performance_debug_screen.dart';
import 'login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _showOnlineStatus = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadOnlineStatusPreference();
  }

  Future<void> _loadOnlineStatusPreference() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _showOnlineStatus = doc.data()?['showOnlineStatus'] ?? true;
        });
      }
    }
  }

  Future<void> _updateOnlineStatusPreference(bool value) async {
    setState(() {
      _isLoading = true;
    });
    
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'showOnlineStatus': value,
          'isOnline': value ? true : false,
        });
        if (mounted) {
          setState(() {
            _showOnlineStatus = value;
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(value 
                ? 'Your active status is now visible to others' 
                : 'Your active status is now hidden'),
              backgroundColor: value ? Colors.green : Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final isGlass = themeProvider.isGlassmorphism;
    final authService = AuthService();
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              title: const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: isGlass 
                  ? Colors.white.withValues(alpha: 0.7)
                  : (isDark ? Colors.black.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9)),
              elevation: 0,
              centerTitle: false,
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
                    : isDark 
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
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ThemeProvider.iosPurple.withValues(alpha: 0.3),
                      ThemeProvider.iosPurple.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ThemeProvider.iosBlue.withValues(alpha: 0.2),
                      ThemeProvider.iosBlue.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
          
          ListView(
            padding: const EdgeInsets.only(
              top: kToolbarHeight + 60,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            children: [
              // Online Status Section - Top Priority Feature
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ThemeProvider.iosGreen.withValues(alpha: 0.8),
                      ThemeProvider.iosBlue.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? Colors.green : ThemeProvider.iosGreen).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isGlass 
                          ? Colors.white.withValues(alpha: 0.2)
                          : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.9)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  _showOnlineStatus 
                                    ? CupertinoIcons.circle_fill 
                                    : CupertinoIcons.circle,
                                  color: _showOnlineStatus ? Colors.green : Colors.grey,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Active Status',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark || isGlass ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _showOnlineStatus 
                                        ? 'Others can see when you\'re active'
                                        : 'Your activity status is hidden',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark || isGlass 
                                          ? Colors.white.withValues(alpha: 0.8)
                                          : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Transform.scale(
                                scale: 1.1,
                                child: CupertinoSwitch(
                                  value: _showOnlineStatus,
                                  onChanged: _isLoading ? null : _updateOnlineStatusPreference,
                                  activeColor: ThemeProvider.iosGreen,
                                ),
                              ),
                            ],
                          ),
                          if (_showOnlineStatus) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.info_circle_fill,
                                    color: isDark || isGlass ? Colors.white70 : Colors.black54,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'When active status is on, your contacts will see when you\'re online and when you were last active',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark || isGlass 
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : Colors.black54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Theme Section
              _buildSectionHeader(
                icon: CupertinoIcons.paintbrush_fill,
                title: 'Appearance',
                color: ThemeProvider.iosPurple,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildSettingsCard(
                isDark: isDark,
                isGlass: isGlass,
                children: [
                  _buildThemeOption(
                    context,
                    title: 'iOS 16 Glassmorphism',
                    subtitle: 'Premium glass effect with blur',
                    icon: CupertinoIcons.sparkles,
                    isSelected: isGlass,
                    onTap: () {
                      themeProvider.setTheme(AppThemeMode.glassmorphism);
                    },
                  ),
                  const Divider(height: 1),
                  _buildThemeOption(
                    context,
                    title: 'Dark Mode',
                    subtitle: 'Easier on the eyes in low light',
                    icon: CupertinoIcons.moon_fill,
                    isSelected: isDark,
                    onTap: () {
                      themeProvider.setTheme(AppThemeMode.dark);
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Account Section
              _buildSectionHeader(
                icon: CupertinoIcons.person_circle_fill,
                title: 'Account',
                color: ThemeProvider.iosBlue,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildSettingsCard(
                isDark: isDark,
                isGlass: isGlass,
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Edit Profile'),
                    subtitle: const Text('Update your information'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileEditScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.security_outlined),
                    title: const Text('Privacy'),
                    subtitle: const Text('Manage your privacy settings'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      // TODO: Navigate to privacy settings
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Security'),
                    subtitle: const Text('Password and authentication'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      // TODO: Navigate to security settings
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Notifications Section
              _buildSectionHeader(
                icon: CupertinoIcons.bell_fill,
                title: 'Notifications',
                color: ThemeProvider.iosOrange,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildSettingsCard(
                isDark: isDark,
                isGlass: isGlass,
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.message_outlined),
                    title: const Text('Message Notifications'),
                    subtitle: const Text('New messages from matches'),
                    value: true,
                    onChanged: (value) {
                      // TODO: Handle notification toggle
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.favorite_outline),
                    title: const Text('Match Notifications'),
                    subtitle: const Text('Someone matched with you'),
                    value: true,
                    onChanged: (value) {
                      // TODO: Handle notification toggle
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.campaign_outlined),
                    title: const Text('Promotional'),
                    subtitle: const Text('Updates and offers'),
                    value: false,
                    onChanged: (value) {
                      // TODO: Handle notification toggle
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // App Settings Section
              _buildSectionHeader(
                icon: CupertinoIcons.gear_solid,
                title: 'App Settings',
                color: ThemeProvider.iosGreen,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildSettingsCard(
                isDark: isDark,
                isGlass: isGlass,
                children: [
                  ListTile(
                    leading: const Icon(Icons.language_outlined),
                    title: const Text('Language'),
                    subtitle: const Text('English'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      // TODO: Language selection
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('Location'),
                    subtitle: const Text('Manage location settings'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      // TODO: Location settings
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: const Text('Storage & Data'),
                    subtitle: const Text('Network usage and storage'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      // TODO: Storage settings
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.speed_outlined),
                    title: const Text('Performance Debug'),
                    subtitle: const Text('Monitor app performance'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PerformanceDebugScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Support Section
              _buildSectionHeader(
                icon: CupertinoIcons.question_circle_fill,
                title: 'Support',
                color: ThemeProvider.iosTeal,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildSettingsCard(
                isDark: isDark,
                isGlass: isGlass,
                children: [
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Help Center'),
                    subtitle: const Text('Get help and support'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      // TODO: Help center
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About'),
                    subtitle: const Text('Version 1.0.0'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      // TODO: About page
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms & Privacy'),
                    subtitle: const Text('Terms of service and privacy policy'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      // TODO: Terms page
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Logout Button
              _buildSettingsCard(
                isDark: isDark,
                isGlass: isGlass,
                children: [
                  _buildLogoutButton(context, authService),
                ],
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSettingsCard({
    required bool isDark,
    required bool isGlass,
    required List<Widget> children,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: isGlass ? 20 : 0,
          sigmaY: isGlass ? 20 : 0,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isGlass
                  ? [
                      Colors.white.withValues(alpha: 0.6),
                      Colors.white.withValues(alpha: 0.3),
                    ]
                  : isDark
                      ? [
                          const Color(0xFF2C2C2E),
                          const Color(0xFF1C1C1E),
                        ]
                      : [
                          Colors.white,
                          Colors.grey[50]!,
                        ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isGlass
                  ? Colors.white.withValues(alpha: 0.3)
                  : isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }
  
  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected 
              ? ThemeProvider.iosPurple.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected ? ThemeProvider.iosPurple : Colors.grey,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: Radio<bool>(
        value: true,
        groupValue: isSelected,
        onChanged: (_) => onTap(),
        activeColor: ThemeProvider.iosPurple,
      ),
      onTap: onTap,
    );
  }
  
  Widget _buildLogoutButton(BuildContext context, AuthService authService) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.logout,
          color: Colors.red,
          size: 20,
        ),
      ),
      title: const Text(
        'Logout',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.red,
        ),
      ),
      subtitle: Text(
        FirebaseAuth.instance.currentUser?.email ?? '',
        style: const TextStyle(fontSize: 14),
      ),
      trailing: const Icon(
        CupertinoIcons.chevron_forward,
        color: Colors.red,
      ),
      onTap: () async {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await authService.signOut();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Logout'),
              ),
            ],
          ),
        );
      },
    );
  }
}