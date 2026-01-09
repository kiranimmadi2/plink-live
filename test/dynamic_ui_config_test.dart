import 'package:flutter_test/flutter_test.dart';
import 'package:supper/config/dynamic_business_ui_config.dart';
import 'package:supper/models/business_category_config.dart';

/// Comprehensive test suite for Dynamic UI Configuration System
/// This validates that all 24 business categories have proper configurations
void main() {
  group('Dynamic UI Config - All Categories', () {
    // List of all 24 business categories
    final allCategories = [
      BusinessCategory.hospitality,
      BusinessCategory.foodBeverage,
      BusinessCategory.grocery,
      BusinessCategory.retail,
      BusinessCategory.beautyWellness,
      BusinessCategory.healthcare,
      BusinessCategory.education,
      BusinessCategory.fitness,
      BusinessCategory.automotive,
      BusinessCategory.realEstate,
      BusinessCategory.travelTourism,
      BusinessCategory.entertainment,
      BusinessCategory.petServices,
      BusinessCategory.homeServices,
      BusinessCategory.technology,
      BusinessCategory.legal,
      BusinessCategory.professional,
      BusinessCategory.transportation,
      BusinessCategory.artCreative,
      BusinessCategory.construction,
      BusinessCategory.agriculture,
      BusinessCategory.manufacturing,
      BusinessCategory.weddingEvents,
    ];

    test('All 24 categories have configurations', () {
      for (final category in allCategories) {
        final config = DynamicUIConfig.getConfigForCategory(category);

        expect(config, isNotNull, reason: 'Config for $category should not be null');
        expect(config.category, equals(category),
               reason: 'Config category should match requested category');
      }
    });

    test('All categories have profile templates', () {
      for (final category in allCategories) {
        final config = DynamicUIConfig.getConfigForCategory(category);

        expect(config.profileTemplate, isNotEmpty,
               reason: '$category should have a profile template');
        expect(config.profileTemplate, isA<String>());
      }
    });

    test('All categories have at least 5 profile sections', () {
      for (final category in allCategories) {
        final config = DynamicUIConfig.getConfigForCategory(category);

        expect(config.profileSections.length, greaterThanOrEqualTo(5),
               reason: '$category should have at least 5 profile sections');

        // All should have hero, quickActions, and highlights
        expect(config.profileSections, contains(ProfileSection.hero),
               reason: '$category should have hero section');
        expect(config.profileSections, contains(ProfileSection.quickActions),
               reason: '$category should have quickActions section');
        expect(config.profileSections, contains(ProfileSection.highlights),
               reason: '$category should have highlights section');
      }
    });

    test('All categories have dashboard widgets', () {
      for (final category in allCategories) {
        final config = DynamicUIConfig.getConfigForCategory(category);

        expect(config.dashboardWidgets, isNotEmpty,
               reason: '$category should have dashboard widgets');
        expect(config.dashboardWidgets.length, greaterThanOrEqualTo(2),
               reason: '$category should have at least 2 dashboard widgets');

        // All should have stats widget
        expect(config.dashboardWidgets, contains(DashboardWidget.stats),
               reason: '$category should have stats widget');
      }
    });

    test('All categories have quick actions', () {
      for (final category in allCategories) {
        final config = DynamicUIConfig.getConfigForCategory(category);

        expect(config.quickActions, isNotEmpty,
               reason: '$category should have quick actions');
        expect(config.quickActions.length, greaterThanOrEqualTo(2),
               reason: '$category should have at least 2 quick actions');
      }
    });

    test('All categories have bottom tabs', () {
      for (final category in allCategories) {
        final config = DynamicUIConfig.getConfigForCategory(category);

        expect(config.bottomTabs, isNotEmpty,
               reason: '$category should have bottom tabs');
        expect(config.bottomTabs.length, greaterThanOrEqualTo(4),
               reason: '$category should have at least 4 bottom tabs');

        // All should have home, messages, and profile tabs
        expect(config.bottomTabs, contains(BusinessTab.home),
               reason: '$category should have home tab');
        expect(config.bottomTabs, contains(BusinessTab.messages),
               reason: '$category should have messages tab');
        expect(config.bottomTabs, contains(BusinessTab.profile),
               reason: '$category should have profile tab');
      }
    });
  });

  group('Category-Specific Features', () {
    test('Food & Beverage has menu features', () {
      final config = DynamicUIConfig.getConfigForCategory(
        BusinessCategory.foodBeverage,
      );

      expect(config.profileSections, contains(ProfileSection.menu));
      expect(config.dashboardWidgets, contains(DashboardWidget.recentOrders));
      expect(config.quickActions, contains(QuickAction.addMenuItem));
      expect(config.bottomTabs, contains(BusinessTab.menu));
      expect(config.bottomTabs, contains(BusinessTab.orders));
    });

    test('Hospitality has room features', () {
      final config = DynamicUIConfig.getConfigForCategory(
        BusinessCategory.hospitality,
      );

      expect(config.profileSections, contains(ProfileSection.rooms));
      expect(config.dashboardWidgets, contains(DashboardWidget.roomOccupancy));
      expect(config.quickActions, contains(QuickAction.addRoom));
      expect(config.bottomTabs, contains(BusinessTab.rooms));
      expect(config.bottomTabs, contains(BusinessTab.bookings));
    });

    test('Retail has product features', () {
      final config = DynamicUIConfig.getConfigForCategory(
        BusinessCategory.retail,
      );

      expect(config.profileSections, contains(ProfileSection.products));
      expect(config.dashboardWidgets, contains(DashboardWidget.topProducts));
      expect(config.quickActions, contains(QuickAction.addProduct));
      expect(config.bottomTabs, contains(BusinessTab.products));
      expect(config.bottomTabs, contains(BusinessTab.orders));
    });

    test('Healthcare has service and appointment features', () {
      final config = DynamicUIConfig.getConfigForCategory(
        BusinessCategory.healthcare,
      );

      expect(config.profileSections, contains(ProfileSection.services));
      expect(config.dashboardWidgets, contains(DashboardWidget.todayAppointments));
      expect(config.quickActions, contains(QuickAction.addService));
      expect(config.quickActions, contains(QuickAction.manageAppointments));
      expect(config.bottomTabs, contains(BusinessTab.services));
      expect(config.bottomTabs, contains(BusinessTab.appointments));
    });

    test('Education has course features', () {
      final config = DynamicUIConfig.getConfigForCategory(
        BusinessCategory.education,
      );

      expect(config.profileSections, contains(ProfileSection.courses));
      expect(config.profileSections, contains(ProfileSection.classes));
      expect(config.dashboardWidgets, contains(DashboardWidget.courseEnrollments));
      expect(config.quickActions, contains(QuickAction.addCourse));
      expect(config.bottomTabs, contains(BusinessTab.courses));
    });

    test('Fitness has membership features', () {
      final config = DynamicUIConfig.getConfigForCategory(
        BusinessCategory.fitness,
      );

      expect(config.profileSections, contains(ProfileSection.memberships));
      expect(config.profileSections, contains(ProfileSection.classes));
      expect(config.dashboardWidgets, contains(DashboardWidget.activeMembers));
      expect(config.quickActions, contains(QuickAction.addMembership));
      expect(config.bottomTabs, contains(BusinessTab.memberships));
      expect(config.bottomTabs, contains(BusinessTab.classes));
    });

    test('Real Estate has property features', () {
      final config = DynamicUIConfig.getConfigForCategory(
        BusinessCategory.realEstate,
      );

      expect(config.profileSections, contains(ProfileSection.properties));
      expect(config.dashboardWidgets, contains(DashboardWidget.activeListings));
      expect(config.quickActions, contains(QuickAction.addProperty));
      expect(config.bottomTabs, contains(BusinessTab.properties));
      expect(config.bottomTabs, contains(BusinessTab.inquiries));
    });

    test('Automotive has vehicle features', () {
      final config = DynamicUIConfig.getConfigForCategory(
        BusinessCategory.automotive,
      );

      expect(config.profileSections, contains(ProfileSection.vehicles));
      expect(config.profileSections, contains(ProfileSection.services));
      expect(config.dashboardWidgets, contains(DashboardWidget.vehicleInventory));
      expect(config.quickActions, contains(QuickAction.addVehicle));
      expect(config.bottomTabs, contains(BusinessTab.vehicles));
    });

    test('Travel & Tourism has package features', () {
      final config = DynamicUIConfig.getConfigForCategory(
        BusinessCategory.travelTourism,
      );

      expect(config.profileSections, contains(ProfileSection.packages));
      expect(config.dashboardWidgets, contains(DashboardWidget.popularPackages));
      expect(config.quickActions, contains(QuickAction.addPackage));
      expect(config.bottomTabs, contains(BusinessTab.packages));
    });

    test('Art & Creative has portfolio features', () {
      final config = DynamicUIConfig.getConfigForCategory(
        BusinessCategory.artCreative,
      );

      expect(config.profileSections, contains(ProfileSection.portfolio));
      expect(config.dashboardWidgets, contains(DashboardWidget.activeProjects));
      expect(config.quickActions, contains(QuickAction.addPortfolioItem));
      expect(config.bottomTabs, contains(BusinessTab.portfolio));
    });
  });

  group('Profile Section Extensions', () {
    test('All profile sections have display names', () {
      for (final section in ProfileSection.values) {
        expect(section.displayName, isNotEmpty,
               reason: '$section should have a display name');
      }
    });

    test('All profile sections have icons', () {
      for (final section in ProfileSection.values) {
        expect(section.icon, isNotNull,
               reason: '$section should have an icon');
      }
    });
  });

  group('Business Tab Extensions', () {
    test('All business tabs have labels', () {
      for (final tab in BusinessTab.values) {
        expect(tab.label, isNotEmpty,
               reason: '$tab should have a label');
      }
    });

    test('All business tabs have icons', () {
      for (final tab in BusinessTab.values) {
        expect(tab.icon, isNotNull,
               reason: '$tab should have an icon');
      }
    });
  });

  group('Quick Action Extensions', () {
    test('All quick actions have labels', () {
      for (final action in QuickAction.values) {
        expect(action.label, isNotEmpty,
               reason: '$action should have a label');
      }
    });

    test('All quick actions have icons', () {
      for (final action in QuickAction.values) {
        expect(action.icon, isNotNull,
               reason: '$action should have an icon');
      }
    });
  });

  group('Configuration Consistency', () {
    test('No duplicate sections in any category', () {
      final allCategories = BusinessCategory.values;

      for (final category in allCategories) {
        final config = DynamicUIConfig.getConfigForCategory(category);
        final sections = config.profileSections;
        final uniqueSections = sections.toSet();

        expect(sections.length, equals(uniqueSections.length),
               reason: '$category has duplicate profile sections');
      }
    });

    test('No duplicate tabs in any category', () {
      final allCategories = BusinessCategory.values;

      for (final category in allCategories) {
        final config = DynamicUIConfig.getConfigForCategory(category);
        final tabs = config.bottomTabs;
        final uniqueTabs = tabs.toSet();

        expect(tabs.length, equals(uniqueTabs.length),
               reason: '$category has duplicate bottom tabs');
      }
    });

    test('Profile template names are valid', () {
      final validTemplates = [
        'restaurant_template',
        'hotel_template',
        'retail_template',
        'salon_template',
        'healthcare_template',
        'education_template',
        'fitness_template',
        'real_estate_template',
        'generic_template',
      ];

      final allCategories = BusinessCategory.values;

      for (final category in allCategories) {
        final config = DynamicUIConfig.getConfigForCategory(category);

        expect(validTemplates, contains(config.profileTemplate),
               reason: '$category has invalid template: ${config.profileTemplate}');
      }
    });
  });

  group('Customization Options', () {
    test('Food & Beverage has menu customization', () {
      final config = DynamicUIConfig.getConfigForCategory(
        BusinessCategory.foodBeverage,
      );

      expect(config.customization, isNotEmpty);
      expect(config.customization['showMenuCategories'], isNotNull);
      expect(config.customization['showPopularItems'], isNotNull);
    });

    test('Hospitality has room customization', () {
      final config = DynamicUIConfig.getConfigForCategory(
        BusinessCategory.hospitality,
      );

      expect(config.customization, isNotEmpty);
      expect(config.customization['showAmenities'], isNotNull);
      expect(config.customization['showCheckInOut'], isNotNull);
    });
  });

  group('Integration with BusinessCategory', () {
    test('All BusinessCategory enums have configs', () {
      for (final category in BusinessCategory.values) {
        expect(
          () => DynamicUIConfig.getConfigForCategory(category),
          returnsNormally,
          reason: 'Should have config for $category',
        );
      }
    });

    test('Config categories match enum categories', () {
      for (final category in BusinessCategory.values) {
        final config = DynamicUIConfig.getConfigForCategory(category);
        expect(config.category, equals(category));
      }
    });
  });

  group('Feature Coverage', () {
    test('All service-based categories have service section', () {
      final serviceCategories = [
        BusinessCategory.beautyWellness,
        BusinessCategory.healthcare,
        BusinessCategory.homeServices,
        BusinessCategory.legal,
        BusinessCategory.professional,
      ];

      for (final category in serviceCategories) {
        final config = DynamicUIConfig.getConfigForCategory(category);
        expect(config.profileSections, contains(ProfileSection.services),
               reason: '$category should have services section');
      }
    });

    test('All product-based categories have product section', () {
      final productCategories = [
        BusinessCategory.retail,
        BusinessCategory.grocery,
        BusinessCategory.petServices,
        BusinessCategory.agriculture,
        BusinessCategory.manufacturing,
      ];

      for (final category in productCategories) {
        final config = DynamicUIConfig.getConfigForCategory(category);
        expect(config.profileSections, contains(ProfileSection.products),
               reason: '$category should have products section');
      }
    });

    test('All booking-based categories have booking management', () {
      final bookingCategories = [
        BusinessCategory.hospitality,
        BusinessCategory.travelTourism,
        BusinessCategory.entertainment,
        BusinessCategory.transportation,
      ];

      for (final category in bookingCategories) {
        final config = DynamicUIConfig.getConfigForCategory(category);
        expect(config.quickActions, contains(QuickAction.manageBookings),
               reason: '$category should have booking management');
      }
    });

    test('All appointment-based categories have appointment management', () {
      final appointmentCategories = [
        BusinessCategory.beautyWellness,
        BusinessCategory.healthcare,
        BusinessCategory.homeServices,
        BusinessCategory.legal,
      ];

      for (final category in appointmentCategories) {
        final config = DynamicUIConfig.getConfigForCategory(category);
        expect(config.quickActions, contains(QuickAction.manageAppointments),
               reason: '$category should have appointment management');
      }
    });
  });
}
