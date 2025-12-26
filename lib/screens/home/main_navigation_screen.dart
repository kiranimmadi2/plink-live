import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Replace these with your actual screens
import 'home_screen.dart';
import 'conversations_screen.dart';
import 'live_connect_tab_screen.dart';
import '../profile/profile_with_history_screen.dart';
import 'feed_screen.dart';
import '../chat/incoming_call_screen.dart';

// Professional & Business screens
import '../professional/professional_dashboard_screen.dart';
import '../business/universal_business_dashboard.dart';

// services
import '../../services/location_service.dart';
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAsync();
    });
  }

  void _initializeAsync() {
    Future.microtask(() => _loadAccountType());

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _listenUnread();
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _listenForIncomingCalls();
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _updateStatus(true);
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _checkLocation();
    });
  }

  void _loadAccountType() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final accountType = await _accountTypeService.getCurrentAccountType();
    if (mounted) {
      setState(() {
        _accountType = accountType;
        if (_currentIndex == 0 && widget.initialIndex == null) {
          if (accountType == AccountType.professional) {
            _currentIndex = 5;
          } else if (accountType == AccountType.business) {
            _currentIndex = 6;
          }
        }
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
    final cutoffTime = DateTime.now().subtract(const Duration(seconds: 30));

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
              if (_handledCallIds.contains(callId)) continue;

              final timestamp = data['timestamp'];
              if (timestamp != null) {
                DateTime? callTime;
                if (timestamp is Timestamp) {
                  callTime = timestamp.toDate();
                } else if (timestamp is String) {
                  callTime = DateTime.tryParse(timestamp);
                }

                if (callTime != null && callTime.isBefore(cutoffTime)) {
                  _handledCallIds.add(callId);
                  continue;
                }
              }

              _handledCallIds.add(callId);

              final callerName = data['callerName'] as String? ?? 'Unknown';
              final callerPhoto = data['callerPhoto'] as String?;
              final callerId = data['callerId'] as String? ?? '';

              _showIncomingCall(
                callId: callId,
                callerName: callerName,
                callerPhoto: callerPhoto,
                callerId: callerId,
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

  void _onDragUpdate(DragUpdateDetails d) {
    final newX = _fabPosition.dx + d.delta.dx;
    final newY = _fabPosition.dy + d.delta.dy;

    setState(() {
      _fabPosition = Offset(newX, newY);
    });
  }

  void _onDragEnd(DragEndDetails d) {
    final size = MediaQuery.of(context).size;
    final snappedX = _fabPosition.dx > size.width / 2 ? size.width - 80 : 10.0;

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
      _fabPosition = Offset(size.width - 80, size.height / 2 - 32);
    });
  }

  // Menu items with modern design
  List<_MenuItemData> get menuItems {
    final items = <_MenuItemData>[
      const _MenuItemData(
        label: "Discover",
        icon: Icons.explore_rounded,
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
        label: "Live",
        icon: Icons.people_rounded,
        index: 2,
        gradient: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
      ),
      const _MenuItemData(
        label: "Profile",
        icon: Icons.person_rounded,
        index: 3,
        gradient: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
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
        return const UniversalBusinessDashboard();
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

    const minX = 10.0;
    final maxX = size.width - 74;
    const minY = 200.0;
    final maxY = size.height - 200.0;

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

          // Menu items with modern card design
          if (_fabMenuOpen)
            ...List.generate(menuItems.length, (i) {
              final bool isOnRight = fabX > size.width / 2;

              return AnimatedBuilder(
                animation: _menuController,
                builder: (context, child) {
                  final delay = i * 0.08;
                  final progress =
                      ((_menuController.value - delay) / (1 - delay)).clamp(
                        0.0,
                        1.0,
                      );

                  final curvedProgress = Curves.easeOutBack.transform(progress);

                  const radius = 110.0;
                  final totalButtons = menuItems.length;

                  final angleStep = math.pi / (totalButtons - 1);
                  final baseAngle = -math.pi / 2 + (angleStep * i);

                  double xOffset;
                  double yOffset;

                  if (isOnRight) {
                    xOffset = -radius * math.cos(baseAngle) * curvedProgress;
                    yOffset = radius * math.sin(baseAngle) * curvedProgress;
                  } else {
                    xOffset = radius * math.cos(baseAngle) * curvedProgress;
                    yOffset = radius * math.sin(baseAngle) * curvedProgress;
                  }

                  const centerOffset = (64 - 52) / 2;

                  return Positioned(
                    left: fabX + xOffset + centerOffset,
                    top: fabY + yOffset + centerOffset,
                    child: Transform.scale(
                      scale: curvedProgress,
                      child: Opacity(
                        opacity: curvedProgress.clamp(0.0, 1.0),
                        child: _ModernMenuItem(
                          data: menuItems[i],
                          unread: _unreadMessageCount,
                          onTap: () => _navigate(menuItems[i].index),
                          isOnRight: isOnRight,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),

          // Main FAB button - Modern design
          Positioned(
            left: fabX,
            top: fabY,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: _onDragUpdate,
              onPanEnd: _onDragEnd,
              onDoubleTap: _resetFAB,
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

// Modern FAB button
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
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Outer glow ring
        if (isOpen)
          Container(
            width: 64 + 20 * animationValue,
            height: 64 + 20 * animationValue,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF667EEA).withValues(alpha: 0.4 * animationValue),
                width: 2,
              ),
            ),
          ),

        // Main button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(32),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isOpen
                      ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                      : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isOpen ? const Color(0xFFEF4444) : const Color(0xFF667EEA))
                        .withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: _AnimatedMenuIcon(
                      isOpen: isOpen,
                      animationValue: animationValue,
                    ),
                  ),
                  // Notification badge
                  if (unreadCount > 0 && !isOpen)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          unreadCount > 99 ? "99+" : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Modern Menu Item
class _ModernMenuItem extends StatefulWidget {
  final _MenuItemData data;
  final int unread;
  final VoidCallback onTap;
  final bool isOnRight;

  const _ModernMenuItem({
    required this.data,
    required this.unread,
    required this.onTap,
    required this.isOnRight,
  });

  @override
  State<_ModernMenuItem> createState() => _ModernMenuItemState();
}

class _ModernMenuItemState extends State<_ModernMenuItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final showBadge = widget.data.index == 1 && widget.unread > 0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon button with gradient
          AnimatedScale(
            scale: _isPressed ? 0.9 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.data.gradient,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.data.gradient[0].withValues(alpha: 0.4),
                        blurRadius: _isPressed ? 8 : 16,
                        spreadRadius: _isPressed ? 0 : 2,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      widget.data.icon,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                ),

                // Badge for messages
                if (showBadge)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.unread > 99 ? "99+" : widget.unread.toString(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.data.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
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
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated dots that form menu icon -> X transformation
          // Top-left dot
          _AnimatedDot(
            animation: animationValue,
            startOffset: const Offset(-8, -8),
            endOffset: const Offset(-7, -7),
            rotateToLine: true,
            lineAngle: 0.785, // 45 degrees
          ),
          // Top-right dot
          _AnimatedDot(
            animation: animationValue,
            startOffset: const Offset(8, -8),
            endOffset: const Offset(7, -7),
            rotateToLine: true,
            lineAngle: -0.785,
          ),
          // Center dot
          _AnimatedDot(
            animation: animationValue,
            startOffset: Offset.zero,
            endOffset: Offset.zero,
            fadeOut: true,
          ),
          // Bottom-left dot
          _AnimatedDot(
            animation: animationValue,
            startOffset: const Offset(-8, 8),
            endOffset: const Offset(-7, 7),
            rotateToLine: true,
            lineAngle: -0.785,
          ),
          // Bottom-right dot
          _AnimatedDot(
            animation: animationValue,
            startOffset: const Offset(8, 8),
            endOffset: const Offset(7, 7),
            rotateToLine: true,
            lineAngle: 0.785,
          ),

          // X lines that appear when open
          if (animationValue > 0.3)
            Opacity(
              opacity: ((animationValue - 0.3) / 0.7).clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: 0.785 * animationValue,
                child: Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          if (animationValue > 0.3)
            Opacity(
              opacity: ((animationValue - 0.3) / 0.7).clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: -0.785 * animationValue,
                child: Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimatedDot extends StatelessWidget {
  final double animation;
  final Offset startOffset;
  final Offset endOffset;
  final bool rotateToLine;
  final double lineAngle;
  final bool fadeOut;

  const _AnimatedDot({
    required this.animation,
    required this.startOffset,
    required this.endOffset,
    this.rotateToLine = false,
    this.lineAngle = 0,
    this.fadeOut = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentOffset = Offset.lerp(startOffset, endOffset, animation)!;
    final opacity = fadeOut ? (1 - animation).clamp(0.0, 1.0) : (1 - animation * 0.7).clamp(0.0, 1.0);

    return Transform.translate(
      offset: currentOffset,
      child: Transform.rotate(
        angle: rotateToLine ? lineAngle * animation : 0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: opacity,
          child: Container(
            width: rotateToLine ? 6 + (animation * 8) : 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
