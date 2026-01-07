import 'package:flutter/material.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import '../sections/hero_section.dart';
import '../sections/quick_actions_bar.dart';
import '../sections/services_section.dart';
import '../sections/reviews_section.dart';
import '../sections/hours_section.dart';
import '../sections/location_section.dart';

/// Healthcare template with professional layout
/// Focus on qualifications, specializations, and appointment booking
class HealthcareTemplate extends StatelessWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const HealthcareTemplate({
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

          // Quick action buttons (Book Appointment as primary)
          SliverToBoxAdapter(
            child: QuickActionsBar(
              business: business,
              config: config,
            ),
          ),

          // Specializations
          SliverToBoxAdapter(
            child: _buildSpecializations(isDarkMode),
          ),

          // About / Doctor Info
          SliverToBoxAdapter(
            child: _buildAboutSection(isDarkMode),
          ),

          // Consultation types
          SliverToBoxAdapter(
            child: _buildConsultationTypes(isDarkMode),
          ),

          // Services offered
          SliverToBoxAdapter(
            child: ServicesSection(
              businessId: business.id,
              business: business,
              config: config,
            ),
          ),

          // Patient Reviews
          SliverToBoxAdapter(
            child: _buildReviewsSection(isDarkMode),
          ),

          // Consultation Hours
          SliverToBoxAdapter(
            child: HoursSection(
              business: business,
              config: config,
            ),
          ),

          // Clinic Location
          SliverToBoxAdapter(
            child: LocationSection(
              business: business,
              config: config,
            ),
          ),

          // Contact
          SliverToBoxAdapter(
            child: ContactSection(
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

  Widget _buildSpecializations(bool isDarkMode) {
    final data = business.categoryData ?? {};
    final specializations = data['specializations'] as List<dynamic>?;

    if (specializations == null || specializations.isEmpty) {
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
                Icons.verified,
                size: 20,
                color: config.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Specializations',
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
            children: specializations.map((spec) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: config.primaryColor.withValues(alpha: isDarkMode ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: config.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getSpecializationIcon(spec.toString()),
                      size: 16,
                      color: config.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      spec.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _getSpecializationIcon(String spec) {
    final lower = spec.toLowerCase();
    if (lower.contains('cardio')) return Icons.favorite;
    if (lower.contains('ortho')) return Icons.accessibility_new;
    if (lower.contains('pediatric')) return Icons.child_care;
    if (lower.contains('derma')) return Icons.face;
    if (lower.contains('dental')) return Icons.medical_services;
    if (lower.contains('eye')) return Icons.visibility;
    if (lower.contains('ent')) return Icons.hearing;
    if (lower.contains('gynec')) return Icons.pregnant_woman;
    if (lower.contains('neuro')) return Icons.psychology;
    if (lower.contains('general')) return Icons.local_hospital;
    return Icons.medical_services;
  }

  Widget _buildAboutSection(bool isDarkMode) {
    if (business.description == null || business.description!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
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
                Icons.person,
                size: 20,
                color: config.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'About',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            business.description!,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
          ),
          if (business.yearEstablished != null) ...[
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Experience',
              value: '${DateTime.now().year - business.yearEstablished!}+ years',
              isDarkMode: isDarkMode,
              color: config.primaryColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConsultationTypes(bool isDarkMode) {
    final data = business.categoryData ?? {};
    final consultTypes = data['appointmentType'] as List<dynamic>?;

    if (consultTypes == null || consultTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
                Icons.video_call,
                size: 20,
                color: config.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Consultation Types',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...consultTypes.map((type) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: config.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getConsultIcon(type.toString()),
                        color: config.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      type.toString(),
                      style: TextStyle(
                        fontSize: 15,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  IconData _getConsultIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('in-person') || lower.contains('visit')) {
      return Icons.person;
    }
    if (lower.contains('online') || lower.contains('video')) {
      return Icons.video_call;
    }
    if (lower.contains('home')) return Icons.home;
    if (lower.contains('phone')) return Icons.phone;
    return Icons.calendar_today;
  }

  Widget _buildReviewsSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Row(
            children: [
              Icon(
                Icons.star_rounded,
                size: 20,
                color: config.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Patient Reviews',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        ReviewsSection(
          businessId: business.id,
          config: config,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDarkMode;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDarkMode,
    required this.color,
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
          child: Icon(icon, size: 16, color: color),
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
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
