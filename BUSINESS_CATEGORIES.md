# BUSINESS CATEGORIES - Complete Implementation Roadmap

> **Purpose**: This document serves as the master reference for implementing all 24 business categories in the Plink app. It tracks progress, defines architecture, and stores implementation instructions for each category.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Category Implementation Status](#category-implementation-status)
3. [Shared Components](#shared-components)
4. [Category Details](#category-details)
   - [1. Hospitality](#1-hospitality)
   - [2. Food & Beverage](#2-food--beverage)
   - [3. Grocery & Essentials](#3-grocery--essentials)
   - [4. Retail & Shopping](#4-retail--shopping)
   - [5. Beauty & Wellness](#5-beauty--wellness)
   - [6. Healthcare](#6-healthcare)
   - [7. Education & Training](#7-education--training)
   - [8. Fitness & Sports](#8-fitness--sports)
   - [9. Automotive](#9-automotive)
   - [10. Real Estate](#10-real-estate)
   - [11. Travel & Tourism](#11-travel--tourism)
   - [12. Entertainment](#12-entertainment)
   - [13. Pet Services](#13-pet-services)
   - [14. Home Services](#14-home-services)
   - [15. Technology & IT](#15-technology--it)
   - [16. Financial Services](#16-financial-services)
   - [17. Legal Services](#17-legal-services)
   - [18. Professional Services](#18-professional-services)
   - [19. Transportation](#19-transportation)
   - [20. Art & Creative](#20-art--creative)
   - [21. Construction](#21-construction)
   - [22. Agriculture & Nursery](#22-agriculture--nursery)
   - [23. Manufacturing](#23-manufacturing)
   - [24. Wedding & Events](#24-wedding--events)

---

## Architecture Overview

### Object-Oriented Design Pattern

```
BusinessModel (Base)
├── categoryData: Map<String, dynamic>  // Category-specific data
├── category: BusinessCategory          // Enum for category type
└── subType: String                     // Sub-category selection

CategoryConfig
├── features: List<BusinessFeature>     // Available features for category
├── setupFields: List<SetupField>       // Category-specific setup fields
└── templates: ProfileTemplate          // Profile view template
```

### Feature Types (BusinessFeature enum)
- `rooms` - Room management (Hospitality)
- `menu` - Menu/item management (Food)
- `products` - Product catalog (Retail)
- `services` - Service offerings (All service businesses)
- `appointments` - Booking system (Healthcare, Beauty, etc.)
- `courses` - Course/class management (Education)
- `portfolio` - Work showcase (Creative, Professional)
- `classes` - Group class scheduling (Fitness, Education)
- `bookings` - Reservation system (Hospitality, Events)
- `orders` - Order management (Retail, Food)
- `vehicles` - Vehicle inventory (Automotive)
- `properties` - Property listings (Real Estate)
- `packages` - Package/bundle offerings (Travel, Events)

### Firestore Structure

```
businesses/{businessId}
├── Basic fields (name, contact, address, etc.)
├── category: "category_id"
├── subType: "sub_category_type"
├── categoryData: { category-specific fields }
└── Sub-collections:
    ├── menu_categories/{categoryId}
    ├── menu_items/{itemId}
    ├── products/{productId}
    ├── services/{serviceId}
    ├── rooms/{roomId}
    ├── bookings/{bookingId}
    ├── appointments/{appointmentId}
    ├── orders/{orderId}
    ├── courses/{courseId}
    ├── classes/{classId}
    ├── packages/{packageId}
    ├── properties/{propertyId}
    ├── vehicles/{vehicleId}
    ├── portfolio/{workId}
    └── reviews/{reviewId}
```

---

## Category Implementation Status

| # | Category | Status | Models | Screens | Services | Profile Template |
|---|----------|--------|--------|---------|----------|------------------|
| 1 | Hospitality | `IN_PROGRESS` | RoomModel | rooms_tab, room_form | booking_service | hotel_template |
| 2 | Food & Beverage | `IN_PROGRESS` | MenuModel | menu_tab, menu_item_form | menu_service | restaurant_template |
| 3 | Grocery & Essentials | `PENDING` | ProductModel | - | - | retail_template |
| 4 | Retail & Shopping | `IN_PROGRESS` | ProductModel | products_tab, product_form | product_service | retail_template |
| 5 | Beauty & Wellness | `PENDING` | ServiceModel | - | - | salon_template |
| 6 | Healthcare | `PENDING` | ServiceModel | - | - | healthcare_template |
| 7 | Education & Training | `PENDING` | CourseModel | - | - | education_template |
| 8 | Fitness & Sports | `PENDING` | ClassModel | - | - | fitness_template |
| 9 | Automotive | `PENDING` | VehicleModel, ServiceModel | - | - | generic_template |
| 10 | Real Estate | `PENDING` | PropertyModel | - | - | real_estate_template |
| 11 | Travel & Tourism | `PENDING` | PackageModel | - | - | generic_template |
| 12 | Entertainment | `PENDING` | PackageModel | - | - | generic_template |
| 13 | Pet Services | `PENDING` | ServiceModel | - | - | generic_template |
| 14 | Home Services | `PENDING` | ServiceModel | - | - | generic_template |
| 15 | Technology & IT | `PENDING` | ServiceModel | - | - | generic_template |
| 16 | Financial Services | `PENDING` | ServiceModel | - | - | generic_template |
| 17 | Legal Services | `PENDING` | ServiceModel | - | - | generic_template |
| 18 | Professional Services | `PENDING` | ServiceModel | - | - | generic_template |
| 19 | Transportation | `PENDING` | VehicleModel | - | - | generic_template |
| 20 | Art & Creative | `PENDING` | PortfolioModel | - | - | generic_template |
| 21 | Construction | `PENDING` | ServiceModel | - | - | generic_template |
| 22 | Agriculture & Nursery | `PENDING` | ProductModel | - | - | generic_template |
| 23 | Manufacturing | `PENDING` | ProductModel | - | - | generic_template |
| 24 | Wedding & Events | `PENDING` | PackageModel | - | - | generic_template |

**Status Legend:**
- `DONE` - Fully implemented and tested
- `IN_PROGRESS` - Currently being implemented
- `PENDING` - Not yet started

---

## Shared Components

### Common Models

#### ServiceModel (lib/models/service_model.dart)
```dart
class ServiceModel {
  final String id;
  final String businessId;
  final String name;
  final String? description;
  final double price;
  final int duration; // in minutes
  final String? image;
  final bool isActive;
  final int sortOrder;
  final String? categoryId;
  final List<String> tags;
}
```

#### AppointmentModel (lib/models/appointment_model.dart)
```dart
class AppointmentModel {
  final String id;
  final String businessId;
  final String customerId;
  final String customerName;
  final String? serviceId;
  final DateTime dateTime;
  final int duration;
  final String status; // pending, confirmed, completed, cancelled
  final double? amount;
  final String? notes;
}
```

#### BookingModel (lib/models/booking_model.dart)
```dart
class BookingModel {
  final String id;
  final String businessId;
  final String customerId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final String? roomId;
  final double totalAmount;
  final String status;
  final Map<String, dynamic>? extras;
}
```

### Common Screens

- `business_home_tab.dart` - Dashboard home (adapts based on category)
- `business_messages_tab.dart` - Customer messages
- `business_profile_tab.dart` - Profile management
- `business_analytics_screen.dart` - Business analytics
- `business_hours_screen.dart` - Operating hours
- `business_settings_screen.dart` - Settings

### Common Services

- `business_service.dart` - Core business CRUD operations
- `notification_service.dart` - Push notifications
- `analytics_service.dart` - Business analytics

---

## Category Details

---

### 1. HOSPITALITY

**Category ID:** `hospitality`
**Color:** `#6366F1` (Indigo)
**Icon:** `Icons.hotel`

#### Sub-Types
- Hotel
- Resort
- Guesthouse
- Hostel
- Villa
- Homestay
- Motel
- Service Apartment

#### Features
- `rooms` - Room type management
- `bookings` - Room reservations
- `services` - Additional services (spa, laundry, etc.)

#### Data Models

**RoomModel** (lib/models/room_model.dart) - `EXISTS`
```dart
class RoomModel {
  final String id;
  final String businessId;
  final String name;
  final String? description;
  final String roomType; // Standard, Deluxe, Suite, etc.
  final int maxOccupancy;
  final double pricePerNight;
  final List<String> amenities;
  final List<String> images;
  final bool isAvailable;
  final int totalRooms;
  final int availableRooms;
}
```

#### Screens Required
- [x] `rooms_tab.dart` - List/manage room types
- [x] `room_form_screen.dart` - Add/edit room
- [x] `bookings_tab.dart` - View/manage bookings
- [ ] `booking_calendar_screen.dart` - Calendar view
- [ ] `room_availability_screen.dart` - Manage availability

#### categoryData Fields
```dart
{
  'checkInTime': '14:00',
  'checkOutTime': '11:00',
  'amenities': ['WiFi', 'Parking', 'Pool', ...],
  'policies': {
    'cancellation': 'Free cancellation up to 24 hours',
    'pets': false,
    'smoking': false,
  }
}
```

#### Profile Template
`hotel_template.dart` - Shows rooms, amenities, location, booking widget

#### Implementation Instructions
```
1. Room Management:
   - Create room types with pricing tiers
   - Track room inventory (total/available)
   - Upload multiple images per room type
   - Set amenities per room type

2. Booking System:
   - Check-in/Check-out date selection
   - Guest count validation against maxOccupancy
   - Real-time availability check
   - Payment integration
   - Booking confirmation notifications

3. Dashboard Metrics:
   - Occupancy rate
   - Today's check-ins/check-outs
   - Revenue (daily/weekly/monthly)
   - Pending bookings
```

**STATUS:** `IN_PROGRESS`

---

### 2. FOOD & BEVERAGE

**Category ID:** `food_beverage`
**Color:** `#F59E0B` (Amber)
**Icon:** `Icons.restaurant`

#### Sub-Types
- Restaurant
- Cafe
- Bakery
- Bar & Pub
- Cloud Kitchen
- Food Truck
- Fast Food
- Fine Dining
- Catering
- Ice Cream & Desserts

#### Features
- `menu` - Menu item management
- `orders` - Order management
- `services` - Catering services

#### Data Models

**MenuCategoryModel** (lib/models/menu_model.dart) - `EXISTS`
```dart
class MenuCategoryModel {
  final String id;
  final String businessId;
  final String name;
  final String? description;
  final int sortOrder;
}
```

**MenuItemModel** (lib/models/menu_model.dart) - `EXISTS`
```dart
class MenuItemModel {
  final String id;
  final String businessId;
  final String categoryId;
  final String name;
  final String? description;
  final double price;
  final String? image;
  final bool isVeg;
  final bool isAvailable;
  final bool isPopular;
  final List<String> tags;
  final Map<String, dynamic>? variants;
  final Map<String, dynamic>? addons;
}
```

#### Screens Required
- [x] `menu_tab.dart` - Menu management
- [x] `menu_category_screen.dart` - Category management
- [x] `menu_item_form_screen.dart` - Add/edit menu item
- [x] `orders_tab.dart` - Order management
- [ ] `order_details_screen.dart` - Order details

#### categoryData Fields
```dart
{
  'cuisineTypes': ['Indian', 'Chinese', ...],
  'diningOptions': ['Dine-in', 'Takeaway', 'Delivery'],
  'foodType': 'Both', // Pure Veg, Non-Veg, Both
  'avgCostForTwo': 500,
  'acceptsReservations': true,
}
```

#### Profile Template
`restaurant_template.dart` - Shows menu, ratings, photos, order button

#### Implementation Instructions
```
1. Menu Management:
   - Create menu categories (Starters, Main Course, etc.)
   - Add items with veg/non-veg tags
   - Set pricing with variants (Small/Medium/Large)
   - Add-ons management (Extra cheese, etc.)
   - Mark items as available/unavailable
   - Popular items highlighting

2. Order System:
   - Real-time order notifications
   - Order status management (New > Preparing > Ready > Delivered)
   - Order history
   - Customer details

3. Dashboard Metrics:
   - Today's orders count
   - Revenue tracking
   - Popular items analytics
   - Peak hours analysis
```

**STATUS:** `IN_PROGRESS`

---

### 3. GROCERY & ESSENTIALS

**Category ID:** `grocery`
**Color:** `#22C55E` (Green)
**Icon:** `Icons.shopping_basket`

#### Sub-Types
- Supermarket
- Kirana Store
- Wholesale
- Organic Store
- Fruits & Vegetables
- Dairy Shop
- Meat & Fish
- Convenience Store

#### Features
- `products` - Product catalog
- `orders` - Customer orders

#### Data Models

**ProductCategoryModel**
```dart
class ProductCategoryModel {
  final String id;
  final String businessId;
  final String name;
  final String? image;
  final int sortOrder;
  final int itemCount;
}
```

**ProductModel** - `EXISTS` (lib/models/product_model.dart)
```dart
class ProductModel {
  final String id;
  final String businessId;
  final String categoryId;
  final String name;
  final String? description;
  final String? brand;
  final double price;
  final double? mrp;
  final String unit; // kg, g, L, ml, piece
  final double quantity;
  final String? image;
  final bool isAvailable;
  final int stock;
  final String? sku;
  final List<String> tags;
}
```

#### Screens Required
- [ ] `products_tab.dart` - Product management (reuse from retail)
- [ ] `product_category_screen.dart` - Category management
- [ ] `product_form_screen.dart` - Add/edit product
- [ ] `inventory_screen.dart` - Stock management
- [ ] `orders_tab.dart` - Order management

#### categoryData Fields
```dart
{
  'productTypes': ['Groceries', 'Fruits & Vegetables', ...],
  'deliveryOptions': ['Walk-in', 'Home Delivery', 'Store Pickup'],
  'minOrderValue': 200,
  'deliveryRadius': 5, // km
  'deliveryCharges': {
    'free_above': 500,
    'flat_rate': 30,
  }
}
```

#### Profile Template
`retail_template.dart` (shared with Retail)

#### Implementation Instructions
```
1. Product Catalog:
   - Organize by categories (Vegetables, Dairy, etc.)
   - Support units (kg, g, L, pieces)
   - MRP vs selling price
   - Stock tracking
   - Low stock alerts

2. Order System:
   - Cart functionality
   - Minimum order value
   - Delivery slot selection
   - Order tracking

3. Dashboard Metrics:
   - Daily/weekly sales
   - Low stock items
   - Top selling products
   - Order fulfillment rate
```

**STATUS:** `PENDING`

---

### 4. RETAIL & SHOPPING

**Category ID:** `retail`
**Color:** `#10B981` (Emerald)
**Icon:** `Icons.storefront`

#### Sub-Types
- Clothing Store
- Electronics Store
- Boutique
- Jewelry Store
- Footwear Store
- Home & Furniture
- Sports & Outdoors
- Books & Stationery
- Gift Shop
- Mobile Store

#### Features
- `products` - Product catalog
- `orders` - Customer orders

#### Data Models
(Same as Grocery - ProductModel)

#### Screens Required
- [x] `products_tab.dart` - Product listing
- [x] `product_category_screen.dart` - Categories
- [x] `product_form_screen.dart` - Add/edit product
- [ ] `orders_tab.dart` - Orders management

#### categoryData Fields
```dart
{
  'productCategories': ['Clothing', 'Electronics', ...],
  'orderOptions': ['Walk-in', 'Online Orders', 'Home Delivery'],
  'acceptsReturns': true,
  'returnPolicy': '7 days return policy',
}
```

#### Profile Template
`retail_template.dart` - Product showcase, categories, shop button

**STATUS:** `IN_PROGRESS`

---

### 5. BEAUTY & WELLNESS

**Category ID:** `beauty_wellness`
**Color:** `#EC4899` (Pink)
**Icon:** `Icons.spa`

#### Sub-Types
- Salon
- Spa
- Beauty Parlor
- Barbershop
- Nail Studio
- Makeup Studio
- Hair Studio
- Wellness Center
- Ayurvedic Center
- Tattoo Studio

#### Features
- `services` - Service menu
- `appointments` - Booking system
- `products` - Retail products (optional)

#### Data Models

**ServiceModel** (Already defined in Shared Components)

**StylistModel**
```dart
class StylistModel {
  final String id;
  final String businessId;
  final String name;
  final String? photo;
  final String? specialization;
  final List<String> services;
  final double rating;
  final bool isAvailable;
}
```

#### Screens Required
- [ ] `services_tab.dart` - Service management
- [ ] `service_form_screen.dart` - Add/edit service
- [ ] `appointments_tab.dart` - Appointment management
- [ ] `appointment_calendar_screen.dart` - Calendar view
- [ ] `stylist_management_screen.dart` - Staff management

#### categoryData Fields
```dart
{
  'serviceCategories': ['Hair Styling', 'Skin Care', ...],
  'bookingType': 'Both', // Walk-in, Appointment Only, Both
  'genderServed': 'Unisex', // Men, Women, Unisex
  'stylists': 4, // number of stylists
}
```

#### Profile Template
`salon_template.dart` - Services, stylists, gallery, book button

#### Implementation Instructions
```
1. Service Management:
   - Create service categories (Hair, Skin, Nails, etc.)
   - Set service duration (30 min, 1 hour, etc.)
   - Pricing with variants (haircut - short/medium/long)
   - Attach services to specific stylists

2. Appointment System:
   - Date/time slot selection
   - Stylist selection (optional)
   - Multiple services in one appointment
   - Appointment reminders
   - Rescheduling/cancellation

3. Staff Management:
   - Add stylists/therapists
   - Set working hours per staff
   - Assign specializations
   - Track individual performance

4. Dashboard Metrics:
   - Today's appointments
   - Revenue per service category
   - Staff utilization
   - Popular services
```

**STATUS:** `PENDING`

---

### 6. HEALTHCARE

**Category ID:** `healthcare`
**Color:** `#EF4444` (Red)
**Icon:** `Icons.medical_services`

#### Sub-Types
- Clinic
- Hospital
- Doctor
- Dentist
- Eye Care
- Pharmacy
- Diagnostic Center
- Physiotherapy
- Veterinary
- Mental Health

#### Features
- `services` - Medical services
- `appointments` - Patient appointments

#### Data Models

**DoctorModel**
```dart
class DoctorModel {
  final String id;
  final String businessId;
  final String name;
  final String qualification;
  final String specialization;
  final int experienceYears;
  final String? photo;
  final String? registrationNumber;
  final double consultationFee;
  final List<String> languages;
  final Map<String, dynamic> availability; // day-wise slots
}
```

**PatientAppointmentModel**
```dart
class PatientAppointmentModel {
  final String id;
  final String businessId;
  final String doctorId;
  final String patientId;
  final String patientName;
  final String? patientPhone;
  final DateTime dateTime;
  final String consultationType; // In-Person, Video, Phone
  final String status;
  final double fee;
  final String? notes;
  final String? prescription;
}
```

#### Screens Required
- [ ] `doctors_tab.dart` - Doctor management
- [ ] `doctor_form_screen.dart` - Add/edit doctor
- [ ] `appointments_tab.dart` - Patient appointments
- [ ] `prescription_screen.dart` - Create prescriptions
- [ ] `patient_history_screen.dart` - Patient records

#### categoryData Fields
```dart
{
  'specializations': ['General Medicine', 'Pediatrics', ...],
  'appointmentType': ['In-Person', 'Online/Video'],
  'acceptsInsurance': true,
  'emergencyAvailable': true,
}
```

#### Profile Template
`healthcare_template.dart` - Doctors, services, timings, book appointment

#### Implementation Instructions
```
1. Doctor/Staff Management:
   - Add doctors with qualifications
   - Set consultation fees
   - Configure availability slots
   - Multiple consultation types support

2. Appointment System:
   - Online booking with slot selection
   - Walk-in queue management
   - Video consultation integration
   - Patient history access
   - Prescription generation

3. For Pharmacy subtype:
   - Medicine catalog
   - Prescription upload
   - Order management
   - Inventory tracking

4. Dashboard Metrics:
   - Daily appointments
   - Patient count
   - Revenue
   - Consultation type breakdown
```

**STATUS:** `PENDING`

---

### 7. EDUCATION & TRAINING

**Category ID:** `education`
**Color:** `#3B82F6` (Blue)
**Icon:** `Icons.school`

#### Sub-Types
- School
- College
- Coaching Center
- Tutor
- Training Institute
- Language School
- Music Academy
- Dance Academy
- Computer Training
- Driving School
- Preschool

#### Features
- `courses` - Course catalog
- `classes` - Class scheduling
- `appointments` - Individual sessions

#### Data Models

**CourseModel**
```dart
class CourseModel {
  final String id;
  final String businessId;
  final String name;
  final String? description;
  final String level; // Beginner, Intermediate, Advanced
  final int durationWeeks;
  final double fee;
  final String? syllabus;
  final List<String> schedule; // Mon/Wed/Fri 4-5 PM
  final int maxStudents;
  final int enrolledCount;
  final String? instructor;
  final String? image;
  final bool isActive;
}
```

**ClassScheduleModel**
```dart
class ClassScheduleModel {
  final String id;
  final String businessId;
  final String courseId;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? instructor;
  final String? room;
  final int capacity;
  final int enrolled;
  final bool isRecurring;
  final String? recurrenceRule;
}
```

#### Screens Required
- [ ] `courses_tab.dart` - Course management
- [ ] `course_form_screen.dart` - Add/edit course
- [ ] `class_schedule_screen.dart` - Schedule classes
- [ ] `student_management_screen.dart` - Enrolled students
- [ ] `attendance_screen.dart` - Track attendance

#### categoryData Fields
```dart
{
  'subjects': ['Mathematics', 'Science', ...],
  'classType': ['Individual', 'Group', 'Online'],
  'boardsOffered': ['CBSE', 'ICSE', 'State Board'],
  'ageGroups': ['Kids', 'Teens', 'Adults'],
}
```

#### Profile Template
`education_template.dart` - Courses, faculty, schedule, enroll button

#### Implementation Instructions
```
1. Course Management:
   - Create courses with syllabus
   - Set fee structure
   - Define batch schedules
   - Track enrollment limits

2. Class Scheduling:
   - Weekly timetable
   - Batch management
   - Room/resource allocation
   - Holiday calendar

3. Student Management:
   - Enrollment tracking
   - Fee payment status
   - Attendance records
   - Progress tracking

4. Dashboard Metrics:
   - Total students
   - Course-wise enrollment
   - Fee collection
   - Attendance rates
```

**STATUS:** `PENDING`

---

### 8. FITNESS & SPORTS

**Category ID:** `fitness`
**Color:** `#8B5CF6` (Violet)
**Icon:** `Icons.fitness_center`

#### Sub-Types
- Gym
- Yoga Studio
- Sports Academy
- Personal Trainer
- Martial Arts
- Swimming Pool
- Dance Studio
- Crossfit
- Sports Club
- Cricket Academy

#### Features
- `classes` - Group class scheduling
- `appointments` - Personal training sessions
- `services` - Membership plans

#### Data Models

**MembershipPlanModel**
```dart
class MembershipPlanModel {
  final String id;
  final String businessId;
  final String name;
  final String duration; // monthly, quarterly, annual
  final int durationMonths;
  final double price;
  final List<String> includes;
  final bool isPopular;
}
```

**FitnessClassModel**
```dart
class FitnessClassModel {
  final String id;
  final String businessId;
  final String name; // Yoga, Zumba, HIIT, etc.
  final String? description;
  final String instructor;
  final int durationMinutes;
  final int capacity;
  final List<Map<String, dynamic>> schedule; // [{day, time}]
  final bool membershipRequired;
  final double? dropInFee;
}
```

#### Screens Required
- [ ] `memberships_tab.dart` - Membership plans
- [ ] `membership_form_screen.dart` - Add/edit plan
- [ ] `classes_tab.dart` - Group classes
- [ ] `class_form_screen.dart` - Add/edit class
- [ ] `member_management_screen.dart` - Member tracking
- [ ] `trainer_schedule_screen.dart` - PT scheduling

#### categoryData Fields
```dart
{
  'activities': ['Weight Training', 'Cardio', 'Yoga', ...],
  'membershipTypes': ['Daily Pass', 'Monthly', 'Annual'],
  'facilities': ['Locker', 'Shower', 'Parking', 'Steam'],
  'operatingStyle': 'Membership + Classes',
}
```

#### Profile Template
`fitness_template.dart` - Plans, classes, facilities, trainers, join button

#### Implementation Instructions
```
1. Membership Management:
   - Create membership tiers
   - Track member subscriptions
   - Renewal reminders
   - Access control

2. Class Management:
   - Weekly class schedule
   - Instructor assignment
   - Capacity tracking
   - Drop-in vs members-only classes

3. Personal Training:
   - PT session booking
   - Trainer availability
   - Package sessions

4. Dashboard Metrics:
   - Active members
   - Membership revenue
   - Class attendance
   - Renewal rate
```

**STATUS:** `PENDING`

---

### 9. AUTOMOTIVE

**Category ID:** `automotive`
**Color:** `#64748B` (Slate)
**Icon:** `Icons.directions_car`

#### Sub-Types
- Car Dealership
- Bike Dealership
- Car Service Center
- Bike Service Center
- Car Wash
- Tyre Shop
- Auto Parts
- Car Rental
- Bike Rental
- Driving School

#### Features
- `services` - Service menu
- `vehicles` - Vehicle inventory
- `appointments` - Service appointments

#### Data Models

**VehicleModel**
```dart
class VehicleModel {
  final String id;
  final String businessId;
  final String type; // Car, Bike, Scooter
  final String make;
  final String model;
  final int year;
  final String? variant;
  final double price;
  final String condition; // New, Used
  final int? mileage;
  final String? color;
  final List<String> images;
  final Map<String, dynamic>? specifications;
  final bool isAvailable;
  final String? registrationNumber; // for rentals
}
```

**ServiceJobModel**
```dart
class ServiceJobModel {
  final String id;
  final String businessId;
  final String customerName;
  final String customerPhone;
  final String vehicleType;
  final String vehicleMake;
  final String vehicleModel;
  final String? vehicleNumber;
  final List<String> services;
  final DateTime dateTime;
  final String status; // Pending, In Progress, Completed
  final double estimatedCost;
  final double? finalCost;
  final String? notes;
}
```

#### Screens Required
- [ ] `vehicles_tab.dart` - Vehicle inventory
- [ ] `vehicle_form_screen.dart` - Add/edit vehicle
- [ ] `services_tab.dart` - Service menu
- [ ] `service_jobs_tab.dart` - Job cards/appointments
- [ ] `job_card_form_screen.dart` - Create job card

#### categoryData Fields
```dart
{
  'vehicleTypes': ['Cars', 'Bikes', 'Scooters', ...],
  'servicesOffered': ['Regular Service', 'Repairs', ...],
  'brands': ['Maruti', 'Honda', 'Toyota', ...],
  'acceptsInsurance': true,
}
```

#### Profile Template
`generic_template.dart` - Services, vehicles, book service

#### Implementation Instructions
```
1. For Dealerships:
   - Vehicle inventory management
   - Price and specifications
   - Photo gallery per vehicle
   - Test drive booking
   - Finance/loan integration

2. For Service Centers:
   - Service menu with pricing
   - Job card creation
   - Status tracking
   - Customer notifications
   - Parts inventory (optional)

3. For Rentals:
   - Vehicle availability calendar
   - Booking system
   - Document verification
   - Security deposit handling

4. Dashboard Metrics:
   - Vehicles sold/serviced
   - Revenue
   - Pending service jobs
   - Popular services
```

**STATUS:** `PENDING`

---

### 10. REAL ESTATE

**Category ID:** `real_estate`
**Color:** `#0EA5E9` (Sky Blue)
**Icon:** `Icons.apartment`

#### Sub-Types
- Real Estate Agent
- Property Dealer
- Builder
- Construction Company
- Interior Designer
- PG/Hostel
- Co-working Space
- Warehouse

#### Features
- `properties` - Property listings
- `services` - Consulting services
- `appointments` - Property viewings

#### Data Models

**PropertyModel**
```dart
class PropertyModel {
  final String id;
  final String businessId;
  final String title;
  final String type; // Apartment, House, Villa, Office, Shop
  final String listingType; // Sale, Rent, Lease
  final double price;
  final String priceUnit; // total, per month, per sqft
  final String location;
  final double? latitude;
  final double? longitude;
  final int? bedrooms;
  final int? bathrooms;
  final double area;
  final String areaUnit; // sqft, sqm
  final List<String> amenities;
  final List<String> images;
  final String? description;
  final String status; // Available, Under Negotiation, Sold/Rented
  final DateTime createdAt;
  final bool isFeatured;
}
```

#### Screens Required
- [ ] `properties_tab.dart` - Property listings
- [ ] `property_form_screen.dart` - Add/edit property
- [ ] `property_details_screen.dart` - Property details
- [ ] `inquiries_tab.dart` - Property inquiries
- [ ] `viewing_schedule_screen.dart` - Schedule viewings

#### categoryData Fields
```dart
{
  'propertyTypes': ['Residential', 'Commercial', ...],
  'servicesType': ['Buy/Sell', 'Rental', 'Lease'],
  'operatingAreas': ['City1', 'City2', ...],
  'reraRegistered': true,
  'reraNumber': 'RERA123456',
}
```

#### Profile Template
`real_estate_template.dart` - Properties grid, contact for viewing

#### Implementation Instructions
```
1. Property Listing:
   - Detailed property information
   - Multiple images/virtual tour
   - Location with map
   - Price and negotiability
   - Amenities checklist

2. Lead Management:
   - Inquiry capture
   - Property viewing scheduling
   - Follow-up tracking
   - Lead status pipeline

3. For PG/Hostel:
   - Room/bed availability
   - Monthly rent with meals
   - Facility listing
   - Booking/move-in process

4. Dashboard Metrics:
   - Active listings
   - Inquiries received
   - Properties sold/rented
   - Revenue
```

**STATUS:** `PENDING`

---

### 11. TRAVEL & TOURISM

**Category ID:** `travel_tourism`
**Color:** `#06B6D4` (Cyan)
**Icon:** `Icons.flight`

#### Sub-Types
- Travel Agency
- Tour Operator
- Visa Services
- Passport Services
- Taxi Service
- Bus Service
- Adventure Tourism
- Pilgrimage Tours

#### Features
- `packages` - Tour packages
- `bookings` - Package bookings
- `services` - Individual services

#### Data Models

**TourPackageModel**
```dart
class TourPackageModel {
  final String id;
  final String businessId;
  final String title;
  final String destination;
  final String duration; // 3N/4D
  final int nights;
  final int days;
  final double pricePerPerson;
  final String? description;
  final List<String> inclusions;
  final List<String> exclusions;
  final List<Map<String, dynamic>> itinerary;
  final List<String> images;
  final String? startDate;
  final String? endDate;
  final int maxGroupSize;
  final bool isActive;
}
```

#### Screens Required
- [ ] `packages_tab.dart` - Tour packages
- [ ] `package_form_screen.dart` - Create package
- [ ] `itinerary_builder_screen.dart` - Build day-wise itinerary
- [ ] `bookings_tab.dart` - Package bookings
- [ ] `visa_services_screen.dart` - Visa processing

#### categoryData Fields
```dart
{
  'tourTypes': ['Domestic', 'International', 'Pilgrimage', ...],
  'servicesOffered': ['Flight Booking', 'Hotel Booking', 'Visa', ...],
  'destinations': ['Goa', 'Kerala', 'Europe', ...],
}
```

#### Profile Template
`generic_template.dart` - Packages, destinations, inquire button

**STATUS:** `PENDING`

---

### 12. ENTERTAINMENT

**Category ID:** `entertainment`
**Color:** `#F97316` (Orange)
**Icon:** `Icons.celebration`

#### Sub-Types
- Event Venue
- Banquet Hall
- Party Hall
- Gaming Zone
- Amusement Park
- Cinema
- Theatre
- Night Club
- Bowling Alley
- Escape Room

#### Features
- `bookings` - Venue bookings
- `packages` - Event packages
- `services` - Additional services

#### Data Models

**VenueModel**
```dart
class VenueModel {
  final String id;
  final String businessId;
  final String name;
  final String type; // Hall, Outdoor, Poolside
  final int capacity;
  final double pricePerDay;
  final double? pricePerHour;
  final List<String> amenities;
  final List<String> images;
  final bool isAC;
  final bool cateringAvailable;
  final String? description;
}
```

**EventBookingModel**
```dart
class EventBookingModel {
  final String id;
  final String businessId;
  final String venueId;
  final String customerName;
  final String customerPhone;
  final String eventType;
  final DateTime eventDate;
  final String startTime;
  final String endTime;
  final int expectedGuests;
  final double totalAmount;
  final double advancePaid;
  final String status;
  final Map<String, dynamic>? requirements;
}
```

#### Screens Required
- [ ] `venues_tab.dart` - Venue management
- [ ] `venue_form_screen.dart` - Add venue
- [ ] `event_bookings_tab.dart` - Booking management
- [ ] `booking_calendar_screen.dart` - Availability calendar
- [ ] `packages_tab.dart` - Event packages

#### categoryData Fields
```dart
{
  'eventTypes': ['Weddings', 'Corporate Events', ...],
  'capacity': '100-300',
  'facilities': ['Parking', 'Catering', 'DJ', 'Decoration'],
  'pricingType': 'Per Day',
}
```

#### Profile Template
`generic_template.dart` - Venues, capacity, gallery, check availability

**STATUS:** `PENDING`

---

### 13. PET SERVICES

**Category ID:** `pet_services`
**Color:** `#A855F7` (Purple)
**Icon:** `Icons.pets`

#### Sub-Types
- Pet Shop
- Pet Grooming
- Pet Boarding
- Pet Training
- Veterinary Clinic
- Pet Food Store
- Pet Accessories
- Pet Adoption

#### Features
- `services` - Pet services
- `products` - Pet products
- `appointments` - Grooming/vet appointments

#### Data Models

(Uses ServiceModel and ProductModel from shared)

**BoardingModel**
```dart
class BoardingModel {
  final String id;
  final String businessId;
  final String petOwnerName;
  final String petName;
  final String petType;
  final String? petBreed;
  final DateTime checkIn;
  final DateTime checkOut;
  final double dailyRate;
  final double totalAmount;
  final String? specialInstructions;
  final String status;
}
```

#### Screens Required
- [ ] `services_tab.dart` - Services (grooming, training)
- [ ] `products_tab.dart` - Pet products
- [ ] `appointments_tab.dart` - Appointments
- [ ] `boarding_tab.dart` - Boarding management

#### categoryData Fields
```dart
{
  'petTypes': ['Dogs', 'Cats', 'Birds', ...],
  'servicesOffered': ['Grooming', 'Boarding', 'Training', ...],
  'facilitiesAvailable': ['AC Rooms', 'Play Area', 'CCTV'],
}
```

**STATUS:** `PENDING`

---

### 14. HOME SERVICES

**Category ID:** `home_services`
**Color:** `#84CC16` (Lime)
**Icon:** `Icons.home_repair_service`

#### Sub-Types
- Plumber
- Electrician
- Carpenter
- Painter
- AC Service
- Pest Control
- Cleaning Service
- Appliance Repair
- Handyman
- Movers & Packers

#### Features
- `services` - Service offerings
- `appointments` - Service bookings

#### Data Models

**ServiceRequestModel**
```dart
class ServiceRequestModel {
  final String id;
  final String businessId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final double? latitude;
  final double? longitude;
  final String serviceType;
  final String? description;
  final DateTime preferredDate;
  final String preferredTimeSlot;
  final String status;
  final double? estimatedCost;
  final double? finalCost;
  final String? technicianName;
  final String? notes;
}
```

#### Screens Required
- [ ] `services_tab.dart` - Service menu
- [ ] `service_requests_tab.dart` - Service requests
- [ ] `request_details_screen.dart` - Request details
- [ ] `technician_management_screen.dart` - Technician tracking

#### categoryData Fields
```dart
{
  'serviceTypes': ['Plumbing', 'Electrical', ...],
  'serviceArea': 'Within 10 km',
  'pricingType': 'Fixed + Hourly',
  'emergencyAvailable': true,
}
```

**STATUS:** `PENDING`

---

### 15. TECHNOLOGY & IT

**Category ID:** `technology`
**Color:** `#14B8A6` (Teal)
**Icon:** `Icons.computer`

#### Sub-Types
- IT Services
- Software Company
- Computer Repair
- Mobile Repair
- Web Development
- App Development
- Digital Marketing
- CCTV Installation
- Networking Services

#### Features
- `services` - Service offerings
- `appointments` - Consultations
- `portfolio` - Project showcase

#### Data Models

(Uses ServiceModel and PortfolioModel)

**ProjectModel**
```dart
class ProjectModel {
  final String id;
  final String businessId;
  final String title;
  final String? client;
  final String category;
  final String? description;
  final List<String> technologies;
  final List<String> images;
  final String? url;
  final DateTime completedAt;
}
```

#### Screens Required
- [ ] `services_tab.dart` - Service offerings
- [ ] `portfolio_tab.dart` - Project portfolio
- [ ] `project_form_screen.dart` - Add project
- [ ] `inquiries_tab.dart` - Service inquiries

#### categoryData Fields
```dart
{
  'techServices': ['Software Development', 'Web Development', ...],
  'clientType': ['Individuals', 'SMBs', 'Enterprises'],
  'technologies': ['Flutter', 'React', 'Node.js', ...],
}
```

**STATUS:** `PENDING`

---

### 16. FINANCIAL SERVICES

**Category ID:** `financial`
**Color:** `#059669` (Emerald Dark)
**Icon:** `Icons.account_balance`

*(Similar structure - Services + Appointments)*

**STATUS:** `PENDING`

---

### 17. LEGAL SERVICES

**Category ID:** `legal`
**Color:** `#78716C` (Stone)
**Icon:** `Icons.gavel`

*(Similar structure - Services + Appointments)*

**STATUS:** `PENDING`

---

### 18. PROFESSIONAL SERVICES

**Category ID:** `professional`
**Color:** `#6B7280` (Gray)
**Icon:** `Icons.work`

*(Similar structure - Services + Portfolio + Appointments)*

**STATUS:** `PENDING`

---

### 19. TRANSPORTATION

**Category ID:** `transportation`
**Color:** `#DC2626` (Red Dark)
**Icon:** `Icons.local_shipping`

#### Sub-Types
- Courier Service
- Logistics Company
- Taxi Service
- Auto Rickshaw
- Truck Transport
- Movers & Packers
- Ambulance Service
- School Bus
- Bike Taxi

#### Features
- `services` - Transport services
- `bookings` - Trip bookings
- `vehicles` - Fleet management

#### Data Models

**TripBookingModel**
```dart
class TripBookingModel {
  final String id;
  final String businessId;
  final String customerName;
  final String customerPhone;
  final String pickupLocation;
  final String dropLocation;
  final DateTime pickupDateTime;
  final String vehicleType;
  final String? vehicleId;
  final String? driverName;
  final double? fare;
  final String status;
  final String? notes;
}
```

**FleetVehicleModel**
```dart
class FleetVehicleModel {
  final String id;
  final String businessId;
  final String vehicleNumber;
  final String vehicleType;
  final String model;
  final int capacity;
  final String status; // Available, On Trip, Maintenance
  final String? currentDriverId;
  final DateTime? lastServiceDate;
}
```

#### Screens Required
- [ ] `bookings_tab.dart` - Trip bookings
- [ ] `vehicles_tab.dart` - Fleet management
- [ ] `drivers_tab.dart` - Driver management

**STATUS:** `PENDING`

---

### 20. ART & CREATIVE

**Category ID:** `art_creative`
**Color:** `#E11D48` (Rose)
**Icon:** `Icons.palette`

#### Sub-Types
- Photography Studio
- Graphic Designer
- Video Production
- Art Gallery
- Printing Press
- Signage & Banners
- Animation Studio
- Music Studio
- Content Creator

#### Features
- `portfolio` - Work showcase
- `services` - Creative services
- `appointments` - Bookings/sessions

#### Data Models

**PortfolioWorkModel**
```dart
class PortfolioWorkModel {
  final String id;
  final String businessId;
  final String title;
  final String category; // Wedding, Corporate, Product, etc.
  final String? description;
  final List<String> images;
  final String? videoUrl;
  final DateTime? projectDate;
  final String? clientName;
  final bool isFeatured;
}
```

#### Screens Required
- [ ] `portfolio_tab.dart` - Portfolio gallery
- [ ] `work_form_screen.dart` - Add work
- [ ] `services_tab.dart` - Service packages
- [ ] `bookings_tab.dart` - Session bookings

**STATUS:** `PENDING`

---

### 21. CONSTRUCTION

**Category ID:** `construction`
**Color:** `#CA8A04` (Yellow Dark)
**Icon:** `Icons.construction`

*(Similar structure - Services + Portfolio + Appointments)*

**STATUS:** `PENDING`

---

### 22. AGRICULTURE & NURSERY

**Category ID:** `agriculture`
**Color:** `#16A34A` (Green Dark)
**Icon:** `Icons.agriculture`

*(Similar structure - Products + Services)*

**STATUS:** `PENDING`

---

### 23. MANUFACTURING

**Category ID:** `manufacturing`
**Color:** `#57534E` (Warm Gray)
**Icon:** `Icons.factory`

*(Similar structure - Products + Orders)*

**STATUS:** `PENDING`

---

### 24. WEDDING & EVENTS

**Category ID:** `wedding_events`
**Color:** `#DB2777` (Pink Dark)
**Icon:** `Icons.cake`

#### Sub-Types
- Wedding Planner
- Event Decorator
- Caterer
- DJ & Sound
- Florist
- Mehndi Artist
- Wedding Card
- Pandit/Priest
- Wedding Venue
- Choreographer

#### Features
- `packages` - Event packages
- `services` - Individual services
- `portfolio` - Past work showcase
- `bookings` - Event bookings

#### Data Models

**EventPackageModel**
```dart
class EventPackageModel {
  final String id;
  final String businessId;
  final String name;
  final String eventType; // Wedding, Birthday, Corporate
  final String? description;
  final double basePrice;
  final List<String> includes;
  final List<Map<String, dynamic>> addOns;
  final List<String> images;
  final bool isPopular;
}
```

#### Screens Required
- [ ] `packages_tab.dart` - Event packages
- [ ] `package_form_screen.dart` - Create package
- [ ] `portfolio_tab.dart` - Past events gallery
- [ ] `bookings_tab.dart` - Event bookings
- [ ] `inquiry_management_screen.dart` - Lead management

**STATUS:** `PENDING`

---

## Implementation Guidelines

### Adding a New Category Implementation

1. **Create/Update Models**
   - Add any category-specific models in `lib/models/`
   - Ensure models have `fromMap`, `toMap`, `copyWith` methods

2. **Create Screens**
   - Create screens in `lib/screens/business/{category_folder}/`
   - Follow existing patterns (tabs, forms, lists)

3. **Update Services**
   - Add CRUD methods in `business_service.dart`
   - Create category-specific service if needed

4. **Create Profile Template**
   - Add template in `lib/screens/business/profile_view/templates/`
   - Register template in profile selector

5. **Update Dashboard**
   - Ensure `business_home_tab.dart` adapts to category features
   - Add category-specific metrics

6. **Test Thoroughly**
   - Test all CRUD operations
   - Test Firestore security rules
   - Test profile view rendering

### Marking Category as Done

Update the status table and add checkmarks to completed screens:
- Change status from `PENDING` to `IN_PROGRESS` when starting
- Change to `DONE` when all screens are implemented and tested
- Add ` - DONE` suffix to completed items in Implementation Instructions

---

## Notes & Decisions Log

### 2024-XX-XX
- Initial document created
- Architecture defined
- All 24 categories documented

---

*Last Updated: [Auto-update on changes]*

---

## Database Storage & Data Flow

### Complete Firestore Structure

```
firestore-root/
│
├── users/{userId}                              # Personal user profiles
│   ├── uid: string
│   ├── name: string
│   ├── email: string
│   ├── photoUrl: string
│   ├── bio: string
│   ├── location: string
│   ├── latitude: number
│   ├── longitude: number
│   ├── interests: string[]
│   ├── isOnline: boolean
│   ├── lastSeen: timestamp
│   ├── isBusiness: boolean                     # true if user has a business
│   ├── businessId: string                      # Reference to business document
│   └── fcmToken: string
│
├── businesses/{businessId}                     # Business profiles
│   ├── ownerId: string                         # Link to user who owns this business
│   ├── name: string
│   ├── tagline: string
│   ├── description: string
│   ├── category: string                        # e.g., "food_beverage"
│   ├── subType: string                         # e.g., "Restaurant"
│   ├── logoUrl: string
│   ├── coverImageUrl: string
│   ├── images: string[]                        # Gallery images
│   ├── address: string
│   ├── city: string
│   ├── state: string
│   ├── pincode: string
│   ├── latitude: number
│   ├── longitude: number
│   ├── phone: string
│   ├── email: string
│   ├── website: string
│   ├── socialLinks: { facebook, instagram, twitter }
│   │
│   ├── operatingHours: {                       # Business hours
│   │     monday: { open: "09:00", close: "21:00", isClosed: false },
│   │     tuesday: { ... },
│   │     ...
│   │   }
│   │
│   ├── categoryData: {                         # Category-specific fields
│   │     // Varies by category (see category details above)
│   │   }
│   │
│   ├── features: string[]                      # Enabled features for this business
│   ├── rating: number                          # Average rating (0-5)
│   ├── reviewCount: number
│   ├── isVerified: boolean
│   ├── isActive: boolean
│   ├── createdAt: timestamp
│   ├── updatedAt: timestamp
│   │
│   └── Sub-collections (based on category features):
│       ├── menu_categories/{categoryId}        # Food & Beverage
│       ├── menu_items/{itemId}
│       ├── products/{productId}                # Retail, Grocery
│       ├── product_categories/{categoryId}
│       ├── services/{serviceId}                # All service businesses
│       ├── service_categories/{categoryId}
│       ├── rooms/{roomId}                      # Hospitality
│       ├── bookings/{bookingId}
│       ├── appointments/{appointmentId}        # Healthcare, Beauty
│       ├── orders/{orderId}                    # Retail, Food
│       ├── courses/{courseId}                  # Education
│       ├── classes/{classId}                   # Fitness, Education
│       ├── packages/{packageId}                # Travel, Events
│       ├── properties/{propertyId}             # Real Estate
│       ├── vehicles/{vehicleId}                # Automotive
│       ├── portfolio/{workId}                  # Creative, Professional
│       ├── staff/{staffId}                     # Employees/Doctors/Stylists
│       └── reviews/{reviewId}
│
├── posts/{postId}                              # AI-matched posts (personal & business)
│   ├── userId: string                          # Can be personal user OR business owner
│   ├── businessId: string                      # Optional - if post is from a business
│   ├── isBusinessPost: boolean                 # true if from business
│   ├── originalPrompt: string
│   ├── title: string
│   ├── description: string
│   ├── intentAnalysis: {
│   │     primary_intent: string,
│   │     action_type: "seeking" | "offering" | "neutral",
│   │     domain: string,
│   │     entities: { ... },
│   │     complementary_intents: [...],
│   │     search_keywords: [...]
│   │   }
│   ├── embedding: number[]                     # 768-dim vector
│   ├── keywords: string[]
│   ├── location: string
│   ├── latitude: number
│   ├── longitude: number
│   ├── price: number
│   ├── priceMin: number
│   ├── priceMax: number
│   ├── category: string                        # Business category (if business post)
│   ├── isActive: boolean
│   ├── createdAt: timestamp
│   └── expiresAt: timestamp
│
├── conversations/{conversationId}              # Chat between users/businesses
│   ├── participants: [userId1, userId2]
│   ├── participantDetails: {
│   │     [userId]: { name, photoUrl, isBusiness, businessId }
│   │   }
│   ├── lastMessage: string
│   ├── lastMessageTime: timestamp
│   ├── unreadCount: { [userId]: number }
│   └── messages/{messageId}
│       ├── senderId: string
│       ├── receiverId: string
│       ├── text: string
│       ├── imageUrl: string
│       ├── timestamp: timestamp
│       └── read: boolean
│
├── connection_requests/{requestId}             # Connection/inquiry requests
│   ├── senderId: string
│   ├── senderName: string
│   ├── senderPhoto: string
│   ├── senderIsBusiness: boolean
│   ├── senderBusinessId: string
│   ├── receiverId: string
│   ├── receiverIsBusiness: boolean
│   ├── receiverBusinessId: string
│   ├── message: string
│   ├── postId: string                          # Related post (if from matching)
│   ├── status: "pending" | "accepted" | "rejected"
│   ├── createdAt: timestamp
│   └── updatedAt: timestamp
│
├── notifications/{notificationId}              # Push/in-app notifications
│   ├── userId: string
│   ├── senderId: string
│   ├── title: string
│   ├── body: string
│   ├── type: string
│   ├── data: { ... }
│   ├── read: boolean
│   └── createdAt: timestamp
│
└── reviews/{reviewId}                          # Business reviews
    ├── businessId: string
    ├── userId: string
    ├── userName: string
    ├── userPhoto: string
    ├── rating: number                          # 1-5 stars
    ├── comment: string
    ├── images: string[]
    ├── reply: string                           # Business reply
    ├── replyAt: timestamp
    └── createdAt: timestamp
```

### Data Flow: Creating a Business Post

```
┌─────────────────────────────────────────────────────────────────────┐
│                     BUSINESS POST CREATION FLOW                     │
└─────────────────────────────────────────────────────────────────────┘

1. Business Owner Types Prompt
   ┌─────────────────────────────────────────────────────────────────┐
   │  "Fresh homemade pizzas available for delivery, order now!"     │
   └─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
2. UniversalIntentService.processInput()
   ┌─────────────────────────────────────────────────────────────────┐
   │  - Calls GeminiService for intent analysis                      │
   │  - Detects: action_type = "offering"                            │
   │  - Detects: domain = "food_delivery"                            │
   │  - Extracts: entities = { food_type: "pizza", service: "delivery" }│
   └─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
3. UnifiedIntentProcessor.checkClarificationNeeded()
   ┌─────────────────────────────────────────────────────────────────┐
   │  - If ambiguous: Show clarification dialog                      │
   │  - If clear: Proceed to create post                             │
   └─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
4. GeminiService.getEmbedding()
   ┌─────────────────────────────────────────────────────────────────┐
   │  - Generates 768-dimension vector embedding                     │
   │  - Combines: original prompt + business context                 │
   └─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
5. UnifiedPostService.createPost()
   ┌─────────────────────────────────────────────────────────────────┐
   │  Posts to Firestore: posts/{newPostId}                          │
   │  {                                                              │
   │    userId: "owner123",                                          │
   │    businessId: "business456",                                   │
   │    isBusinessPost: true,                                        │
   │    originalPrompt: "Fresh homemade pizzas...",                  │
   │    title: "Fresh Homemade Pizzas - Delivery Available",         │
   │    description: "Order freshly made pizzas delivered to...",    │
   │    intentAnalysis: { ... },                                     │
   │    embedding: [0.123, -0.456, ...],  // 768 values              │
   │    category: "food_beverage",                                   │
   │    location: "Mumbai",                                          │
   │    isActive: true,                                              │
   │    createdAt: now,                                              │
   │    expiresAt: now + 7 days                                      │
   │  }                                                              │
   └─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
6. UnifiedMatchingService.findMatches()
   ┌─────────────────────────────────────────────────────────────────┐
   │  - Finds complementary posts (seeking pizza/food delivery)      │
   │  - Calculates cosine similarity between embeddings              │
   │  - Applies weighting: 70% semantic + 15% location + 15% price   │
   │  - Returns ranked matches                                       │
   └─────────────────────────────────────────────────────────────────┘
```

### Data Flow: Customer Finding a Business

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CUSTOMER SEARCH & MATCH FLOW                     │
└─────────────────────────────────────────────────────────────────────┘

1. Customer Types Search Prompt
   ┌─────────────────────────────────────────────────────────────────┐
   │  "Looking for a good pizza place nearby with delivery"          │
   └─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
2. AI Intent Analysis
   ┌─────────────────────────────────────────────────────────────────┐
   │  intentAnalysis: {                                              │
   │    primary_intent: "find_restaurant",                           │
   │    action_type: "seeking",                                      │
   │    domain: "food_delivery",                                     │
   │    entities: { cuisine: "pizza", requirement: "delivery" },     │
   │    complementary_intents: ["offering_food", "pizza_restaurant"] │
   │  }                                                              │
   └─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
3. Create Customer Post + Generate Embedding
                                    │
                                    ▼
4. Semantic Matching Algorithm
   ┌─────────────────────────────────────────────────────────────────┐
   │  Query: posts WHERE isActive = true AND action_type = "offering"│
   │                                                                 │
   │  For each candidate post:                                       │
   │    similarity_score = cosine_similarity(customer_emb, post_emb) │
   │    location_score = calculate_distance(customer_loc, post_loc)  │
   │    price_score = check_price_compatibility()                    │
   │                                                                 │
   │    final_score = (0.70 * similarity_score) +                    │
   │                  (0.15 * location_score) +                      │
   │                  (0.15 * price_score)                           │
   └─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
5. Return Matched Businesses
   ┌─────────────────────────────────────────────────────────────────┐
   │  Results: [                                                     │
   │    { businessId: "pizza_place_1", score: 0.92, ... },          │
   │    { businessId: "pizza_place_2", score: 0.87, ... },          │
   │    { businessId: "italian_resto", score: 0.78, ... },          │
   │  ]                                                              │
   └─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
6. Display Business Profiles to Customer
```

---

## Profile Display System

### How Business Profiles Are Displayed

#### 1. Business Owner's View (Dashboard)

```
┌─────────────────────────────────────────────────────────────────────┐
│                    BUSINESS DASHBOARD VIEW                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────┐  Mario's Pizzeria                    [Edit Profile]   │
│  │  LOGO   │  Italian Restaurant | ⭐ 4.5 (128)                     │
│  └─────────┘  📍 Andheri West, Mumbai                               │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                     TODAY'S METRICS                                 │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐               │
│  │   12    │  │   8     │  │  ₹4,500 │  │   3     │               │
│  │ Orders  │  │ Messages│  │ Revenue │  │ Matches │               │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘               │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                       QUICK ACTIONS                                 │
│  [📝 Add Menu Item]  [📢 Create Post]  [📊 Analytics]              │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│  RECENT ORDERS                                          [View All]  │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ #1234 | Rahul S. | 2 Margherita, 1 Pepperoni | ₹750 | NEW    │ │
│  │ #1233 | Priya M. | 1 Farm Fresh | ₹450 | PREPARING            │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│  MATCHED CUSTOMERS (Potential Leads)                    [View All]  │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ 👤 Amit K. | "Looking for pizza delivery" | 92% match         │ │
│  │ 👤 Sara J. | "Italian food near Andheri" | 87% match          │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
│    🏠 Home    │   💬 Messages   │   📋 Menu   │   👤 Profile       │
└─────────────────────────────────────────────────────────────────────┘
```

#### 2. Customer's View (Business Profile Card)

When customers find a business through matching:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    BUSINESS PROFILE CARD                            │
│                   (Shown in Match Results)                          │
├─────────────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                      [COVER IMAGE]                            │ │
│  │                                                               │ │
│  │  ┌─────────┐                                                  │ │
│  │  │  LOGO   │                                                  │ │
│  │  └─────────┘                                                  │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│   Mario's Pizzeria                                    92% Match    │
│   ⭐ 4.5 (128 reviews) | Italian Restaurant                        │
│   📍 2.3 km away • Andheri West                                    │
│   🕐 Open Now • Closes 11 PM                                        │
│                                                                     │
│   ───────────────────────────────────────────────────────────────  │
│   "Authentic wood-fired pizzas made with love since 1995..."       │
│   ───────────────────────────────────────────────────────────────  │
│                                                                     │
│   HIGHLIGHTS                                                        │
│   🍕 Pure Veg & Non-Veg  |  🚗 Delivery  |  💺 Dine-in             │
│   💰 ₹400 for two       |  🏷️ 20% off on first order              │
│                                                                     │
│   POPULAR ITEMS                                                     │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐                        │
│   │ Marghe-  │  │ Pepperoni│  │ Farm     │                        │
│   │ rita     │  │ Special  │  │ Fresh    │                        │
│   │ ₹299     │  │ ₹449     │  │ ₹399     │                        │
│   └──────────┘  └──────────┘  └──────────┘                        │
│                                                                     │
│   ┌─────────────────────┐  ┌─────────────────────┐                │
│   │     💬 Message      │  │     📞 Call         │                │
│   └─────────────────────┘  └─────────────────────┘                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

#### 3. Full Business Profile View

When customer taps to see full details:

```
┌─────────────────────────────────────────────────────────────────────┐
│  ←  Mario's Pizzeria                              [Share] [Save]   │
├─────────────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                   [SCROLLABLE GALLERY]                        │ │
│  │   [img1]    [img2]    [img3]    [img4]    [img5]              │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│   Mario's Pizzeria                              ✓ Verified         │
│   Italian Restaurant                                                │
│   ⭐ 4.5 (128 reviews)                                              │
│                                                                     │
│   📍 Shop 12, Harmony Plaza, Andheri West, Mumbai 400053           │
│   📞 +91 98765 43210                                                │
│   🌐 www.mariospizzeria.com                                         │
│                                                                     │
│   ───────────────────────────────────────────────────────────────  │
│                                                                     │
│   📋 MENU                                              [View Full]  │
│   ┌───────────────────────────────────────────────────────────────┐│
│   │ PIZZAS                                                        ││
│   │ ├─ Margherita ............................ ₹299               ││
│   │ ├─ Pepperoni Special ..................... ₹449               ││
│   │ ├─ Farm Fresh (Veg) ...................... ₹399               ││
│   │ └─ BBQ Chicken ........................... ₹499               ││
│   │                                                               ││
│   │ PASTA                                                         ││
│   │ ├─ Alfredo ............................... ₹349               ││
│   │ └─ Arrabiata ............................ ₹299               ││
│   └───────────────────────────────────────────────────────────────┘│
│                                                                     │
│   🕐 BUSINESS HOURS                                                 │
│   ┌───────────────────────────────────────────────────────────────┐│
│   │ Monday - Friday    11:00 AM - 11:00 PM                        ││
│   │ Saturday - Sunday  10:00 AM - 12:00 AM                        ││
│   └───────────────────────────────────────────────────────────────┘│
│                                                                     │
│   ⭐ REVIEWS                                           [Write Review]│
│   ┌───────────────────────────────────────────────────────────────┐│
│   │ 👤 Rahul S.  ⭐⭐⭐⭐⭐  "Best pizza in Mumbai!"                 ││
│   │ 👤 Priya M.  ⭐⭐⭐⭐   "Good food, quick delivery"             ││
│   └───────────────────────────────────────────────────────────────┘│
│                                                                     │
│   📍 LOCATION                                                       │
│   ┌───────────────────────────────────────────────────────────────┐│
│   │                    [MAP VIEW]                                 ││
│   │              📍 Mario's Pizzeria                               ││
│   │                  [Get Directions]                             ││
│   └───────────────────────────────────────────────────────────────┘│
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐       │
│  │  💬 Message    │  │   📞 Call      │  │  🛒 Order      │       │
│  └────────────────┘  └────────────────┘  └────────────────┘       │
└─────────────────────────────────────────────────────────────────────┘
```

### Profile Templates by Category

Each business category uses a specialized profile template:

| Category | Template | Key Display Elements |
|----------|----------|---------------------|
| Food & Beverage | `restaurant_template` | Menu, food photos, dietary tags, delivery options |
| Hospitality | `hotel_template` | Rooms, amenities, check-in/out, booking calendar |
| Retail | `retail_template` | Products grid, categories, pricing, shop button |
| Healthcare | `healthcare_template` | Doctors, specializations, appointment slots |
| Beauty & Wellness | `salon_template` | Services, stylists, gallery, book appointment |
| Education | `education_template` | Courses, faculty, schedule, enrollment |
| Fitness | `fitness_template` | Plans, classes, trainers, facilities |
| Real Estate | `real_estate_template` | Properties grid, filters, viewing request |
| Art & Creative | `portfolio_template` | Portfolio gallery, projects, hire button |
| Generic | `generic_template` | Services list, contact info, inquiry button |

---

## Complete Business Model

### Overview: How Plink Works

```
┌─────────────────────────────────────────────────────────────────────┐
│                         PLINK BUSINESS MODEL                        │
│              AI-Powered Local Business Discovery Platform           │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                          VALUE PROPOSITION                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   FOR CUSTOMERS                        FOR BUSINESSES               │
│   ───────────────                      ──────────────               │
│   • Natural language search            • Free business listing      │
│   • AI-powered matching                • AI-matched customer leads  │
│   • Discover local businesses          • No ads required           │
│   • Direct communication               • Direct customer messaging  │
│   • One app for all needs              • Category-specific tools   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### User Journey: Personal Users

```
┌─────────────────────────────────────────────────────────────────────┐
│                    PERSONAL USER JOURNEY                            │
└─────────────────────────────────────────────────────────────────────┘

1. SIGN UP
   ┌──────────────────────────────────────────────────────────────┐
   │  User creates account with:                                  │
   │  • Phone/Email authentication                                │
   │  • Basic profile (name, photo, location)                     │
   │  • Optional interests                                        │
   └──────────────────────────────────────────────────────────────┘
                              │
                              ▼
2. DISCOVER (Natural Language Search)
   ┌──────────────────────────────────────────────────────────────┐
   │  User types what they need:                                  │
   │  • "Need a plumber urgently"                                 │
   │  • "Looking for yoga classes near me"                        │
   │  • "Best birthday cake shop"                                 │
   │  • "Selling my old iPhone"                                   │
   │                                                              │
   │  AI understands intent and finds:                            │
   │  • Matching businesses (for services/products)               │
   │  • Matching users (for P2P marketplace/social)               │
   └──────────────────────────────────────────────────────────────┘
                              │
                              ▼
3. BROWSE MATCHES
   ┌──────────────────────────────────────────────────────────────┐
   │  View matched results:                                       │
   │  • Business profiles with match % score                      │
   │  • Distance, ratings, key info                               │
   │  • Quick actions (message, call)                             │
   └──────────────────────────────────────────────────────────────┘
                              │
                              ▼
4. CONNECT
   ┌──────────────────────────────────────────────────────────────┐
   │  • Send message/inquiry                                      │
   │  • Make voice call                                           │
   │  • Book appointment/service                                  │
   │  • Place order                                               │
   └──────────────────────────────────────────────────────────────┘
                              │
                              ▼
5. TRANSACT & REVIEW
   ┌──────────────────────────────────────────────────────────────┐
   │  • Complete transaction (external)                           │
   │  • Leave review/rating                                       │
   │  • Save favorite businesses                                  │
   │  • Re-order/rebook                                           │
   └──────────────────────────────────────────────────────────────┘
```

### User Journey: Business Owners

```
┌─────────────────────────────────────────────────────────────────────┐
│                    BUSINESS OWNER JOURNEY                           │
└─────────────────────────────────────────────────────────────────────┘

1. SIGN UP & CREATE BUSINESS
   ┌──────────────────────────────────────────────────────────────┐
   │  Step 1: Personal Account                                    │
   │  • Same sign-up as personal users                            │
   │                                                              │
   │  Step 2: Register Business                                   │
   │  • Select category (24 options)                              │
   │  • Select sub-type (varies by category)                      │
   │  • Enter business details                                    │
   │  • Upload logo, cover image                                  │
   │  • Set operating hours                                       │
   │  • Add location                                              │
   └──────────────────────────────────────────────────────────────┘
                              │
                              ▼
2. SET UP CATEGORY-SPECIFIC FEATURES
   ┌──────────────────────────────────────────────────────────────┐
   │  Based on category, business sets up:                        │
   │                                                              │
   │  Restaurant:   Menu categories → Menu items                  │
   │  Hotel:        Room types → Amenities → Policies             │
   │  Salon:        Services → Stylists → Appointment slots       │
   │  Retail:       Product categories → Products → Pricing       │
   │  Healthcare:   Doctors → Services → Timings                  │
   │  ...                                                         │
   └──────────────────────────────────────────────────────────────┘
                              │
                              ▼
3. CREATE POSTS (Get Discovered)
   ┌──────────────────────────────────────────────────────────────┐
   │  Business creates posts to attract customers:                │
   │                                                              │
   │  • "Fresh pizzas ready for delivery!"                        │
   │  • "50% off on hair treatments this week"                    │
   │  • "Luxury rooms available for weekend bookings"             │
   │                                                              │
   │  AI generates embeddings and matches with seeking customers  │
   └──────────────────────────────────────────────────────────────┘
                              │
                              ▼
4. RECEIVE & MANAGE LEADS
   ┌──────────────────────────────────────────────────────────────┐
   │  • View matched customers (potential leads)                  │
   │  • Receive inquiry messages                                  │
   │  • Respond to queries                                        │
   │  • Convert leads to customers                                │
   └──────────────────────────────────────────────────────────────┘
                              │
                              ▼
5. MANAGE OPERATIONS
   ┌──────────────────────────────────────────────────────────────┐
   │  Dashboard features:                                         │
   │  • Orders/Bookings management                                │
   │  • Customer messages                                         │
   │  • Analytics & insights                                      │
   │  • Inventory/menu updates                                    │
   │  • Review responses                                          │
   └──────────────────────────────────────────────────────────────┘
```

### Matching Algorithm Deep Dive

```
┌─────────────────────────────────────────────────────────────────────┐
│                     AI MATCHING ALGORITHM                           │
└─────────────────────────────────────────────────────────────────────┘

INPUT: User search prompt
       "I need a good Italian restaurant with home delivery near Andheri"

                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  STEP 1: INTENT ANALYSIS (Gemini AI)                               │
├─────────────────────────────────────────────────────────────────────┤
│  {                                                                  │
│    "primary_intent": "find_restaurant",                            │
│    "action_type": "seeking",                                       │
│    "domain": "food_delivery",                                      │
│    "entities": {                                                   │
│      "cuisine": "Italian",                                         │
│      "service": "home_delivery",                                   │
│      "location": "Andheri"                                         │
│    },                                                              │
│    "complementary_intents": [                                      │
│      "restaurant_offering_delivery",                               │
│      "italian_food_provider"                                       │
│    ],                                                              │
│    "search_keywords": [                                            │
│      "italian", "restaurant", "delivery", "pizza", "pasta"         │
│    ]                                                               │
│  }                                                                 │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  STEP 2: EMBEDDING GENERATION (text-embedding-004)                 │
├─────────────────────────────────────────────────────────────────────┤
│  Input text: Original prompt + Intent analysis + Location          │
│  Output: 768-dimensional vector                                    │
│                                                                    │
│  embedding = [0.0234, -0.1456, 0.0891, ..., 0.0567]  // 768 dims  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  STEP 3: CANDIDATE RETRIEVAL                                       │
├─────────────────────────────────────────────────────────────────────┤
│  Query Firestore:                                                  │
│  - posts WHERE isActive = true                                     │
│  - AND action_type = "offering"                                    │
│  - AND category IN ["food_beverage", null]                         │
│  - LIMIT 100                                                       │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  STEP 4: SIMILARITY SCORING                                        │
├─────────────────────────────────────────────────────────────────────┤
│  For each candidate post:                                          │
│                                                                    │
│  1. SEMANTIC SIMILARITY (70% weight)                               │
│     cosine_sim = dot(user_emb, post_emb) /                        │
│                  (norm(user_emb) * norm(post_emb))                 │
│                                                                    │
│  2. LOCATION PROXIMITY (15% weight)                                │
│     distance = haversine(user_lat_lng, post_lat_lng)              │
│     location_score = 1 - (distance / max_distance)                │
│                                                                    │
│  3. PRICE COMPATIBILITY (15% weight)                               │
│     if user_budget and post_price:                                │
│       price_score = 1 - abs(user_budget - post_price) / max_price │
│     else:                                                         │
│       price_score = 0.5  // neutral                               │
│                                                                    │
│  FINAL_SCORE = (0.70 * semantic) + (0.15 * location) +            │
│                (0.15 * price)                                      │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  STEP 5: RANKING & FILTERING                                       │
├─────────────────────────────────────────────────────────────────────┤
│  - Sort by FINAL_SCORE descending                                  │
│  - Filter out: own posts, blocked users, expired posts             │
│  - Apply minimum threshold (e.g., score > 0.5)                     │
│  - Return top 20 matches                                           │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
OUTPUT: Ranked list of matched businesses/users
        [
          { businessId: "mario_pizza", score: 0.92, name: "Mario's..." },
          { businessId: "bella_italia", score: 0.87, name: "Bella..." },
          ...
        ]
```

### Revenue Model (Future)

```
┌─────────────────────────────────────────────────────────────────────┐
│                      REVENUE STREAMS                                │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  FREE TIER (Current)                                               │
├─────────────────────────────────────────────────────────────────────┤
│  For Customers:                                                    │
│  • Unlimited searches                                              │
│  • View all business profiles                                      │
│  • Direct messaging                                                │
│  • Voice calls                                                     │
│                                                                    │
│  For Businesses:                                                   │
│  • Basic business profile                                          │
│  • Appear in search results                                        │
│  • Receive customer messages                                       │
│  • Basic analytics                                                 │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  PREMIUM TIER (Planned)                                            │
├─────────────────────────────────────────────────────────────────────┤
│  Business Premium (₹999-2999/month):                               │
│  • Featured/boosted listings                                       │
│  • Priority in search results                                      │
│  • Advanced analytics dashboard                                    │
│  • Customer insights                                               │
│  • Multiple staff accounts                                         │
│  • Automated responses                                             │
│  • Verified badge                                                  │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  TRANSACTION FEES (Planned)                                        │
├─────────────────────────────────────────────────────────────────────┤
│  • Booking commission: 2-5% per transaction                        │
│  • Order commission: 1-3% per order                                │
│  • Payment processing: Standard gateway fees                       │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  ADVERTISING (Planned)                                             │
├─────────────────────────────────────────────────────────────────────┤
│  • Sponsored posts in feed                                         │
│  • Featured category placement                                     │
│  • Banner ads (non-intrusive)                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Key Differentiators

```
┌─────────────────────────────────────────────────────────────────────┐
│                    WHY PLINK IS DIFFERENT                          │
└─────────────────────────────────────────────────────────────────────┘

1. AI-FIRST APPROACH
   ┌──────────────────────────────────────────────────────────────┐
   │  Traditional Apps:          Plink:                          │
   │  • Browse categories        • Type what you need            │
   │  • Filter manually          • AI understands intent         │
   │  • Keyword search           • Semantic matching             │
   │  • Static results           • Personalized matches          │
   └──────────────────────────────────────────────────────────────┘

2. NO HARDCODED CATEGORIES
   ┌──────────────────────────────────────────────────────────────┐
   │  Traditional Apps:          Plink:                          │
   │  • Fixed category tree      • AI infers category from text  │
   │  • Limited to predefined    • Understands any request       │
   │  • Users must navigate      • Natural conversation          │
   └──────────────────────────────────────────────────────────────┘

3. BIDIRECTIONAL MATCHING
   ┌──────────────────────────────────────────────────────────────┐
   │  Traditional Apps:          Plink:                          │
   │  • Users search businesses  • Users search → see businesses │
   │  • Businesses wait          • Businesses → see matched leads│
   │  • One-way discovery        • Two-way lead generation       │
   └──────────────────────────────────────────────────────────────┘

4. UNIFIED PLATFORM
   ┌──────────────────────────────────────────────────────────────┐
   │  Traditional Apps:          Plink:                          │
   │  • Zomato for food          • One app for everything        │
   │  • Practo for doctors       • Restaurants, hotels, services │
   │  • UrbanCompany for home    • Healthcare, retail, and more  │
   │  • Multiple apps needed     • Single discovery platform     │
   └──────────────────────────────────────────────────────────────┘

5. VOICE-ONLY CALLING
   ┌──────────────────────────────────────────────────────────────┐
   │  • Privacy-focused: No video surveillance                   │
   │  • Lower bandwidth requirement                              │
   │  • Works in low connectivity areas                          │
   │  • Professional communication                               │
   └──────────────────────────────────────────────────────────────┘
```

### Data Privacy & Security

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DATA PRIVACY PRINCIPLES                         │
└─────────────────────────────────────────────────────────────────────┘

1. LOCATION PRIVACY
   • Store city name only (not exact GPS in display)
   • Exact coordinates used only for distance calculation
   • Users control location sharing

2. COMMUNICATION PRIVACY
   • End-to-end encryption for messages (planned)
   • No message content used for advertising
   • Voice calls are peer-to-peer (WebRTC)

3. DATA MINIMIZATION
   • Collect only necessary data
   • Clear data retention policies
   • User can delete account and data

4. BUSINESS DATA
   • Business owns their customer data
   • No selling of customer lists
   • Analytics aggregated (not individual)
```

---

## Implementation Checklist

### Core Infrastructure
- [x] Firebase Authentication
- [x] Firestore Database
- [x] Firebase Storage
- [x] FCM Push Notifications
- [x] Gemini AI Integration
- [x] WebRTC Voice Calling
- [x] Location Services

### Personal User Features
- [x] User Registration/Login
- [x] Profile Management
- [x] Natural Language Search
- [x] AI Matching
- [x] View Matches
- [x] Messaging
- [x] Voice Calling
- [x] Notifications
- [ ] Review/Rating System
- [ ] Save Favorites

### Business Features
- [x] Business Registration
- [x] Category Selection
- [x] Business Profile Setup
- [x] Logo/Cover Upload
- [x] Operating Hours
- [x] Post Creation
- [x] Lead Notifications
- [x] Customer Messaging
- [ ] Full Analytics Dashboard
- [ ] All Category-Specific Features (see status table above)

### Profile Templates
- [x] Generic Template
- [x] Restaurant Template (partial)
- [ ] Hotel Template
- [ ] Salon Template
- [ ] Healthcare Template
- [ ] Education Template
- [ ] Fitness Template
- [ ] Real Estate Template
- [ ] Portfolio Template
- [ ] Retail Template

---

## How Any User's Prompt Works (End-to-End Flow)

This section explains exactly what happens when **any user anywhere in the world** types a prompt, how data is stored, and how business profiles are displayed.

### Scenario: User Types "I need a good pizza place nearby"

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    COMPLETE USER PROMPT → BUSINESS MATCH FLOW               │
│                         (What happens behind the scenes)                    │
└─────────────────────────────────────────────────────────────────────────────┘

USER: Rahul in Mumbai opens Plink app and types:
      "I need a good pizza place nearby with delivery"

┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 1: USER INPUT CAPTURE                                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  App captures:                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  {                                                                   │   │
│  │    "userId": "rahul_123",                                           │   │
│  │    "originalPrompt": "I need a good pizza place nearby with delivery"│   │
│  │    "userLocation": {                                                 │   │
│  │      "latitude": 19.1176,                                           │   │
│  │      "longitude": 72.9060,                                          │   │
│  │      "city": "Mumbai",                                              │   │
│  │      "area": "Andheri West"                                         │   │
│  │    },                                                               │   │
│  │    "timestamp": "2024-01-15T14:30:00Z"                              │   │
│  │  }                                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 2: AI INTENT ANALYSIS (Gemini AI)                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  GeminiService.analyzeIntent() processes the prompt:                        │
│                                                                             │
│  INPUT:  "I need a good pizza place nearby with delivery"                   │
│                                                                             │
│  OUTPUT (intentAnalysis):                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  {                                                                   │   │
│  │    "primary_intent": "find_food_delivery",                          │   │
│  │    "action_type": "seeking",        // User WANTS something         │   │
│  │    "domain": "food_beverage",                                       │   │
│  │    "confidence": 0.95,                                              │   │
│  │    "entities": {                                                    │   │
│  │      "food_type": "pizza",                                          │   │
│  │      "requirement": "delivery",                                     │   │
│  │      "quality_preference": "good",                                  │   │
│  │      "location_context": "nearby"                                   │   │
│  │    },                                                               │   │
│  │    "complementary_intents": [                                       │   │
│  │      "restaurant_offering_delivery",                                │   │
│  │      "pizza_shop_offering",                                         │   │
│  │      "italian_restaurant_delivery"                                  │   │
│  │    ],                                                               │   │
│  │    "search_keywords": [                                             │   │
│  │      "pizza", "delivery", "restaurant", "italian", "food"           │   │
│  │    ],                                                               │   │
│  │    "inferred_category": "food_beverage"                             │   │
│  │  }                                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  KEY INSIGHT: AI detected this is "seeking" - user wants something.        │
│  Will match with "offering" posts from businesses.                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 3: GENERATE SEMANTIC EMBEDDING                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  GeminiService.getEmbedding() creates a 768-dimension vector:               │
│                                                                             │
│  Combined text for embedding:                                               │
│  "I need a good pizza place nearby with delivery | seeking | food_beverage │
│   | pizza delivery restaurant italian | Mumbai Andheri"                     │
│                                                                             │
│  Output:                                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  embedding = [                                                       │   │
│  │    0.0234, -0.1456, 0.0891, 0.2341, -0.0567, 0.1234, ...            │   │
│  │    // 768 floating-point numbers that represent the semantic meaning │   │
│  │  ]                                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  This vector captures the MEANING of the request, not just keywords.        │
│  Similar requests will have similar vectors (high cosine similarity).       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 4: CREATE & STORE USER POST                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  UnifiedPostService.createPost() saves to Firestore:                        │
│                                                                             │
│  COLLECTION: posts/{auto-generated-id}                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  {                                                                   │   │
│  │    "id": "post_abc123xyz",                                          │   │
│  │    "userId": "rahul_123",                                           │   │
│  │    "businessId": null,              // Personal user, not business   │   │
│  │    "isBusinessPost": false,                                         │   │
│  │                                                                      │   │
│  │    "originalPrompt": "I need a good pizza place nearby with delivery"│   │
│  │    "title": "Looking for Pizza Delivery",     // AI-generated        │   │
│  │    "description": "Searching for a quality pizza restaurant with    │   │
│  │                    home delivery service in the nearby area",       │   │
│  │                                                                      │   │
│  │    "intentAnalysis": {                                              │   │
│  │      "primary_intent": "find_food_delivery",                        │   │
│  │      "action_type": "seeking",                                      │   │
│  │      "domain": "food_beverage",                                     │   │
│  │      "entities": { "food_type": "pizza", "requirement": "delivery" }│   │
│  │      "complementary_intents": ["restaurant_offering_delivery", ...] │   │
│  │      "search_keywords": ["pizza", "delivery", "restaurant", ...]    │   │
│  │    },                                                               │   │
│  │                                                                      │   │
│  │    "embedding": [0.0234, -0.1456, 0.0891, ...],  // 768 dimensions  │   │
│  │    "keywords": ["pizza", "delivery", "restaurant", "food"],         │   │
│  │                                                                      │   │
│  │    "location": "Andheri West, Mumbai",                              │   │
│  │    "latitude": 19.1176,                                             │   │
│  │    "longitude": 72.9060,                                            │   │
│  │                                                                      │   │
│  │    "price": null,                   // No budget specified           │   │
│  │    "priceMin": null,                                                │   │
│  │    "priceMax": null,                                                │   │
│  │                                                                      │   │
│  │    "category": "food_beverage",     // Inferred by AI                │   │
│  │    "isActive": true,                                                │   │
│  │    "createdAt": Timestamp,                                          │   │
│  │    "expiresAt": Timestamp + 7 days                                  │   │
│  │  }                                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  POST IS NOW STORED IN DATABASE - Available for matching from both sides!   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 5: FIND MATCHING BUSINESSES (Semantic Search)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  UnifiedMatchingService.findMatches() runs immediately:                     │
│                                                                             │
│  QUERY STRATEGY:                                                            │
│  1. Get all active posts where action_type = "offering"                     │
│  2. Filter by location radius (e.g., within 10km)                           │
│  3. Calculate cosine similarity with each candidate                         │
│  4. Apply scoring weights: 70% semantic + 15% location + 15% price          │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Firestore Query:                                                    │   │
│  │  posts WHERE                                                         │   │
│  │    isActive == true AND                                             │   │
│  │    intentAnalysis.action_type == "offering" AND                     │   │
│  │    expiresAt > now                                                  │   │
│  │  LIMIT 100                                                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  For each candidate post (e.g., Mario's Pizzeria's post):                  │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Mario's Post:                                                       │   │
│  │  {                                                                   │   │
│  │    "originalPrompt": "Fresh wood-fired pizzas, free delivery!",     │   │
│  │    "action_type": "offering",                                       │   │
│  │    "embedding": [0.0198, -0.1502, 0.0823, ...]                      │   │
│  │    "businessId": "mario_pizzeria_456",                              │   │
│  │    "location": "Andheri West, Mumbai",                              │   │
│  │    "latitude": 19.1190,                                             │   │
│  │    "longitude": 72.9045                                             │   │
│  │  }                                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  SCORING CALCULATION:                                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                                                      │   │
│  │  1. SEMANTIC SIMILARITY (70% weight):                               │   │
│  │     user_embedding = [0.0234, -0.1456, 0.0891, ...]                 │   │
│  │     business_embedding = [0.0198, -0.1502, 0.0823, ...]             │   │
│  │                                                                      │   │
│  │     cosine_similarity = dot(user, business) / (|user| × |business|) │   │
│  │     cosine_similarity = 0.94  (very high - similar meanings!)       │   │
│  │                                                                      │   │
│  │  2. LOCATION PROXIMITY (15% weight):                                │   │
│  │     user: (19.1176, 72.9060)                                        │   │
│  │     business: (19.1190, 72.9045)                                    │   │
│  │     distance = haversine() = 0.3 km                                 │   │
│  │     location_score = 1 - (0.3 / 10) = 0.97                         │   │
│  │                                                                      │   │
│  │  3. PRICE COMPATIBILITY (15% weight):                               │   │
│  │     user: no budget specified                                       │   │
│  │     business: avg ₹400 for two                                      │   │
│  │     price_score = 0.5 (neutral - no user preference)                │   │
│  │                                                                      │   │
│  │  FINAL SCORE = (0.70 × 0.94) + (0.15 × 0.97) + (0.15 × 0.5)        │   │
│  │              = 0.658 + 0.146 + 0.075                                │   │
│  │              = 0.879 ≈ 88% match                                    │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 6: FETCH BUSINESS PROFILES FOR MATCHED POSTS                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  For each matched business post, fetch full business profile:               │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Firestore: businesses/{businessId}                                  │   │
│  │                                                                      │   │
│  │  Mario's Pizzeria Profile:                                          │   │
│  │  {                                                                   │   │
│  │    "id": "mario_pizzeria_456",                                      │   │
│  │    "ownerId": "owner_789",                                          │   │
│  │    "name": "Mario's Pizzeria",                                      │   │
│  │    "tagline": "Authentic Wood-Fired Pizzas Since 1995",             │   │
│  │    "description": "Family-owned pizzeria serving the best...",      │   │
│  │    "category": "food_beverage",                                     │   │
│  │    "subType": "Restaurant",                                         │   │
│  │                                                                      │   │
│  │    "logoUrl": "https://storage.../mario_logo.jpg",                  │   │
│  │    "coverImageUrl": "https://storage.../mario_cover.jpg",           │   │
│  │    "images": ["img1.jpg", "img2.jpg", "img3.jpg"],                  │   │
│  │                                                                      │   │
│  │    "address": "Shop 12, Harmony Plaza",                             │   │
│  │    "city": "Mumbai",                                                │   │
│  │    "area": "Andheri West",                                          │   │
│  │    "pincode": "400053",                                             │   │
│  │    "latitude": 19.1190,                                             │   │
│  │    "longitude": 72.9045,                                            │   │
│  │                                                                      │   │
│  │    "phone": "+91 98765 43210",                                      │   │
│  │    "email": "info@mariospizzeria.com",                              │   │
│  │    "website": "www.mariospizzeria.com",                             │   │
│  │                                                                      │   │
│  │    "operatingHours": {                                              │   │
│  │      "monday": { "open": "11:00", "close": "23:00", "isClosed": false }│   │
│  │      "tuesday": { "open": "11:00", "close": "23:00", "isClosed": false }│   │
│  │      ...                                                            │   │
│  │    },                                                               │   │
│  │                                                                      │   │
│  │    "categoryData": {                                                │   │
│  │      "cuisineTypes": ["Italian", "Pizza"],                          │   │
│  │      "diningOptions": ["Dine-in", "Takeaway", "Delivery"],          │   │
│  │      "foodType": "Both",                                            │   │
│  │      "avgCostForTwo": 400,                                          │   │
│  │      "acceptsReservations": true                                    │   │
│  │    },                                                               │   │
│  │                                                                      │   │
│  │    "rating": 4.5,                                                   │   │
│  │    "reviewCount": 128,                                              │   │
│  │    "isVerified": true,                                              │   │
│  │    "isActive": true                                                 │   │
│  │  }                                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Also fetch category-specific data (menu items for restaurants):            │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Firestore: businesses/{businessId}/menu_items (LIMIT 3 popular)     │   │
│  │                                                                      │   │
│  │  [                                                                   │   │
│  │    { "name": "Margherita", "price": 299, "isPopular": true },       │   │
│  │    { "name": "Pepperoni Special", "price": 449, "isPopular": true },│   │
│  │    { "name": "Farm Fresh", "price": 399, "isPopular": true }        │   │
│  │  ]                                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STEP 7: DISPLAY TO USER                                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  User sees match results screen:                                            │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  🔍 "I need a good pizza place nearby with delivery"                │   │
│  │  ─────────────────────────────────────────────────────────────────  │   │
│  │  Found 8 matches near you                                           │   │
│  │                                                                      │   │
│  │  ┌───────────────────────────────────────────────────────────────┐  │   │
│  │  │ [COVER IMAGE                                            ]     │  │   │
│  │  │ ┌────┐                                                        │  │   │
│  │  │ │LOGO│ Mario's Pizzeria                        92% Match     │  │   │
│  │  │ └────┘ ⭐ 4.5 (128) • Italian Restaurant                      │  │   │
│  │  │        📍 0.3 km • Andheri West                               │  │   │
│  │  │        🕐 Open Now • Closes 11 PM                              │  │   │
│  │  │                                                               │  │   │
│  │  │        "Authentic wood-fired pizzas made with love..."        │  │   │
│  │  │                                                               │  │   │
│  │  │        🍕 Veg & Non-Veg  |  🚗 Delivery  |  💰 ₹400 for two   │  │   │
│  │  │                                                               │  │   │
│  │  │        POPULAR: Margherita ₹299 • Pepperoni ₹449              │  │   │
│  │  │                                                               │  │   │
│  │  │        [💬 Message]  [📞 Call]  [View Profile →]              │  │   │
│  │  └───────────────────────────────────────────────────────────────┘  │   │
│  │                                                                      │   │
│  │  ┌───────────────────────────────────────────────────────────────┐  │   │
│  │  │ [COVER IMAGE                                            ]     │  │   │
│  │  │ ┌────┐                                                        │  │   │
│  │  │ │LOGO│ Bella Italia                            87% Match     │  │   │
│  │  │ └────┘ ⭐ 4.3 (95) • Italian Restaurant                       │  │   │
│  │  │        📍 1.2 km • Versova                                    │  │   │
│  │  │        ...                                                    │  │   │
│  │  └───────────────────────────────────────────────────────────────┘  │   │
│  │                                                                      │   │
│  │  ┌───────────────────────────────────────────────────────────────┐  │   │
│  │  │ Pizza Hut                                      82% Match      │  │   │
│  │  │ ...                                                           │  │   │
│  │  └───────────────────────────────────────────────────────────────┘  │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### What Happens When User Taps on a Business

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FULL BUSINESS PROFILE VIEW                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  User taps "Mario's Pizzeria" → App fetches full profile + sub-collections  │
│                                                                             │
│  DATA FETCHED:                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  1. businesses/{businessId}              → Main profile             │   │
│  │  2. businesses/{businessId}/menu_categories → Menu sections         │   │
│  │  3. businesses/{businessId}/menu_items   → All menu items           │   │
│  │  4. reviews WHERE businessId == ...      → Customer reviews         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  DISPLAYED PROFILE:                                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  ←  Mario's Pizzeria                         [Share] [❤️ Save]      │   │
│  │  ─────────────────────────────────────────────────────────────────  │   │
│  │                                                                      │   │
│  │  [════════════════ IMAGE GALLERY SLIDER ═══════════════════]        │   │
│  │                                                                      │   │
│  │  Mario's Pizzeria                              ✓ Verified           │   │
│  │  Italian Restaurant                                                  │   │
│  │  ⭐ 4.5 (128 reviews)                                                │   │
│  │                                                                      │   │
│  │  📍 Shop 12, Harmony Plaza, Andheri West, Mumbai 400053             │   │
│  │  📞 +91 98765 43210                                                  │   │
│  │  🌐 www.mariospizzeria.com                                           │   │
│  │                                                                      │   │
│  │  ═══════════════════════════════════════════════════════════════    │   │
│  │                                                                      │   │
│  │  ABOUT                                                               │   │
│  │  "Family-owned pizzeria serving authentic Italian flavors with      │   │
│  │   fresh ingredients and wood-fired perfection since 1995."          │   │
│  │                                                                      │   │
│  │  ═══════════════════════════════════════════════════════════════    │   │
│  │                                                                      │   │
│  │  HIGHLIGHTS                                                          │   │
│  │  🍕 Veg & Non-Veg  |  🚗 Free Delivery  |  💺 Dine-in Available     │   │
│  │  💰 ₹400 for two   |  🏷️ 20% off first order                        │   │
│  │                                                                      │   │
│  │  ═══════════════════════════════════════════════════════════════    │   │
│  │                                                                      │   │
│  │  📋 MENU                                            [See Full Menu]  │   │
│  │  ┌───────────────────────────────────────────────────────────────┐  │   │
│  │  │ PIZZAS                                                        │  │   │
│  │  │ ├─ Margherita (V) ............................ ₹299           │  │   │
│  │  │ │   Classic tomato sauce, mozzarella, fresh basil             │  │   │
│  │  │ ├─ Pepperoni Special ......................... ₹449           │  │   │
│  │  │ │   Double pepperoni, mozzarella, oregano                     │  │   │
│  │  │ ├─ Farm Fresh (V) ............................ ₹399           │  │   │
│  │  │ │   Bell peppers, onions, mushrooms, olives                   │  │   │
│  │  │ └─ BBQ Chicken ............................... ₹499           │  │   │
│  │  │                                                               │  │   │
│  │  │ PASTA                                                         │  │   │
│  │  │ ├─ Alfredo (V) ............................... ₹349           │  │   │
│  │  │ └─ Arrabiata (V) ............................. ₹299           │  │   │
│  │  │                                                               │  │   │
│  │  │ SIDES & BEVERAGES                                             │  │   │
│  │  │ ├─ Garlic Bread .............................. ₹149           │  │   │
│  │  │ └─ Cold Drinks ............................... ₹60            │  │   │
│  │  └───────────────────────────────────────────────────────────────┘  │   │
│  │                                                                      │   │
│  │  ═══════════════════════════════════════════════════════════════    │   │
│  │                                                                      │   │
│  │  🕐 BUSINESS HOURS                                                   │   │
│  │  ┌───────────────────────────────────────────────────────────────┐  │   │
│  │  │ Monday - Thursday    11:00 AM - 11:00 PM                      │  │   │
│  │  │ Friday - Saturday    11:00 AM - 12:00 AM                      │  │   │
│  │  │ Sunday               12:00 PM - 10:00 PM                      │  │   │
│  │  │                                                               │  │   │
│  │  │ 🟢 Currently OPEN • Closes in 6 hours                         │  │   │
│  │  └───────────────────────────────────────────────────────────────┘  │   │
│  │                                                                      │   │
│  │  ═══════════════════════════════════════════════════════════════    │   │
│  │                                                                      │   │
│  │  ⭐ REVIEWS (128)                                  [Write a Review]  │   │
│  │  ┌───────────────────────────────────────────────────────────────┐  │   │
│  │  │ 👤 Priya Sharma  ⭐⭐⭐⭐⭐   2 days ago                         │  │   │
│  │  │ "Best pizza in Mumbai! The Margherita is absolutely perfect." │  │   │
│  │  │                                                               │  │   │
│  │  │    ↪️ Owner: Thank you Priya! We're glad you loved it! 🍕     │  │   │
│  │  │ ─────────────────────────────────────────────────────────────│  │   │
│  │  │ 👤 Rahul Mehta  ⭐⭐⭐⭐   1 week ago                           │  │   │
│  │  │ "Great food, quick delivery. Will order again!"               │  │   │
│  │  │ ─────────────────────────────────────────────────────────────│  │   │
│  │  │ [See All Reviews]                                             │  │   │
│  │  └───────────────────────────────────────────────────────────────┘  │   │
│  │                                                                      │   │
│  │  ═══════════════════════════════════════════════════════════════    │   │
│  │                                                                      │   │
│  │  📍 LOCATION                                                         │   │
│  │  ┌───────────────────────────────────────────────────────────────┐  │   │
│  │  │                     [GOOGLE MAP VIEW]                         │  │   │
│  │  │                                                               │  │   │
│  │  │                    📍 Mario's Pizzeria                         │  │   │
│  │  │                                                               │  │   │
│  │  │              [Open in Maps] [Get Directions]                  │  │   │
│  │  └───────────────────────────────────────────────────────────────┘  │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ═══════════════════ STICKY BOTTOM ACTION BAR ═══════════════════════════  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  [💬 Message]     [📞 Call]     [🛒 Order Now]                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### The Other Side: What Business Owner Sees

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              BUSINESS OWNER'S VIEW (Bidirectional Matching)                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  When Rahul posts "I need a good pizza place nearby with delivery",         │
│  Mario's Pizzeria owner ALSO sees Rahul as a matched customer!              │
│                                                                             │
│  BUSINESS DASHBOARD:                                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  🏠 Mario's Pizzeria Dashboard                                       │   │
│  │  ─────────────────────────────────────────────────────────────────  │   │
│  │                                                                      │   │
│  │  📊 TODAY'S STATS                                                    │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐               │   │
│  │  │    12    │ │    8     │ │  ₹4,500  │ │  🔴 3    │               │   │
│  │  │  Orders  │ │ Messages │ │ Revenue  │ │NEW LEADS │               │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘               │   │
│  │                                                                      │   │
│  │  ─────────────────────────────────────────────────────────────────  │   │
│  │                                                                      │   │
│  │  🎯 NEW MATCHED CUSTOMERS (Potential Leads)              [View All]  │   │
│  │  ┌───────────────────────────────────────────────────────────────┐  │   │
│  │  │ 🔴 NEW                                                         │  │   │
│  │  │ ┌────┐                                                         │  │   │
│  │  │ │ 👤 │  Rahul M.                              92% Match       │  │   │
│  │  │ └────┘  📍 0.3 km away • Andheri West                         │  │   │
│  │  │                                                                │  │   │
│  │  │  "I need a good pizza place nearby with delivery"             │  │   │
│  │  │                                                                │  │   │
│  │  │  Posted: 5 minutes ago                                        │  │   │
│  │  │                                                                │  │   │
│  │  │  [💬 Send Message]  [👁️ View Profile]                         │  │   │
│  │  └───────────────────────────────────────────────────────────────┘  │   │
│  │                                                                      │   │
│  │  ┌───────────────────────────────────────────────────────────────┐  │   │
│  │  │ ┌────┐                                                         │  │   │
│  │  │ │ 👤 │  Sara J.                               87% Match       │  │   │
│  │  │ └────┘  📍 1.1 km away • Lokhandwala                          │  │   │
│  │  │                                                                │  │   │
│  │  │  "Looking for Italian food with home delivery"                │  │   │
│  │  │                                                                │  │   │
│  │  │  Posted: 2 hours ago                                          │  │   │
│  │  │                                                                │  │   │
│  │  │  [💬 Send Message]  [👁️ View Profile]                         │  │   │
│  │  └───────────────────────────────────────────────────────────────┘  │   │
│  │                                                                      │   │
│  │  ─────────────────────────────────────────────────────────────────  │   │
│  │                                                                      │   │
│  │  💡 TIP: Customers who match with your posts are actively looking   │   │
│  │  for services you offer. Send them a message to convert them!       │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  KEY INSIGHT:                                                               │
│  - User searches → sees businesses (traditional)                            │
│  - Business ALSO sees matched users (Plink's unique bidirectional match)    │
│  - Both sides can initiate conversation                                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Different Prompt Examples & How They're Handled

### Example 1: Service-Seeking Prompt

```
USER PROMPT: "Need a plumber urgently, my bathroom is flooding"

┌─────────────────────────────────────────────────────────────────────────────┐
│ AI ANALYSIS:                                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│ {                                                                           │
│   "primary_intent": "emergency_service_request",                           │
│   "action_type": "seeking",                                                │
│   "domain": "home_services",                                               │
│   "urgency": "high",                                                       │
│   "entities": {                                                            │
│     "service_type": "plumbing",                                            │
│     "problem": "flooding",                                                 │
│     "location": "bathroom"                                                 │
│   },                                                                       │
│   "complementary_intents": ["plumber_available", "emergency_plumbing"]    │
│ }                                                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│ MATCHES WITH: Plumbers in "home_services" category who have posts          │
│ offering emergency services nearby                                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Example 2: Product-Selling Prompt

```
USER PROMPT: "Selling my iPhone 13 Pro, 256GB, excellent condition, ₹55000"

┌─────────────────────────────────────────────────────────────────────────────┐
│ AI ANALYSIS:                                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│ {                                                                           │
│   "primary_intent": "sell_product",                                        │
│   "action_type": "offering",         // User is OFFERING something         │
│   "domain": "marketplace",                                                 │
│   "entities": {                                                            │
│     "product": "iPhone 13 Pro",                                            │
│     "storage": "256GB",                                                    │
│     "condition": "excellent",                                              │
│     "price": 55000,                                                        │
│     "currency": "INR"                                                      │
│   },                                                                       │
│   "complementary_intents": ["buy_iphone", "looking_for_phone"]            │
│ }                                                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│ MATCHES WITH: Users who have posted "looking to buy iPhone" or similar     │
│ This is P2P matching, not business matching                                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Example 3: Business Promotion Prompt

```
BUSINESS PROMPT: "50% off on all haircuts this weekend! Book now"

┌─────────────────────────────────────────────────────────────────────────────┐
│ AI ANALYSIS:                                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│ {                                                                           │
│   "primary_intent": "promotion_announcement",                              │
│   "action_type": "offering",                                               │
│   "domain": "beauty_wellness",                                             │
│   "entities": {                                                            │
│     "service_type": "haircut",                                             │
│     "discount": "50%",                                                     │
│     "validity": "this weekend"                                             │
│   },                                                                       │
│   "complementary_intents": ["looking_for_haircut", "salon_nearby"]        │
│ }                                                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│ MATCHES WITH: Users who posted "need a haircut" or "looking for salon"     │
│ Business proactively reaches potential customers                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Example 4: Social/Connection Prompt

```
USER PROMPT: "Looking to make friends who love hiking, I'm new in Bangalore"

┌─────────────────────────────────────────────────────────────────────────────┐
│ AI ANALYSIS:                                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│ {                                                                           │
│   "primary_intent": "social_connection",                                   │
│   "action_type": "seeking",                                                │
│   "domain": "friendship",                                                  │
│   "entities": {                                                            │
│     "connection_type": "friends",                                          │
│     "interest": "hiking",                                                  │
│     "context": "new_in_city"                                               │
│   },                                                                       │
│   "complementary_intents": ["hiking_buddy", "outdoor_activities"]         │
│ }                                                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│ MATCHES WITH: Other users who posted about hiking or outdoor activities    │
│ P2P social matching (not business)                                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Summary: Complete Data Model

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     PLINK DATA MODEL SUMMARY                                │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                           HOW DATA IS STORED                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. USERS (Personal Profiles)                                               │
│     └── users/{userId}                                                      │
│         • Basic info: name, photo, location                                 │
│         • Link to business if owner: businessId                             │
│                                                                             │
│  2. BUSINESSES (Business Profiles)                                          │
│     └── businesses/{businessId}                                             │
│         • Profile: name, logo, address, hours, category                     │
│         • Category-specific data: categoryData { ... }                      │
│         • Sub-collections: menu_items, products, services, etc.             │
│                                                                             │
│  3. POSTS (AI-Matched Content)                                              │
│     └── posts/{postId}                                                      │
│         • What user/business typed: originalPrompt                          │
│         • AI understanding: intentAnalysis                                  │
│         • Semantic vector: embedding[768]                                   │
│         • Used for MATCHING                                                 │
│                                                                             │
│  4. CONVERSATIONS (Chats)                                                   │
│     └── conversations/{conversationId}/messages/{messageId}                 │
│                                                                             │
│  5. REVIEWS (Business Ratings)                                              │
│     └── reviews/{reviewId}                                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                       HOW MATCHING WORKS                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. User types prompt → AI analyzes intent (seeking/offering)               │
│  2. AI generates 768-dim embedding                                          │
│  3. Post stored in Firestore with embedding                                 │
│  4. Match engine finds complementary posts (seeking ↔ offering)             │
│  5. Cosine similarity + location + price = final score                      │
│  6. Display matched profiles to user                                        │
│                                                                             │
│  BIDIRECTIONAL:                                                             │
│  • User sees matched businesses                                             │
│  • Business sees matched potential customers                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                     HOW PROFILES ARE DISPLAYED                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  FOR CUSTOMERS VIEWING BUSINESSES:                                          │
│  • Match Results Card: Cover, logo, name, rating, distance, match %         │
│  • Full Profile: Gallery, menu/services, hours, reviews, map, actions       │
│                                                                             │
│  FOR BUSINESSES VIEWING MATCHED CUSTOMERS:                                  │
│  • Lead Card: Name, photo, original prompt, match %, distance               │
│  • Action: Send message to convert lead                                     │
│                                                                             │
│  TEMPLATE-BASED:                                                            │
│  • Each category has specialized profile template                           │
│  • Restaurant: menu display                                                 │
│  • Hotel: room types, amenities                                             │
│  • Salon: services, stylists                                                │
│  • Generic: services list                                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```
