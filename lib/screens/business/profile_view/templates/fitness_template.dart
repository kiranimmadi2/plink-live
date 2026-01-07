import 'package:flutter/material.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import '../sections/hero_section.dart';
import '../sections/quick_actions_bar.dart';
import '../sections/classes_section.dart';
import '../sections/memberships_section.dart';
import '../sections/gallery_section.dart';
import '../sections/reviews_section.dart';
import '../sections/hours_section.dart';
import '../sections/location_section.dart';

/// Fitness/Gym template with classes and membership focus
/// Features: Class schedule, trainers, membership plans, facilities
class FitnessTemplate extends StatefulWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const FitnessTemplate({
    super.key,
    required this.business,
    required this.config,
  });

  @override
  State<FitnessTemplate> createState() => _FitnessTemplateState();
}

class _FitnessTemplateState extends State<FitnessTemplate>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

            // Quick action buttons (Join Now as primary)
            SliverToBoxAdapter(
              child: QuickActionsBar(
                business: widget.business,
                config: widget.config,
              ),
            ),

            // Gym highlights / Facilities
            SliverToBoxAdapter(
              child: _buildFacilities(isDarkMode),
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
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(text: 'Classes'),
                    Tab(text: 'Membership'),
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
            // Classes tab
            _buildClassesTab(isDarkMode),

            // Membership tab
            _buildMembershipTab(isDarkMode),

            // Gallery tab
            _buildGalleryTab(isDarkMode),

            // Reviews tab
            _buildReviewsTab(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilities(bool isDarkMode) {
    final data = widget.business.categoryData ?? {};
    final facilities = data['facilities'] as List<dynamic>?;
    final gymType = data['gymType'] as String?;
    final genderPolicy = data['genderPolicy'] as String?;

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
                'Facilities',
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
            spacing: 12,
            runSpacing: 12,
            children: [
              // Gym type
              if (gymType != null)
                _FacilityItem(
                  icon: _getGymTypeIcon(gymType),
                  label: gymType,
                  isDarkMode: isDarkMode,
                  color: widget.config.primaryColor,
                ),

              // Gender policy
              if (genderPolicy != null)
                _FacilityItem(
                  icon: _getGenderIcon(genderPolicy),
                  label: genderPolicy,
                  isDarkMode: isDarkMode,
                  color: Colors.purple,
                ),

              // Facilities
              if (facilities != null)
                ...facilities.map((facility) => _FacilityItem(
                      icon: _getFacilityIcon(facility.toString()),
                      label: facility.toString(),
                      isDarkMode: isDarkMode,
                      color: widget.config.accentColor,
                    )),
            ],
          ),

          // Operating stats
          const SizedBox(height: 16),
          _buildStats(isDarkMode),
        ],
      ),
    );
  }

  IconData _getGymTypeIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('crossfit')) return Icons.fitness_center;
    if (lower.contains('yoga')) return Icons.self_improvement;
    if (lower.contains('martial')) return Icons.sports_martial_arts;
    if (lower.contains('boxing')) return Icons.sports_mma;
    if (lower.contains('swimming')) return Icons.pool;
    return Icons.fitness_center;
  }

  IconData _getGenderIcon(String policy) {
    final lower = policy.toLowerCase();
    if (lower.contains('women') || lower.contains('female')) return Icons.woman;
    if (lower.contains('men') || lower.contains('male')) return Icons.man;
    return Icons.people;
  }

  IconData _getFacilityIcon(String facility) {
    final lower = facility.toLowerCase();
    if (lower.contains('cardio')) return Icons.directions_run;
    if (lower.contains('weight') || lower.contains('strength')) {
      return Icons.fitness_center;
    }
    if (lower.contains('pool') || lower.contains('swim')) return Icons.pool;
    if (lower.contains('steam') || lower.contains('sauna')) return Icons.hot_tub;
    if (lower.contains('locker')) return Icons.lock;
    if (lower.contains('parking')) return Icons.local_parking;
    if (lower.contains('shower')) return Icons.shower;
    if (lower.contains('cafe') || lower.contains('juice')) {
      return Icons.local_cafe;
    }
    if (lower.contains('wifi')) return Icons.wifi;
    if (lower.contains('ac') || lower.contains('air')) return Icons.ac_unit;
    if (lower.contains('trainer')) return Icons.person;
    if (lower.contains('yoga')) return Icons.self_improvement;
    if (lower.contains('zumba') || lower.contains('dance')) return Icons.music_note;
    return Icons.check_circle;
  }

  Widget _buildStats(bool isDarkMode) {
    final data = widget.business.categoryData ?? {};
    final memberCount = data['memberCount'] as int?;
    final trainerCount = data['trainerCount'] as int?;
    final classCount = data['classCount'] as int?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (memberCount != null)
            _StatItem(
              value: memberCount > 1000
                  ? '${(memberCount / 1000).toStringAsFixed(1)}k+'
                  : '$memberCount+',
              label: 'Members',
              color: widget.config.primaryColor,
              isDarkMode: isDarkMode,
            ),
          if (trainerCount != null)
            _StatItem(
              value: '$trainerCount',
              label: 'Trainers',
              color: Colors.orange,
              isDarkMode: isDarkMode,
            ),
          if (classCount != null)
            _StatItem(
              value: '$classCount+',
              label: 'Classes',
              color: Colors.green,
              isDarkMode: isDarkMode,
            ),
          if (widget.business.yearEstablished != null)
            _StatItem(
              value: '${DateTime.now().year - widget.business.yearEstablished!}+',
              label: 'Years',
              color: Colors.blue,
              isDarkMode: isDarkMode,
            ),
        ],
      ),
    );
  }

  Widget _buildClassesTab(bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          ClassesSection(
            businessId: widget.business.id,
            config: widget.config,
            onBook: () {
              // Handle class booking
            },
          ),
          const SizedBox(height: 16),
          _buildTrainers(isDarkMode),
          HoursSection(
            business: widget.business,
            config: widget.config,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTrainers(bool isDarkMode) {
    final data = widget.business.categoryData ?? {};
    final trainers = data['trainers'] as List<dynamic>?;

    if (trainers == null || trainers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Icon(
                Icons.person,
                size: 20,
                color: widget.config.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Our Trainers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: trainers.length,
            itemBuilder: (context, index) {
              final trainer = trainers[index] as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _TrainerCard(
                  name: trainer['name'] ?? 'Trainer',
                  specialty: trainer['specialty'] ?? '',
                  imageUrl: trainer['imageUrl'],
                  isDarkMode: isDarkMode,
                  color: widget.config.primaryColor,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMembershipTab(bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          MembershipsSection(
            businessId: widget.business.id,
            config: widget.config,
            onPlanSelect: () {
              // Handle plan selection
            },
          ),
          const SizedBox(height: 24),
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

class _FacilityItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDarkMode;
  final Color color;

  const _FacilityItem({
    required this.icon,
    required this.label,
    required this.isDarkMode,
    required this.color,
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

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final bool isDarkMode;

  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white54 : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _TrainerCard extends StatelessWidget {
  final String name;
  final String specialty;
  final String? imageUrl;
  final bool isDarkMode;
  final Color color;

  const _TrainerCard({
    required this.name,
    required this.specialty,
    this.imageUrl,
    required this.isDarkMode,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: color.withValues(alpha: 0.1),
            backgroundImage:
                imageUrl != null ? NetworkImage(imageUrl!) : null,
            child: imageUrl == null
                ? Icon(Icons.person, color: color, size: 32)
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (specialty.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              specialty,
              style: TextStyle(
                fontSize: 11,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
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
