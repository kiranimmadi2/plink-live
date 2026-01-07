import 'package:flutter/material.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import '../sections/hero_section.dart';
import '../sections/quick_actions_bar.dart';
import '../sections/courses_section.dart';
import '../sections/gallery_section.dart';
import '../sections/reviews_section.dart';
import '../sections/hours_section.dart';
import '../sections/location_section.dart';

/// Education template for coaching institutes, schools, training centers
/// Features: Courses, faculty, facilities, achievements
class EducationTemplate extends StatefulWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const EducationTemplate({
    super.key,
    required this.business,
    required this.config,
  });

  @override
  State<EducationTemplate> createState() => _EducationTemplateState();
}

class _EducationTemplateState extends State<EducationTemplate>
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

            // Quick action buttons (Enquire as primary)
            SliverToBoxAdapter(
              child: QuickActionsBar(
                business: widget.business,
                config: widget.config,
              ),
            ),

            // About / Institute info
            SliverToBoxAdapter(
              child: _buildAboutSection(isDarkMode),
            ),

            // Achievements / Stats
            SliverToBoxAdapter(
              child: _buildAchievements(isDarkMode),
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
                    Tab(text: 'Courses'),
                    Tab(text: 'Faculty'),
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
            // Courses tab
            _buildCoursesTab(isDarkMode),

            // Faculty tab
            _buildFacultyTab(isDarkMode),

            // Gallery tab
            _buildGalleryTab(isDarkMode),

            // Reviews tab
            _buildReviewsTab(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(bool isDarkMode) {
    final data = widget.business.categoryData ?? {};
    final instituteType = data['instituteType'] as String?;
    final subjects = data['subjects'] as List<dynamic>?;
    final boards = data['boards'] as List<dynamic>?;
    final batchSizes = data['batchSizes'] as List<dynamic>?;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          if (widget.business.description != null &&
              widget.business.description!.isNotEmpty)
            Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: widget.config.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'About Us',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.business.description!,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Highlights
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Institute type
              if (instituteType != null)
                _HighlightChip(
                  icon: _getInstituteIcon(instituteType),
                  label: instituteType,
                  color: widget.config.primaryColor,
                  isDarkMode: isDarkMode,
                ),

              // Subjects
              if (subjects != null)
                ...subjects.take(3).map((subject) => _HighlightChip(
                      icon: _getSubjectIcon(subject.toString()),
                      label: subject.toString(),
                      color: Colors.blue,
                      isDarkMode: isDarkMode,
                    )),

              // Boards
              if (boards != null)
                ...boards.map((board) => _HighlightChip(
                      icon: Icons.school,
                      label: board.toString(),
                      color: Colors.green,
                      isDarkMode: isDarkMode,
                    )),

              // Batch sizes
              if (batchSizes != null)
                ...batchSizes.map((size) => _HighlightChip(
                      icon: Icons.groups,
                      label: size.toString(),
                      color: Colors.orange,
                      isDarkMode: isDarkMode,
                    )),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getInstituteIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('school')) return Icons.school;
    if (lower.contains('college')) return Icons.account_balance;
    if (lower.contains('coaching')) return Icons.menu_book;
    if (lower.contains('tuition')) return Icons.edit;
    if (lower.contains('online')) return Icons.laptop;
    if (lower.contains('training')) return Icons.work;
    return Icons.school;
  }

  IconData _getSubjectIcon(String subject) {
    final lower = subject.toLowerCase();
    if (lower.contains('math')) return Icons.calculate;
    if (lower.contains('science') || lower.contains('physics')) {
      return Icons.science;
    }
    if (lower.contains('english') || lower.contains('language')) {
      return Icons.translate;
    }
    if (lower.contains('computer') || lower.contains('coding')) {
      return Icons.computer;
    }
    if (lower.contains('music')) return Icons.music_note;
    if (lower.contains('art')) return Icons.palette;
    if (lower.contains('business')) return Icons.business;
    return Icons.book;
  }

  Widget _buildAchievements(bool isDarkMode) {
    final data = widget.business.categoryData ?? {};
    final studentCount = data['studentCount'] as int?;
    final facultyCount = data['facultyCount'] as int?;
    final successRate = data['successRate'] as int?;
    final yearsExperience = widget.business.yearEstablished != null
        ? DateTime.now().year - widget.business.yearEstablished!
        : null;

    if (studentCount == null &&
        facultyCount == null &&
        successRate == null &&
        yearsExperience == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
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
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (studentCount != null)
            _AchievementItem(
              value: studentCount > 1000
                  ? '${(studentCount / 1000).toStringAsFixed(0)}K+'
                  : '$studentCount+',
              label: 'Students',
              icon: Icons.people,
            ),
          if (facultyCount != null)
            _AchievementItem(
              value: '$facultyCount+',
              label: 'Faculty',
              icon: Icons.person,
            ),
          if (successRate != null)
            _AchievementItem(
              value: '$successRate%',
              label: 'Success Rate',
              icon: Icons.trending_up,
            ),
          if (yearsExperience != null)
            _AchievementItem(
              value: '$yearsExperience+',
              label: 'Years',
              icon: Icons.calendar_today,
            ),
        ],
      ),
    );
  }

  Widget _buildCoursesTab(bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          CoursesSection(
            businessId: widget.business.id,
            config: widget.config,
            onEnroll: () {
              // Handle enrollment
            },
          ),
          const SizedBox(height: 16),
          HoursSection(
            business: widget.business,
            config: widget.config,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFacultyTab(bool isDarkMode) {
    final data = widget.business.categoryData ?? {};
    final faculty = data['faculty'] as List<dynamic>?;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          if (faculty != null && faculty.isNotEmpty)
            _buildFacultyList(faculty, isDarkMode)
          else
            _buildEmptyFaculty(isDarkMode),
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

  Widget _buildFacultyList(List<dynamic> faculty, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.people,
                size: 20,
                color: widget.config.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Our Faculty',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...faculty.map((member) {
          final m = member as Map<String, dynamic>;
          return _FacultyCard(
            name: m['name'] ?? 'Faculty',
            subject: m['subject'] ?? '',
            qualification: m['qualification'] ?? '',
            experience: m['experience'] ?? '',
            imageUrl: m['imageUrl'],
            isDarkMode: isDarkMode,
            color: widget.config.primaryColor,
          );
        }),
      ],
    );
  }

  Widget _buildEmptyFaculty(bool isDarkMode) {
    // Show sample faculty if none available
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.people,
                size: 20,
                color: widget.config.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Our Faculty',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _FacultyCard(
          name: 'Dr. Ramesh Kumar',
          subject: 'Mathematics',
          qualification: 'PhD in Mathematics',
          experience: '15+ years',
          isDarkMode: isDarkMode,
          color: widget.config.primaryColor,
        ),
        _FacultyCard(
          name: 'Prof. Anita Sharma',
          subject: 'Physics',
          qualification: 'M.Sc, B.Ed',
          experience: '12+ years',
          isDarkMode: isDarkMode,
          color: widget.config.primaryColor,
        ),
        _FacultyCard(
          name: 'Mr. Suresh Patel',
          subject: 'Chemistry',
          qualification: 'M.Sc Chemistry',
          experience: '10+ years',
          isDarkMode: isDarkMode,
          color: widget.config.primaryColor,
        ),
      ],
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

class _AchievementItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _AchievementItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _FacultyCard extends StatelessWidget {
  final String name;
  final String subject;
  final String qualification;
  final String experience;
  final String? imageUrl;
  final bool isDarkMode;
  final Color color;

  const _FacultyCard({
    required this.name,
    required this.subject,
    required this.qualification,
    required this.experience,
    this.imageUrl,
    required this.isDarkMode,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: color.withValues(alpha: 0.1),
            backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
            child: imageUrl == null
                ? Icon(Icons.person, color: color, size: 35)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subject,
                  style: TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.school,
                      size: 12,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        qualification,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.work,
                      size: 12,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      experience,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
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
