import 'package:flutter/material.dart';

/// Master categories covering all major business domains
enum BusinessCategory {
  hospitality,       // Hotels, Resorts, Guesthouses
  foodBeverage,      // Restaurants, Cafes, Bakeries
  retail,            // Shops, Stores, Boutiques
  beautyWellness,    // Salons, Spas, Beauty Parlors
  healthcare,        // Clinics, Doctors, Pharmacies
  education,         // Schools, Tutors, Training Centers
  fitness,           // Gyms, Yoga, Sports Academies
  automotive,        // Car Services, Dealerships, Workshops
  realEstate,        // Property, Rentals, Brokers
  travelTourism,     // Travel Agencies, Tour Operators
  entertainment,     // Events, Gaming, Cinema
  petServices,       // Pet Shops, Grooming, Boarding
  homeServices,      // Plumbing, Electrical, Cleaning
  technology,        // IT Services, Software, Tech Repair
  financial,         // Banking, Insurance, Investments
  legal,             // Lawyers, Notaries, Legal Services
  professional,      // Consultants, HR, Marketing Agencies
  transportation,    // Courier, Logistics, Taxi
  artCreative,       // Photography, Design, Art Studios
  construction,      // Contractors, Interior Design
  agriculture,       // Farms, Nurseries, Dairy
  manufacturing,     // Factories, Workshops, Production
  weddingEvents,     // Wedding Planning, Decorators
  grocery,           // Supermarkets, Kirana, Wholesale
}

/// Features available for each business category
enum BusinessFeature {
  rooms,        // For hospitality - manage room types
  menu,         // For food & beverage - manage menu items
  products,     // For retail - manage product catalog
  services,     // For services - manage service offerings
  appointments, // For healthcare, services - booking system
  courses,      // For education - manage courses/classes
  portfolio,    // For professional, services - showcase work
  classes,      // For fitness, education - group classes
  bookings,     // For hospitality - room bookings
  orders,       // For retail, food - customer orders
  vehicles,     // For automotive - manage vehicles/inventory
  properties,   // For real estate - property listings
  packages,     // For travel, events - tour/event packages
}

/// Configuration for each business category
class BusinessCategoryConfig {
  final BusinessCategory category;
  final String id;
  final String displayName;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> subTypes;
  final List<BusinessFeature> features;
  final List<CategorySetupField> setupFields;

  const BusinessCategoryConfig({
    required this.category,
    required this.id,
    required this.displayName,
    required this.description,
    required this.icon,
    required this.color,
    required this.subTypes,
    required this.features,
    required this.setupFields,
  });

  /// Get all category configurations
  static List<BusinessCategoryConfig> get all => [
        hospitality,
        foodBeverage,
        grocery,
        retail,
        beautyWellness,
        healthcare,
        education,
        fitness,
        automotive,
        realEstate,
        travelTourism,
        entertainment,
        petServices,
        homeServices,
        technology,
        financial,
        legal,
        professional,
        transportation,
        artCreative,
        construction,
        agriculture,
        manufacturing,
        weddingEvents,
      ];

  /// Get config by category enum
  static BusinessCategoryConfig getConfig(BusinessCategory category) {
    return all.firstWhere((c) => c.category == category);
  }

  /// Get config by category id string
  static BusinessCategoryConfig? getConfigById(String id) {
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Map old businessType to new category
  static BusinessCategory? getCategoryFromBusinessType(String businessType) {
    return _businessTypeToCategory[businessType];
  }

  // ============ HOSPITALITY ============
  static const hospitality = BusinessCategoryConfig(
    category: BusinessCategory.hospitality,
    id: 'hospitality',
    displayName: 'Hospitality',
    description: 'Hotels, Resorts & Stays',
    icon: Icons.hotel,
    color: Color(0xFF6366F1), // Indigo
    subTypes: [
      'Hotel',
      'Resort',
      'Guesthouse',
      'Hostel',
      'Villa',
      'Homestay',
      'Motel',
      'Service Apartment',
    ],
    features: [
      BusinessFeature.rooms,
      BusinessFeature.bookings,
      BusinessFeature.services,
    ],
    setupFields: [
      CategorySetupField(
        id: 'checkInTime',
        label: 'Check-in Time',
        type: FieldType.time,
        defaultValue: '14:00',
      ),
      CategorySetupField(
        id: 'checkOutTime',
        label: 'Check-out Time',
        type: FieldType.time,
        defaultValue: '11:00',
      ),
      CategorySetupField(
        id: 'amenities',
        label: 'Amenities',
        type: FieldType.multiSelect,
        options: [
          'WiFi',
          'Parking',
          'Pool',
          'Gym',
          'Restaurant',
          'Room Service',
          'AC',
          'Pet Friendly',
        ],
      ),
    ],
  );

  // ============ FOOD & BEVERAGE ============
  static const foodBeverage = BusinessCategoryConfig(
    category: BusinessCategory.foodBeverage,
    id: 'food_beverage',
    displayName: 'Food & Beverage',
    description: 'Restaurants, Cafes & Bakeries',
    icon: Icons.restaurant,
    color: Color(0xFFF59E0B), // Amber
    subTypes: [
      'Restaurant',
      'Cafe',
      'Bakery',
      'Bar & Pub',
      'Cloud Kitchen',
      'Food Truck',
      'Fast Food',
      'Fine Dining',
      'Catering',
      'Ice Cream & Desserts',
    ],
    features: [
      BusinessFeature.menu,
      BusinessFeature.orders,
      BusinessFeature.services,
    ],
    setupFields: [
      CategorySetupField(
        id: 'cuisineTypes',
        label: 'Cuisine Types',
        type: FieldType.multiSelect,
        options: [
          'Indian',
          'Chinese',
          'Italian',
          'Mexican',
          'Thai',
          'Japanese',
          'American',
          'Continental',
        ],
      ),
      CategorySetupField(
        id: 'diningOptions',
        label: 'Dining Options',
        type: FieldType.multiSelect,
        options: ['Dine-in', 'Takeaway', 'Delivery', 'Drive-through'],
      ),
      CategorySetupField(
        id: 'foodType',
        label: 'Food Type',
        type: FieldType.dropdown,
        options: ['Pure Veg', 'Non-Veg', 'Both'],
      ),
    ],
  );

  // ============ GROCERY ============
  static const grocery = BusinessCategoryConfig(
    category: BusinessCategory.grocery,
    id: 'grocery',
    displayName: 'Grocery & Essentials',
    description: 'Supermarkets, Kirana & Wholesale',
    icon: Icons.shopping_basket,
    color: Color(0xFF22C55E), // Green
    subTypes: [
      'Supermarket',
      'Kirana Store',
      'Wholesale',
      'Organic Store',
      'Fruits & Vegetables',
      'Dairy Shop',
      'Meat & Fish',
      'Convenience Store',
    ],
    features: [
      BusinessFeature.products,
      BusinessFeature.orders,
    ],
    setupFields: [
      CategorySetupField(
        id: 'productTypes',
        label: 'Product Types',
        type: FieldType.multiSelect,
        options: [
          'Groceries',
          'Fruits & Vegetables',
          'Dairy',
          'Meat & Fish',
          'Beverages',
          'Snacks',
          'Household',
          'Personal Care',
        ],
      ),
      CategorySetupField(
        id: 'deliveryOptions',
        label: 'Delivery Options',
        type: FieldType.multiSelect,
        options: ['Walk-in', 'Home Delivery', 'Store Pickup'],
      ),
    ],
  );

  // ============ RETAIL ============
  static const retail = BusinessCategoryConfig(
    category: BusinessCategory.retail,
    id: 'retail',
    displayName: 'Retail & Shopping',
    description: 'Shops, Stores & Boutiques',
    icon: Icons.storefront,
    color: Color(0xFF10B981), // Emerald
    subTypes: [
      'Clothing Store',
      'Electronics Store',
      'Boutique',
      'Jewelry Store',
      'Footwear Store',
      'Home & Furniture',
      'Sports & Outdoors',
      'Books & Stationery',
      'Gift Shop',
      'Mobile Store',
    ],
    features: [
      BusinessFeature.products,
      BusinessFeature.orders,
    ],
    setupFields: [
      CategorySetupField(
        id: 'productCategories',
        label: 'Product Categories',
        type: FieldType.multiSelect,
        options: [
          'Clothing',
          'Electronics',
          'Home & Living',
          'Beauty & Personal Care',
          'Jewelry & Accessories',
          'Sports & Fitness',
          'Books & Stationery',
        ],
      ),
      CategorySetupField(
        id: 'orderOptions',
        label: 'Order Options',
        type: FieldType.multiSelect,
        options: ['Walk-in', 'Online Orders', 'Home Delivery', 'Store Pickup'],
      ),
    ],
  );

  // ============ BEAUTY & WELLNESS ============
  static const beautyWellness = BusinessCategoryConfig(
    category: BusinessCategory.beautyWellness,
    id: 'beauty_wellness',
    displayName: 'Beauty & Wellness',
    description: 'Salons, Spas & Beauty Parlors',
    icon: Icons.spa,
    color: Color(0xFFEC4899), // Pink
    subTypes: [
      'Salon',
      'Spa',
      'Beauty Parlor',
      'Barbershop',
      'Nail Studio',
      'Makeup Studio',
      'Hair Studio',
      'Wellness Center',
      'Ayurvedic Center',
      'Tattoo Studio',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.appointments,
      BusinessFeature.products,
    ],
    setupFields: [
      CategorySetupField(
        id: 'serviceCategories',
        label: 'Services Offered',
        type: FieldType.multiSelect,
        options: [
          'Hair Styling',
          'Hair Coloring',
          'Skin Care',
          'Facial',
          'Nail Art',
          'Makeup',
          'Massage',
          'Waxing',
          'Threading',
          'Bridal Services',
        ],
      ),
      CategorySetupField(
        id: 'bookingType',
        label: 'Booking Type',
        type: FieldType.multiSelect,
        options: ['Walk-in', 'Appointment Only', 'Both'],
      ),
      CategorySetupField(
        id: 'genderServed',
        label: 'Gender Served',
        type: FieldType.dropdown,
        options: ['Men', 'Women', 'Unisex'],
      ),
    ],
  );

  // ============ HEALTHCARE ============
  static const healthcare = BusinessCategoryConfig(
    category: BusinessCategory.healthcare,
    id: 'healthcare',
    displayName: 'Healthcare',
    description: 'Clinics, Doctors & Pharmacies',
    icon: Icons.medical_services,
    color: Color(0xFFEF4444), // Red
    subTypes: [
      'Clinic',
      'Hospital',
      'Doctor',
      'Dentist',
      'Eye Care',
      'Pharmacy',
      'Diagnostic Center',
      'Physiotherapy',
      'Veterinary',
      'Mental Health',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'specializations',
        label: 'Specializations',
        type: FieldType.multiSelect,
        options: [
          'General Medicine',
          'Pediatrics',
          'Dermatology',
          'Cardiology',
          'Orthopedics',
          'Gynecology',
          'ENT',
          'Dental',
          'Eye Care',
        ],
      ),
      CategorySetupField(
        id: 'appointmentType',
        label: 'Consultation Type',
        type: FieldType.multiSelect,
        options: ['In-Person', 'Online/Video', 'Home Visit'],
      ),
    ],
  );

  // ============ EDUCATION ============
  static const education = BusinessCategoryConfig(
    category: BusinessCategory.education,
    id: 'education',
    displayName: 'Education & Training',
    description: 'Schools, Tutors & Coaching',
    icon: Icons.school,
    color: Color(0xFF3B82F6), // Blue
    subTypes: [
      'School',
      'College',
      'Coaching Center',
      'Tutor',
      'Training Institute',
      'Language School',
      'Music Academy',
      'Dance Academy',
      'Computer Training',
      'Driving School',
      'Preschool',
    ],
    features: [
      BusinessFeature.courses,
      BusinessFeature.classes,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'subjects',
        label: 'Subjects/Courses',
        type: FieldType.multiSelect,
        options: [
          'Mathematics',
          'Science',
          'English',
          'Programming',
          'Music',
          'Dance',
          'Art & Craft',
          'Languages',
          'Competitive Exams',
        ],
      ),
      CategorySetupField(
        id: 'classType',
        label: 'Class Type',
        type: FieldType.multiSelect,
        options: ['Individual', 'Group', 'Online', 'Hybrid'],
      ),
    ],
  );

  // ============ FITNESS ============
  static const fitness = BusinessCategoryConfig(
    category: BusinessCategory.fitness,
    id: 'fitness',
    displayName: 'Fitness & Sports',
    description: 'Gyms, Yoga & Sports Academies',
    icon: Icons.fitness_center,
    color: Color(0xFF8B5CF6), // Violet
    subTypes: [
      'Gym',
      'Yoga Studio',
      'Sports Academy',
      'Personal Trainer',
      'Martial Arts',
      'Swimming Pool',
      'Dance Studio',
      'Crossfit',
      'Sports Club',
      'Cricket Academy',
    ],
    features: [
      BusinessFeature.classes,
      BusinessFeature.appointments,
      BusinessFeature.services,
    ],
    setupFields: [
      CategorySetupField(
        id: 'activities',
        label: 'Activities Offered',
        type: FieldType.multiSelect,
        options: [
          'Weight Training',
          'Cardio',
          'Yoga',
          'Zumba',
          'CrossFit',
          'Martial Arts',
          'Swimming',
          'Dance',
          'Personal Training',
        ],
      ),
      CategorySetupField(
        id: 'membershipType',
        label: 'Membership Options',
        type: FieldType.multiSelect,
        options: ['Daily Pass', 'Monthly', 'Quarterly', 'Annual'],
      ),
    ],
  );

  // ============ AUTOMOTIVE ============
  static const automotive = BusinessCategoryConfig(
    category: BusinessCategory.automotive,
    id: 'automotive',
    displayName: 'Automotive',
    description: 'Car Services, Dealerships & Repair',
    icon: Icons.directions_car,
    color: Color(0xFF64748B), // Slate
    subTypes: [
      'Car Dealership',
      'Bike Dealership',
      'Car Service Center',
      'Bike Service Center',
      'Car Wash',
      'Tyre Shop',
      'Auto Parts',
      'Car Rental',
      'Bike Rental',
      'Driving School',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.vehicles,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'vehicleTypes',
        label: 'Vehicle Types',
        type: FieldType.multiSelect,
        options: ['Cars', 'Bikes', 'Scooters', 'Commercial Vehicles', 'Electric Vehicles'],
      ),
      CategorySetupField(
        id: 'servicesOffered',
        label: 'Services Offered',
        type: FieldType.multiSelect,
        options: [
          'Regular Service',
          'Repairs',
          'Denting & Painting',
          'Car Wash',
          'AC Service',
          'Tyre Service',
          'Insurance',
        ],
      ),
    ],
  );

  // ============ REAL ESTATE ============
  static const realEstate = BusinessCategoryConfig(
    category: BusinessCategory.realEstate,
    id: 'real_estate',
    displayName: 'Real Estate',
    description: 'Property, Rentals & Brokers',
    icon: Icons.apartment,
    color: Color(0xFF0EA5E9), // Sky Blue
    subTypes: [
      'Real Estate Agent',
      'Property Dealer',
      'Builder',
      'Construction Company',
      'Interior Designer',
      'PG/Hostel',
      'Co-working Space',
      'Warehouse',
    ],
    features: [
      BusinessFeature.properties,
      BusinessFeature.services,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'propertyTypes',
        label: 'Property Types',
        type: FieldType.multiSelect,
        options: [
          'Residential',
          'Commercial',
          'Industrial',
          'Land/Plots',
          'Rental',
          'PG/Hostels',
        ],
      ),
      CategorySetupField(
        id: 'servicesType',
        label: 'Services',
        type: FieldType.multiSelect,
        options: ['Buy/Sell', 'Rental', 'Lease', 'Property Management'],
      ),
    ],
  );

  // ============ TRAVEL & TOURISM ============
  static const travelTourism = BusinessCategoryConfig(
    category: BusinessCategory.travelTourism,
    id: 'travel_tourism',
    displayName: 'Travel & Tourism',
    description: 'Travel Agencies & Tour Operators',
    icon: Icons.flight,
    color: Color(0xFF06B6D4), // Cyan
    subTypes: [
      'Travel Agency',
      'Tour Operator',
      'Visa Services',
      'Passport Services',
      'Taxi Service',
      'Bus Service',
      'Adventure Tourism',
      'Pilgrimage Tours',
    ],
    features: [
      BusinessFeature.packages,
      BusinessFeature.bookings,
      BusinessFeature.services,
    ],
    setupFields: [
      CategorySetupField(
        id: 'tourTypes',
        label: 'Tour Types',
        type: FieldType.multiSelect,
        options: [
          'Domestic Tours',
          'International Tours',
          'Pilgrimage',
          'Adventure',
          'Honeymoon',
          'Corporate',
          'Group Tours',
        ],
      ),
      CategorySetupField(
        id: 'servicesOffered',
        label: 'Services',
        type: FieldType.multiSelect,
        options: ['Flight Booking', 'Hotel Booking', 'Visa', 'Passport', 'Travel Insurance'],
      ),
    ],
  );

  // ============ ENTERTAINMENT ============
  static const entertainment = BusinessCategoryConfig(
    category: BusinessCategory.entertainment,
    id: 'entertainment',
    displayName: 'Entertainment',
    description: 'Events, Gaming & Recreation',
    icon: Icons.celebration,
    color: Color(0xFFF97316), // Orange
    subTypes: [
      'Event Venue',
      'Banquet Hall',
      'Party Hall',
      'Gaming Zone',
      'Amusement Park',
      'Cinema',
      'Theatre',
      'Night Club',
      'Bowling Alley',
      'Escape Room',
    ],
    features: [
      BusinessFeature.bookings,
      BusinessFeature.packages,
      BusinessFeature.services,
    ],
    setupFields: [
      CategorySetupField(
        id: 'eventTypes',
        label: 'Event Types',
        type: FieldType.multiSelect,
        options: [
          'Weddings',
          'Corporate Events',
          'Birthday Parties',
          'Conferences',
          'Live Shows',
          'Private Parties',
        ],
      ),
      CategorySetupField(
        id: 'capacity',
        label: 'Capacity',
        type: FieldType.dropdown,
        options: ['Up to 50', '50-100', '100-300', '300-500', '500+'],
      ),
    ],
  );

  // ============ PET SERVICES ============
  static const petServices = BusinessCategoryConfig(
    category: BusinessCategory.petServices,
    id: 'pet_services',
    displayName: 'Pet Services',
    description: 'Pet Shops, Grooming & Boarding',
    icon: Icons.pets,
    color: Color(0xFFA855F7), // Purple
    subTypes: [
      'Pet Shop',
      'Pet Grooming',
      'Pet Boarding',
      'Pet Training',
      'Veterinary Clinic',
      'Pet Food Store',
      'Pet Accessories',
      'Pet Adoption',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.products,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'petTypes',
        label: 'Pet Types Served',
        type: FieldType.multiSelect,
        options: ['Dogs', 'Cats', 'Birds', 'Fish', 'Rabbits', 'Exotic Pets'],
      ),
      CategorySetupField(
        id: 'servicesOffered',
        label: 'Services',
        type: FieldType.multiSelect,
        options: ['Grooming', 'Boarding', 'Training', 'Daycare', 'Walking', 'Veterinary'],
      ),
    ],
  );

  // ============ HOME SERVICES ============
  static const homeServices = BusinessCategoryConfig(
    category: BusinessCategory.homeServices,
    id: 'home_services',
    displayName: 'Home Services',
    description: 'Plumbing, Electrical & Cleaning',
    icon: Icons.home_repair_service,
    color: Color(0xFF84CC16), // Lime
    subTypes: [
      'Plumber',
      'Electrician',
      'Carpenter',
      'Painter',
      'AC Service',
      'Pest Control',
      'Cleaning Service',
      'Appliance Repair',
      'Handyman',
      'Movers & Packers',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'serviceTypes',
        label: 'Service Types',
        type: FieldType.multiSelect,
        options: [
          'Plumbing',
          'Electrical',
          'Carpentry',
          'Painting',
          'AC/Refrigeration',
          'Pest Control',
          'Deep Cleaning',
          'Appliance Repair',
        ],
      ),
      CategorySetupField(
        id: 'serviceArea',
        label: 'Service Area',
        type: FieldType.dropdown,
        options: ['Within 5 km', 'Within 10 km', 'Within 25 km', 'City-wide'],
      ),
    ],
  );

  // ============ TECHNOLOGY ============
  static const technology = BusinessCategoryConfig(
    category: BusinessCategory.technology,
    id: 'technology',
    displayName: 'Technology & IT',
    description: 'IT Services, Software & Repair',
    icon: Icons.computer,
    color: Color(0xFF14B8A6), // Teal
    subTypes: [
      'IT Services',
      'Software Company',
      'Computer Repair',
      'Mobile Repair',
      'Web Development',
      'App Development',
      'Digital Marketing',
      'CCTV Installation',
      'Networking Services',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.appointments,
      BusinessFeature.portfolio,
    ],
    setupFields: [
      CategorySetupField(
        id: 'techServices',
        label: 'Services',
        type: FieldType.multiSelect,
        options: [
          'Software Development',
          'Web Development',
          'Mobile Apps',
          'Hardware Repair',
          'Networking',
          'Cloud Services',
          'Cybersecurity',
          'Digital Marketing',
        ],
      ),
      CategorySetupField(
        id: 'clientType',
        label: 'Client Type',
        type: FieldType.multiSelect,
        options: ['Individuals', 'SMBs', 'Enterprises', 'Startups'],
      ),
    ],
  );

  // ============ FINANCIAL ============
  static const financial = BusinessCategoryConfig(
    category: BusinessCategory.financial,
    id: 'financial',
    displayName: 'Financial Services',
    description: 'Banking, Insurance & Investments',
    icon: Icons.account_balance,
    color: Color(0xFF059669), // Emerald Dark
    subTypes: [
      'Bank',
      'Insurance Agent',
      'Investment Advisor',
      'Loan Agent',
      'CA Firm',
      'Tax Consultant',
      'Stock Broker',
      'Mutual Fund Distributor',
      'Money Exchange',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'financialServices',
        label: 'Services',
        type: FieldType.multiSelect,
        options: [
          'Savings Account',
          'Loans',
          'Insurance',
          'Investments',
          'Tax Filing',
          'Accounting',
          'Financial Planning',
        ],
      ),
      CategorySetupField(
        id: 'clientType',
        label: 'Client Type',
        type: FieldType.multiSelect,
        options: ['Individuals', 'Businesses', 'Corporates', 'NRIs'],
      ),
    ],
  );

  // ============ LEGAL ============
  static const legal = BusinessCategoryConfig(
    category: BusinessCategory.legal,
    id: 'legal',
    displayName: 'Legal Services',
    description: 'Lawyers, Notaries & Legal Aid',
    icon: Icons.gavel,
    color: Color(0xFF78716C), // Stone
    subTypes: [
      'Lawyer',
      'Advocate',
      'Notary',
      'Legal Consultant',
      'Corporate Law Firm',
      'Family Court Lawyer',
      'Criminal Lawyer',
      'Property Lawyer',
      'Immigration Lawyer',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'practiceAreas',
        label: 'Practice Areas',
        type: FieldType.multiSelect,
        options: [
          'Civil',
          'Criminal',
          'Family',
          'Property',
          'Corporate',
          'Tax',
          'Immigration',
          'Labor & Employment',
        ],
      ),
      CategorySetupField(
        id: 'consultationType',
        label: 'Consultation Type',
        type: FieldType.multiSelect,
        options: ['In-Person', 'Online', 'Phone'],
      ),
    ],
  );

  // ============ PROFESSIONAL ============
  static const professional = BusinessCategoryConfig(
    category: BusinessCategory.professional,
    id: 'professional',
    displayName: 'Professional Services',
    description: 'Consultants, HR & Agencies',
    icon: Icons.work,
    color: Color(0xFF6B7280), // Gray
    subTypes: [
      'Business Consultant',
      'Management Consultant',
      'HR Consultant',
      'Marketing Agency',
      'PR Agency',
      'Recruitment Agency',
      'Training Company',
      'Event Management',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.appointments,
      BusinessFeature.portfolio,
    ],
    setupFields: [
      CategorySetupField(
        id: 'expertise',
        label: 'Areas of Expertise',
        type: FieldType.multiSelect,
        options: [
          'Business Strategy',
          'Marketing & Branding',
          'HR & Recruitment',
          'Operations',
          'Sales',
          'Finance',
          'Technology',
        ],
      ),
      CategorySetupField(
        id: 'clientType',
        label: 'Client Type',
        type: FieldType.multiSelect,
        options: ['Startups', 'SMEs', 'Enterprises', 'Individuals'],
      ),
    ],
  );

  // ============ TRANSPORTATION ============
  static const transportation = BusinessCategoryConfig(
    category: BusinessCategory.transportation,
    id: 'transportation',
    displayName: 'Transportation',
    description: 'Courier, Logistics & Taxi',
    icon: Icons.local_shipping,
    color: Color(0xFFDC2626), // Red Dark
    subTypes: [
      'Courier Service',
      'Logistics Company',
      'Taxi Service',
      'Auto Rickshaw',
      'Truck Transport',
      'Movers & Packers',
      'Ambulance Service',
      'School Bus',
      'Bike Taxi',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.bookings,
      BusinessFeature.vehicles,
    ],
    setupFields: [
      CategorySetupField(
        id: 'transportTypes',
        label: 'Transport Types',
        type: FieldType.multiSelect,
        options: ['Passenger', 'Goods', 'Documents', 'Medical', 'Food Delivery'],
      ),
      CategorySetupField(
        id: 'serviceArea',
        label: 'Service Area',
        type: FieldType.dropdown,
        options: ['Local', 'City', 'State', 'National', 'International'],
      ),
    ],
  );

  // ============ ART & CREATIVE ============
  static const artCreative = BusinessCategoryConfig(
    category: BusinessCategory.artCreative,
    id: 'art_creative',
    displayName: 'Art & Creative',
    description: 'Photography, Design & Studios',
    icon: Icons.palette,
    color: Color(0xFFE11D48), // Rose
    subTypes: [
      'Photography Studio',
      'Graphic Designer',
      'Video Production',
      'Art Gallery',
      'Printing Press',
      'Signage & Banners',
      'Animation Studio',
      'Music Studio',
      'Content Creator',
    ],
    features: [
      BusinessFeature.portfolio,
      BusinessFeature.services,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'creativeServices',
        label: 'Services',
        type: FieldType.multiSelect,
        options: [
          'Photography',
          'Videography',
          'Graphic Design',
          'Logo Design',
          'Printing',
          'Editing',
          'Animation',
          'Social Media Content',
        ],
      ),
      CategorySetupField(
        id: 'eventTypes',
        label: 'Event Types',
        type: FieldType.multiSelect,
        options: ['Weddings', 'Corporate', 'Product', 'Fashion', 'Food', 'Real Estate'],
      ),
    ],
  );

  // ============ CONSTRUCTION ============
  static const construction = BusinessCategoryConfig(
    category: BusinessCategory.construction,
    id: 'construction',
    displayName: 'Construction',
    description: 'Contractors, Interior & Renovation',
    icon: Icons.construction,
    color: Color(0xFFCA8A04), // Yellow Dark
    subTypes: [
      'Building Contractor',
      'Civil Engineer',
      'Architect',
      'Interior Designer',
      'Renovation',
      'Flooring',
      'Roofing',
      'False Ceiling',
      'Modular Kitchen',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.portfolio,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'constructionServices',
        label: 'Services',
        type: FieldType.multiSelect,
        options: [
          'New Construction',
          'Renovation',
          'Interior Design',
          'Architecture',
          'Civil Work',
          'Electrical',
          'Plumbing',
          'Finishing',
        ],
      ),
      CategorySetupField(
        id: 'projectTypes',
        label: 'Project Types',
        type: FieldType.multiSelect,
        options: ['Residential', 'Commercial', 'Industrial', 'Institutional'],
      ),
    ],
  );

  // ============ AGRICULTURE ============
  static const agriculture = BusinessCategoryConfig(
    category: BusinessCategory.agriculture,
    id: 'agriculture',
    displayName: 'Agriculture & Nursery',
    description: 'Farms, Nurseries & Dairy',
    icon: Icons.agriculture,
    color: Color(0xFF16A34A), // Green Dark
    subTypes: [
      'Farm',
      'Nursery',
      'Dairy Farm',
      'Poultry Farm',
      'Organic Farm',
      'Seed Shop',
      'Fertilizer Shop',
      'Agri Equipment',
      'Fishery',
    ],
    features: [
      BusinessFeature.products,
      BusinessFeature.services,
    ],
    setupFields: [
      CategorySetupField(
        id: 'farmTypes',
        label: 'Farm/Product Types',
        type: FieldType.multiSelect,
        options: [
          'Vegetables',
          'Fruits',
          'Grains',
          'Dairy',
          'Poultry',
          'Fishery',
          'Flowers',
          'Plants',
          'Organic',
        ],
      ),
      CategorySetupField(
        id: 'salesType',
        label: 'Sales Type',
        type: FieldType.multiSelect,
        options: ['Wholesale', 'Retail', 'Direct to Consumer', 'B2B'],
      ),
    ],
  );

  // ============ MANUFACTURING ============
  static const manufacturing = BusinessCategoryConfig(
    category: BusinessCategory.manufacturing,
    id: 'manufacturing',
    displayName: 'Manufacturing',
    description: 'Factories, Workshops & Production',
    icon: Icons.factory,
    color: Color(0xFF57534E), // Warm Gray
    subTypes: [
      'Factory',
      'Workshop',
      'Fabrication',
      'Packaging',
      'Textile',
      'Food Processing',
      'Furniture Manufacturing',
      'Machine Shop',
      'Printing Press',
    ],
    features: [
      BusinessFeature.products,
      BusinessFeature.services,
      BusinessFeature.orders,
    ],
    setupFields: [
      CategorySetupField(
        id: 'manufacturingTypes',
        label: 'Manufacturing Types',
        type: FieldType.multiSelect,
        options: [
          'Consumer Goods',
          'Industrial Products',
          'Food & Beverage',
          'Textiles',
          'Machinery',
          'Packaging',
          'Custom Manufacturing',
        ],
      ),
      CategorySetupField(
        id: 'orderTypes',
        label: 'Order Types',
        type: FieldType.multiSelect,
        options: ['Bulk Orders', 'Custom Orders', 'Retail', 'B2B'],
      ),
    ],
  );

  // ============ WEDDING & EVENTS ============
  static const weddingEvents = BusinessCategoryConfig(
    category: BusinessCategory.weddingEvents,
    id: 'wedding_events',
    displayName: 'Wedding & Events',
    description: 'Wedding Planning & Decorators',
    icon: Icons.cake,
    color: Color(0xFFDB2777), // Pink Dark
    subTypes: [
      'Wedding Planner',
      'Event Decorator',
      'Caterer',
      'DJ & Sound',
      'Florist',
      'Mehndi Artist',
      'Wedding Card',
      'Pandit/Priest',
      'Wedding Venue',
      'Choreographer',
    ],
    features: [
      BusinessFeature.packages,
      BusinessFeature.services,
      BusinessFeature.portfolio,
      BusinessFeature.bookings,
    ],
    setupFields: [
      CategorySetupField(
        id: 'eventServices',
        label: 'Services',
        type: FieldType.multiSelect,
        options: [
          'Wedding Planning',
          'Decoration',
          'Catering',
          'Photography',
          'Videography',
          'DJ & Music',
          'Makeup',
          'Mehndi',
          'Flowers',
        ],
      ),
      CategorySetupField(
        id: 'eventTypes',
        label: 'Event Types',
        type: FieldType.multiSelect,
        options: [
          'Wedding',
          'Engagement',
          'Reception',
          'Birthday',
          'Corporate',
          'Anniversary',
          'Baby Shower',
        ],
      ),
    ],
  );

  /// Map old business types to new categories
  static const Map<String, BusinessCategory> _businessTypeToCategory = {
    'Retail Store': BusinessCategory.retail,
    'Restaurant & Cafe': BusinessCategory.foodBeverage,
    'Professional Services': BusinessCategory.professional,
    'Healthcare': BusinessCategory.healthcare,
    'Beauty & Wellness': BusinessCategory.beautyWellness,
    'Fitness & Sports': BusinessCategory.fitness,
    'Education & Training': BusinessCategory.education,
    'Technology & IT': BusinessCategory.technology,
    'Manufacturing': BusinessCategory.manufacturing,
    'Construction': BusinessCategory.construction,
    'Real Estate': BusinessCategory.realEstate,
    'Transportation & Logistics': BusinessCategory.transportation,
    'Entertainment & Media': BusinessCategory.entertainment,
    'Hospitality & Tourism': BusinessCategory.hospitality,
    'Financial Services': BusinessCategory.financial,
    'Non-Profit Organization': BusinessCategory.professional,
    'Home Services': BusinessCategory.homeServices,
    'Automotive': BusinessCategory.automotive,
    'Agriculture': BusinessCategory.agriculture,
    'Other': BusinessCategory.professional,
  };
}

/// Field types for category-specific setup
enum FieldType {
  text,
  dropdown,
  multiSelect,
  toggle,
  time,
  number,
}

/// Setup field configuration
class CategorySetupField {
  final String id;
  final String label;
  final FieldType type;
  final List<String>? options;
  final String? defaultValue;
  final bool required;

  const CategorySetupField({
    required this.id,
    required this.label,
    required this.type,
    this.options,
    this.defaultValue,
    this.required = false,
  });
}

/// Extension to get string value of category
extension BusinessCategoryExtension on BusinessCategory {
  String get id {
    switch (this) {
      case BusinessCategory.hospitality:
        return 'hospitality';
      case BusinessCategory.foodBeverage:
        return 'food_beverage';
      case BusinessCategory.grocery:
        return 'grocery';
      case BusinessCategory.retail:
        return 'retail';
      case BusinessCategory.beautyWellness:
        return 'beauty_wellness';
      case BusinessCategory.healthcare:
        return 'healthcare';
      case BusinessCategory.education:
        return 'education';
      case BusinessCategory.fitness:
        return 'fitness';
      case BusinessCategory.automotive:
        return 'automotive';
      case BusinessCategory.realEstate:
        return 'real_estate';
      case BusinessCategory.travelTourism:
        return 'travel_tourism';
      case BusinessCategory.entertainment:
        return 'entertainment';
      case BusinessCategory.petServices:
        return 'pet_services';
      case BusinessCategory.homeServices:
        return 'home_services';
      case BusinessCategory.technology:
        return 'technology';
      case BusinessCategory.financial:
        return 'financial';
      case BusinessCategory.legal:
        return 'legal';
      case BusinessCategory.professional:
        return 'professional';
      case BusinessCategory.transportation:
        return 'transportation';
      case BusinessCategory.artCreative:
        return 'art_creative';
      case BusinessCategory.construction:
        return 'construction';
      case BusinessCategory.agriculture:
        return 'agriculture';
      case BusinessCategory.manufacturing:
        return 'manufacturing';
      case BusinessCategory.weddingEvents:
        return 'wedding_events';
    }
  }

  String get displayName => BusinessCategoryConfig.getConfig(this).displayName;
  IconData get icon => BusinessCategoryConfig.getConfig(this).icon;
  Color get color => BusinessCategoryConfig.getConfig(this).color;
  List<String> get subTypes => BusinessCategoryConfig.getConfig(this).subTypes;
  List<BusinessFeature> get features => BusinessCategoryConfig.getConfig(this).features;

  /// Parse category from string
  static BusinessCategory? fromString(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'hospitality':
        return BusinessCategory.hospitality;
      case 'food_beverage':
        return BusinessCategory.foodBeverage;
      case 'grocery':
        return BusinessCategory.grocery;
      case 'retail':
        return BusinessCategory.retail;
      case 'beauty_wellness':
        return BusinessCategory.beautyWellness;
      case 'healthcare':
        return BusinessCategory.healthcare;
      case 'education':
        return BusinessCategory.education;
      case 'fitness':
        return BusinessCategory.fitness;
      case 'automotive':
        return BusinessCategory.automotive;
      case 'real_estate':
        return BusinessCategory.realEstate;
      case 'travel_tourism':
        return BusinessCategory.travelTourism;
      case 'entertainment':
        return BusinessCategory.entertainment;
      case 'pet_services':
        return BusinessCategory.petServices;
      case 'home_services':
        return BusinessCategory.homeServices;
      case 'technology':
        return BusinessCategory.technology;
      case 'financial':
        return BusinessCategory.financial;
      case 'legal':
        return BusinessCategory.legal;
      case 'professional':
        return BusinessCategory.professional;
      case 'transportation':
        return BusinessCategory.transportation;
      case 'art_creative':
        return BusinessCategory.artCreative;
      case 'construction':
        return BusinessCategory.construction;
      case 'agriculture':
        return BusinessCategory.agriculture;
      case 'manufacturing':
        return BusinessCategory.manufacturing;
      case 'wedding_events':
        return BusinessCategory.weddingEvents;
      default:
        return null;
    }
  }
}
