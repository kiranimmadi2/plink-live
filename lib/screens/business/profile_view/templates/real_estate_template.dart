import 'package:flutter/material.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import '../sections/hero_section.dart';
import '../sections/quick_actions_bar.dart';
import '../sections/properties_section.dart';
import '../sections/gallery_section.dart';
import '../sections/reviews_section.dart';
import '../sections/hours_section.dart';
import '../sections/location_section.dart';

/// Real Estate template with property listings focus
/// Features: Property listings, filters, enquiry forms
class RealEstateTemplate extends StatefulWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const RealEstateTemplate({
    super.key,
    required this.business,
    required this.config,
  });

  @override
  State<RealEstateTemplate> createState() => _RealEstateTemplateState();
}

class _RealEstateTemplateState extends State<RealEstateTemplate>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPropertyType = 'All';
  String _selectedListingType = 'All';

  final List<String> _propertyTypes = [
    'All',
    'Apartment',
    'House',
    'Villa',
    'Plot',
    'Commercial'
  ];
  final List<String> _listingTypes = ['All', 'Sale', 'Rent', 'Lease'];

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

            // Quick action buttons (Enquire as primary)
            SliverToBoxAdapter(
              child: QuickActionsBar(
                business: widget.business,
                config: widget.config,
              ),
            ),

            // Agency highlights
            SliverToBoxAdapter(
              child: _buildAgencyHighlights(isDarkMode),
            ),

            // Property type filters
            SliverToBoxAdapter(
              child: _buildFilters(isDarkMode),
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
                    Tab(text: 'Listings'),
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
            // Listings tab
            _buildListingsTab(isDarkMode),

            // Gallery tab
            _buildGalleryTab(isDarkMode),

            // Reviews tab
            _buildReviewsTab(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildAgencyHighlights(bool isDarkMode) {
    final data = widget.business.categoryData ?? {};
    final propertyTypes = data['propertyTypes'] as List<dynamic>?;
    final transactionTypes = data['transactionTypes'] as List<dynamic>?;
    final reraRegistered = data['reraRegistered'] as bool? ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.business,
                size: 20,
                color: widget.config.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Agency Highlights',
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
            spacing: 8,
            runSpacing: 8,
            children: [
              // RERA Registered badge
              if (reraRegistered)
                _HighlightChip(
                  icon: Icons.verified,
                  label: 'RERA Registered',
                  color: Colors.green,
                  isDarkMode: isDarkMode,
                ),

              // Property types
              if (propertyTypes != null)
                ...propertyTypes.take(3).map((type) => _HighlightChip(
                      icon: _getPropertyTypeIcon(type.toString()),
                      label: type.toString(),
                      color: widget.config.primaryColor,
                      isDarkMode: isDarkMode,
                    )),

              // Transaction types
              if (transactionTypes != null)
                ...transactionTypes.map((type) => _HighlightChip(
                      icon: _getTransactionIcon(type.toString()),
                      label: type.toString(),
                      color: Colors.blue,
                      isDarkMode: isDarkMode,
                    )),
            ],
          ),

          // Experience
          if (widget.business.yearEstablished != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.config.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.timeline,
                      color: widget.config.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Experience',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${DateTime.now().year - widget.business.yearEstablished!}+ years in Real Estate',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getPropertyTypeIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('apartment')) return Icons.apartment;
    if (lower.contains('house')) return Icons.house;
    if (lower.contains('villa')) return Icons.villa;
    if (lower.contains('plot') || lower.contains('land')) return Icons.landscape;
    if (lower.contains('commercial')) return Icons.store;
    if (lower.contains('office')) return Icons.business;
    return Icons.home;
  }

  IconData _getTransactionIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('sale') || lower.contains('buy')) return Icons.sell;
    if (lower.contains('rent')) return Icons.key;
    if (lower.contains('lease')) return Icons.description;
    return Icons.handshake;
  }

  Widget _buildFilters(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property type filter
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _propertyTypes.length,
              itemBuilder: (context, index) {
                final type = _propertyTypes[index];
                final isSelected = type == _selectedPropertyType;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedPropertyType = type;
                      });
                    },
                    selectedColor:
                        widget.config.primaryColor.withValues(alpha: 0.2),
                    checkmarkColor: widget.config.primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? widget.config.primaryColor
                          : (isDarkMode ? Colors.white70 : Colors.grey[700]),
                      fontSize: 13,
                    ),
                    backgroundColor:
                        isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? widget.config.primaryColor
                          : (isDarkMode ? Colors.white24 : Colors.grey[300]!),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Listing type filter
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _listingTypes.length,
              itemBuilder: (context, index) {
                final type = _listingTypes[index];
                final isSelected = type == _selectedListingType;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedListingType = type;
                      });
                    },
                    selectedColor: Colors.blue.withValues(alpha: 0.2),
                    checkmarkColor: Colors.blue,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.blue
                          : (isDarkMode ? Colors.white70 : Colors.grey[700]),
                      fontSize: 13,
                    ),
                    backgroundColor:
                        isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? Colors.blue
                          : (isDarkMode ? Colors.white24 : Colors.grey[300]!),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingsTab(bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          PropertiesSection(
            businessId: widget.business.id,
            config: widget.config,
            onEnquire: () {
              // Handle enquiry
              _showEnquiryDialog();
            },
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
          HoursSection(
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

  void _showEnquiryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EnquiryBottomSheet(
        business: widget.business,
        config: widget.config,
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

class _EnquiryBottomSheet extends StatefulWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const _EnquiryBottomSheet({
    required this.business,
    required this.config,
  });

  @override
  State<_EnquiryBottomSheet> createState() => _EnquiryBottomSheetState();
}

class _EnquiryBottomSheetState extends State<_EnquiryBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Send Enquiry',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Your Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    value?.isEmpty == true ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    value?.isEmpty == true ? 'Please enter your phone' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: 'Message (Optional)',
                  prefixIcon: const Icon(Icons.message_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitEnquiry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.config.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Submit Enquiry',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _submitEnquiry() {
    if (_formKey.currentState?.validate() == true) {
      // TODO: Submit enquiry to Firebase
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enquiry sent successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
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
