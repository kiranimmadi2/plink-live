import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Replace these with your actual screens
import 'home_screen.dart';
import 'conversations_screen.dart';
import 'live_connect_tab_screen.dart';
import 'profile_with_history_screen.dart';
import 'feed_screen.dart';
import '../chat/incoming_call_screen.dart';

// Professional & Business screens
import '../professional/professional_dashboard_screen.dart';
import '../business/business_main_screen.dart';

// services
import '../../services/location services/location_service.dart';
import '../../services/notification_service.dart';
import '../../services/account_type_service.dart';
import '../../models/user_profile.dart';

class MainNavigationScreen extends StatefulWidget {
  final int? initialIndex;
  final String? loginAccountType; // Account type from login screen

  const MainNavigationScreen({super.key, this.initialIndex, this.loginAccountType});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _unreadMessageCount = 0;

  // Account type for showing appropriate dashboard
  AccountType _accountType = AccountType.personal;
  StreamSubscription<AccountType>? _accountTypeSubscription;

  // Stream subscription for cleanup
  StreamSubscription<QuerySnapshot>? _unreadSubscription;
  StreamSubscription<QuerySnapshot>? _incomingCallSubscription;
  bool _isShowingIncomingCall = false;
  final Set<String> _handledCallIds = {};

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _location = LocationService();
  final AccountTypeService _accountTypeService = AccountTypeService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Set initial index based on login account type or initialIndex
    if (widget.initialIndex != null) {
      _currentIndex = widget.initialIndex!;
    } else if (widget.loginAccountType != null) {
      // Set initial screen based on account type from login
      if (widget.loginAccountType == 'Business Account') {
        _currentIndex = 6; // Business dashboard
      } else {
        _currentIndex = 0; // Home screen for Personal
      }
    }

    _listenUnread();
    _listenForIncomingCalls();
    _checkAndMarkMissedCalls(); // Check for old unanswered calls
    _updateStatus(true);
    _checkLocation();
    _loadAccountType();
  }

  // Check for old calls that were never answered and mark them as missed
  Future<void> _checkAndMarkMissedCalls() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Get calls where this user is the receiver and status is still calling/ringing
      final oldCalls = await _firestore
          .collection('calls')
          .where('receiverId', isEqualTo: user.uid)
          .where('status', whereIn: ['calling', 'ringing'])
          .get();

      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(seconds: 60));

      for (var doc in oldCalls.docs) {
        final data = doc.data();
        // Use timestamp or createdAt field
        final timestamp = data['timestamp'] ?? data['createdAt'];
        DateTime? callTime;

        if (timestamp is Timestamp) {
          callTime = timestamp.toDate();
        } else if (timestamp is String) {
          callTime = DateTime.tryParse(timestamp);
        }

        // If call is older than 60 seconds, mark as missed
        if (callTime != null && callTime.isBefore(cutoffTime)) {
          await _firestore.collection('calls').doc(doc.id).update({
            'status': 'missed',
            'missedAt': FieldValue.serverTimestamp(),
          });

          // Show missed call notification
          final callerName = data['callerName'] as String? ?? 'Unknown';
          _showMissedCallNotification(callerName);
        }
      }
    } catch (e) {
      debugPrint('Error checking missed calls: $e');
    }
  }

  void _showMissedCallNotification(String callerName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.phone_missed, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('Missed call from $callerName')),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _loadAccountType() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final accountType = await _accountTypeService.getCurrentAccountType();
    if (mounted) {
      setState(() {
        _accountType = accountType;
        // Don't override _currentIndex if loginAccountType or initialIndex was provided
        // This ensures the login screen's account type selection takes priority
      });
    }

    _accountTypeSubscription?.cancel();
    _accountTypeSubscription = _accountTypeService
        .watchAccountType(user.uid)
        .listen((type) {
          if (mounted) {
            setState(() => _accountType = type);
          }
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unreadSubscription?.cancel();
    _incomingCallSubscription?.cancel();
    _accountTypeSubscription?.cancel();
    super.dispose();
  }

  void _listenForIncomingCalls() {
    final user = _auth.currentUser;
    if (user == null) return;

    _incomingCallSubscription?.cancel();

    final currentUserId = user.uid;
    debugPrint('  ====== CALL LISTENER SETUP ======');
    debugPrint('  Current user ID: $currentUserId');
    debugPrint('  User email: ${user.email}');

    _incomingCallSubscription = _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'calling')
        .snapshots()
        .listen((snapshot) {
          if (!mounted || _isShowingIncomingCall) return;

          debugPrint('  ====== CALL SNAPSHOT ======');
          debugPrint('  Total calls in snapshot: ${snapshot.docs.length}');
          debugPrint('  Changes count: ${snapshot.docChanges.length}');

          // Get current time for checking call freshness
          final now = DateTime.now();
          final cutoffTime = now.subtract(const Duration(seconds: 30));

          for (var change in snapshot.docChanges) {
            debugPrint('  Change type: ${change.type}');

            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data == null) {
                debugPrint('  Skipping: null data');
                continue;
              }

              final callId = change.doc.id;
              final callerId = data['callerId'] as String? ?? '';
              final receiverId = data['receiverId'] as String? ?? '';

              debugPrint('  ====== CALL DETAILS ======');
              debugPrint('  Call ID: $callId');
              debugPrint('  Caller ID: $callerId');
              debugPrint('  Receiver ID: $receiverId');
              debugPrint('  My User ID: $currentUserId');
              debugPrint('  Am I caller? ${callerId == currentUserId}');
              debugPrint('  Am I receiver? ${receiverId == currentUserId}');

              // Skip if we've already handled this call
              if (_handledCallIds.contains(callId)) {
                debugPrint('    Skipping: already handled');
                continue;
              }

              // CRITICAL CHECK: Skip if current user is the caller (not the receiver)
              if (callerId == currentUserId) {
                debugPrint('    Skipping: I am the caller, not receiver');
                _handledCallIds.add(callId);
                continue;
              }

              // Double verify: receiver ID must match current user exactly
              if (receiverId != currentUserId) {
                debugPrint('    Skipping: receiver ID does not match my ID');
                debugPrint('  Expected: $currentUserId, Got: $receiverId');
                _handledCallIds.add(callId);
                continue;
              }

              debugPrint('    Call is valid for this user!');

              // Check call timestamp - ignore old calls and mark as missed
              // Use timestamp or createdAt field
              final timestamp = data['timestamp'] ?? data['createdAt'];
              DateTime? callTime;
              if (timestamp is Timestamp) {
                callTime = timestamp.toDate();
              } else if (timestamp is String) {
                callTime = DateTime.tryParse(timestamp);
              }

              // If call is older than 30 seconds, mark as missed instead of showing incoming call
              if (callTime != null && callTime.isBefore(cutoffTime)) {
                _handledCallIds.add(callId);

                // Mark as missed in Firestore
                _firestore.collection('calls').doc(callId).update({
                  'status': 'missed',
                  'missedAt': FieldValue.serverTimestamp(),
                });

                // Show missed call notification
                final callerNameMissed = data['callerName'] as String? ?? 'Unknown';
                _showMissedCallNotification(callerNameMissed);
                continue;
              }

              _handledCallIds.add(callId);

              final callerName = data['callerName'] as String? ?? 'Unknown';
              final callerPhoto = data['callerPhoto'] as String?;

              // Show incoming call screen for fresh calls only
              _showIncomingCall(
                callId: callId,
                callerName: callerName,
                callerPhoto: callerPhoto,
                callerId: callerId, // Using callerId from earlier check
              );
              break;
            }
          }
        });
  }

  void _showIncomingCall({
    required String callId,
    required String callerName,
    String? callerPhoto,
    required String callerId,
  }) {
    if (_isShowingIncomingCall) return;

    _isShowingIncomingCall = true;
    HapticFeedback.heavyImpact();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncomingCallScreen(
          callId: callId,
          callerName: callerName,
          callerPhoto: callerPhoto,
          callerId: callerId,
        ),
      ),
    ).then((_) {
      _isShowingIncomingCall = false;
    });
  }

  void _checkLocation() async {
    try {
      await _location.checkAndRefreshStaleLocation();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_auth.currentUser == null) return;

    if (state == AppLifecycleState.resumed) {
      _updateStatus(true);
    } else {
      _updateStatus(false);
    }
  }

  void _updateStatus(bool online) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      _firestore
          .collection("users")
          .doc(uid)
          .update({
            "isOnline": online,
            "lastSeen": FieldValue.serverTimestamp(),
          })
          .catchError((e) {
            debugPrint('Error updating status: $e');
          });
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  void _listenUnread() {
    final user = _auth.currentUser;
    if (user == null) return;

    _unreadSubscription?.cancel();
    _unreadSubscription = _firestore
        .collection("conversations")
        .where("participants", arrayContains: user.uid)
        .snapshots()
        .listen(
          (snap) {
            if (!mounted) return;
            try {
              int total = 0;
              for (var doc in snap.docs) {
                total += ((doc["unreadCount"]?[user.uid] ?? 0) as num).toInt();
              }
              setState(() => _unreadMessageCount = total);
              NotificationService().updateBadgeCount(total);
            } catch (e) {
              debugPrint('Error processing unread count: $e');
            }
          },
          onError: (error) {
            debugPrint('Unread listener error: $error');
          },
        );
  }

  Widget _buildScreen() {
    switch (_currentIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const ConversationsScreen();
      case 2:
        return const LiveConnectTabScreen();
      case 3:
        return const ProfileWithHistoryScreen();
      case 5:
        return const ProfessionalDashboardScreen();
      case 6:
        return const BusinessMainScreen();
      case 7:
        return FeedScreen(
          onBack: () {
            setState(() => _currentIndex = 0);
          },
        );
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          _buildScreen(),

          // Bottom Navigation Bar (hide on Feed screen)
          if (_currentIndex != 7)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ModernBottomNavBar(
                currentIndex: _currentIndex,
                unreadCount: _unreadMessageCount,
                onTap: (index) {
                  HapticFeedback.mediumImpact();
                  setState(() => _currentIndex = index);
                },
              ),
            ),

          // Swipe gesture detector for Feed
          if (_currentIndex == 0)
            Positioned(
              left: 0,
              top: 0,
              height: size.height - 100,
              width: 100,
              child: _SwipeDetector(
                onSwipeRight: () {
                  HapticFeedback.mediumImpact();
                  setState(() => _currentIndex = 7);
                },
              ),
            ),
        ],
      ),
    );
  }
}

// Modern Bottom Navigation Bar - 3 tabs with proper styling
class _ModernBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final int unreadCount;
  final Function(int) onTap;

  const _ModernBottomNavBar({
    required this.currentIndex,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomPadding + 8,
        top: 8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
                _NavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  selectedIcon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  isSelected: currentIndex == 1,
                  badge: unreadCount > 0 ? unreadCount : null,
                  onTap: () => onTap(1),
                ),
                _NavItem(
                  icon: Icons.people_outline_rounded,
                  selectedIcon: Icons.people_rounded,
                  label: 'Networking',
                  isSelected: currentIndex == 2,
                  onTap: () => onTap(2),
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Individual navigation item - icon with label below
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final int? badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 26,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                ),
                // Badge
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Text(
                        badge! > 99 ? '99+' : badge.toString(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Label always visible
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Swipe Detector for Feed access
class _SwipeDetector extends StatefulWidget {
  final VoidCallback? onSwipeRight;

  const _SwipeDetector({this.onSwipeRight});

  @override
  State<_SwipeDetector> createState() => _SwipeDetectorState();
}

class _SwipeDetectorState extends State<_SwipeDetector> {
  double _startX = 0;
  bool _hasTriggered = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        _startX = event.position.dx;
        _hasTriggered = false;
      },
      onPointerMove: (event) {
        if (_hasTriggered) return;

        final deltaX = event.position.dx - _startX;

        if (widget.onSwipeRight != null && deltaX > 30) {
          _hasTriggered = true;
          widget.onSwipeRight!();
        }
      },
      onPointerUp: (_) {
        _hasTriggered = false;
      },
      child: Container(color: Colors.transparent),
    );
  }
}