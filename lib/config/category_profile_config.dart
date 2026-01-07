import 'package:flutter/material.dart';
import '../models/business_category_config.dart';

/// Types of quick actions available on business profiles
enum QuickActionType {
  call,
  whatsapp,
  directions,
  book,
  order,
  enquire,
  share,
  website,
}

/// A quick action button on the business profile
class QuickAction {
  final String id;
  final String label;
  final IconData icon;
  final QuickActionType type;
  final Color? color;
  final bool isPrimary;

  const QuickAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.type,
    this.color,
    this.isPrimary = false,
  });
}

/// Configuration for category-specific profile views
class CategoryProfileConfig {
  final BusinessCategory category;
  final String primarySectionTitle;
  final IconData primarySectionIcon;
  final List<QuickAction> quickActions;
  final Color primaryColor;
  final Color accentColor;
  final List<String> highlightFields;
  final String emptyStateMessage;
  final String emptyStateIcon;

  const CategoryProfileConfig({
    required this.category,
    required this.primarySectionTitle,
    required this.primarySectionIcon,
    required this.quickActions,
    required this.primaryColor,
    required this.accentColor,
    required this.highlightFields,
    required this.emptyStateMessage,
    this.emptyStateIcon = '📭',
  });

  /// Get configuration for a business category
  static CategoryProfileConfig getConfig(BusinessCategory? category) {
    if (category == null) return _defaultConfig;
    return _configs[category] ?? _defaultConfig;
  }

  /// Get configuration by category ID string
  static CategoryProfileConfig getConfigById(String? categoryId) {
    if (categoryId == null) return _defaultConfig;
    final category = BusinessCategoryExtension.fromString(categoryId);
    return getConfig(category);
  }

  // ============================================================
  // CATEGORY CONFIGURATIONS
  // ============================================================

  static const Map<BusinessCategory, CategoryProfileConfig> _configs = {
    // FOOD & BEVERAGE - Restaurants, Cafes, Bakeries
    BusinessCategory.foodBeverage: CategoryProfileConfig(
      category: BusinessCategory.foodBeverage,
      primarySectionTitle: 'Menu',
      primarySectionIcon: Icons.restaurant_menu,
      quickActions: [
        QuickAction(
          id: 'order',
          label: 'Order',
          icon: Icons.shopping_bag_rounded,
          type: QuickActionType.order,
          color: Color(0xFFF59E0B),
          isPrimary: true,
        ),
        QuickAction(
          id: 'call',
          label: 'Call',
          icon: Icons.phone_rounded,
          type: QuickActionType.call,
        ),
        QuickAction(
          id: 'directions',
          label: 'Directions',
          icon: Icons.directions_rounded,
          type: QuickActionType.directions,
        ),
        QuickAction(
          id: 'share',
          label: 'Share',
          icon: Icons.share_rounded,
          type: QuickActionType.share,
        ),
      ],
      primaryColor: Color(0xFFF59E0B),
      accentColor: Color(0xFFD97706),
      highlightFields: ['cuisineTypes', 'foodType', 'diningOptions'],
      emptyStateMessage: 'This restaurant hasn\'t added their menu yet',
      emptyStateIcon: '🍽️',
    ),

    // BEAUTY & WELLNESS - Salons, Spas
    BusinessCategory.beautyWellness: CategoryProfileConfig(
      category: BusinessCategory.beautyWellness,
      primarySectionTitle: 'Services',
      primarySectionIcon: Icons.spa,
      quickActions: [
        QuickAction(
          id: 'book',
          label: 'Book Now',
          icon: Icons.calendar_today_rounded,
          type: QuickActionType.book,
          color: Color(0xFFEC4899),
          isPrimary: true,
        ),
        QuickAction(
          id: 'call',
          label: 'Call',
          icon: Icons.phone_rounded,
          type: QuickActionType.call,
        ),
        QuickAction(
          id: 'whatsapp',
          label: 'WhatsApp',
          icon: Icons.chat_rounded,
          type: QuickActionType.whatsapp,
        ),
        QuickAction(
          id: 'share',
          label: 'Share',
          icon: Icons.share_rounded,
          type: QuickActionType.share,
        ),
      ],
      primaryColor: Color(0xFFEC4899),
      accentColor: Color(0xFFDB2777),
      highlightFields: ['serviceCategories', 'genderServed', 'bookingType'],
      emptyStateMessage: 'This salon hasn\'t added their services yet',
      emptyStateIcon: '💇',
    ),

    // HEALTHCARE - Clinics, Doctors
    BusinessCategory.healthcare: CategoryProfileConfig(
      category: BusinessCategory.healthcare,
      primarySectionTitle: 'Services',
      primarySectionIcon: Icons.medical_services,
      quickActions: [
        QuickAction(
          id: 'book',
          label: 'Book Appointment',
          icon: Icons.calendar_today_rounded,
          type: QuickActionType.book,
          color: Color(0xFFEF4444),
          isPrimary: true,
        ),
        QuickAction(
          id: 'call',
          label: 'Call',
          icon: Icons.phone_rounded,
          type: QuickActionType.call,
        ),
        QuickAction(
          id: 'directions',
          label: 'Directions',
          icon: Icons.directions_rounded,
          type: QuickActionType.directions,
        ),
        QuickAction(
          id: 'share',
          label: 'Share',
          icon: Icons.share_rounded,
          type: QuickActionType.share,
        ),
      ],
      primaryColor: Color(0xFFEF4444),
      accentColor: Color(0xFFDC2626),
      highlightFields: ['specializations', 'appointmentType'],
      emptyStateMessage: 'This healthcare provider hasn\'t added their services yet',
      emptyStateIcon: '🏥',
    ),

    // HOSPITALITY - Hotels, Resorts
    BusinessCategory.hospitality: CategoryProfileConfig(
      category: BusinessCategory.hospitality,
      primarySectionTitle: 'Rooms',
      primarySectionIcon: Icons.hotel,
      quickActions: [
        QuickAction(
          id: 'book',
          label: 'Book Room',
          icon: Icons.hotel_rounded,
          type: QuickActionType.book,
          color: Color(0xFF6366F1),
          isPrimary: true,
        ),
        QuickAction(
          id: 'call',
          label: 'Call',
          icon: Icons.phone_rounded,
          type: QuickActionType.call,
        ),
        QuickAction(
          id: 'directions',
          label: 'Directions',
          icon: Icons.directions_rounded,
          type: QuickActionType.directions,
        ),
        QuickAction(
          id: 'share',
          label: 'Share',
          icon: Icons.share_rounded,
          type: QuickActionType.share,
        ),
      ],
      primaryColor: Color(0xFF6366F1),
      accentColor: Color(0xFF4F46E5),
      highlightFields: ['amenities', 'checkInTime', 'checkOutTime'],
      emptyStateMessage: 'This property hasn\'t added room details yet',
      emptyStateIcon: '🏨',
    ),

    // REAL ESTATE - Property, Rentals
    BusinessCategory.realEstate: CategoryProfileConfig(
      category: BusinessCategory.realEstate,
      primarySectionTitle: 'Properties',
      primarySectionIcon: Icons.apartment,
      quickActions: [
        QuickAction(
          id: 'enquire',
          label: 'Enquire',
          icon: Icons.mail_rounded,
          type: QuickActionType.enquire,
          color: Color(0xFF0EA5E9),
          isPrimary: true,
        ),
        QuickAction(
          id: 'call',
          label: 'Call',
          icon: Icons.phone_rounded,
          type: QuickActionType.call,
        ),
        QuickAction(
          id: 'whatsapp',
          label: 'WhatsApp',
          icon: Icons.chat_rounded,
          type: QuickActionType.whatsapp,
        ),
        QuickAction(
          id: 'share',
          label: 'Share',
          icon: Icons.share_rounded,
          type: QuickActionType.share,
        ),
      ],
      primaryColor: Color(0xFF0EA5E9),
      accentColor: Color(0xFF0284C7),
      highlightFields: ['propertyTypes', 'servicesType'],
      emptyStateMessage: 'No property listings available',
      emptyStateIcon: '🏠',
    ),

    // RETAIL - Shops, Stores
    BusinessCategory.retail: CategoryProfileConfig(
      category: BusinessCategory.retail,
      primarySectionTitle: 'Products',
      primarySectionIcon: Icons.storefront,
      quickActions: [
        QuickAction(
          id: 'order',
          label: 'Shop',
          icon: Icons.shopping_bag_rounded,
          type: QuickActionType.order,
          color: Color(0xFF10B981),
          isPrimary: true,
        ),
        QuickAction(
          id: 'call',
          label: 'Call',
          icon: Icons.phone_rounded,
          type: QuickActionType.call,
        ),
        QuickAction(
          id: 'directions',
          label: 'Directions',
          icon: Icons.directions_rounded,
          type: QuickActionType.directions,
        ),
        QuickAction(
          id: 'share',
          label: 'Share',
          icon: Icons.share_rounded,
          type: QuickActionType.share,
        ),
      ],
      primaryColor: Color(0xFF10B981),
      accentColor: Color(0xFF059669),
      highlightFields: ['productCategories', 'orderOptions'],
      emptyStateMessage: 'This store hasn\'t added their products yet',
      emptyStateIcon: '🛍️',
    ),

    // GROCERY - Supermarkets, Kirana
    BusinessCategory.grocery: CategoryProfileConfig(
      category: BusinessCategory.grocery,
      primarySectionTitle: 'Products',
      primarySectionIcon: Icons.shopping_basket,
      quickActions: [
        QuickAction(
          id: 'order',
          label: 'Order',
          icon: Icons.shopping_cart_rounded,
          type: QuickActionType.order,
          color: Color(0xFF22C55E),
          isPrimary: true,
        ),
        QuickAction(
          id: 'call',
          label: 'Call',
          icon: Icons.phone_rounded,
          type: QuickActionType.call,
        ),
        QuickAction(
          id: 'directions',
          label: 'Directions',
          icon: Icons.directions_rounded,
          type: QuickActionType.directions,
        ),
        QuickAction(
          id: 'share',
          label: 'Share',
          icon: Icons.share_rounded,
          type: QuickActionType.share,
        ),
      ],
      primaryColor: Color(0xFF22C55E),
      accentColor: Color(0xFF16A34A),
      highlightFields: ['productTypes', 'deliveryOptions'],
      emptyStateMessage: 'This store hasn\'t added their products yet',
      emptyStateIcon: '🛒',
    ),

    // FITNESS - Gyms, Studios
    BusinessCategory.fitness: CategoryProfileConfig(
      category: BusinessCategory.fitness,
      primarySectionTitle: 'Classes',
      primarySectionIcon: Icons.fitness_center,
      quickActions: [
        QuickAction(
          id: 'book',
          label: 'Join Now',
          icon: Icons.add_circle_rounded,
          type: QuickActionType.book,
          color: Color(0xFF8B5CF6),
          isPrimary: true,
        ),
        QuickAction(
          id: 'call',
          label: 'Call',
          icon: Icons.phone_rounded,
          type: QuickActionType.call,
        ),
        QuickAction(
          id: 'directions',
          label: 'Directions',
          icon: Icons.directions_rounded,
          type: QuickActionType.directions,
        ),
        QuickAction(
          id: 'share',
          label: 'Share',
          icon: Icons.share_rounded,
          type: QuickActionType.share,
        ),
      ],
      primaryColor: Color(0xFF8B5CF6),
      accentColor: Color(0xFF7C3AED),
      highlightFields: ['activities', 'membershipType'],
      emptyStateMessage: 'This fitness center hasn\'t added their classes yet',
      emptyStateIcon: '🏋️',
    ),

    // EDUCATION - Schools, Tutors
    BusinessCategory.education: CategoryProfileConfig(
      category: BusinessCategory.education,
      primarySectionTitle: 'Courses',
      primarySectionIcon: Icons.school,
      quickActions: [
        QuickAction(
          id: 'enquire',
          label: 'Enquire',
          icon: Icons.mail_rounded,
          type: QuickActionType.enquire,
          color: Color(0xFF3B82F6),
          isPrimary: true,
        ),
        QuickAction(
          id: 'call',
          label: 'Call',
          icon: Icons.phone_rounded,
          type: QuickActionType.call,
        ),
        QuickAction(
          id: 'whatsapp',
          label: 'WhatsApp',
          icon: Icons.chat_rounded,
          type: QuickActionType.whatsapp,
        ),
        QuickAction(
          id: 'share',
          label: 'Share',
          icon: Icons.share_rounded,
          type: QuickActionType.share,
        ),
      ],
      primaryColor: Color(0xFF3B82F6),
      accentColor: Color(0xFF2563EB),
      highlightFields: ['subjects', 'classType'],
      emptyStateMessage: 'This institution hasn\'t added their courses yet',
      emptyStateIcon: '📚',
    ),

    // TRAVEL & TOURISM
    BusinessCategory.travelTourism: CategoryProfileConfig(
      category: BusinessCategory.travelTourism,
      primarySectionTitle: 'Packages',
      primarySectionIcon: Icons.flight,
      quickActions: [
        QuickAction(
          id: 'enquire',
          label: 'Enquire',
          icon: Icons.mail_rounded,
          type: QuickActionType.enquire,
          color: Color(0xFF06B6D4),
          isPrimary: true,
        ),
        QuickAction(
          id: 'call',
          label: 'Call',
          icon: Icons.phone_rounded,
          type: QuickActionType.call,
        ),
        QuickAction(
          id: 'whatsapp',
          label: 'WhatsApp',
          icon: Icons.chat_rounded,
          type: QuickActionType.whatsapp,
        ),
        QuickAction(
          id: 'share',
          label: 'Share',
          icon: Icons.share_rounded,
          type: QuickActionType.share,
        ),
      ],
      primaryColor: Color(0xFF06B6D4),
      accentColor: Color(0xFF0891B2),
      highlightFields: ['tourTypes', 'servicesOffered'],
      emptyStateMessage: 'This agency hasn\'t added their packages yet',
      emptyStateIcon: '✈️',
    ),

    // AUTOMOTIVE
    BusinessCategory.automotive: CategoryProfileConfig(
      category: BusinessCategory.automotive,
      primarySectionTitle: 'Services',
      primarySectionIcon: Icons.directions_car,
      quickActions: [
        QuickAction(
          id: 'book',
          label: 'Book Service',
          icon: Icons.calendar_today_rounded,
          type: QuickActionType.book,
          color: Color(0xFF64748B),
          isPrimary: true,
        ),
        QuickAction(
          id: 'call',
          label: 'Call',
          icon: Icons.phone_rounded,
          type: QuickActionType.call,
        ),
        QuickAction(
          id: 'directions',
          label: 'Directions',
          icon: Icons.directions_rounded,
          type: QuickActionType.directions,
        ),
        QuickAction(
          id: 'share',
          label: 'Share',
          icon: Icons.share_rounded,
          type: QuickActionType.share,
        ),
      ],
      primaryColor: Color(0xFF64748B),
      accentColor: Color(0xFF475569),
      highlightFields: ['vehicleTypes', 'servicesOffered'],
      emptyStateMessage: 'This service center hasn\'t added their services yet',
      emptyStateIcon: '🚗',
    ),

    // PROFESSIONAL SERVICES
    BusinessCategory.professional: CategoryProfileConfig(
      category: BusinessCategory.professional,
      primarySectionTitle: 'Services',
      primarySectionIcon: Icons.work,
      quickActions: [
        QuickAction(
          id: 'enquire',
          label: 'Contact',
          icon: Icons.mail_rounded,
          type: QuickActionType.enquire,
          color: Color(0xFF6B7280),
          isPrimary: true,
        ),
        QuickAction(
          id: 'call',
          label: 'Call',
          icon: Icons.phone_rounded,
          type: QuickActionType.call,
        ),
        QuickAction(
          id: 'website',
          label: 'Website',
          icon: Icons.language_rounded,
          type: QuickActionType.website,
        ),
        QuickAction(
          id: 'share',
          label: 'Share',
          icon: Icons.share_rounded,
          type: QuickActionType.share,
        ),
      ],
      primaryColor: Color(0xFF6B7280),
      accentColor: Color(0xFF4B5563),
      highlightFields: ['expertise', 'clientType'],
      emptyStateMessage: 'This business hasn\'t added their services yet',
      emptyStateIcon: '💼',
    ),

    // ART & CREATIVE
    BusinessCategory.artCreative: CategoryProfileConfig(
      category: BusinessCategory.artCreative,
      primarySectionTitle: 'Portfolio',
      primarySectionIcon: Icons.palette,
      quickActions: [
        QuickAction(
          id: 'enquire',
          label: 'Get Quote',
          icon: Icons.mail_rounded,
          type: QuickActionType.enquire,
          color: Color(0xFFE11D48),
          isPrimary: true,
        ),
        QuickAction(
          id: 'call',
          label: 'Call',
          icon: Icons.phone_rounded,
          type: QuickActionType.call,
        ),
        QuickAction(
          id: 'whatsapp',
          label: 'WhatsApp',
          icon: Icons.chat_rounded,
          type: QuickActionType.whatsapp,
        ),
        QuickAction(
          id: 'share',
          label: 'Share',
          icon: Icons.share_rounded,
          type: QuickActionType.share,
        ),
      ],
      primaryColor: Color(0xFFE11D48),
      accentColor: Color(0xFFBE123C),
      highlightFields: ['creativeServices', 'eventTypes'],
      emptyStateMessage: 'This studio hasn\'t added their portfolio yet',
      emptyStateIcon: '🎨',
    ),

    // HOME SERVICES
    BusinessCategory.homeServices: CategoryProfileConfig(
      category: BusinessCategory.homeServices,
      primarySectionTitle: 'Services',
      primarySectionIcon: Icons.home_repair_service,
      quickActions: [
        QuickAction(
          id: 'book',
          label: 'Book Service',
          icon: Icons.calendar_today_rounded,
          type: QuickActionType.book,
          color: Color(0xFF84CC16),
          isPrimary: true,
        ),
        QuickAction(
          id: 'call',
          label: 'Call',
          icon: Icons.phone_rounded,
          type: QuickActionType.call,
        ),
        QuickAction(
          id: 'whatsapp',
          label: 'WhatsApp',
          icon: Icons.chat_rounded,
          type: QuickActionType.whatsapp,
        ),
        QuickAction(
          id: 'share',
          label: 'Share',
          icon: Icons.share_rounded,
          type: QuickActionType.share,
        ),
      ],
      primaryColor: Color(0xFF84CC16),
      accentColor: Color(0xFF65A30D),
      highlightFields: ['serviceTypes', 'serviceArea'],
      emptyStateMessage: 'This service provider hasn\'t added their services yet',
      emptyStateIcon: '🔧',
    ),

    // WEDDING & EVENTS
    BusinessCategory.weddingEvents: CategoryProfileConfig(
      category: BusinessCategory.weddingEvents,
      primarySectionTitle: 'Packages',
      primarySectionIcon: Icons.cake,
      quickActions: [
        QuickAction(
          id: 'enquire',
          label: 'Get Quote',
          icon: Icons.mail_rounded,
          type: QuickActionType.enquire,
          color: Color(0xFFDB2777),
          isPrimary: true,
        ),
        QuickAction(
          id: 'call',
          label: 'Call',
          icon: Icons.phone_rounded,
          type: QuickActionType.call,
        ),
        QuickAction(
          id: 'whatsapp',
          label: 'WhatsApp',
          icon: Icons.chat_rounded,
          type: QuickActionType.whatsapp,
        ),
        QuickAction(
          id: 'share',
          label: 'Share',
          icon: Icons.share_rounded,
          type: QuickActionType.share,
        ),
      ],
      primaryColor: Color(0xFFDB2777),
      accentColor: Color(0xFFBE185D),
      highlightFields: ['eventServices', 'eventTypes'],
      emptyStateMessage: 'This vendor hasn\'t added their packages yet',
      emptyStateIcon: '💒',
    ),
  };

  /// Default configuration for unknown categories
  static const _defaultConfig = CategoryProfileConfig(
    category: BusinessCategory.professional,
    primarySectionTitle: 'Services',
    primarySectionIcon: Icons.business,
    quickActions: [
      QuickAction(
        id: 'call',
        label: 'Call',
        icon: Icons.phone_rounded,
        type: QuickActionType.call,
        color: Color(0xFF00D67D),
        isPrimary: true,
      ),
      QuickAction(
        id: 'whatsapp',
        label: 'WhatsApp',
        icon: Icons.chat_rounded,
        type: QuickActionType.whatsapp,
      ),
      QuickAction(
        id: 'directions',
        label: 'Directions',
        icon: Icons.directions_rounded,
        type: QuickActionType.directions,
      ),
      QuickAction(
        id: 'share',
        label: 'Share',
        icon: Icons.share_rounded,
        type: QuickActionType.share,
      ),
    ],
    primaryColor: Color(0xFF00D67D),
    accentColor: Color(0xFF00B368),
    highlightFields: [],
    emptyStateMessage: 'This business hasn\'t added their services yet',
    emptyStateIcon: '🏢',
  );
}

/// Extension to get profile config from BusinessCategory
extension BusinessCategoryProfileExtension on BusinessCategory {
  CategoryProfileConfig get profileConfig => CategoryProfileConfig.getConfig(this);
}
