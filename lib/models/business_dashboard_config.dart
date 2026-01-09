import 'package:flutter/material.dart';
import 'business_category_config.dart';

/// Dashboard stat item configuration
class DashboardStat {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String Function(DashboardData data) getValue;
  final String? route;

  const DashboardStat({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.getValue,
    this.route,
  });
}

/// Quick action configuration
class QuickAction {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  const QuickAction({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}

/// Dashboard data model for stats
class DashboardData {
  final int totalOrders;
  final int pendingOrders;
  final int completedOrders;
  final int todayOrders;
  final int newInquiries;
  final int respondedInquiries;
  final double todayRevenue;
  final double weekRevenue;
  final double monthRevenue;
  final int totalItems;
  final int lowStockItems;
  final int todayAppointments;
  final int pendingAppointments;
  final int availableRooms;
  final int totalRooms;
  final int todayCheckIns;
  final int todayCheckOuts;
  final int preparingOrders;
  final int deliveryOrders;

  const DashboardData({
    this.totalOrders = 0,
    this.pendingOrders = 0,
    this.completedOrders = 0,
    this.todayOrders = 0,
    this.newInquiries = 0,
    this.respondedInquiries = 0,
    this.todayRevenue = 0,
    this.weekRevenue = 0,
    this.monthRevenue = 0,
    this.totalItems = 0,
    this.lowStockItems = 0,
    this.todayAppointments = 0,
    this.pendingAppointments = 0,
    this.availableRooms = 0,
    this.totalRooms = 0,
    this.todayCheckIns = 0,
    this.todayCheckOuts = 0,
    this.preparingOrders = 0,
    this.deliveryOrders = 0,
  });
}

/// Category group for dashboard configuration
enum CategoryGroup {
  food,        // Restaurant, Cafe, Bakery, Food Truck
  retail,      // Retail, Grocery
  hospitality, // Hotels, Resorts
  services,    // Beauty, Healthcare, Legal, etc.
  fitness,     // Gyms, Yoga studios
  education,   // Schools, Training centers
  professional,// Consultants, Agencies
}

/// Get category group from BusinessCategory
CategoryGroup getCategoryGroup(BusinessCategory? category) {
  if (category == null) return CategoryGroup.services;

  switch (category) {
    case BusinessCategory.foodBeverage:
      return CategoryGroup.food;
    case BusinessCategory.retail:
    case BusinessCategory.grocery:
      return CategoryGroup.retail;
    case BusinessCategory.hospitality:
    case BusinessCategory.travelTourism:
      return CategoryGroup.hospitality;
    case BusinessCategory.fitness:
      return CategoryGroup.fitness;
    case BusinessCategory.education:
      return CategoryGroup.education;
    case BusinessCategory.professional:
    case BusinessCategory.artCreative:
      return CategoryGroup.professional;
    case BusinessCategory.beautyWellness:
    case BusinessCategory.healthcare:
    case BusinessCategory.automotive:
    case BusinessCategory.homeServices:
    case BusinessCategory.petServices:
    case BusinessCategory.weddingEvents:
    case BusinessCategory.realEstate:
    case BusinessCategory.technology:
    case BusinessCategory.entertainment:
    case BusinessCategory.legal:
    case BusinessCategory.transportation:
    case BusinessCategory.construction:
    case BusinessCategory.agriculture:
    case BusinessCategory.manufacturing:
      return CategoryGroup.services;
  }
}

/// Dashboard configuration for each category group
class BusinessDashboardConfig {
  /// Get stats for a category group
  static List<DashboardStat> getStats(CategoryGroup group) {
    switch (group) {
      case CategoryGroup.food:
        return _foodStats;
      case CategoryGroup.retail:
        return _retailStats;
      case CategoryGroup.hospitality:
        return _hospitalityStats;
      case CategoryGroup.fitness:
        return _fitnessStats;
      case CategoryGroup.education:
        return _educationStats;
      case CategoryGroup.professional:
        return _professionalStats;
      case CategoryGroup.services:
        return _serviceStats;
    }
  }

  /// Get quick actions for a category group
  static List<QuickAction> getQuickActions(CategoryGroup group) {
    switch (group) {
      case CategoryGroup.food:
        return _foodActions;
      case CategoryGroup.retail:
        return _retailActions;
      case CategoryGroup.hospitality:
        return _hospitalityActions;
      case CategoryGroup.fitness:
        return _fitnessActions;
      case CategoryGroup.education:
        return _educationActions;
      case CategoryGroup.professional:
        return _professionalActions;
      case CategoryGroup.services:
        return _serviceActions;
    }
  }

  /// Get title for stats section
  static String getStatsTitle(CategoryGroup group) {
    switch (group) {
      case CategoryGroup.food:
        return "Today's Kitchen";
      case CategoryGroup.retail:
        return "Store Overview";
      case CategoryGroup.hospitality:
        return "Property Status";
      case CategoryGroup.fitness:
        return "Today's Activity";
      case CategoryGroup.education:
        return "Today's Schedule";
      case CategoryGroup.professional:
        return "Work Overview";
      case CategoryGroup.services:
        return "Today's Snapshot";
    }
  }

  // ============ FOOD & BEVERAGE STATS ============
  static final List<DashboardStat> _foodStats = [
    DashboardStat(
      id: 'orders',
      label: 'Orders',
      icon: Icons.receipt_long_outlined,
      color: const Color(0xFF00D67D),
      getValue: (data) => '${data.pendingOrders}',
      route: 'orders',
    ),
    DashboardStat(
      id: 'revenue',
      label: 'Revenue',
      icon: Icons.currency_rupee,
      color: const Color(0xFF42A5F5),
      getValue: (data) => _formatCurrency(data.todayRevenue),
      route: 'analytics',
    ),
    DashboardStat(
      id: 'preparing',
      label: 'Preparing',
      icon: Icons.restaurant,
      color: const Color(0xFFFFA726),
      getValue: (data) => '${data.preparingOrders}',
      route: 'orders',
    ),
    DashboardStat(
      id: 'delivery',
      label: 'Delivery',
      icon: Icons.delivery_dining,
      color: const Color(0xFF7E57C2),
      getValue: (data) => '${data.deliveryOrders}',
      route: 'orders',
    ),
  ];

  // ============ RETAIL STATS ============
  static final List<DashboardStat> _retailStats = [
    DashboardStat(
      id: 'orders',
      label: 'Orders',
      icon: Icons.shopping_bag_outlined,
      color: const Color(0xFF00D67D),
      getValue: (data) => '${data.pendingOrders}',
      route: 'orders',
    ),
    DashboardStat(
      id: 'revenue',
      label: 'Revenue',
      icon: Icons.currency_rupee,
      color: const Color(0xFF42A5F5),
      getValue: (data) => _formatCurrency(data.todayRevenue),
      route: 'analytics',
    ),
    DashboardStat(
      id: 'lowStock',
      label: 'Low Stock',
      icon: Icons.warning_amber_outlined,
      color: const Color(0xFFEF5350),
      getValue: (data) => '${data.lowStockItems}',
      route: 'products',
    ),
    DashboardStat(
      id: 'items',
      label: 'In Stock',
      icon: Icons.inventory_2_outlined,
      color: const Color(0xFF66BB6A),
      getValue: (data) => '${data.totalItems}',
      route: 'products',
    ),
  ];

  // ============ HOSPITALITY STATS ============
  static final List<DashboardStat> _hospitalityStats = [
    DashboardStat(
      id: 'checkIns',
      label: 'Check-ins',
      icon: Icons.login_outlined,
      color: const Color(0xFF00D67D),
      getValue: (data) => '${data.todayCheckIns}',
      route: 'bookings',
    ),
    DashboardStat(
      id: 'checkOuts',
      label: 'Check-outs',
      icon: Icons.logout_outlined,
      color: const Color(0xFFFFA726),
      getValue: (data) => '${data.todayCheckOuts}',
      route: 'bookings',
    ),
    DashboardStat(
      id: 'rooms',
      label: 'Available',
      icon: Icons.hotel_outlined,
      color: const Color(0xFF42A5F5),
      getValue: (data) => '${data.availableRooms}/${data.totalRooms}',
      route: 'rooms',
    ),
    DashboardStat(
      id: 'bookings',
      label: 'Bookings',
      icon: Icons.calendar_month_outlined,
      color: const Color(0xFF7E57C2),
      getValue: (data) => '${data.pendingOrders}',
      route: 'bookings',
    ),
  ];

  // ============ SERVICE STATS (Beauty, Healthcare, Legal, etc.) ============
  static final List<DashboardStat> _serviceStats = [
    DashboardStat(
      id: 'appointments',
      label: 'Appointments',
      icon: Icons.calendar_today_outlined,
      color: const Color(0xFF00D67D),
      getValue: (data) => '${data.todayAppointments}',
      route: 'appointments',
    ),
    DashboardStat(
      id: 'inquiries',
      label: 'Inquiries',
      icon: Icons.chat_bubble_outline,
      color: const Color(0xFFFFA726),
      getValue: (data) => '${data.newInquiries}',
      route: 'inquiries',
    ),
    DashboardStat(
      id: 'completed',
      label: 'Completed',
      icon: Icons.check_circle_outline,
      color: const Color(0xFF42A5F5),
      getValue: (data) => '${data.completedOrders}',
      route: 'history',
    ),
    DashboardStat(
      id: 'revenue',
      label: 'Revenue',
      icon: Icons.currency_rupee,
      color: const Color(0xFF66BB6A),
      getValue: (data) => _formatCurrency(data.todayRevenue),
      route: 'analytics',
    ),
  ];

  // ============ FITNESS STATS ============
  static final List<DashboardStat> _fitnessStats = [
    DashboardStat(
      id: 'classes',
      label: 'Classes',
      icon: Icons.fitness_center,
      color: const Color(0xFF00D67D),
      getValue: (data) => '${data.todayAppointments}',
      route: 'classes',
    ),
    DashboardStat(
      id: 'members',
      label: 'Check-ins',
      icon: Icons.people_outline,
      color: const Color(0xFF42A5F5),
      getValue: (data) => '${data.todayCheckIns}',
      route: 'members',
    ),
    DashboardStat(
      id: 'bookings',
      label: 'Bookings',
      icon: Icons.event_available,
      color: const Color(0xFFFFA726),
      getValue: (data) => '${data.pendingOrders}',
      route: 'bookings',
    ),
    DashboardStat(
      id: 'revenue',
      label: 'Revenue',
      icon: Icons.currency_rupee,
      color: const Color(0xFF66BB6A),
      getValue: (data) => _formatCurrency(data.todayRevenue),
      route: 'analytics',
    ),
  ];

  // ============ EDUCATION STATS ============
  static final List<DashboardStat> _educationStats = [
    DashboardStat(
      id: 'classes',
      label: 'Classes',
      icon: Icons.school_outlined,
      color: const Color(0xFF00D67D),
      getValue: (data) => '${data.todayAppointments}',
      route: 'classes',
    ),
    DashboardStat(
      id: 'students',
      label: 'Attendance',
      icon: Icons.people_outline,
      color: const Color(0xFF42A5F5),
      getValue: (data) => '${data.todayCheckIns}',
      route: 'attendance',
    ),
    DashboardStat(
      id: 'inquiries',
      label: 'Inquiries',
      icon: Icons.chat_bubble_outline,
      color: const Color(0xFFFFA726),
      getValue: (data) => '${data.newInquiries}',
      route: 'inquiries',
    ),
    DashboardStat(
      id: 'revenue',
      label: 'Revenue',
      icon: Icons.currency_rupee,
      color: const Color(0xFF66BB6A),
      getValue: (data) => _formatCurrency(data.todayRevenue),
      route: 'analytics',
    ),
  ];

  // ============ PROFESSIONAL STATS ============
  static final List<DashboardStat> _professionalStats = [
    DashboardStat(
      id: 'projects',
      label: 'Projects',
      icon: Icons.work_outline,
      color: const Color(0xFF00D67D),
      getValue: (data) => '${data.pendingOrders}',
      route: 'projects',
    ),
    DashboardStat(
      id: 'meetings',
      label: 'Meetings',
      icon: Icons.videocam_outlined,
      color: const Color(0xFF42A5F5),
      getValue: (data) => '${data.todayAppointments}',
      route: 'meetings',
    ),
    DashboardStat(
      id: 'inquiries',
      label: 'Inquiries',
      icon: Icons.chat_bubble_outline,
      color: const Color(0xFFFFA726),
      getValue: (data) => '${data.newInquiries}',
      route: 'inquiries',
    ),
    DashboardStat(
      id: 'revenue',
      label: 'Revenue',
      icon: Icons.currency_rupee,
      color: const Color(0xFF66BB6A),
      getValue: (data) => _formatCurrency(data.todayRevenue),
      route: 'analytics',
    ),
  ];

  // ============ FOOD QUICK ACTIONS ============
  static const List<QuickAction> _foodActions = [
    QuickAction(
      id: 'orders',
      label: 'Orders',
      subtitle: 'View & manage orders',
      icon: Icons.receipt_long_outlined,
      color: Color(0xFF00D67D),
      route: 'orders',
    ),
    QuickAction(
      id: 'menu',
      label: 'Menu',
      subtitle: 'Edit menu items',
      icon: Icons.restaurant_menu,
      color: Color(0xFFFFA726),
      route: 'menu',
    ),
    QuickAction(
      id: 'tables',
      label: 'Tables',
      subtitle: 'Manage reservations',
      icon: Icons.table_restaurant,
      color: Color(0xFF42A5F5),
      route: 'tables',
    ),
  ];

  // ============ RETAIL QUICK ACTIONS ============
  static const List<QuickAction> _retailActions = [
    QuickAction(
      id: 'orders',
      label: 'Orders',
      subtitle: 'View & manage orders',
      icon: Icons.shopping_bag_outlined,
      color: Color(0xFF00D67D),
      route: 'orders',
    ),
    QuickAction(
      id: 'products',
      label: 'Products',
      subtitle: 'Manage inventory',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFF42A5F5),
      route: 'products',
    ),
    QuickAction(
      id: 'add',
      label: 'Add Product',
      subtitle: 'List new product',
      icon: Icons.add_box_outlined,
      color: Color(0xFFFFA726),
      route: 'add_product',
    ),
  ];

  // ============ HOSPITALITY QUICK ACTIONS ============
  static const List<QuickAction> _hospitalityActions = [
    QuickAction(
      id: 'bookings',
      label: 'Bookings',
      subtitle: 'View reservations',
      icon: Icons.calendar_month_outlined,
      color: Color(0xFF00D67D),
      route: 'bookings',
    ),
    QuickAction(
      id: 'rooms',
      label: 'Rooms',
      subtitle: 'Manage room types',
      icon: Icons.hotel_outlined,
      color: Color(0xFF42A5F5),
      route: 'rooms',
    ),
    QuickAction(
      id: 'checkins',
      label: 'Check-ins',
      subtitle: "Today's arrivals",
      icon: Icons.login_outlined,
      color: Color(0xFFFFA726),
      route: 'checkins',
    ),
  ];

  // ============ SERVICE QUICK ACTIONS ============
  static const List<QuickAction> _serviceActions = [
    QuickAction(
      id: 'appointments',
      label: 'Appointments',
      subtitle: 'View schedule',
      icon: Icons.calendar_today_outlined,
      color: Color(0xFF00D67D),
      route: 'appointments',
    ),
    QuickAction(
      id: 'services',
      label: 'Services',
      subtitle: 'Manage offerings',
      icon: Icons.build_outlined,
      color: Color(0xFF42A5F5),
      route: 'services',
    ),
    QuickAction(
      id: 'clients',
      label: 'Clients',
      subtitle: 'Customer list',
      icon: Icons.people_outline,
      color: Color(0xFFFFA726),
      route: 'clients',
    ),
  ];

  // ============ FITNESS QUICK ACTIONS ============
  static const List<QuickAction> _fitnessActions = [
    QuickAction(
      id: 'classes',
      label: 'Classes',
      subtitle: 'View schedule',
      icon: Icons.fitness_center,
      color: Color(0xFF00D67D),
      route: 'classes',
    ),
    QuickAction(
      id: 'members',
      label: 'Members',
      subtitle: 'Manage memberships',
      icon: Icons.card_membership,
      color: Color(0xFF42A5F5),
      route: 'members',
    ),
    QuickAction(
      id: 'trainers',
      label: 'Trainers',
      subtitle: 'Staff schedule',
      icon: Icons.sports,
      color: Color(0xFFFFA726),
      route: 'trainers',
    ),
  ];

  // ============ EDUCATION QUICK ACTIONS ============
  static const List<QuickAction> _educationActions = [
    QuickAction(
      id: 'classes',
      label: 'Classes',
      subtitle: 'View schedule',
      icon: Icons.school_outlined,
      color: Color(0xFF00D67D),
      route: 'classes',
    ),
    QuickAction(
      id: 'students',
      label: 'Students',
      subtitle: 'Manage students',
      icon: Icons.people_outline,
      color: Color(0xFF42A5F5),
      route: 'students',
    ),
    QuickAction(
      id: 'courses',
      label: 'Courses',
      subtitle: 'Course catalog',
      icon: Icons.menu_book_outlined,
      color: Color(0xFFFFA726),
      route: 'courses',
    ),
  ];

  // ============ PROFESSIONAL QUICK ACTIONS ============
  static const List<QuickAction> _professionalActions = [
    QuickAction(
      id: 'projects',
      label: 'Projects',
      subtitle: 'Active projects',
      icon: Icons.work_outline,
      color: Color(0xFF00D67D),
      route: 'projects',
    ),
    QuickAction(
      id: 'portfolio',
      label: 'Portfolio',
      subtitle: 'Showcase work',
      icon: Icons.collections_outlined,
      color: Color(0xFF42A5F5),
      route: 'portfolio',
    ),
    QuickAction(
      id: 'clients',
      label: 'Clients',
      subtitle: 'Client list',
      icon: Icons.people_outline,
      color: Color(0xFFFFA726),
      route: 'clients',
    ),
  ];

  /// Format currency
  static String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
