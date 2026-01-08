# Adding New Business Categories - Complete Guide 📋

This guide shows you how to add a new business category to the Plink app with full dynamic UI support.

---

## Quick Overview

Adding a new category involves **3 simple steps**:

1. ✅ Add the category enum value
2. ✅ Create category configuration (features, sub-types, setup fields)
3. ✅ Create dynamic UI configuration (profile sections, dashboard widgets, quick actions)

**Time Required:** 10-15 minutes per category
**Files to Modify:** 2 files

---

## Step-by-Step Guide

### Step 1: Add Category Enum

**File:** `lib/models/business_category_config.dart`

Find the `BusinessCategory` enum and add your new category:

```dart
enum BusinessCategory {
  hospitality,
  foodBeverage,
  retail,
  // ... existing categories ...
  weddingEvents,

  // ADD YOUR NEW CATEGORY HERE 👇
  photography,  // Example: Photography business
}
```

---

### Step 2: Create Category Configuration

**File:** `lib/models/business_category_config.dart`

Add the configuration after the enum definition:

```dart
// ============ PHOTOGRAPHY CONFIG ============
static const photography = BusinessCategoryConfig(
  category: BusinessCategory.photography,
  id: 'photography',
  displayName: 'Photography',
  description: 'Professional Photography Services',
  icon: Icons.camera_alt,  // Choose appropriate icon
  color: Color(0xFFE91E63),  // Choose category color

  subTypes: [
    'Wedding Photography',
    'Portrait Photography',
    'Event Photography',
    'Product Photography',
    'Real Estate Photography',
    'Fashion Photography',
    'Food Photography',
    'Sports Photography',
  ],

  features: [
    BusinessFeature.portfolio,     // Show portfolio
    BusinessFeature.services,      // Service offerings
    BusinessFeature.bookings,      // Booking system
  ],

  setupFields: [
    CategorySetupField(
      id: 'photographyTypes',
      label: 'Photography Types',
      type: FieldType.multiSelect,
      options: [
        'Wedding',
        'Portrait',
        'Event',
        'Product',
        'Fashion',
        'Food',
        'Wildlife',
        'Architecture',
      ],
    ),
    CategorySetupField(
      id: 'equipmentUsed',
      label: 'Camera Equipment',
      type: FieldType.multiSelect,
      options: [
        'DSLR',
        'Mirrorless',
        'Medium Format',
        'Drone',
        'Studio Lighting',
      ],
    ),
    CategorySetupField(
      id: 'deliveryTime',
      label: 'Photo Delivery Time',
      type: FieldType.dropdown,
      options: ['24 hours', '48 hours', '1 week', '2 weeks'],
    ),
  ],
);
```

**Add to the list:**

```dart
static List<BusinessCategoryConfig> get all => [
  hospitality,
  foodBeverage,
  // ... existing categories ...
  weddingEvents,
  photography,  // ADD HERE 👈
];
```

**Add to extension:**

```dart
extension BusinessCategoryExtension on BusinessCategory {
  String get id {
    switch (this) {
      // ... existing cases ...
      case BusinessCategory.photography:
        return 'photography';
    }
  }

  static BusinessCategory? fromString(String? value) {
    if (value == null) return null;
    switch (value) {
      // ... existing cases ...
      case 'photography':
        return BusinessCategory.photography;
      default:
        return null;
    }
  }
}
```

---

### Step 3: Create Dynamic UI Configuration

**File:** `lib/config/dynamic_business_ui_config.dart`

**3a. Add to switch statement:**

```dart
static DynamicUIConfig getConfigForCategory(BusinessCategory category) {
  switch (category) {
    // ... existing cases ...
    case BusinessCategory.weddingEvents:
      return _weddingEventsConfig;
    case BusinessCategory.photography:
      return _photographyConfig;  // ADD HERE 👈
  }
}
```

**3b. Create the configuration:**

```dart
// ============ PHOTOGRAPHY CONFIG ============
static const _photographyConfig = DynamicUIConfig(
  category: BusinessCategory.photography,
  profileTemplate: 'generic_template',  // Or create custom template

  // What sections appear on the public profile
  profileSections: [
    ProfileSection.hero,           // Cover image, logo, name
    ProfileSection.quickActions,   // Call, message, bookmark
    ProfileSection.highlights,     // Photography types, equipment
    ProfileSection.portfolio,      // Photo portfolio 📸
    ProfileSection.services,       // Service packages
    ProfileSection.gallery,        // Additional photos
    ProfileSection.reviews,        // Customer reviews
    ProfileSection.hours,          // Working hours
    ProfileSection.location,       // Studio location
  ],

  // What widgets appear on the business dashboard
  dashboardWidgets: [
    DashboardWidget.stats,              // Today's stats
    DashboardWidget.activeBookings,     // Upcoming shoots
    DashboardWidget.inquiries,          // New inquiries
    DashboardWidget.earnings,           // Revenue
  ],

  // Quick action buttons on the home tab (max 4, show 3)
  quickActions: [
    QuickAction.addPortfolioItem,   // Add photo to portfolio
    QuickAction.addService,          // Add service package
    QuickAction.manageBookings,      // View bookings
    QuickAction.createPost,          // Create promotional post
  ],

  // Bottom navigation tabs
  bottomTabs: [
    BusinessTab.home,        // Dashboard
    BusinessTab.portfolio,   // Portfolio management
    BusinessTab.services,    // Service packages
    BusinessTab.messages,    // Customer messages
    BusinessTab.profile,     // Business profile
  ],

  // Category-specific customization
  customization: {
    'showPhotographyTypes': true,
    'showEquipment': true,
    'showDeliveryTime': true,
    'portfolioLayout': 'grid',  // 'grid' or 'masonry'
  },
);
```

---

## Complete Examples

### Example 1: Dental Clinic

```dart
// Step 1: Add enum
enum BusinessCategory {
  // ... existing
  dentalClinic,
}

// Step 2: Category config
static const dentalClinic = BusinessCategoryConfig(
  category: BusinessCategory.dentalClinic,
  id: 'dental_clinic',
  displayName: 'Dental Clinic',
  description: 'Dental Care & Services',
  icon: Icons.medical_services,
  color: Color(0xFF00BCD4),
  subTypes: [
    'General Dentistry',
    'Orthodontics',
    'Cosmetic Dentistry',
    'Oral Surgery',
    'Pediatric Dentistry',
    'Endodontics',
  ],
  features: [
    BusinessFeature.services,
    BusinessFeature.appointments,
  ],
  setupFields: [
    CategorySetupField(
      id: 'dentalServices',
      label: 'Services Offered',
      type: FieldType.multiSelect,
      options: [
        'Teeth Cleaning',
        'Fillings',
        'Root Canal',
        'Crowns & Bridges',
        'Teeth Whitening',
        'Braces',
        'Implants',
      ],
    ),
  ],
);

// Step 3: Dynamic UI config
static const _dentalClinicConfig = DynamicUIConfig(
  category: BusinessCategory.dentalClinic,
  profileTemplate: 'healthcare_template',
  profileSections: [
    ProfileSection.hero,
    ProfileSection.quickActions,
    ProfileSection.highlights,
    ProfileSection.services,
    ProfileSection.gallery,
    ProfileSection.reviews,
    ProfileSection.hours,
    ProfileSection.location,
  ],
  dashboardWidgets: [
    DashboardWidget.stats,
    DashboardWidget.todayAppointments,
    DashboardWidget.patientQueue,
    DashboardWidget.earnings,
  ],
  quickActions: [
    QuickAction.addService,
    QuickAction.manageAppointments,
    QuickAction.createPost,
  ],
  bottomTabs: [
    BusinessTab.home,
    BusinessTab.services,
    BusinessTab.appointments,
    BusinessTab.messages,
    BusinessTab.profile,
  ],
  customization: {
    'showDoctors': true,
    'showSpecializations': true,
  },
);
```

---

### Example 2: Car Wash

```dart
// Step 1: Add enum
enum BusinessCategory {
  // ... existing
  carWash,
}

// Step 2: Category config
static const carWash = BusinessCategoryConfig(
  category: BusinessCategory.carWash,
  id: 'car_wash',
  displayName: 'Car Wash',
  description: 'Car Washing & Detailing Services',
  icon: Icons.local_car_wash,
  color: Color(0xFF2196F3),
  subTypes: [
    'Self-Service Car Wash',
    'Automatic Car Wash',
    'Hand Car Wash',
    'Car Detailing',
    'Mobile Car Wash',
  ],
  features: [
    BusinessFeature.services,
    BusinessFeature.appointments,
  ],
  setupFields: [
    CategorySetupField(
      id: 'washTypes',
      label: 'Wash Types',
      type: FieldType.multiSelect,
      options: [
        'Basic Wash',
        'Premium Wash',
        'Detailing',
        'Interior Cleaning',
        'Waxing',
        'Polish',
      ],
    ),
  ],
);

// Step 3: Dynamic UI config
static const _carWashConfig = DynamicUIConfig(
  category: BusinessCategory.carWash,
  profileTemplate: 'generic_template',
  profileSections: [
    ProfileSection.hero,
    ProfileSection.quickActions,
    ProfileSection.highlights,
    ProfileSection.services,
    ProfileSection.gallery,
    ProfileSection.reviews,
    ProfileSection.hours,
    ProfileSection.location,
  ],
  dashboardWidgets: [
    DashboardWidget.stats,
    DashboardWidget.todayAppointments,
    DashboardWidget.earnings,
  ],
  quickActions: [
    QuickAction.addService,
    QuickAction.manageAppointments,
    QuickAction.createPost,
  ],
  bottomTabs: [
    BusinessTab.home,
    BusinessTab.services,
    BusinessTab.appointments,
    BusinessTab.messages,
    BusinessTab.profile,
  ],
);
```

---

### Example 3: Coworking Space

```dart
// Step 1: Add enum
enum BusinessCategory {
  // ... existing
  coworkingSpace,
}

// Step 2: Category config
static const coworkingSpace = BusinessCategoryConfig(
  category: BusinessCategory.coworkingSpace,
  id: 'coworking_space',
  displayName: 'Coworking Space',
  description: 'Shared Office & Workspace',
  icon: Icons.business_center,
  color: Color(0xFF9C27B0),
  subTypes: [
    'Hot Desk',
    'Dedicated Desk',
    'Private Office',
    'Meeting Rooms',
    'Event Space',
  ],
  features: [
    BusinessFeature.rooms,
    BusinessFeature.bookings,
    BusinessFeature.services,
  ],
  setupFields: [
    CategorySetupField(
      id: 'amenities',
      label: 'Amenities',
      type: FieldType.multiSelect,
      options: [
        'High-Speed WiFi',
        'Printer/Scanner',
        'Coffee/Tea',
        'Meeting Rooms',
        'Parking',
        '24/7 Access',
      ],
    ),
  ],
);

// Step 3: Dynamic UI config
static const _coworkingSpaceConfig = DynamicUIConfig(
  category: BusinessCategory.coworkingSpace,
  profileTemplate: 'generic_template',
  profileSections: [
    ProfileSection.hero,
    ProfileSection.quickActions,
    ProfileSection.highlights,
    ProfileSection.rooms,        // Workspace types
    ProfileSection.services,     // Additional services
    ProfileSection.gallery,
    ProfileSection.reviews,
    ProfileSection.hours,
    ProfileSection.location,
  ],
  dashboardWidgets: [
    DashboardWidget.stats,
    DashboardWidget.roomOccupancy,
    DashboardWidget.upcomingBookings,
    DashboardWidget.earnings,
  ],
  quickActions: [
    QuickAction.addRoom,
    QuickAction.manageBookings,
    QuickAction.createPost,
  ],
  bottomTabs: [
    BusinessTab.home,
    BusinessTab.rooms,
    BusinessTab.bookings,
    BusinessTab.messages,
    BusinessTab.profile,
  ],
  customization: {
    'showAmenities': true,
    'showOccupancy': true,
  },
);
```

---

## Available Components Reference

### Profile Sections (What shows on public profile)
```dart
ProfileSection.hero          // Cover image, logo, name, rating
ProfileSection.quickActions  // Call, message, bookmark buttons
ProfileSection.highlights    // Key features, tags, badges
ProfileSection.menu          // For restaurants
ProfileSection.products      // Product catalog
ProfileSection.services      // Service offerings
ProfileSection.rooms         // For hotels, coworking
ProfileSection.properties    // For real estate
ProfileSection.vehicles      // For automotive
ProfileSection.courses       // For education
ProfileSection.classes       // For fitness, education
ProfileSection.memberships   // For gyms
ProfileSection.packages      // For tours, events
ProfileSection.portfolio     // For creative, professional
ProfileSection.gallery       // Photo gallery
ProfileSection.reviews       // Customer reviews
ProfileSection.hours         // Operating hours
ProfileSection.location      // Address and map
```

### Dashboard Widgets (What business owner sees)
```dart
DashboardWidget.stats                // Quick stats card
DashboardWidget.recentOrders         // Latest orders
DashboardWidget.popularItems         // Top-selling items
DashboardWidget.topProducts          // Best products
DashboardWidget.lowStock             // Low inventory alert
DashboardWidget.todayAppointments    // Today's appointments
DashboardWidget.todayCheckIns        // Hotel check-ins
DashboardWidget.roomOccupancy        // Room availability
DashboardWidget.upcomingBookings     // Future bookings
DashboardWidget.popularServices      // Popular services
DashboardWidget.patientQueue         // Healthcare queue
DashboardWidget.totalStudents        // Education enrollment
DashboardWidget.courseEnrollments    // Course stats
DashboardWidget.activeMembers        // Gym members
DashboardWidget.vehicleInventory     // Vehicle stock
DashboardWidget.activeListings       // Real estate listings
DashboardWidget.inquiries            // Customer inquiries
DashboardWidget.activeProjects       // Ongoing projects
DashboardWidget.earnings             // Revenue chart
```

### Quick Actions (Dashboard shortcuts)
```dart
QuickAction.addMenuItem          // For restaurants
QuickAction.addProduct           // For retail
QuickAction.addService           // For services
QuickAction.addRoom              // For hotels
QuickAction.addProperty          // For real estate
QuickAction.addVehicle           // For automotive
QuickAction.addCourse            // For education
QuickAction.addMembership        // For gyms
QuickAction.addPackage           // For tours
QuickAction.addPortfolioItem     // For creative
QuickAction.manageOrders         // Order management
QuickAction.manageBookings       // Booking management
QuickAction.manageAppointments   // Appointment management
QuickAction.manageClasses        // Class schedule
QuickAction.manageInventory      // Stock management
QuickAction.manageInquiries      // Inquiry management
QuickAction.createPost           // Create promotional post
QuickAction.viewAnalytics        // View analytics
```

### Bottom Tabs (App navigation)
```dart
BusinessTab.home          // Dashboard (always included)
BusinessTab.menu          // Menu management
BusinessTab.products      // Product catalog
BusinessTab.services      // Service offerings
BusinessTab.rooms         // Room management
BusinessTab.bookings      // Booking management
BusinessTab.orders        // Order management
BusinessTab.appointments  // Appointment scheduling
BusinessTab.courses       // Course management
BusinessTab.enrollments   // Student enrollments
BusinessTab.classes       // Class schedules
BusinessTab.memberships   // Membership management
BusinessTab.vehicles      // Vehicle inventory
BusinessTab.properties    // Property listings
BusinessTab.inquiries     // Customer inquiries
BusinessTab.packages      // Package management
BusinessTab.portfolio     // Portfolio showcase
BusinessTab.messages      // Messages (always included)
BusinessTab.profile       // Profile (always included)
```

---

## Best Practices

### 1. Choose Appropriate Sections
- ✅ **Include:** Only sections relevant to your category
- ❌ **Avoid:** Including menu section for non-food businesses

### 2. Limit Quick Actions
- ✅ **Show 3-4 actions max** (first 3 are displayed)
- ✅ **Prioritize** most common actions first
- ✅ **Always include** `createPost` for marketing

### 3. Select Relevant Widgets
- ✅ **Stats widget** should always be first
- ✅ **Earnings widget** should usually be last
- ✅ **Category-specific widgets** in the middle

### 4. Bottom Navigation
- ✅ **Always include:** home, messages, profile
- ✅ **Add 2-3 category-specific** tabs
- ❌ **Don't exceed** 6 tabs total (UI limitation)

### 5. Customization Options
```dart
customization: {
  'showFeatureName': true,    // Boolean flags
  'layoutType': 'grid',       // String options
  'maxItems': 10,             // Numeric limits
}
```

---

## Testing Your New Category

### 1. Verify Configuration
```bash
flutter analyze lib/models/business_category_config.dart
flutter analyze lib/config/dynamic_business_ui_config.dart
```

### 2. Run Tests
```bash
flutter test test/dynamic_ui_config_test.dart
```

### 3. Manual Testing
1. Create a business with your new category
2. Verify home tab shows correct quick actions
3. Verify services tab shows correct buttons
4. Check all sections appear on profile
5. Verify bottom navigation has correct tabs

---

## Common Patterns

### Service-Based Business
```dart
features: [BusinessFeature.services, BusinessFeature.appointments]
quickActions: [addService, manageAppointments, createPost]
bottomTabs: [home, services, appointments, messages, profile]
```

### Product-Based Business
```dart
features: [BusinessFeature.products, BusinessFeature.orders]
quickActions: [addProduct, manageOrders, manageInventory, createPost]
bottomTabs: [home, products, orders, messages, profile]
```

### Booking-Based Business
```dart
features: [BusinessFeature.services, BusinessFeature.bookings]
quickActions: [addService, manageBookings, createPost]
bottomTabs: [home, services, bookings, messages, profile]
```

### Creative/Professional Business
```dart
features: [BusinessFeature.portfolio, BusinessFeature.services]
quickActions: [addPortfolioItem, addService, manageInquiries, createPost]
bottomTabs: [home, portfolio, services, messages, profile]
```

---

## Troubleshooting

### Error: "The name 'newCategory' isn't defined"
**Solution:** Make sure you added the enum value in Step 1

### Error: "Missing case in switch"
**Solution:** Add your category to all switch statements:
- `getConfig()` method
- `id` getter
- `fromString()` method
- `getConfigForCategory()` method

### Warning: "Unused field '_newCategoryConfig'"
**Solution:** Make sure you added it to the switch in `getConfigForCategory()`

### Quick actions not showing
**Solution:** Check that quick actions are listed in the dynamic UI config

---

## Summary Checklist

When adding a new category, ensure:

- [ ] Added enum value in `BusinessCategory`
- [ ] Created `BusinessCategoryConfig` static const
- [ ] Added to `all` list
- [ ] Added case to `id` getter
- [ ] Added case to `fromString()` method
- [ ] Created `DynamicUIConfig` static const
- [ ] Added case to `getConfigForCategory()` switch
- [ ] Ran `flutter analyze` with no errors
- [ ] Tested in the app

---

**Time to add a new category:** ~10-15 minutes
**Difficulty:** Easy (just configuration, no complex logic)
**Database changes needed:** None (uses existing structure)

Happy coding! 🚀
