import 'package:flutter/material.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import '../sections/hero_section.dart';
import '../sections/quick_actions_bar.dart';
import '../sections/rooms_section.dart';
import '../sections/gallery_section.dart';
import '../sections/reviews_section.dart';
import '../sections/location_section.dart';

/// Hotel/Hospitality template with gallery-focused layout
/// Features: Amenities, Rooms, Gallery, Reviews
class HotelTemplate extends StatefulWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const HotelTemplate({
    super.key,
    required this.business,
    required this.config,
  });

  @override
  State<HotelTemplate> createState() => _HotelTemplateState();
}

class _HotelTemplateState extends State<HotelTemplate>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Hero section
            HeroSection(
              business: widget.business,
              config: widget.config,
            ),

            // Quick action buttons (Book Room as primary)
            SliverToBoxAdapter(
              child: QuickActionsBar(
                business: widget.business,
                config: widget.config,
              ),
            ),

            // Amenities section
            SliverToBoxAdapter(
              child: _buildAmenities(isDarkMode),
            ),

            // Check-in/Check-out times
            SliverToBoxAdapter(
              child: _buildCheckInOut(isDarkMode),
            ),

            // Tab bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: widget.config.primaryColor,
                  unselectedLabelColor:
                      isDarkMode ? Colors.white54 : Colors.grey[600],
                  indicatorColor: widget.config.primaryColor,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Rooms'),
                    Tab(text: 'Gallery'),
                    Tab(text: 'Reviews'),
                  ],
                ),
                isDarkMode: isDarkMode,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Rooms tab
            _buildRoomsTab(isDarkMode),

            // Gallery tab
            _buildGalleryTab(isDarkMode),

            // Reviews tab
            _buildReviewsTab(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildAmenities(bool isDarkMode) {
    final data = widget.business.categoryData ?? {};
    final amenities = data['amenities'] as List<dynamic>?;

    if (amenities == null || amenities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.star,
                size: 20,
                color: widget.config.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Amenities',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: amenities.map((amenity) {
              return _AmenityItem(
                icon: _getAmenityIcon(amenity.toString()),
                label: amenity.toString(),
                isDarkMode: isDarkMode,
                color: widget.config.primaryColor,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _getAmenityIcon(String amenity) {
    final lower = amenity.toLowerCase();
    if (lower.contains('wifi')) return Icons.wifi;
    if (lower.contains('parking')) return Icons.local_parking;
    if (lower.contains('pool')) return Icons.pool;
    if (lower.contains('gym')) return Icons.fitness_center;
    if (lower.contains('restaurant')) return Icons.restaurant;
    if (lower.contains('room service')) return Icons.room_service;
    if (lower.contains('ac') || lower.contains('air')) return Icons.ac_unit;
    if (lower.contains('pet')) return Icons.pets;
    if (lower.contains('spa')) return Icons.spa;
    if (lower.contains('bar')) return Icons.local_bar;
    if (lower.contains('laundry')) return Icons.local_laundry_service;
    if (lower.contains('tv')) return Icons.tv;
    if (lower.contains('breakfast')) return Icons.free_breakfast;
    return Icons.check_circle;
  }

  Widget _buildCheckInOut(bool isDarkMode) {
    final data = widget.business.categoryData ?? {};
    final checkIn = data['checkInTime'] as String?;
    final checkOut = data['checkOutTime'] as String?;

    if (checkIn == null && checkOut == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _TimeCard(
              icon: Icons.login,
              label: 'Check-in',
              time: checkIn ?? '14:00',
              color: Colors.green,
              isDarkMode: isDarkMode,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: isDarkMode ? Colors.white10 : Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            child: _TimeCard(
              icon: Icons.logout,
              label: 'Check-out',
              time: checkOut ?? '11:00',
              color: Colors.orange,
              isDarkMode: isDarkMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsTab(bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          RoomsSection(
            businessId: widget.business.id,
            config: widget.config,
          ),
          const SizedBox(height: 16),
          LocationSection(
            business: widget.business,
            config: widget.config,
          ),
          ContactSection(
            business: widget.business,
            config: widget.config,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGalleryTab(bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        children: [
          GallerySection(
            business: widget.business,
            config: widget.config,
            maxImages: 100,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildReviewsTab(bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ReviewsSection(
            businessId: widget.business.id,
            config: widget.config,
            maxReviews: 100,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _AmenityItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDarkMode;
  final Color color;

  const _AmenityItem({
    required this.icon,
    required this.label,
    required this.isDarkMode,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final Color color;
  final bool isDarkMode;

  const _TimeCard({
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
            ),
            Text(
              time,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Delegate for pinned tab bar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isDarkMode;

  _SliverTabBarDelegate(this.tabBar, {required this.isDarkMode});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
