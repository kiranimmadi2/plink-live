import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/business_model.dart';
import '../../services/business_service.dart';
import '../../widgets/business/glassmorphic_card.dart';
import 'business_analytics_screen.dart';
import 'business_inquiries_screen.dart';

/// Home tab showing dashboard with stats, online toggle, and quick actions
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

  @override
  void initState() {
    super.initState();
    _isOnline = widget.business.isOnline;
  }

  @override
  void didUpdateWidget(BusinessHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.business.isOnline != widget.business.isOnline) {
      _isOnline = widget.business.isOnline;
    }
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      color: const Color(0xFF00D67D),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(isDarkMode),
            ),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: isDarkMode ? Colors.white : Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () {
                  // TODO: Show notifications
                },
              ),
            ],
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Online Status Toggle
                _buildOnlineToggle(isDarkMode),
                const SizedBox(height: 20),

                // Stats Grid
                _buildSectionTitle('Overview', isDarkMode),
                const SizedBox(height: 12),
                _buildStatsGrid(isDarkMode),
                const SizedBox(height: 24),

                // Quick Actions
                _buildSectionTitle('Quick Actions', isDarkMode),
                const SizedBox(height: 12),
                _buildQuickActions(isDarkMode),
                const SizedBox(height: 24),

                // Analytics Preview
                _buildAnalyticsPreview(isDarkMode),
                const SizedBox(height: 24),

                // Recent Inquiries Preview
                _buildSectionTitle('Recent Inquiries', isDarkMode),
                const SizedBox(height: 12),
                _buildRecentInquiriesPreview(isDarkMode),

                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background gradient with mesh effect
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF00E88A),
                Color(0xFF00D67D),
                Color(0xFF00B86B),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // Decorative circles for depth
        Positioned(
          top: -40,
          right: -40,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ),
        Positioned(
          top: 30,
          right: 60,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: -30,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ),

        // Subtle pattern overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.15),
              ],
            ),
          ),
        ),

        // Business Info
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Logo with glow effect
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.5),
                            Colors.white.withValues(alpha: 0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: const Color(0xFF00D67D).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: -5,
                          ),
                        ],
                      ),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.business.businessName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.business.isVerified) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.verified,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Business type badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  BusinessTypes.getIcon(widget.business.businessType),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.business.businessType,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.business.tagline != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              widget.business.tagline!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.9),
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00D67D).withValues(alpha: 0.1),
            const Color(0xFF00E88A).withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Center(
        child: Text(
          widget.business.businessName.isNotEmpty
              ? widget.business.businessName[0].toUpperCase()
              : 'B',
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00D67D),
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineToggle(bool isDarkMode) {
    final statusColor = _isOnline ? const Color(0xFF00D67D) : Colors.grey;

    return GestureDetector(
      onTap: _toggleOnlineStatus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isOnline
                ? [
                    const Color(0xFF00D67D).withValues(alpha: 0.15),
                    const Color(0xFF00E88A).withValues(alpha: 0.08),
                  ]
                : isDarkMode
                    ? [
                        const Color(0xFF2D2D44).withValues(alpha: 0.8),
                        const Color(0xFF1A1A2E).withValues(alpha: 0.6),
                      ]
                    : [
                        Colors.grey.withValues(alpha: 0.1),
                        Colors.grey.withValues(alpha: 0.05),
                      ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isOnline
                ? const Color(0xFF00D67D).withValues(alpha: 0.4)
                : isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            if (_isOnline)
              BoxShadow(
                color: const Color(0xFF00D67D).withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: -5,
                offset: const Offset(0, 4),
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Animated status indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isOnline
                      ? [
                          const Color(0xFF00D67D),
                          const Color(0xFF00B86B),
                        ]
                      : [
                          Colors.grey[600]!,
                          Colors.grey[700]!,
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse effect for online
                  if (_isOnline)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  Icon(
                    _isOnline ? Icons.storefront : Icons.storefront_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Animated dot indicator
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                          boxShadow: _isOnline
                              ? [
                                  BoxShadow(
                                    color: statusColor.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isOnline
                              ? const Color(0xFF00D67D)
                              : (isDarkMode ? Colors.white70 : Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isOnline
                        ? 'Customers can discover your business'
                        : 'Tap to go online and get discovered',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Custom toggle
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 60,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: _isOnline
                      ? [const Color(0xFF00D67D), const Color(0xFF00B86B)]
                      : [Colors.grey[400]!, Colors.grey[500]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isOnline ? const Color(0xFF00D67D) : Colors.grey).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    left: _isOnline ? 30 : 4,
                    top: 4,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isOnline ? Icons.check : Icons.close,
                        size: 14,
                        color: _isOnline ? const Color(0xFF00D67D) : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildStatsGrid(bool isDarkMode) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: [
        GlassmorphicStatCard(
          title: 'Total Inquiries',
          value: '${widget.business.totalOrders}',
          icon: Icons.inbox_outlined,
          accentColor: const Color(0xFF00D67D),
          onTap: () => _navigateToInquiries('All'),
        ),
        GlassmorphicStatCard(
          title: 'New',
          value: '${widget.business.pendingOrders}',
          icon: Icons.mark_email_unread_outlined,
          accentColor: Colors.orange,
          onTap: () => _navigateToInquiries('New'),
        ),
        GlassmorphicStatCard(
          title: 'Responded',
          value: '${widget.business.completedOrders}',
          icon: Icons.check_circle_outline,
          accentColor: Colors.blue,
          onTap: () => _navigateToInquiries('Responded'),
        ),
        GlassmorphicStatCard(
          title: 'Today',
          value: '${widget.business.todayOrders}',
          icon: Icons.today,
          accentColor: Colors.purple,
          onTap: () => _navigateToInquiries('Today'),
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: GlassmorphicButton(
            icon: Icons.add_box_outlined,
            label: 'Add Service',
            color: const Color(0xFF00D67D),
            expanded: true,
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onSwitchTab(1);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassmorphicButton(
            icon: Icons.post_add,
            label: 'Create Post',
            color: Colors.blue,
            expanded: true,
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onSwitchTab(2);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsPreview(bool isDarkMode) {
    return GlassmorphicCard(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BusinessAnalyticsScreen(business: widget.business),
          ),
        );
      },
      showGlow: true,
      glowColor: const Color(0xFF00D67D),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00D67D).withValues(alpha: 0.3),
                  Colors.blue.withValues(alpha: 0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF00D67D).withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Color(0xFF00D67D),
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'View Analytics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'See insights about your business',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00D67D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: isDarkMode ? Colors.white54 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentInquiriesPreview(bool isDarkMode) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (widget.business.totalOrders == 0)
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.inbox_outlined,
                    size: 40,
                    color: isDarkMode ? Colors.white24 : Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No inquiries yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Customer inquiries will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.white38 : Colors.grey[500],
                  ),
                ),
              ],
            )
          else
            GlassmorphicButton(
              icon: Icons.arrow_forward,
              label: 'View All Inquiries',
              onTap: () => _navigateToInquiries('All'),
            ),
        ],
      ),
    );
  }

  void _navigateToInquiries(String filter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessInquiriesScreen(
          business: widget.business,
          initialFilter: filter,
        ),
      ),
    );
  }
}
