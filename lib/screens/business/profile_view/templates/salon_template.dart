import 'package:flutter/material.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import '../sections/hero_section.dart';
import '../sections/quick_actions_bar.dart';
import '../sections/services_section.dart';
import '../sections/gallery_section.dart';
import '../sections/reviews_section.dart';
import '../sections/hours_section.dart';
import '../sections/location_section.dart';

/// Salon/Beauty template with focus on services and portfolio
class SalonTemplate extends StatelessWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const SalonTemplate({
    super.key,
    required this.business,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Hero section
          HeroSection(
            business: business,
            config: config,
          ),

          // Quick action buttons (Book Now as primary)
          SliverToBoxAdapter(
            child: QuickActionsBar(
              business: business,
              config: config,
            ),
          ),

          // Salon highlights (services offered, gender served, etc.)
          SliverToBoxAdapter(
            child: _buildSalonHighlights(isDarkMode),
          ),

          // Services & Pricing section (primary focus)
          SliverToBoxAdapter(
            child: _buildServicesSection(isDarkMode),
          ),

          // Portfolio / Our Work section
          SliverToBoxAdapter(
            child: _buildPortfolioSection(isDarkMode),
          ),

          // Reviews
          SliverToBoxAdapter(
            child: ReviewsSection(
              businessId: business.id,
              config: config,
            ),
          ),

          // Hours
          SliverToBoxAdapter(
            child: HoursSection(
              business: business,
              config: config,
            ),
          ),

          // Location
          SliverToBoxAdapter(
            child: LocationSection(
              business: business,
              config: config,
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildSalonHighlights(bool isDarkMode) {
    final data = business.categoryData ?? {};
    final services = data['serviceCategories'] as List<dynamic>?;
    final genderServed = data['genderServed'] as String?;
    final bookingType = data['bookingType'] as List<dynamic>?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Gender served
              if (genderServed != null)
                _HighlightChip(
                  icon: _getGenderIcon(genderServed),
                  label: genderServed,
                  color: _getGenderColor(genderServed),
                  isDarkMode: isDarkMode,
                ),

              // Booking type
              if (bookingType != null)
                ...bookingType.map((type) => _HighlightChip(
                      icon: type.toString().toLowerCase().contains('walk')
                          ? Icons.directions_walk
                          : Icons.calendar_today,
                      label: type.toString(),
                      color: Colors.blue,
                      isDarkMode: isDarkMode,
                    )),

              // Service categories (show up to 4)
              if (services != null)
                ...services.take(4).map((service) => _HighlightChip(
                      icon: _getServiceIcon(service.toString()),
                      label: service.toString(),
                      color: config.primaryColor,
                      isDarkMode: isDarkMode,
                    )),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getGenderIcon(String gender) {
    final lower = gender.toLowerCase();
    if (lower == 'men') return Icons.man;
    if (lower == 'women') return Icons.woman;
    return Icons.people;
  }

  Color _getGenderColor(String gender) {
    final lower = gender.toLowerCase();
    if (lower == 'men') return Colors.blue;
    if (lower == 'women') return Colors.pink;
    return Colors.purple;
  }

  IconData _getServiceIcon(String service) {
    final lower = service.toLowerCase();
    if (lower.contains('hair')) return Icons.content_cut;
    if (lower.contains('facial')) return Icons.face;
    if (lower.contains('nail')) return Icons.pan_tool;
    if (lower.contains('makeup')) return Icons.brush;
    if (lower.contains('massage')) return Icons.spa;
    if (lower.contains('wax')) return Icons.remove;
    if (lower.contains('bridal')) return Icons.cake;
    return Icons.spa;
  }

  Widget _buildServicesSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    config.primarySectionIcon,
                    size: 20,
                    color: config.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Services & Pricing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ServicesSection(
          businessId: business.id,
          business: business,
          config: config,
        ),
      ],
    );
  }

  Widget _buildPortfolioSection(bool isDarkMode) {
    if (business.images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.photo_library,
                size: 20,
                color: config.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Our Work',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        GallerySection(
          business: business,
          config: config,
        ),
      ],
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
