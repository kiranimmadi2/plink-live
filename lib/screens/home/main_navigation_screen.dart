import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Replace these with your actual screens
import 'home_screen.dart';
import 'conversations_screen.dart';
import 'live_connect_tab_screen.dart';
import '../profile/profile_with_history_screen.dart'; // Use provider-based version
import 'messageser_screen.dart';
import 'feed_screen.dart';
import '../chat/incoming_call_screen.dart';

// Professional & Business screens
import '../professional/professional_dashboard_screen.dart';
import '../business/business_dashboard_screen.dart';

// services
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../services/account_type_service.dart';
import '../../models/user_profile.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

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

  // Account type for showing appropriate dashboard
  AccountType _accountType = AccountType.personal;
  StreamSubscription<AccountType>? _accountTypeSubscription;

  // Stream subscription for cleanup
  StreamSubscription<QuerySnapshot>? _unreadSubscription;
  StreamSubscription<QuerySnapshot>? _incomingCallSubscription;
  bool _isShowingIncomingCall = false;

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

    _menuController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _listenUnread();
    _listenForIncomingCalls();
    _updateStatus(true);
    _checkLocation();
    _loadAccountType();
  }

  void _loadAccountType() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Initial load
    final accountType = await _accountTypeService.getCurrentAccountType();
    if (mounted) {
      setState(() => _accountType = accountType);
    }

    // Listen for changes
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
    _incomingCallSubscription = _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'calling')
        .snapshots()
        .listen((snapshot) {
      if (!mounted || _isShowingIncomingCall) return;

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final callId = change.doc.id;
          final callerName = data['callerName'] as String? ?? 'Unknown';
          final callerPhoto = data['callerPhoto'] as String?;
          final callerId = data['callerId'] as String? ?? '';

          // Show incoming call screen
          _showIncomingCall(
            callId: callId,
            callerName: callerName,
            callerPhoto: callerPhoto,
            callerId: callerId,
          );
          break; // Only show one call at a time
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
      // FAB starts on right side, vertically centered
      _fabPosition = Offset(size.width - 80, size.height / 2 - 32);
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
      _firestore.collection("users").doc(uid).update({
        "isOnline": online,
        "lastSeen": FieldValue.serverTimestamp(),
      }).catchError((e) {
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
    Future.delayed(const Duration(milliseconds: 200), () {
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

  void _onDragUpdate(DragUpdateDetails d) {
    // Calculate new position - allow free movement during drag
    final newX = _fabPosition.dx + d.delta.dx;
    final newY = _fabPosition.dy + d.delta.dy;

    setState(() {
      _fabPosition = Offset(newX, newY);
    });
  }

  void _onDragEnd(DragEndDetails d) {
    final size = MediaQuery.of(context).size;

    // Snap X to left (10) or right (size.width - 80) edge based on position
    final snappedX = _fabPosition.dx > size.width / 2 ? size.width - 80 : 10.0;

    // Clamp Y: 200 from top, 200 from bottom
    const minY = 200.0;
    const maxY = 200.0;
    final clampedY = _fabPosition.dy.clamp(minY, size.height - maxY);

    setState(() {
      _fabPosition = Offset(snappedX, clampedY);
    });
  }

  void _resetFAB() {
    final size = MediaQuery.of(context).size;
    setState(() {
      // Reset to right side, vertically centered
      _fabPosition = Offset(size.width - 80, size.height / 2 - 32);
    });
  }

  // MENU ITEMS - Built dynamically based on account type
  List<Map<String, dynamic>> get menuItems {
    final items = <Map<String, dynamic>>[
      {
        "label": "Discover",
        "icon": Icons.explore_outlined,
        "index": 0,
        "color": Colors.blue,
      },
      {
        "label": "Messages",
        "icon": Icons.message_outlined,
        "index": 1,
        "color": Colors.green,
      },
      {
        "label": "Live",
        "icon": Icons.people_outline,
        "index": 2,
        "color": Colors.orange,
      },
      {
        "label": "Profile",
        "icon": Icons.person_outline,
        "index": 3,
        "color": Colors.purple,
      },
    ];

    // Add Dashboard for Professional/Business accounts
    if (_accountType == AccountType.professional) {
      items.add({
        "label": "Dashboard",
        "icon": Icons.dashboard_outlined,
        "index": 5,
        "color": const Color(0xFF9C27B0), // Purple for professional
      });
    } else if (_accountType == AccountType.business) {
      items.add({
        "label": "Dashboard",
        "icon": Icons.business_center_outlined,
        "index": 6,
        "color": const Color(0xFFFF9800), // Orange for business
      });
    }

    // Add Messageser at the end
    items.add({
      "label": "Messageser",
      "icon": Icons.message_rounded,
      "index": 4,
      "color": Colors.teal,
    });

    return items;
  }

  // SCREENS
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
      case 4:
        return const MessageserScreen();
      case 5:
        // Professional Dashboard
        return const ProfessionalDashboardScreen();
      case 6:
        // Business Dashboard
        return const BusinessDashboardScreen();
      case 7:
        // Feed Screen
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

    // Safe area boundaries - FAB must stay within bounds
    const minX = 10.0;
    final maxX = size.width - 74; // 64 FAB width + 10 margin
    const minY = 200.0; // 200 from top
    final maxY = size.height - 200.0; // 200 from bottom

    final fabX = _fabPosition.dx.clamp(minX, maxX);
    final fabY = _fabPosition.dy.clamp(minY, maxY);

    return Scaffold(
      body: Stack(
        children: [
          // Main screen
          _buildScreen(),

          // Dark overlay when menu is open
          if (_fabMenuOpen)
            AnimatedBuilder(
              animation: _menuController,
              builder: (context, child) {
                return GestureDetector(
                  onTap: _closeMenu,
                  child: Container(
                    color: Colors.black.withValues(
                      alpha: 0.4 * _menuController.value,
                    ),
                  ),
                );
              },
            ),

          // Animated menu buttons - half circle arc (left or right based on FAB position)
          if (_fabMenuOpen)
            ...List.generate(menuItems.length, (i) {
              // Determine if FAB is on left or right side
              final bool isOnRight = fabX > size.width / 2;

              return AnimatedBuilder(
                animation: _menuController,
                builder: (context, child) {
                  // Staggered animation
                  final delay = i * 0.06;
                  final progress =
                      ((_menuController.value - delay) / (1 - delay)).clamp(
                        0.0,
                        1.0,
                      );

                  // Curved animation
                  final curvedProgress = Curves.easeOutBack.transform(progress);

                  // Half circle arc parameters
                  const radius = 95.0;
                  final totalButtons = menuItems.length;
                  const buttonSize = 56.0;

                  // Half circle = 180 degrees = pi radians
                  // Spread buttons from top (-90°) to bottom (90°)
                  final angleStep = math.pi / (totalButtons - 1);
                  final baseAngle = -math.pi / 2 + (angleStep * i); // -90° to +90°

                  // Calculate x and y offsets
                  double xOffset;
                  double yOffset;

                  if (isOnRight) {
                    // FAB is on RIGHT → Arc opens to LEFT
                    xOffset = -radius * math.cos(baseAngle) * curvedProgress;
                    yOffset = radius * math.sin(baseAngle) * curvedProgress;
                  } else {
                    // FAB is on LEFT → Arc opens to RIGHT
                    xOffset = radius * math.cos(baseAngle) * curvedProgress;
                    yOffset = radius * math.sin(baseAngle) * curvedProgress;
                  }

                  // Center button on FAB
                  const centerOffset = (64 - buttonSize) / 2;

                  return Positioned(
                    left: fabX + xOffset + centerOffset,
                    top: fabY + yOffset + centerOffset,
                    child: Transform.scale(
                      scale: curvedProgress,
                      child: Opacity(
                        opacity: curvedProgress.clamp(0.0, 1.0),
                        child: _AnimatedMenuItem(
                          item: menuItems[i],
                          unread: _unreadMessageCount,
                          delay: delay,
                          onTap: () => _navigate(menuItems[i]["index"] as int),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),

          // Main FAB button
          Positioned(
            left: fabX,
            top: fabY,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: _onDragUpdate,
              onPanEnd: _onDragEnd, // Snap to edge when released
              onDoubleTap: _resetFAB,
              child: AnimatedBuilder(
                animation: _menuController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Pulse ring animation
                      Container(
                        width: 64 + 30 * _menuController.value,
                        height: 64 + 30 * _menuController.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blue.withValues(
                              alpha: 0.3 * _menuController.value,
                            ),
                            width: 2,
                          ),
                        ),
                      ),

                      // Main FAB with glassmorphism effect
                      ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _toggleMenu,
                              borderRadius: BorderRadius.circular(32),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: _fabMenuOpen
                                      ? Colors.red.withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: AnimatedRotation(
                                        turns: _fabMenuOpen ? 0.125 : 0,
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        child: Icon(
                                          _fabMenuOpen
                                              ? Icons.close
                                              : Icons.apps,
                                          size: 28,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (_unreadMessageCount > 0 &&
                                        !_fabMenuOpen)
                                      Positioned(
                                        right: 4,
                                        top: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            _unreadMessageCount > 99
                                                ? "99+"
                                                : _unreadMessageCount
                                                      .toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Swipe gesture detector - HomeScreen -> FeedScreen (right swipe from left edge)
          // Full screen height, left edge 100px wide for detecting right swipe
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

// ==================================================
// ANIMATED MENU ITEM
// ==================================================
class _AnimatedMenuItem extends StatefulWidget {
  final Map<String, dynamic> item;
  final int unread;
  final double delay;
  final VoidCallback onTap;

  const _AnimatedMenuItem({
    required this.item,
    required this.unread,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_AnimatedMenuItem> createState() => _AnimatedMenuItemState();
}

class _AnimatedMenuItemState extends State<_AnimatedMenuItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 56,
            height: 56,
            transform: Matrix4.identity()
              ..setEntry(0, 0, _isPressed ? 0.9 : 1.0)
              ..setEntry(1, 1, _isPressed ? 0.9 : 1.0)
              ..setEntry(2, 2, _isPressed ? 0.9 : 1.0),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: _isPressed ? 8 : 12,
                  spreadRadius: _isPressed ? 0 : 2,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    widget.item["icon"] as IconData,
                    size: 26,
                    color: Colors.white,
                  ),
                ),
                // Unread badge for Messages
                if (widget.item["index"] == 1 && widget.unread > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        widget.unread > 99 ? "99+" : widget.unread.toString(),
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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

// ==================================================
// SWIPE DETECTOR - Custom widget for edge swipe detection
// ==================================================
class _SwipeDetector extends StatefulWidget {
  final VoidCallback? onSwipeRight;

  const _SwipeDetector({
    this.onSwipeRight,
  });

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

        // Right swipe: moved right by at least 30px
        if (widget.onSwipeRight != null && deltaX > 30) {
          _hasTriggered = true;
          widget.onSwipeRight!();
        }
      },
      onPointerUp: (_) {
        _hasTriggered = false;
      },
      child: Container(
        color: Colors.transparent,
      ),
    );
  }
}
