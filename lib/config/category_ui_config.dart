import 'package:flutter/material.dart';
import '../models/business_category_config.dart';
import '../models/item_model.dart';
import '../models/booking_model.dart';

/// UI Configuration for each business category
/// Maps generic model types to category-specific labels
///
/// Example: ItemType.room shows as "Room" for hotels, "Suite" for resorts
/// Example: BookingType.order shows as "Order" for retail, "Reservation" for restaurants
class CategoryUIConfig {
  final BusinessCategory category;

  // Tab labels
  final String itemsTabLabel;      // "Products", "Menu", "Rooms", "Services", etc.
  final String bookingsTabLabel;   // "Orders", "Bookings", "Appointments", etc.

  // Item labels
  final String itemSingular;       // "Product", "Menu Item", "Room", "Service"
  final String itemPlural;         // "Products", "Menu Items", "Rooms", "Services"

  // Booking labels
  final String bookingSingular;    // "Order", "Booking", "Appointment"
  final String bookingPlural;      // "Orders", "Bookings", "Appointments"

  // Action labels
  final String addItemLabel;       // "Add Product", "Add Menu Item", etc.
  final String newBookingLabel;    // "New Order", "New Booking", etc.

  // Empty state messages
  final String noItemsMessage;
  final String noBookingsMessage;

  // Default ItemType for this category
  final ItemType defaultItemType;

  // Default BookingType for this category
  final BookingType defaultBookingType;

  // Icons
  final IconData itemIcon;
  final IconData bookingIcon;

  const CategoryUIConfig({
    required this.category,
    required this.itemsTabLabel,
    required this.bookingsTabLabel,
    required this.itemSingular,
    required this.itemPlural,
    required this.bookingSingular,
    required this.bookingPlural,
    required this.addItemLabel,
    required this.newBookingLabel,
    required this.noItemsMessage,
    required this.noBookingsMessage,
    required this.defaultItemType,
    required this.defaultBookingType,
    required this.itemIcon,
    required this.bookingIcon,
  });

  /// Get UI config for a business category
  static CategoryUIConfig getConfig(BusinessCategory? category) {
    if (category == null) return _defaultConfig;

    return _configs[category] ?? _defaultConfig;
  }

  /// Get UI config from category string
  static CategoryUIConfig getConfigFromString(String? categoryId) {
    if (categoryId == null) return _defaultConfig;

    final category = BusinessCategoryExtension.fromString(categoryId);
    return getConfig(category);
  }

  // === CATEGORY CONFIGURATIONS ===

  static const Map<BusinessCategory, CategoryUIConfig> _configs = {
    // HOSPITALITY - Hotels, Resorts
    BusinessCategory.hospitality: CategoryUIConfig(
      category: BusinessCategory.hospitality,
      itemsTabLabel: 'Rooms',
      bookingsTabLabel: 'Bookings',
      itemSingular: 'Room',
      itemPlural: 'Rooms',
      bookingSingular: 'Booking',
      bookingPlural: 'Bookings',
      addItemLabel: 'Add Room',
      newBookingLabel: 'New Booking',
      noItemsMessage: 'No rooms added yet',
      noBookingsMessage: 'No bookings yet',
      defaultItemType: ItemType.room,
      defaultBookingType: BookingType.roomBooking,
      itemIcon: Icons.hotel,
      bookingIcon: Icons.calendar_today,
    ),

    // FOOD & BEVERAGE - Restaurants, Cafes
    BusinessCategory.foodBeverage: CategoryUIConfig(
      category: BusinessCategory.foodBeverage,
      itemsTabLabel: 'Menu',
      bookingsTabLabel: 'Orders',
      itemSingular: 'Menu Item',
      itemPlural: 'Menu Items',
      bookingSingular: 'Order',
      bookingPlural: 'Orders',
      addItemLabel: 'Add Menu Item',
      newBookingLabel: 'New Order',
      noItemsMessage: 'No menu items added yet',
      noBookingsMessage: 'No orders yet',
      defaultItemType: ItemType.menu,
      defaultBookingType: BookingType.foodOrder,
      itemIcon: Icons.restaurant_menu,
      bookingIcon: Icons.receipt_long,
    ),

    // GROCERY - Supermarkets, Kirana
    BusinessCategory.grocery: CategoryUIConfig(
      category: BusinessCategory.grocery,
      itemsTabLabel: 'Products',
      bookingsTabLabel: 'Orders',
      itemSingular: 'Product',
      itemPlural: 'Products',
      bookingSingular: 'Order',
      bookingPlural: 'Orders',
      addItemLabel: 'Add Product',
      newBookingLabel: 'New Order',
      noItemsMessage: 'No products added yet',
      noBookingsMessage: 'No orders yet',
      defaultItemType: ItemType.product,
      defaultBookingType: BookingType.order,
      itemIcon: Icons.shopping_basket,
      bookingIcon: Icons.shopping_cart,
    ),

    // RETAIL - Shops, Boutiques
    BusinessCategory.retail: CategoryUIConfig(
      category: BusinessCategory.retail,
      itemsTabLabel: 'Products',
      bookingsTabLabel: 'Orders',
      itemSingular: 'Product',
      itemPlural: 'Products',
      bookingSingular: 'Order',
      bookingPlural: 'Orders',
      addItemLabel: 'Add Product',
      newBookingLabel: 'New Order',
      noItemsMessage: 'No products added yet',
      noBookingsMessage: 'No orders yet',
      defaultItemType: ItemType.product,
      defaultBookingType: BookingType.order,
      itemIcon: Icons.storefront,
      bookingIcon: Icons.shopping_bag,
    ),

    // BEAUTY & WELLNESS - Salons, Spas
    BusinessCategory.beautyWellness: CategoryUIConfig(
      category: BusinessCategory.beautyWellness,
      itemsTabLabel: 'Services',
      bookingsTabLabel: 'Appointments',
      itemSingular: 'Service',
      itemPlural: 'Services',
      bookingSingular: 'Appointment',
      bookingPlural: 'Appointments',
      addItemLabel: 'Add Service',
      newBookingLabel: 'New Appointment',
      noItemsMessage: 'No services added yet',
      noBookingsMessage: 'No appointments yet',
      defaultItemType: ItemType.service,
      defaultBookingType: BookingType.appointment,
      itemIcon: Icons.spa,
      bookingIcon: Icons.calendar_month,
    ),

    // HEALTHCARE - Clinics, Doctors
    BusinessCategory.healthcare: CategoryUIConfig(
      category: BusinessCategory.healthcare,
      itemsTabLabel: 'Services',
      bookingsTabLabel: 'Appointments',
      itemSingular: 'Service',
      itemPlural: 'Services',
      bookingSingular: 'Appointment',
      bookingPlural: 'Appointments',
      addItemLabel: 'Add Service',
      newBookingLabel: 'New Appointment',
      noItemsMessage: 'No services added yet',
      noBookingsMessage: 'No appointments yet',
      defaultItemType: ItemType.service,
      defaultBookingType: BookingType.appointment,
      itemIcon: Icons.medical_services,
      bookingIcon: Icons.event_available,
    ),

    // EDUCATION - Schools, Tutors
    BusinessCategory.education: CategoryUIConfig(
      category: BusinessCategory.education,
      itemsTabLabel: 'Courses',
      bookingsTabLabel: 'Enrollments',
      itemSingular: 'Course',
      itemPlural: 'Courses',
      bookingSingular: 'Enrollment',
      bookingPlural: 'Enrollments',
      addItemLabel: 'Add Course',
      newBookingLabel: 'New Enrollment',
      noItemsMessage: 'No courses added yet',
      noBookingsMessage: 'No enrollments yet',
      defaultItemType: ItemType.course,
      defaultBookingType: BookingType.enrollment,
      itemIcon: Icons.school,
      bookingIcon: Icons.how_to_reg,
    ),

    // FITNESS - Gyms, Studios
    BusinessCategory.fitness: CategoryUIConfig(
      category: BusinessCategory.fitness,
      itemsTabLabel: 'Classes',
      bookingsTabLabel: 'Bookings',
      itemSingular: 'Class',
      itemPlural: 'Classes',
      bookingSingular: 'Booking',
      bookingPlural: 'Bookings',
      addItemLabel: 'Add Class',
      newBookingLabel: 'New Booking',
      noItemsMessage: 'No classes added yet',
      noBookingsMessage: 'No bookings yet',
      defaultItemType: ItemType.service,
      defaultBookingType: BookingType.appointment,
      itemIcon: Icons.fitness_center,
      bookingIcon: Icons.event,
    ),

    // AUTOMOTIVE - Car Services
    BusinessCategory.automotive: CategoryUIConfig(
      category: BusinessCategory.automotive,
      itemsTabLabel: 'Services',
      bookingsTabLabel: 'Appointments',
      itemSingular: 'Service',
      itemPlural: 'Services',
      bookingSingular: 'Appointment',
      bookingPlural: 'Appointments',
      addItemLabel: 'Add Service',
      newBookingLabel: 'New Appointment',
      noItemsMessage: 'No services added yet',
      noBookingsMessage: 'No appointments yet',
      defaultItemType: ItemType.service,
      defaultBookingType: BookingType.appointment,
      itemIcon: Icons.directions_car,
      bookingIcon: Icons.build,
    ),

    // REAL ESTATE - Property Listings
    BusinessCategory.realEstate: CategoryUIConfig(
      category: BusinessCategory.realEstate,
      itemsTabLabel: 'Properties',
      bookingsTabLabel: 'Inquiries',
      itemSingular: 'Property',
      itemPlural: 'Properties',
      bookingSingular: 'Inquiry',
      bookingPlural: 'Inquiries',
      addItemLabel: 'Add Property',
      newBookingLabel: 'New Inquiry',
      noItemsMessage: 'No properties added yet',
      noBookingsMessage: 'No inquiries yet',
      defaultItemType: ItemType.property,
      defaultBookingType: BookingType.appointment,
      itemIcon: Icons.apartment,
      bookingIcon: Icons.contact_phone,
    ),

    // TRAVEL & TOURISM - Tour Packages
    BusinessCategory.travelTourism: CategoryUIConfig(
      category: BusinessCategory.travelTourism,
      itemsTabLabel: 'Packages',
      bookingsTabLabel: 'Bookings',
      itemSingular: 'Package',
      itemPlural: 'Packages',
      bookingSingular: 'Booking',
      bookingPlural: 'Bookings',
      addItemLabel: 'Add Package',
      newBookingLabel: 'New Booking',
      noItemsMessage: 'No packages added yet',
      noBookingsMessage: 'No bookings yet',
      defaultItemType: ItemType.package,
      defaultBookingType: BookingType.eventBooking,
      itemIcon: Icons.flight,
      bookingIcon: Icons.luggage,
    ),

    // ENTERTAINMENT - Events, Gaming
    BusinessCategory.entertainment: CategoryUIConfig(
      category: BusinessCategory.entertainment,
      itemsTabLabel: 'Events',
      bookingsTabLabel: 'Bookings',
      itemSingular: 'Event',
      itemPlural: 'Events',
      bookingSingular: 'Booking',
      bookingPlural: 'Bookings',
      addItemLabel: 'Add Event',
      newBookingLabel: 'New Booking',
      noItemsMessage: 'No events added yet',
      noBookingsMessage: 'No bookings yet',
      defaultItemType: ItemType.package,
      defaultBookingType: BookingType.eventBooking,
      itemIcon: Icons.celebration,
      bookingIcon: Icons.confirmation_number,
    ),

    // PET SERVICES
    BusinessCategory.petServices: CategoryUIConfig(
      category: BusinessCategory.petServices,
      itemsTabLabel: 'Services',
      bookingsTabLabel: 'Appointments',
      itemSingular: 'Service',
      itemPlural: 'Services',
      bookingSingular: 'Appointment',
      bookingPlural: 'Appointments',
      addItemLabel: 'Add Service',
      newBookingLabel: 'New Appointment',
      noItemsMessage: 'No services added yet',
      noBookingsMessage: 'No appointments yet',
      defaultItemType: ItemType.service,
      defaultBookingType: BookingType.appointment,
      itemIcon: Icons.pets,
      bookingIcon: Icons.schedule,
    ),

    // HOME SERVICES
    BusinessCategory.homeServices: CategoryUIConfig(
      category: BusinessCategory.homeServices,
      itemsTabLabel: 'Services',
      bookingsTabLabel: 'Bookings',
      itemSingular: 'Service',
      itemPlural: 'Services',
      bookingSingular: 'Booking',
      bookingPlural: 'Bookings',
      addItemLabel: 'Add Service',
      newBookingLabel: 'New Booking',
      noItemsMessage: 'No services added yet',
      noBookingsMessage: 'No bookings yet',
      defaultItemType: ItemType.service,
      defaultBookingType: BookingType.appointment,
      itemIcon: Icons.home_repair_service,
      bookingIcon: Icons.handyman,
    ),

    // TECHNOLOGY
    BusinessCategory.technology: CategoryUIConfig(
      category: BusinessCategory.technology,
      itemsTabLabel: 'Services',
      bookingsTabLabel: 'Projects',
      itemSingular: 'Service',
      itemPlural: 'Services',
      bookingSingular: 'Project',
      bookingPlural: 'Projects',
      addItemLabel: 'Add Service',
      newBookingLabel: 'New Project',
      noItemsMessage: 'No services added yet',
      noBookingsMessage: 'No projects yet',
      defaultItemType: ItemType.service,
      defaultBookingType: BookingType.appointment,
      itemIcon: Icons.computer,
      bookingIcon: Icons.work,
    ),

    // FINANCIAL
    BusinessCategory.financial: CategoryUIConfig(
      category: BusinessCategory.financial,
      itemsTabLabel: 'Services',
      bookingsTabLabel: 'Appointments',
      itemSingular: 'Service',
      itemPlural: 'Services',
      bookingSingular: 'Appointment',
      bookingPlural: 'Appointments',
      addItemLabel: 'Add Service',
      newBookingLabel: 'New Appointment',
      noItemsMessage: 'No services added yet',
      noBookingsMessage: 'No appointments yet',
      defaultItemType: ItemType.service,
      defaultBookingType: BookingType.appointment,
      itemIcon: Icons.account_balance,
      bookingIcon: Icons.event_note,
    ),

    // LEGAL
    BusinessCategory.legal: CategoryUIConfig(
      category: BusinessCategory.legal,
      itemsTabLabel: 'Services',
      bookingsTabLabel: 'Consultations',
      itemSingular: 'Service',
      itemPlural: 'Services',
      bookingSingular: 'Consultation',
      bookingPlural: 'Consultations',
      addItemLabel: 'Add Service',
      newBookingLabel: 'New Consultation',
      noItemsMessage: 'No services added yet',
      noBookingsMessage: 'No consultations yet',
      defaultItemType: ItemType.service,
      defaultBookingType: BookingType.appointment,
      itemIcon: Icons.gavel,
      bookingIcon: Icons.schedule_send,
    ),

    // PROFESSIONAL
    BusinessCategory.professional: CategoryUIConfig(
      category: BusinessCategory.professional,
      itemsTabLabel: 'Services',
      bookingsTabLabel: 'Appointments',
      itemSingular: 'Service',
      itemPlural: 'Services',
      bookingSingular: 'Appointment',
      bookingPlural: 'Appointments',
      addItemLabel: 'Add Service',
      newBookingLabel: 'New Appointment',
      noItemsMessage: 'No services added yet',
      noBookingsMessage: 'No appointments yet',
      defaultItemType: ItemType.service,
      defaultBookingType: BookingType.appointment,
      itemIcon: Icons.work,
      bookingIcon: Icons.people,
    ),

    // TRANSPORTATION
    BusinessCategory.transportation: CategoryUIConfig(
      category: BusinessCategory.transportation,
      itemsTabLabel: 'Vehicles',
      bookingsTabLabel: 'Bookings',
      itemSingular: 'Vehicle',
      itemPlural: 'Vehicles',
      bookingSingular: 'Booking',
      bookingPlural: 'Bookings',
      addItemLabel: 'Add Vehicle',
      newBookingLabel: 'New Booking',
      noItemsMessage: 'No vehicles added yet',
      noBookingsMessage: 'No bookings yet',
      defaultItemType: ItemType.vehicle,
      defaultBookingType: BookingType.reservation,
      itemIcon: Icons.local_shipping,
      bookingIcon: Icons.directions,
    ),

    // ART & CREATIVE
    BusinessCategory.artCreative: CategoryUIConfig(
      category: BusinessCategory.artCreative,
      itemsTabLabel: 'Services',
      bookingsTabLabel: 'Projects',
      itemSingular: 'Service',
      itemPlural: 'Services',
      bookingSingular: 'Project',
      bookingPlural: 'Projects',
      addItemLabel: 'Add Service',
      newBookingLabel: 'New Project',
      noItemsMessage: 'No services added yet',
      noBookingsMessage: 'No projects yet',
      defaultItemType: ItemType.service,
      defaultBookingType: BookingType.appointment,
      itemIcon: Icons.palette,
      bookingIcon: Icons.brush,
    ),

    // CONSTRUCTION
    BusinessCategory.construction: CategoryUIConfig(
      category: BusinessCategory.construction,
      itemsTabLabel: 'Services',
      bookingsTabLabel: 'Projects',
      itemSingular: 'Service',
      itemPlural: 'Services',
      bookingSingular: 'Project',
      bookingPlural: 'Projects',
      addItemLabel: 'Add Service',
      newBookingLabel: 'New Project',
      noItemsMessage: 'No services added yet',
      noBookingsMessage: 'No projects yet',
      defaultItemType: ItemType.service,
      defaultBookingType: BookingType.appointment,
      itemIcon: Icons.construction,
      bookingIcon: Icons.engineering,
    ),

    // AGRICULTURE
    BusinessCategory.agriculture: CategoryUIConfig(
      category: BusinessCategory.agriculture,
      itemsTabLabel: 'Products',
      bookingsTabLabel: 'Orders',
      itemSingular: 'Product',
      itemPlural: 'Products',
      bookingSingular: 'Order',
      bookingPlural: 'Orders',
      addItemLabel: 'Add Product',
      newBookingLabel: 'New Order',
      noItemsMessage: 'No products added yet',
      noBookingsMessage: 'No orders yet',
      defaultItemType: ItemType.product,
      defaultBookingType: BookingType.order,
      itemIcon: Icons.agriculture,
      bookingIcon: Icons.inventory,
    ),

    // MANUFACTURING
    BusinessCategory.manufacturing: CategoryUIConfig(
      category: BusinessCategory.manufacturing,
      itemsTabLabel: 'Products',
      bookingsTabLabel: 'Orders',
      itemSingular: 'Product',
      itemPlural: 'Products',
      bookingSingular: 'Order',
      bookingPlural: 'Orders',
      addItemLabel: 'Add Product',
      newBookingLabel: 'New Order',
      noItemsMessage: 'No products added yet',
      noBookingsMessage: 'No orders yet',
      defaultItemType: ItemType.product,
      defaultBookingType: BookingType.order,
      itemIcon: Icons.factory,
      bookingIcon: Icons.receipt,
    ),

    // WEDDING & EVENTS
    BusinessCategory.weddingEvents: CategoryUIConfig(
      category: BusinessCategory.weddingEvents,
      itemsTabLabel: 'Packages',
      bookingsTabLabel: 'Events',
      itemSingular: 'Package',
      itemPlural: 'Packages',
      bookingSingular: 'Event',
      bookingPlural: 'Events',
      addItemLabel: 'Add Package',
      newBookingLabel: 'New Event',
      noItemsMessage: 'No packages added yet',
      noBookingsMessage: 'No events yet',
      defaultItemType: ItemType.package,
      defaultBookingType: BookingType.eventBooking,
      itemIcon: Icons.cake,
      bookingIcon: Icons.event,
    ),
  };

  /// Default config for unknown categories
  static const _defaultConfig = CategoryUIConfig(
    category: BusinessCategory.professional,
    itemsTabLabel: 'Items',
    bookingsTabLabel: 'Bookings',
    itemSingular: 'Item',
    itemPlural: 'Items',
    bookingSingular: 'Booking',
    bookingPlural: 'Bookings',
    addItemLabel: 'Add Item',
    newBookingLabel: 'New Booking',
    noItemsMessage: 'No items added yet',
    noBookingsMessage: 'No bookings yet',
    defaultItemType: ItemType.service,
    defaultBookingType: BookingType.appointment,
    itemIcon: Icons.inventory_2,
    bookingIcon: Icons.event,
  );
}

/// Extension methods for easy access
extension BusinessModelUIExtension on BusinessCategory {
  CategoryUIConfig get uiConfig => CategoryUIConfig.getConfig(this);
}
