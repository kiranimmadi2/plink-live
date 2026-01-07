import 'package:flutter/material.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import '../sections/hero_section.dart';
import '../sections/quick_actions_bar.dart';
import '../sections/products_section.dart';
import '../sections/gallery_section.dart';
import '../sections/reviews_section.dart';
import '../sections/hours_section.dart';
import '../sections/location_section.dart';

/// Retail/Grocery template with product catalog focus
/// Features: Product categories, deals, shopping cart
class RetailTemplate extends StatefulWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const RetailTemplate({
    super.key,
    required this.business,
    required this.config,
  });

  @override
  State<RetailTemplate> createState() => _RetailTemplateState();
}

class _RetailTemplateState extends State<RetailTemplate>
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

            // Quick action buttons (Order as primary)
            SliverToBoxAdapter(
              child: QuickActionsBar(
                business: widget.business,
                config: widget.config,
              ),
            ),

            // Store highlights
            SliverToBoxAdapter(
              child: _buildStoreHighlights(isDarkMode),
            ),

            // Deals banner (if available)
            SliverToBoxAdapter(
              child: _buildDealsBanner(isDarkMode),
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
                    Tab(text: 'Products'),
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
            // Products tab
            _buildProductsTab(isDarkMode),

            // Photos tab
            _buildPhotosTab(isDarkMode),

            // Reviews tab
            _buildReviewsTab(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreHighlights(bool isDarkMode) {
    final data = widget.business.categoryData ?? {};
    final storeType = data['storeType'] as String?;
    final productCategories = data['productCategories'] as List<dynamic>?;
    final deliveryAvailable = data['deliveryAvailable'] as bool? ?? false;
    final pickupAvailable = data['pickupAvailable'] as bool? ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // Store type
          if (storeType != null)
            _HighlightChip(
              icon: _getStoreTypeIcon(storeType),
              label: storeType,
              color: widget.config.primaryColor,
              isDarkMode: isDarkMode,
            ),

          // Delivery available
          if (deliveryAvailable)
            _HighlightChip(
              icon: Icons.delivery_dining,
              label: 'Delivery',
              color: Colors.green,
              isDarkMode: isDarkMode,
            ),

          // Pickup available
          if (pickupAvailable)
            _HighlightChip(
              icon: Icons.shopping_bag,
              label: 'Pickup',
              color: Colors.blue,
              isDarkMode: isDarkMode,
            ),

          // Product categories (show first 3)
          if (productCategories != null)
            ...productCategories.take(3).map((category) => _HighlightChip(
                  icon: _getCategoryIcon(category.toString()),
                  label: category.toString(),
                  color: widget.config.accentColor,
                  isDarkMode: isDarkMode,
                )),
        ],
      ),
    );
  }

  IconData _getStoreTypeIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('grocery')) return Icons.local_grocery_store;
    if (lower.contains('supermarket')) return Icons.store;
    if (lower.contains('convenience')) return Icons.storefront;
    if (lower.contains('organic')) return Icons.eco;
    if (lower.contains('wholesale')) return Icons.warehouse;
    return Icons.shopping_cart;
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('fruit') || lower.contains('vegetable')) {
      return Icons.apple;
    }
    if (lower.contains('dairy')) return Icons.egg;
    if (lower.contains('meat')) return Icons.set_meal;
    if (lower.contains('bakery')) return Icons.bakery_dining;
    if (lower.contains('beverage')) return Icons.local_drink;
    if (lower.contains('snack')) return Icons.cookie;
    if (lower.contains('frozen')) return Icons.ac_unit;
    if (lower.contains('personal')) return Icons.face;
    if (lower.contains('household')) return Icons.cleaning_services;
    return Icons.category;
  }

  Widget _buildDealsBanner(bool isDarkMode) {
    final data = widget.business.categoryData ?? {};
    final hasDeals = data['hasActiveDeals'] as bool? ?? false;
    final dealText = data['currentDeal'] as String?;

    if (!hasDeals || dealText == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.config.primaryColor,
            widget.config.primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: widget.config.primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_offer,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Special Offer',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dealText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            color: Colors.white70,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTab(bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          ProductsSection(
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
          ContactSection(
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
