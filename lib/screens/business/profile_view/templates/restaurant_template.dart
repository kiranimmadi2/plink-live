import 'package:flutter/material.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import '../sections/hero_section.dart';
import '../sections/quick_actions_bar.dart';
import '../sections/menu_section.dart';
import '../sections/gallery_section.dart';
import '../sections/reviews_section.dart';
import '../sections/hours_section.dart';
import '../sections/location_section.dart';

/// Restaurant-specific template with tabbed layout
/// Features: Menu (tabbed), Photos, Reviews
class RestaurantTemplate extends StatefulWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const RestaurantTemplate({
    super.key,
    required this.business,
    required this.config,
  });

  @override
  State<RestaurantTemplate> createState() => _RestaurantTemplateState();
}

class _RestaurantTemplateState extends State<RestaurantTemplate>
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

            // Quick action buttons
            SliverToBoxAdapter(
              child: QuickActionsBar(
                business: widget.business,
                config: widget.config,
              ),
            ),

            // Restaurant highlights (cuisines, veg/non-veg, etc.)
            SliverToBoxAdapter(
              child: _buildRestaurantHighlights(isDarkMode),
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
                    Tab(text: 'Menu'),
                    Tab(text: 'Photos'),
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
            // Menu tab
            _buildMenuTab(isDarkMode),

            // Photos tab
            _buildPhotosTab(isDarkMode),

            // Reviews tab
            _buildReviewsTab(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantHighlights(bool isDarkMode) {
    final data = widget.business.categoryData ?? {};
    final foodType = data['foodType'] as String?;
    final cuisines = data['cuisineTypes'] as List<dynamic>?;
    final diningOptions = data['diningOptions'] as List<dynamic>?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // Food type (Veg/Non-veg)
          if (foodType != null)
            _HighlightChip(
              icon: Icons.eco,
              label: foodType,
              color: foodType.toLowerCase().contains('non')
                  ? Colors.red
                  : Colors.green,
              isDarkMode: isDarkMode,
            ),

          // Cuisines
          if (cuisines != null)
            ...cuisines.take(4).map((cuisine) => _HighlightChip(
                  icon: Icons.restaurant,
                  label: cuisine.toString(),
                  color: widget.config.primaryColor,
                  isDarkMode: isDarkMode,
                )),

          // Dining options
          if (diningOptions != null)
            ...diningOptions.map((option) => _HighlightChip(
                  icon: _getDiningIcon(option.toString()),
                  label: option.toString(),
                  color: Colors.blue,
                  isDarkMode: isDarkMode,
                )),
        ],
      ),
    );
  }

  IconData _getDiningIcon(String option) {
    final lower = option.toLowerCase();
    if (lower.contains('dine')) return Icons.restaurant;
    if (lower.contains('takeaway') || lower.contains('take')) return Icons.takeout_dining;
    if (lower.contains('delivery')) return Icons.delivery_dining;
    if (lower.contains('drive')) return Icons.drive_eta;
    return Icons.storefront;
  }

  Widget _buildMenuTab(bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        children: [
          MenuSection(
            businessId: widget.business.id,
            config: widget.config,
            showCategories: true,
          ),
          const SizedBox(height: 16),
          HoursSection(
            business: widget.business,
            config: widget.config,
          ),
          LocationSection(
            business: widget.business,
            config: widget.config,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPhotosTab(bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        children: [
          GallerySection(
            business: widget.business,
            config: widget.config,
            maxImages: 100, // Show all images
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
            maxReviews: 100, // Show all reviews
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDarkMode;

  const _HighlightChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
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
