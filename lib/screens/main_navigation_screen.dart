import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// screens
import 'home/home_screen.dart';
import 'conversations_screen.dart';
import 'live_connect_tab_screen.dart';
import 'profile/profile_with_history_screen.dart';

// services
import '../services/location_service.dart';
import '../services/notification_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _fabMenuOpen = false;
  int _unreadMessageCount = 0;

  Offset _fabPosition = const Offset(0, 0);
  bool _isDragging = false;
  bool _initialPosSet = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _location = LocationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _listenUnread();
    _updateStatus(true);
    _checkLocation();
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

    _firestore.collection("users").doc(uid).update({
      "isOnline": online,
      "lastSeen": FieldValue.serverTimestamp(),
    });
  }

  void _listenUnread() {
    final user = _auth.currentUser;
    if (user == null) return;

    _firestore
        .collection("conversations")
        .where("participants", arrayContains: user.uid)
        .snapshots()
        .listen((snap) {
          int total = 0;
          for (var doc in snap.docs) {
            total += ((doc["unreadCount"]?[user.uid] ?? 0) as num).toInt();
          }
          setState(() => _unreadMessageCount = total);
          NotificationService().updateBadgeCount(total);
        });
  }

  void _navigate(int index) {
    setState(() {
      _currentIndex = index;
      _fabMenuOpen = false;
    });
  }

  void _onDragStart(DragStartDetails d) => setState(() => _isDragging = true);
  void _onDragUpdate(DragUpdateDetails d) =>
      setState(() => _fabPosition += d.delta);
  void _onDragEnd(DragEndDetails d) => setState(() => _isDragging = false);

  void _resetFAB() {
    final size = MediaQuery.of(context).size;
    setState(() {
      _fabPosition = Offset(size.width - 80, size.height / 2 - 32);
    });
  }

  // Menu items
  List<Map<String, dynamic>> menuItems = [
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
  List<Widget> _buildMenu() {
    const double buttonSize = 52; // menu item size
    const double spacing = 10; // distance between buttons
    final int itemCount = menuItems.length;

    List<Widget> widgets = [];
    final size = MediaQuery.of(context).size;

    // Determine quadrant / direction
    bool isLeft = _fabPosition.dx < size.width / 2;
    bool isTop = _fabPosition.dy < size.height / 2;

    // Define start and end angle of arc (degrees)
    double startAngle, endAngle;
    if (isLeft && isTop) {
      startAngle = 0;
      endAngle = 90;
    } else if (!isLeft && isTop) {
      startAngle = 90;
      endAngle = 180;
    } else if (isLeft && !isTop) {
      startAngle = -90;
      endAngle = 0;
    } else {
      startAngle = 180;
      endAngle = 270;
    }

    // Total arc in radians
    double arc = (endAngle - startAngle) * math.pi / 180;

    // Calculate radius so that buttons have spacing
    // Arc length = radius * angle → radius = arc length / angle
    double arcLength = (buttonSize + spacing) * (itemCount - 1);
    double radius = arcLength / arc;

    for (int i = 0; i < itemCount; i++) {
      double angleRad =
          (startAngle + i * (endAngle - startAngle) / (itemCount - 1)) *
          math.pi /
          180;
      final offset = Offset(
        math.cos(angleRad) * radius,
        math.sin(angleRad) * radius,
      );

      widgets.add(
        Positioned(
          left: (_fabPosition.dx + offset.dx - buttonSize / 2).clamp(
            0,
            size.width - buttonSize,
          ),
          top: (_fabPosition.dy + offset.dy - buttonSize / 2).clamp(
            0,
            size.height - buttonSize,
          ),
          child: _FloatingMenuItem(
            item: menuItems[i],
            unread: _unreadMessageCount,
            onTap: () => _navigate(menuItems[i]["index"]),
          ),
        ),
      );
    }

    return widgets;
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
          if (_fabMenuOpen) ..._buildMenu(),
          Positioned(
            left: _fabPosition.dx.clamp(0, size.width - 80),
            top: _fabPosition.dy.clamp(0, size.height - 80),
            child: _FloatingFAB(
              unread: _unreadMessageCount,
              dragging: _isDragging,
              isOpen: _fabMenuOpen,
              onToggle: () => setState(() => _fabMenuOpen = !_fabMenuOpen),
              onDragStart: _onDragStart,
              onDragUpdate: _onDragUpdate,
              onDragEnd: _onDragEnd,
              onReset: _resetFAB,
            ),
          ),
        ],
      ),
    );
  }
}

//////////////////////////////////////////////////////////////////////
// Main FAB
//////////////////////////////////////////////////////////////////////

class _FloatingFAB extends StatelessWidget {
  final bool isOpen;
  final bool dragging;
  final int unread;

  final Function(DragStartDetails) onDragStart;
  final Function(DragUpdateDetails) onDragUpdate;
  final Function(DragEndDetails) onDragEnd;

  final VoidCallback onToggle;
  final VoidCallback onReset;

  const _FloatingFAB({
    required this.isOpen,
    required this.dragging,
    required this.unread,
    required this.onToggle,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: onDragStart,
      onPanUpdate: onDragUpdate,
      onPanEnd: onDragEnd,
      onLongPress: onReset,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(32),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.shade800, // grey background
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2), // white border
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: dragging ? 14 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    isOpen ? Icons.close : Icons.menu,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unread > 99 ? "99+" : unread.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
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

//////////////////////////////////////////////////////////////////////
// Menu item (circular icons only)
//////////////////////////////////////////////////////////////////////

class _FloatingMenuItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final int unread;
  final VoidCallback onTap;

  const _FloatingMenuItem({
    required this.item,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade800, // grey background
          border: Border.all(color: Colors.white, width: 2), // white border
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(child: Icon(item["icon"], size: 26, color: item["color"])),
            if (item["index"] == 1 && unread > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                  child: Text(
                    unread > 99 ? "99+" : unread.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
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
