import 'dart:async';
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

  const MainNavigationScreen({super.key, this.initialIndex});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _fabMenuOpen = false;
  int _unreadMessageCount = 0;

  Offset _fabPosition = const Offset(0, 0);
  bool _initialPosSet = false;

  // Drag-to-select state
  int? _hoveredMenuIndex;
  bool _isDraggingToSelect = false;

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

  // Animation controller
  late AnimationController _menuController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.initialIndex != null) {
      _currentIndex = widget.initialIndex!;
    }

    _menuController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

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
        // Always start on the home screen (index 0) regardless of account type
        // User can navigate to their dashboard using the FAB menu if needed
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
    _menuController.dispose();
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialPosSet) {
      final size = MediaQuery.of(context).size;
      // Position FAB lower on screen (70% down) so menu opens upward
      _fabPosition = Offset(size.width - 60, size.height * 0.70);
      _initialPosSet = true;
      setState(() {});
    }
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

  void _navigate(int index) {
    HapticFeedback.mediumImpact();
    _closeMenu();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _currentIndex = index;
        });
      }
    });
  }

  void _openMenu() {
    HapticFeedback.mediumImpact();
    setState(() => _fabMenuOpen = true);
    _menuController.forward();
  }

  void _closeMenu() {
    _menuController.reverse().then((_) {
      if (mounted) {
        setState(() => _fabMenuOpen = false);
      }
    });
  }

  void _toggleMenu() {
    if (_fabMenuOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  // === Drag-to-Select Feature ===

  // Track drag distance to differentiate tap vs drag
  double _totalDragDistance = 0;

  void _onPanStart(DragStartDetails details) {
    _totalDragDistance = 0;
    _isDraggingToSelect = false;
    _hoveredMenuIndex = null;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _totalDragDistance += details.delta.distance;

    // If dragged more than 8px, treat as drag-to-select (quick response)
    if (_totalDragDistance > 8 && !_isDraggingToSelect) {
      // Open menu and start drag-to-select mode
      _isDraggingToSelect = true;
      HapticFeedback.mediumImpact();
      if (!_fabMenuOpen) {
        setState(() => _fabMenuOpen = true);
        _menuController.forward();
      }
    }

    // If in drag-to-select mode, always track hover (even while menu is animating)
    if (_isDraggingToSelect) {
      _updateHoveredItem(details.globalPosition);
    } else if (!_fabMenuOpen) {
      // Normal FAB position drag (only if not triggering menu)
      final newX = _fabPosition.dx + details.delta.dx;
      final newY = _fabPosition.dy + details.delta.dy;
      setState(() {
        _fabPosition = Offset(newX, newY);
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isDraggingToSelect && _hoveredMenuIndex != null) {
      // Navigate to the selected item
      HapticFeedback.mediumImpact();
      final selectedIndex = menuItems[_hoveredMenuIndex!].index;
      _navigate(selectedIndex);
    } else if (_isDraggingToSelect) {
      // Dragged but didn't select anything - close menu
      _closeMenu();
    } else if (!_fabMenuOpen) {
      // Was just moving FAB - snap to edge
      final size = MediaQuery.of(context).size;
      final snappedX = _fabPosition.dx > size.width / 2 ? size.width - 60 : 8.0;
      const minY = 120.0;
      final maxY = size.height - 120.0;
      final clampedY = _fabPosition.dy.clamp(minY, maxY);
      setState(() {
        _fabPosition = Offset(snappedX, clampedY);
      });
    }

    setState(() {
      _isDraggingToSelect = false;
      _hoveredMenuIndex = null;
      _totalDragDistance = 0;
    });
  }

  void _updateHoveredItem(Offset fingerPos) {
    final size = MediaQuery.of(context).size;
    final fabX = _fabPosition.dx.clamp(8.0, size.width - 60);
    final fabY = _fabPosition.dy.clamp(120.0, size.height - 120.0);
    final goDown = fabY < size.height / 2;
    final expandLeft = fabX > size.width / 2;

    const itemSpacing = 56.0;
    const itemWidth = 150.0; // Width of pill items
    const itemHeight = 48.0;
    const hitAreaPadding = 25.0; // Generous hit area

    int? newHoveredIndex;

    for (int i = 0; i < menuItems.length; i++) {
      final yOffset = goDown
          ? (i + 1) * itemSpacing + 6
          : -(i + 1) * itemSpacing - 6;

      // Calculate item center based on where items are actually positioned
      double itemCenterX;
      if (expandLeft) {
        // Items expand left - right edge aligns with FAB right edge
        // Item right edge at fabX + 52, so center is at fabX + 52 - itemWidth/2
        itemCenterX = fabX + 52 - (itemWidth / 2);
      } else {
        // Items expand right - left edge aligns with FAB left edge
        // Item left edge at fabX, so center is at fabX + itemWidth/2
        itemCenterX = fabX + (itemWidth / 2);
      }
      final itemCenterY = fabY + 26 + yOffset;

      final dx = (fingerPos.dx - itemCenterX).abs();
      final dy = (fingerPos.dy - itemCenterY).abs();

      // Check if finger is within hit area
      if (dx < (itemWidth / 2 + hitAreaPadding) &&
          dy < (itemHeight / 2 + hitAreaPadding)) {
        newHoveredIndex = i;
        break;
      }
    }

    if (newHoveredIndex != _hoveredMenuIndex) {
      if (newHoveredIndex != null) {
        HapticFeedback.selectionClick();
      }
      setState(() => _hoveredMenuIndex = newHoveredIndex);
    }
  }

  void _resetFAB() {
    final size = MediaQuery.of(context).size;
    setState(() {
      // Reset to lower position (70% down) so menu opens upward
      _fabPosition = Offset(size.width - 60, size.height * 0.70);
    });
  }

  // Menu items with modern design
  List<_MenuItemData> get menuItems {
    final items = <_MenuItemData>[
      const _MenuItemData(
        label: "Home",
        icon: Icons.home_rounded,
        index: 0,
        gradient: [Color(0xFF667EEA), Color(0xFF764BA2)],
      ),
      const _MenuItemData(
        label: "Messages",
        icon: Icons.chat_bubble_rounded,
        index: 1,
        gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
      ),
      const _MenuItemData(
        label: "Networking",
        icon: Icons.people_rounded,
        index: 2,
        gradient: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
      ),
    ];

    if (_accountType == AccountType.professional) {
      items.add(const _MenuItemData(
        label: "Dashboard",
        icon: Icons.dashboard_rounded,
        index: 5,
        gradient: [Color(0xFF9C27B0), Color(0xFFE040FB)],
      ));
    } else if (_accountType == AccountType.business) {
      items.add(const _MenuItemData(
        label: "Business",
        icon: Icons.business_center_rounded,
        index: 6,
        gradient: [Color(0xFFFF9800), Color(0xFFFFEB3B)],
      ));
    }

    return items;
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

    // FAB is 52px, allow it to go to screen edges with small padding
    const minX = 8.0;
    final maxX = size.width - 60; // 52px FAB + 8px padding
    const minY = 120.0;
    final maxY = size.height - 120.0;

    final fabX = _fabPosition.dx.clamp(minX, maxX);
    final fabY = _fabPosition.dy.clamp(minY, maxY);

    return Scaffold(
      body: Stack(
        children: [
          _buildScreen(),

          // Blur overlay when menu is open
          if (_fabMenuOpen)
            AnimatedBuilder(
              animation: _menuController,
              builder: (context, child) {
                return GestureDetector(
                  onTap: _closeMenu,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(
                        alpha: 0.6 * _menuController.value,
                      ),
                    ),
                  ),
                );
              },
            ),

          // Menu items - pill shape with icon + label
          if (_fabMenuOpen)
            ...List.generate(menuItems.length, (i) {
              // If FAB is in upper half, menu goes down; otherwise up
              final bool goDown = fabY < size.height / 2;
              // If FAB is on right side, menu expands to left; otherwise to right
              final bool expandLeft = fabX > size.width / 2;
              final bool isHovered = _hoveredMenuIndex == i;

              return AnimatedBuilder(
                animation: _menuController,
                builder: (context, child) {
                  final delay = i * 0.05;
                  final progress =
                      ((_menuController.value - delay) / (1 - delay)).clamp(
                        0.0,
                        1.0,
                      );

                  final curvedProgress = Curves.easeOutCubic.transform(progress);

                  // Vertical stack layout - 56px spacing for pill items
                  const itemSpacing = 56.0;
                  final yOffset = goDown
                      ? (i + 1) * itemSpacing * curvedProgress + 6 // Go down
                      : -(i + 1) * itemSpacing * curvedProgress - 6; // Go up

                  return Positioned(
                    // If on right side, use 'right' positioning; otherwise use 'left'
                    right: expandLeft ? (size.width - fabX - 52) : null,
                    left: expandLeft ? null : fabX,
                    top: fabY + yOffset,
                    child: Transform.scale(
                      scale: curvedProgress,
                      child: Opacity(
                        opacity: curvedProgress.clamp(0.0, 1.0),
                        child: _CompactMenuItem(
                          data: menuItems[i],
                          unread: _unreadMessageCount,
                          isHovered: isHovered,
                          onTap: () => _navigate(menuItems[i].index),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),

          // Main FAB button - Modern design with drag-to-select
          Positioned(
            left: fabX,
            top: fabY,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              // Pan for drag-to-select (opens menu on drag, selects on release)
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              // Double tap to reset position
              onDoubleTap: _resetFAB,
              // Single tap to toggle menu
              onTap: _toggleMenu,
              child: AnimatedBuilder(
                animation: _menuController,
                builder: (context, child) {
                  return _ModernFAB(
                    isOpen: _fabMenuOpen,
                    animationValue: _menuController.value,
                    unreadCount: _unreadMessageCount,
                    onTap: _toggleMenu,
                  );
                },
              ),
            ),
          ),

          // Swipe gesture detector
          if (_currentIndex == 0)
            Positioned(
              left: 0,
              top: 0,
              height: size.height,
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

// Data class for menu items
class _MenuItemData {
  final String label;
  final IconData icon;
  final int index;
  final List<Color> gradient;

  const _MenuItemData({
    required this.label,
    required this.icon,
    required this.index,
    required this.gradient,
  });
}

// Modern FAB button - Pure Glass theme
class _ModernFAB extends StatelessWidget {
  final bool isOpen;
  final double animationValue;
  final int unreadCount;
  final VoidCallback onTap;

  const _ModernFAB({
    required this.isOpen,
    required this.animationValue,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Pure frosted glass
            color: Colors.white.withValues(alpha: isOpen ? 0.2 : 0.18),
            // Soft shadows
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: Stack(
              children: [
                // Subtle tint when open (reddish) or closed (neutral)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isOpen
                          ? [
                              const Color(0xFFE0A0A0).withValues(alpha: 0.15),
                              const Color(0xFFD08080).withValues(alpha: 0.08),
                            ]
                          : [
                              const Color(0xFFA0B0C0).withValues(alpha: 0.12),
                              const Color(0xFF90A0B0).withValues(alpha: 0.06),
                            ],
                    ),
                  ),
                ),
                // Glass highlight (top shine)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 26,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.3),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Frosted border
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                // Icon
                Center(
                  child: _AnimatedMenuIcon(
                    isOpen: isOpen,
                    animationValue: animationValue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Menu Item - Pill shape with icon + label (like Google Calendar)
class _CompactMenuItem extends StatefulWidget {
  final _MenuItemData data;
  final int unread;
  final bool isHovered;
  final VoidCallback onTap;

  const _CompactMenuItem({
    required this.data,
    required this.unread,
    this.isHovered = false,
    required this.onTap,
  });

  @override
  State<_CompactMenuItem> createState() => _CompactMenuItemState();
}

class _CompactMenuItemState extends State<_CompactMenuItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final showBadge = widget.data.index == 1 && widget.unread > 0;
    final isHovered = widget.isHovered;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: isHovered ? 1.08 : (_isPressed ? 0.95 : 1.0),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Pill-shaped container with icon + label
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                // Frosted glass effect - brighter when hovered
                color: Colors.white.withValues(alpha: isHovered ? 0.30 : 0.18),
                // Shadow
                boxShadow: [
                  if (isHovered) ...[
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ] else ...[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: isHovered ? 0.5 : 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Icon(
                    widget.data.icon,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                  const SizedBox(width: 10),
                  // Label
                  Text(
                    widget.data.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.95),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

            // Badge for messages
            if (showBadge)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.unread > 99 ? "99+" : widget.unread.toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Swipe Detector
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

// Custom Animated Menu Icon - Modern design
class _AnimatedMenuIcon extends StatelessWidget {
  final bool isOpen;
  final double animationValue;

  const _AnimatedMenuIcon({
    required this.isOpen,
    required this.animationValue,
  });

  @override
  Widget build(BuildContext context) {
    // Rotate from + (0°) to X (45°)
    final rotation = animationValue * 0.785; // 45 degrees in radians

    return Transform.rotate(
      angle: rotation,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Horizontal bar of +
            Container(
              width: 20,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
            // Vertical bar of +
            Container(
              width: 3,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

