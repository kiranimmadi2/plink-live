import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../services/connection_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/chat_common.dart';
import '../models/user_profile.dart';
import '../providers/app_providers.dart';
import 'enhanced_chat_screen.dart';

class MyConnectionsScreen extends ConsumerStatefulWidget {
  const MyConnectionsScreen({super.key});

  @override
  ConsumerState<MyConnectionsScreen> createState() => _MyConnectionsScreenState();
}

class _MyConnectionsScreenState extends ConsumerState<MyConnectionsScreen>
    with SingleTickerProviderStateMixin {
  final ConnectionService _connectionService = ConnectionService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  // For refresh
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  String? get _currentUserId => ref.read(currentUserIdProvider);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        title: const Text(
          'Connections',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF0f0f23),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildTabBar(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestsTab(),
          _buildConnectionsTab(),
          _buildSentRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9C27B0), Color(0xFF673AB7)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[500],
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Requests'),
                const SizedBox(width: 6),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _connectionService.getPendingRequestsStream(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Connected'),
                const SizedBox(width: 6),
                StreamBuilder<DocumentSnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(_currentUserId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final count = (snapshot.data?.data() as Map<String, dynamic>?)?['connectionCount'] ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D67D),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Sent'),
                const SizedBox(width: 6),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _connectionService.getSentRequestsStream(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== REQUESTS TAB ====================
  Widget _buildRequestsTab() {
    return RefreshIndicator(
      key: _refreshKey,
      onRefresh: _refreshData,
      color: const Color(0xFF9C27B0),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _connectionService.getPendingRequestsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState('Failed to load requests');
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return _buildEmptyState(
              icon: Icons.mark_email_read_outlined,
              title: 'No Pending Requests',
              subtitle: 'When someone sends you a connection request, it will appear here',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              return _buildRequestCard(requests[index]);
            },
          );
        },
      ),
    );
  }

  // ==================== CONNECTIONS TAB ====================
  Widget _buildConnectionsTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF00D67D),
      child: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(_currentUserId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState('Failed to load connections');
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final connectionIds = List<String>.from(userData?['connections'] ?? []);

          if (connectionIds.isEmpty) {
            return _buildEmptyState(
              icon: Icons.people_outline,
              title: 'No Connections Yet',
              subtitle: 'Start connecting with people on Live Connect!',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: connectionIds.length,
            itemBuilder: (context, index) {
              return _buildConnectionCardStream(connectionIds[index]);
            },
          );
        },
      ),
    );
  }

  // ==================== SENT REQUESTS TAB ====================
  Widget _buildSentRequestsTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.orange,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _connectionService.getSentRequestsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState('Failed to load sent requests');
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return _buildEmptyState(
              icon: Icons.send_outlined,
              title: 'No Sent Requests',
              subtitle: 'Requests you send will appear here until they\'re accepted',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              return _buildSentRequestCard(requests[index]);
            },
          );
        },
      ),
    );
  }

  // ==================== CARD WIDGETS ====================

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final requestId = request['id'] as String?;
    final senderId = request['senderId'] as String?;
    final senderName = request['senderName'] as String? ?? 'Unknown User';
    final senderPhoto = request['senderPhoto'] as String?;
    final message = request['message'] as String?;
    final createdAt = request['createdAt'];

    if (requestId == null || senderId == null) return const SizedBox.shrink();

    String timeAgo = _formatTimeAgo(createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1a1a2e),
            const Color(0xFF16213e).withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF9C27B0).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar with glow
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9C27B0).withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: GestureDetector(
                        onTap: () => _viewProfile(senderId),
                        child: UserAvatar(
                          profileImageUrl: senderPhoto,
                          fallbackText: senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                          radius: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _viewProfile(senderId),
                                  child: Text(
                                    formatDisplayName(senderName),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              if (timeAgo.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    timeAgo,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message ?? 'Wants to connect with you',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Action buttons - Modern style
                Row(
                  children: [
                    Expanded(
                      child: _buildGradientButton(
                        text: 'Accept',
                        icon: Icons.check_rounded,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D67D), Color(0xFF00A86B)],
                        ),
                        onPressed: () => _acceptRequest(requestId, senderName),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildOutlineButton(
                        text: 'Decline',
                        icon: Icons.close_rounded,
                        onPressed: () => _rejectRequest(requestId),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCardStream(String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox.shrink();

        return _buildConnectionCard(userId, userData);
      },
    );
  }

  Widget _buildConnectionCard(String userId, Map<String, dynamic> userData) {
    final name = userData['name'] ?? 'Unknown User';
    final photoUrl = userData['photoUrl'] as String?;
    final isOnline = userData['isOnline'] ?? false;
    final lastSeen = userData['lastSeen'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1a1a2e),
            const Color(0xFF16213e).withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF00D67D).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D67D).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: InkWell(
            onTap: () => _viewProfile(userId),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar with online indicator
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isOnline ? const Color(0xFF00D67D) : Colors.grey)
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: UserAvatar(
                          profileImageUrl: photoUrl,
                          fallbackText: name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          radius: 28,
                        ),
                      ),
                      // Online indicator
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: isOnline ? const Color(0xFF00D67D) : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF1a1a2e),
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatDisplayName(name),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isOnline ? const Color(0xFF00D67D) : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOnline ? 'Online' : _formatLastSeen(lastSeen),
                              style: TextStyle(
                                fontSize: 13,
                                color: isOnline ? const Color(0xFF00D67D) : Colors.grey[500],
                                fontWeight: isOnline ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Action buttons - larger touch targets
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCircularButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        color: const Color(0xFF00D67D),
                        onPressed: () => _openChat(userId, userData),
                        tooltip: 'Message',
                      ),
                      const SizedBox(width: 8),
                      _buildCircularButton(
                        icon: Icons.person_remove_outlined,
                        color: Colors.red.shade400,
                        onPressed: () => _removeConnection(userId, name),
                        tooltip: 'Remove',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSentRequestCard(Map<String, dynamic> request) {
    final requestId = request['id'] as String?;
    final receiverId = request['receiverId'] as String?;
    final createdAt = request['createdAt'];

    if (requestId == null || receiverId == null) return const SizedBox.shrink();

    String timeAgo = _formatTimeAgo(createdAt);

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(receiverId).snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final name = userData?['name'] ?? 'Unknown User';
        final photoUrl = userData?['photoUrl'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1a1a2e),
                const Color(0xFF16213e).withValues(alpha: 0.8),
              ],
            ),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: GestureDetector(
                        onTap: () => _viewProfile(receiverId),
                        child: UserAvatar(
                          profileImageUrl: photoUrl,
                          fallbackText: name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          radius: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => _viewProfile(receiverId),
                            child: Text(
                              formatDisplayName(name),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: Colors.orange[300],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Pending • $timeAgo',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange[300],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildOutlineButton(
                      text: 'Cancel',
                      icon: Icons.close_rounded,
                      compact: true,
                      onPressed: () => _cancelRequest(requestId, name),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildGradientButton({
    required String text,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D67D).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlineButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    bool compact = false,
  }) {
    return Container(
      height: compact ? 40 : 48,
      padding: compact ? const EdgeInsets.symmetric(horizontal: 16) : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              children: [
                Icon(icon, size: 18, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(24),
            child: Center(
              child: Icon(icon, color: color, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) => _buildSkeletonCard(),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9C27B0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 50, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== HELPER METHODS ====================

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final time = timestamp.toDate();
      final difference = DateTime.now().difference(time);
      if (difference.inDays > 0) return '${difference.inDays}d ago';
      if (difference.inHours > 0) return '${difference.inHours}h ago';
      if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return '';
    }
  }

  String _formatLastSeen(dynamic timestamp) {
    if (timestamp == null) return 'Offline';
    try {
      final time = timestamp.toDate();
      final difference = DateTime.now().difference(time);
      if (difference.inDays > 0) return 'Last seen ${difference.inDays}d ago';
      if (difference.inHours > 0) return 'Last seen ${difference.inHours}h ago';
      if (difference.inMinutes > 0) return 'Last seen ${difference.inMinutes}m ago';
      return 'Last seen recently';
    } catch (e) {
      return 'Offline';
    }
  }

  // ==================== ACTIONS ====================

  void _viewProfile(String userId) {
    // Show profile bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildProfileBottomSheet(userId),
    );
  }

  Widget _buildProfileBottomSheet(String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final name = userData?['name'] ?? 'Loading...';
        final photoUrl = userData?['photoUrl'] as String?;
        final bio = userData?['bio'] as String?;
        final location = userData?['location'] as String?;
        final isOnline = userData?['isOnline'] ?? false;

        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Color(0xFF1a1a2e),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // Avatar
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9C27B0).withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: UserAvatar(
                      profileImageUrl: photoUrl,
                      fallbackText: name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      radius: 50,
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D67D),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1a1a2e), width: 3),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                formatDisplayName(name),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (location != null && location.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              ],
              if (bio != null && bio.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const Spacer(),
              // Actions
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildGradientButton(
                        text: 'Message',
                        icon: Icons.chat_bubble_outline_rounded,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D67D), Color(0xFF00A86B)],
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          if (userData != null) {
                            _openChat(userId, userData);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _acceptRequest(String requestId, String senderName) async {
    try {
      final result = await _connectionService.acceptConnectionRequest(requestId);

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('You and ${formatDisplayName(senderName)} are now connected!'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF00D67D),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        } else {
          throw Exception(result['message'] ?? 'Failed to accept request');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      final result = await _connectionService.rejectConnectionRequest(requestId);

      if (mounted && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check, color: Colors.white),
                SizedBox(width: 12),
                Text('Request declined'),
              ],
            ),
            backgroundColor: Colors.grey[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelRequest(String requestId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Request', style: TextStyle(color: Colors.white)),
        content: Text(
          'Cancel your connection request to $userName?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await _connectionService.cancelConnectionRequest(requestId);

      if (mounted && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check, color: Colors.white),
                SizedBox(width: 12),
                Text('Request cancelled'),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeConnection(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Connection', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove $userName from your connections?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await _connectionService.removeConnection(userId);

      if (mounted && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.person_remove, color: Colors.white),
                SizedBox(width: 12),
                Text('Connection removed'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openChat(String userId, Map<String, dynamic> userData) {
    try {
      if (userId.isEmpty) throw Exception('Invalid user ID');
      if (userData['name'] == null) throw Exception('User profile incomplete');

      final safeUserData = {
        'name': userData['name'] ?? 'Unknown User',
        'email': userData['email'] ?? '',
        'profileImageUrl': userData['profileImageUrl'] ?? userData['photoUrl'],
        'photoUrl': userData['photoUrl'] ?? userData['profileImageUrl'],
        'phone': userData['phone'],
        'location': userData['location'] ?? userData['city'],
        'latitude': userData['latitude'],
        'longitude': userData['longitude'],
        'createdAt': userData['createdAt'],
        'lastSeen': userData['lastSeen'],
        'isOnline': userData['isOnline'] ?? false,
        'isVerified': userData['isVerified'] ?? false,
        'showOnlineStatus': userData['showOnlineStatus'] ?? true,
        'bio': userData['bio'] ?? '',
        'interests': userData['interests'] ?? [],
        'fcmToken': userData['fcmToken'],
      };

      final userProfile = UserProfile.fromMap(safeUserData, userId);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedChatScreen(otherUser: userProfile),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
