import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/business_model.dart';
import '../../models/business_dashboard_config.dart';
import '../../services/business_service.dart';
import '../../res/config/app_assets.dart';
import '../../res/config/app_colors.dart';
import 'business_analytics_screen.dart';
import 'business_inquiries_screen.dart';
import 'gallery_screen.dart';

/// Category-aware home tab showing dynamic dashboard based on business type
class BusinessHomeTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onRefresh;
  final Function(int) onSwitchTab;

  const BusinessHomeTab({
    super.key,
    required this.business,
    required this.onRefresh,
    required this.onSwitchTab,
  });

  @override
  State<BusinessHomeTab> createState() => _BusinessHomeTabState();
}

class _BusinessHomeTabState extends State<BusinessHomeTab> {
  final BusinessService _businessService = BusinessService();
  bool _isOnline = false;
  late CategoryGroup _categoryGroup;
  DashboardData _dashboardData = const DashboardData();

  @override
  void initState() {
    super.initState();
    _isOnline = widget.business.isOnline;
    _categoryGroup = getCategoryGroup(widget.business.category);
    _loadDashboardData();
  }

  @override
  void didUpdateWidget(BusinessHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.business.isOnline != widget.business.isOnline) {
      _isOnline = widget.business.isOnline;
    }
    if (oldWidget.business.category != widget.business.category) {
      _categoryGroup = getCategoryGroup(widget.business.category);
    }
  }

  Future<void> _loadDashboardData() async {
    // Load dashboard data from business model for now
    // In production, this would fetch real-time data from Firestore
    setState(() {
      _dashboardData = DashboardData(
        totalOrders: widget.business.totalOrders,
        pendingOrders: widget.business.pendingOrders,
        completedOrders: widget.business.completedOrders,
        todayOrders: widget.business.todayOrders,
        todayRevenue: widget.business.todayEarnings,
        weekRevenue: widget.business.monthlyEarnings,
        monthRevenue: widget.business.totalEarnings,
      );
    });
  }

  Future<void> _toggleOnlineStatus() async {
    HapticFeedback.lightImpact();
    final newStatus = !_isOnline;
    setState(() => _isOnline = newStatus);

    try {
      await _businessService.updateOnlineStatus(widget.business.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'You are now online' : 'You are now offline'),
            backgroundColor: newStatus ? Colors.green : Colors.grey[700],
          ),
        );
      }
    } catch (e) {
      setState(() => _isOnline = !newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Image
        Positioned.fill(
          child: Image.asset(
            AppAssets.homeBackgroundImage,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),

        // Dark overlay
        Positioned.fill(
          child: Container(color: AppColors.darkOverlay()),
        ),

        // Main content
        SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Divider
              Container(
                height: 0.5,
                color: Colors.white.withValues(alpha: 0.2),
              ),

              // Scrollable content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _loadDashboardData();
                    widget.onRefresh();
                  },
                  color: const Color(0xFF00D67D),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Today's Snapshot - Category-aware stats
                      _buildSectionTitle(
                        BusinessDashboardConfig.getStatsTitle(_categoryGroup),
                      ),
                      const SizedBox(height: 12),
                      _buildStatsGrid(),
                      const SizedBox(height: 24),

                      // Quick Actions - Category-specific
                      _buildSectionTitle('Quick Actions'),
                      const SizedBox(height: 12),
                      _buildQuickActions(),
                      const SizedBox(height: 24),

                      // Recent Activity
                      _buildSectionTitle('Recent Activity', showSeeAll: true),
                      const SizedBox(height: 12),
                      _buildRecentActivity(),
                      const SizedBox(height: 24),

                      // Performance Card
                      _buildPerformanceCard(),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Business logo
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GalleryScreen(business: widget.business),
                ),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: widget.business.logo != null
                    ? Image.network(
                        widget.business.logo!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildLogoPlaceholder(),
                      )
                    : _buildLogoPlaceholder(),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Business name and location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.business.businessName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 12,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        _getLocationText(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Online/Offline toggle
          _buildOnlineToggle(),

          const SizedBox(width: 8),

          // Notification button
          _buildNotificationButton(),
        ],
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF00D67D),
      ),
      child: Center(
        child: Text(
          widget.business.businessName.isNotEmpty
              ? widget.business.businessName[0].toUpperCase()
              : 'B',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String _getLocationText() {
    final address = widget.business.address;
    if (address == null) return 'Location not set';

    final parts = <String>[];
    if (address.city != null && address.city!.isNotEmpty) {
      parts.add(address.city!);
    }
    if (address.state != null && address.state!.isNotEmpty) {
      parts.add(address.state!);
    }
    return parts.isNotEmpty ? parts.join(', ') : 'Location not set';
  }

  Widget _buildOnlineToggle() {
    return GestureDetector(
      onTap: _toggleOnlineStatus,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status dot with glow
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isOnline ? const Color(0xFF00D67D) : Colors.grey,
              boxShadow: _isOnline
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00D67D).withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _isOnline ? const Color(0xFF00D67D) : Colors.white70,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            _isOnline ? Icons.toggle_on : Icons.toggle_off,
            size: 40,
            color: _isOnline ? const Color(0xFF00D67D) : Colors.white54,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationButton() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            // TODO: Navigate to notifications
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        // Notification badge
        Positioned(
          right: 4,
          top: 4,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFEF5350),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, {bool showSeeAll = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        if (showSeeAll)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              // TODO: Navigate to activity history
            },
            child: Text(
              'See All',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF00D67D).withValues(alpha: 0.9),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final stats = BusinessDashboardConfig.getStats(_categoryGroup);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: stats.map((stat) {
        return _buildStatCard(
          label: stat.label,
          value: stat.getValue(_dashboardData),
          icon: stat.icon,
          color: stat.color,
          onTap: () => _handleStatTap(stat.route),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
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

  Widget _buildQuickActions() {
    final actions = BusinessDashboardConfig.getQuickActions(_categoryGroup);

    return SizedBox(
      height: 105,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final action = actions[index];
          return _buildQuickActionItem(
            label: action.label,
            subtitle: action.subtitle,
            icon: action.icon,
            color: action.color,
            onTap: () => _handleQuickAction(action.route),
          );
        },
      ),
    );
  }

  Widget _buildQuickActionItem({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 130,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildRecentActivity() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.business.id)
          .collection('activity')
          .orderBy('timestamp', descending: true)
          .limit(4)
          .snapshots(),
      builder: (context, snapshot) {
        // Show sample data if no activity yet
        final activities = snapshot.hasData && snapshot.data!.docs.isNotEmpty
            ? snapshot.data!.docs
            : null;

        if (activities == null) {
          return _buildSampleActivityList();
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activities.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                itemBuilder: (context, activityIndex) {
                  final activity = activities[activityIndex].data() as Map<String, dynamic>;
                  return _buildActivityItem(
                    icon: _getActivityIcon(activity['type'] ?? ''),
                    color: _getActivityColor(activity['type'] ?? ''),
                    title: activity['title'] ?? 'Activity',
                    subtitle: activity['subtitle'] ?? '',
                    time: _formatActivityTime(activity['timestamp']),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSampleActivityList() {
    final sampleActivities = [
      {
        'icon': Icons.circle,
        'color': const Color(0xFF00D67D),
        'title': 'Business is online',
        'subtitle': 'Ready to receive orders',
        'time': 'Just now',
      },
      {
        'icon': Icons.storefront_outlined,
        'color': const Color(0xFF42A5F5),
        'title': 'Profile updated',
        'subtitle': 'Business details saved',
        'time': '2h ago',
      },
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sampleActivities.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            itemBuilder: (context, sampleIndex) {
              final activity = sampleActivities[sampleIndex];
              return _buildActivityItem(
                icon: activity['icon'] as IconData,
                color: activity['color'] as Color,
                title: activity['title'] as String,
                subtitle: activity['subtitle'] as String,
                time: activity['time'] as String,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard() {
    final weekRevenue = _dashboardData.weekRevenue;
    final previousWeek = weekRevenue * 0.85; // Mock previous week
    final percentChange = previousWeek > 0
        ? ((weekRevenue - previousWeek) / previousWeek * 100).round()
        : 0;
    final isPositive = percentChange >= 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BusinessAnalyticsScreen(business: widget.business),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00D67D).withValues(alpha: 0.2),
                  const Color(0xFF42A5F5).withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D67D).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.trending_up,
                        color: Color(0xFF00D67D),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'This Week',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? const Color(0xFF00D67D).withValues(alpha: 0.2)
                            : const Color(0xFFEF5350).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 14,
                            color: isPositive ? const Color(0xFF00D67D) : const Color(0xFFEF5350),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$percentChange%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isPositive ? const Color(0xFF00D67D) : const Color(0xFFEF5350),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${_formatAmount(weekRevenue)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Revenue',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.75,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D67D)),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '75% of weekly goal',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'View Analytics',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF00D67D).withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: const Color(0xFF00D67D).withValues(alpha: 0.9),
                        ),
                      ],
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

  void _handleStatTap(String? route) {
    if (route == null) return;

    switch (route) {
      case 'orders':
      case 'inquiries':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BusinessInquiriesScreen(
              business: widget.business,
              initialFilter: 'All',
            ),
          ),
        );
        break;
      case 'analytics':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BusinessAnalyticsScreen(business: widget.business),
          ),
        );
        break;
      default:
        // Navigate to appropriate screen or switch tab
        break;
    }
  }

  void _handleQuickAction(String route) {
    switch (route) {
      case 'orders':
      case 'appointments':
      case 'bookings':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BusinessInquiriesScreen(
              business: widget.business,
              initialFilter: 'All',
            ),
          ),
        );
        break;
      case 'menu':
      case 'products':
      case 'services':
      case 'rooms':
        widget.onSwitchTab(1); // Switch to services/products tab
        break;
      default:
        // Handle other routes
        break;
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag_outlined;
      case 'message':
        return Icons.chat_bubble_outline;
      case 'review':
        return Icons.star_outline;
      case 'booking':
        return Icons.calendar_today_outlined;
      default:
        return Icons.circle;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'order':
        return const Color(0xFF00D67D);
      case 'message':
        return const Color(0xFF42A5F5);
      case 'review':
        return const Color(0xFFFFA726);
      case 'booking':
        return const Color(0xFF7E57C2);
      default:
        return const Color(0xFF00D67D);
    }
  }

  String _formatActivityTime(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      return timeago.format(timestamp.toDate(), locale: 'en_short');
    }
    return '';
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
