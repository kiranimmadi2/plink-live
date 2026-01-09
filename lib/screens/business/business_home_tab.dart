import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/business_model.dart';
import '../../models/business_dashboard_config.dart';
import '../../config/dynamic_business_ui_config.dart' as dynamic_config;
import '../../services/business_service.dart';
import 'business_analytics_screen.dart';
import 'business_inquiries_screen.dart';
import 'gallery_screen.dart';

/// Redesigned business home tab with clean, professional UI
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
            backgroundColor: newStatus ? const Color(0xFF00D67D) : Colors.grey[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        // Premium black gradient background
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D0D0D),
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                  Color(0xFF0F0F0F),
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),
        // Subtle premium overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.5,
                colors: [
                  const Color(0xFF00D67D).withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Main content
        SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadDashboardData();
              widget.onRefresh();
            },
            color: const Color(0xFF00D67D),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header with toggle and notification
                SliverToBoxAdapter(child: _buildHeader()),

                // Content
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Key Metrics Row
                      _buildMetricsSection(),
                      const SizedBox(height: 20),

                      // Quick Actions
                      _buildQuickActionsSection(),
                      const SizedBox(height: 20),

                      // Revenue Overview
                      _buildRevenueCard(),
                      const SizedBox(height: 20),

                      // Recent Activity
                      _buildActivitySection(),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Business Logo
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF00D67D),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D67D).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: widget.business.logo != null
                    ? Image.network(
                        widget.business.logo!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildLogoPlaceholder(),
                      )
                    : _buildLogoPlaceholder(),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Business Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.business.businessName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        _getLocationText(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Online Status Toggle (compact)
          GestureDetector(
            onTap: _toggleOnlineStatus,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isOnline
                    ? const Color(0xFF00D67D).withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isOnline
                      ? const Color(0xFF00D67D).withValues(alpha: 0.5)
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isOnline ? const Color(0xFF00D67D) : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _isOnline ? Icons.toggle_on : Icons.toggle_off,
                    size: 20,
                    color: _isOnline ? const Color(0xFF00D67D) : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Notification Bell
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              if (_dashboardData.pendingOrders > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF5350),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _dashboardData.pendingOrders > 9 ? '9+' : '${_dashboardData.pendingOrders}',
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
        ],
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Center(
      child: Text(
        widget.business.businessName.isNotEmpty
            ? widget.business.businessName[0].toUpperCase()
            : 'B',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  String _getLocationText() {
    final address = widget.business.address;
    if (address == null) return 'Location not set';
    final parts = <String>[];
    if (address.city != null && address.city!.isNotEmpty) parts.add(address.city!);
    if (address.state != null && address.state!.isNotEmpty) parts.add(address.state!);
    return parts.isNotEmpty ? parts.join(', ') : 'Location not set';
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2D2D44).withValues(alpha: 0.9),
            const Color(0xFF1A1A2E).withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Online Status Toggle
          GestureDetector(
            onTap: _toggleOnlineStatus,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _isOnline
                    ? const Color(0xFF00D67D).withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isOnline
                      ? const Color(0xFF00D67D).withValues(alpha: 0.5)
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
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
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isOnline ? const Color(0xFF00D67D) : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isOnline ? Icons.toggle_on : Icons.toggle_off,
                    size: 24,
                    color: _isOnline ? const Color(0xFF00D67D) : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          // Notification Bell
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              if (_dashboardData.pendingOrders > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF5350),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _dashboardData.pendingOrders > 9 ? '9+' : '${_dashboardData.pendingOrders}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning!';
    if (hour < 17) return 'Good afternoon!';
    return 'Good evening!';
  }

  Widget _buildMetricsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Overview',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.shopping_bag_outlined,
                value: '${_dashboardData.todayOrders}',
                label: 'Orders',
                color: const Color(0xFF00D67D),
                onTap: () => _navigateToInquiries(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.currency_rupee,
                value: _formatCompactAmount(_dashboardData.todayRevenue),
                label: 'Revenue',
                color: const Color(0xFF42A5F5),
                onTap: () => _navigateToAnalytics(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.pending_actions_outlined,
                value: '${_dashboardData.pendingOrders}',
                label: 'Pending',
                color: const Color(0xFFFFA726),
                onTap: () => _navigateToInquiries(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    final actions = _getQuickActions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: actions.map((action) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: action != actions.last ? 10 : 0,
                ),
                child: _buildQuickActionButton(
                  icon: action['icon'] as IconData,
                  label: action['label'] as String,
                  color: action['color'] as Color,
                  onTap: action['onTap'] as VoidCallback,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getQuickActions() {
    // Get dynamic configuration based on business category
    if (widget.business.category == null) {
      return _getDefaultQuickActions();
    }

    final config = dynamic_config.DynamicUIConfig.getConfigForCategory(widget.business.category!);
    final quickActions = config.quickActions.take(3).toList(); // Show max 3 actions

    return quickActions.map((action) {
      return {
        'icon': action.icon,
        'label': action.label,
        'color': _getColorForAction(action),
        'onTap': () => _handleQuickAction(action),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getDefaultQuickActions() {
    return [
      {
        'icon': Icons.add_circle_outline,
        'label': 'Add Item',
        'color': const Color(0xFF00D67D),
        'onTap': () => widget.onSwitchTab(1),
      },
      {
        'icon': Icons.receipt_long_outlined,
        'label': 'Orders',
        'color': const Color(0xFF42A5F5),
        'onTap': () => _navigateToInquiries(),
      },
      {
        'icon': Icons.analytics_outlined,
        'label': 'Analytics',
        'color': const Color(0xFF7E57C2),
        'onTap': () => _navigateToAnalytics(),
      },
    ];
  }

  Color _getColorForAction(dynamic_config.QuickAction action) {
    switch (action) {
      case dynamic_config.QuickAction.addMenuItem:
      case dynamic_config.QuickAction.addProduct:
      case dynamic_config.QuickAction.addService:
      case dynamic_config.QuickAction.addRoom:
      case dynamic_config.QuickAction.addProperty:
      case dynamic_config.QuickAction.addVehicle:
      case dynamic_config.QuickAction.addCourse:
      case dynamic_config.QuickAction.addMembership:
      case dynamic_config.QuickAction.addPackage:
      case dynamic_config.QuickAction.addPortfolioItem:
        return const Color(0xFF00D67D);
      case dynamic_config.QuickAction.manageOrders:
      case dynamic_config.QuickAction.manageBookings:
      case dynamic_config.QuickAction.manageAppointments:
      case dynamic_config.QuickAction.manageClasses:
      case dynamic_config.QuickAction.manageInventory:
      case dynamic_config.QuickAction.manageInquiries:
        return const Color(0xFF42A5F5);
      case dynamic_config.QuickAction.createPost:
        return const Color(0xFFFF6B6B);
      case dynamic_config.QuickAction.viewAnalytics:
        return const Color(0xFF7E57C2);
    }
  }

  void _handleQuickAction(dynamic_config.QuickAction action) {
    HapticFeedback.lightImpact();

    switch (action) {
      // Add actions - switch to appropriate tab
      case dynamic_config.QuickAction.addMenuItem:
      case dynamic_config.QuickAction.addProduct:
      case dynamic_config.QuickAction.addService:
      case dynamic_config.QuickAction.addRoom:
      case dynamic_config.QuickAction.addProperty:
      case dynamic_config.QuickAction.addVehicle:
      case dynamic_config.QuickAction.addCourse:
      case dynamic_config.QuickAction.addMembership:
      case dynamic_config.QuickAction.addPackage:
      case dynamic_config.QuickAction.addPortfolioItem:
        widget.onSwitchTab(1); // Switch to items/services tab
        break;

      // Manage actions
      case dynamic_config.QuickAction.manageOrders:
      case dynamic_config.QuickAction.manageBookings:
      case dynamic_config.QuickAction.manageAppointments:
        _navigateToInquiries();
        break;

      case dynamic_config.QuickAction.manageClasses:
      case dynamic_config.QuickAction.manageInventory:
      case dynamic_config.QuickAction.manageInquiries:
        _navigateToInquiries();
        break;

      case dynamic_config.QuickAction.createPost:
        // Navigate to post creation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post creation coming soon')),
        );
        break;

      case dynamic_config.QuickAction.viewAnalytics:
        _navigateToAnalytics();
        break;
    }
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCard() {
    final weekRevenue = _dashboardData.weekRevenue;
    final monthRevenue = _dashboardData.monthRevenue;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _navigateToAnalytics();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF00D67D).withValues(alpha: 0.15),
              const Color(0xFF00D67D).withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF00D67D).withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Revenue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D67D).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF00D67D).withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: const Color(0xFF00D67D).withValues(alpha: 0.9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This Week',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${_formatAmount(weekRevenue)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This Month',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${_formatAmount(monthRevenue)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _navigateToInquiries();
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
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('businesses')
              .doc(widget.business.id)
              .collection('activity')
              .orderBy('timestamp', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snapshot) {
            final activities = snapshot.hasData && snapshot.data!.docs.isNotEmpty
                ? snapshot.data!.docs
                : null;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: activities == null
                  ? _buildEmptyActivity()
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: activities.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 60,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      itemBuilder: (context, index) {
                        final activity = activities[index].data() as Map<String, dynamic>;
                        return _buildActivityItem(
                          icon: _getActivityIcon(activity['type'] ?? ''),
                          color: _getActivityColor(activity['type'] ?? ''),
                          title: activity['title'] ?? 'Activity',
                          subtitle: activity['subtitle'] ?? '',
                          time: _formatActivityTime(activity['timestamp']),
                        );
                      },
                    ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyActivity() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 40,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No recent activity',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          Text(
            'Your business activities will appear here',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
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
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToInquiries() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessInquiriesScreen(
          business: widget.business,
          initialFilter: 'All',
        ),
      ),
    );
  }

  void _navigateToAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessAnalyticsScreen(business: widget.business),
      ),
    );
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
        return Icons.info_outline;
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

  String _formatCompactAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(0)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }
}
