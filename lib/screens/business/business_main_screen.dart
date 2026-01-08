import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/business_model.dart';
import '../../models/business_category_config.dart';
import '../../models/conversation_model.dart';
import '../../config/dynamic_business_ui_config.dart' as dynamic_config;
import '../../services/business_service.dart';
import '../../services/auth_service.dart';
import '../../services/chat services/conversation_service.dart';
import '../login/choose_account_type_screen.dart';
import 'business_home_tab.dart';
import 'business_messages_tab.dart';
import 'business_profile_tab.dart';
import 'business_setup_screen.dart';
import 'business_services_tab.dart';
// Category-specific tabs
import 'hospitality/rooms_tab.dart';
import 'hospitality/bookings_tab.dart';
import 'food/menu_tab.dart';
import 'food/orders_tab.dart';
import 'retail/products_tab.dart';
import 'appointments/appointments_tab.dart';

/// Main business screen with bottom navigation
class BusinessMainScreen extends ConsumerStatefulWidget {
  const BusinessMainScreen({super.key});

  @override
  ConsumerState<BusinessMainScreen> createState() => _BusinessMainScreenState();
}

class _BusinessMainScreenState extends ConsumerState<BusinessMainScreen> {
  int _currentIndex = 0;
  final BusinessService _businessService = BusinessService();
  final ConversationService _conversationService = ConversationService();
  BusinessModel? _business;
  bool _isLoading = true;

  /// Get dynamic label for the services/listings tab based on category
  String _getServicesTabLabel(BusinessCategory category) {
    final terminology = dynamic_config.CategoryTerminology.getForCategory(category);
    // Extract first word from screen title (e.g., "Packages & Tours" -> "Packages")
    final firstWord = terminology.screenTitle.split(' ')[0];
    return firstWord;
  }

  /// Get navigation items based on business category
  List<_NavItem> get _navItems {
    final category = _business?.category;

    // Base items always present
    final items = <_NavItem>[
      _NavItem(icon: Icons.home_rounded, activeIcon: Icons.home_rounded, label: 'Home'),
    ];

    // Add category-specific tabs
    switch (category) {
      case BusinessCategory.hospitality:
        items.addAll([
          _NavItem(icon: Icons.hotel_outlined, activeIcon: Icons.hotel, label: 'Rooms'),
          _NavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'Bookings'),
        ]);
        break;
      case BusinessCategory.foodBeverage:
        items.addAll([
          _NavItem(icon: Icons.restaurant_menu_outlined, activeIcon: Icons.restaurant_menu, label: 'Menu'),
          _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Orders'),
        ]);
        break;
      case BusinessCategory.retail:
      case BusinessCategory.grocery:
        items.addAll([
          _NavItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Products'),
        ]);
        break;
      case BusinessCategory.beautyWellness:
      case BusinessCategory.healthcare:
      case BusinessCategory.fitness:
      case BusinessCategory.education:
      case BusinessCategory.homeServices:
      case BusinessCategory.petServices:
        // Services-based businesses with appointments
        items.addAll([
          _NavItem(icon: Icons.build_outlined, activeIcon: Icons.build, label: 'Services'),
          _NavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month, label: 'Bookings'),
        ]);
        break;
      case BusinessCategory.technology:
      case BusinessCategory.legal:
      case BusinessCategory.professional:
      case BusinessCategory.artCreative:
      case BusinessCategory.construction:
      case BusinessCategory.automotive:
      case BusinessCategory.realEstate:
      case BusinessCategory.travelTourism:
      case BusinessCategory.entertainment:
      case BusinessCategory.transportation:
      case BusinessCategory.agriculture:
      case BusinessCategory.manufacturing:
      case BusinessCategory.weddingEvents:
        // Other categories with dynamic labels
        final label = category != null ? _getServicesTabLabel(category) : 'Services';
        items.addAll([
          _NavItem(icon: Icons.miscellaneous_services_outlined, activeIcon: Icons.miscellaneous_services, label: label),
        ]);
        break;
      default:
        // Default for businesses without category
        break;
    }

    // Messages and Profile always at the end
    items.addAll([
      _NavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Messages'),
      _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
    ]);

    return items;
  }

  /// Get the index for messages tab (varies based on category)
  int get _messagesTabIndex => _navItems.length - 2;

  /// Build tab children based on business category
  List<Widget> _buildTabChildren() {
    final category = _business?.category;
    final children = <Widget>[
      // Home tab is always first
      BusinessHomeTab(
        business: _business!,
        onRefresh: _refreshBusiness,
        onSwitchTab: (index) => setState(() => _currentIndex = index),
      ),
    ];

    // Add category-specific tabs
    switch (category) {
      case BusinessCategory.hospitality:
        children.addAll([
          RoomsTab(business: _business!, onRefresh: _refreshBusiness),
          BookingsTab(business: _business!, onRefresh: _refreshBusiness),
        ]);
        break;
      case BusinessCategory.foodBeverage:
        children.addAll([
          MenuTab(business: _business!, onRefresh: _refreshBusiness),
          OrdersTab(business: _business!, onRefresh: _refreshBusiness),
        ]);
        break;
      case BusinessCategory.retail:
      case BusinessCategory.grocery:
        children.addAll([
          ProductsTab(business: _business!, onRefresh: _refreshBusiness),
        ]);
        break;
      case BusinessCategory.beautyWellness:
      case BusinessCategory.healthcare:
      case BusinessCategory.fitness:
      case BusinessCategory.education:
      case BusinessCategory.homeServices:
      case BusinessCategory.petServices:
        // Services-based businesses with appointments
        children.addAll([
          BusinessServicesTab(business: _business!, onRefresh: _refreshBusiness),
          AppointmentsTab(business: _business!, onRefresh: _refreshBusiness),
        ]);
        break;
      case BusinessCategory.technology:
      case BusinessCategory.legal:
      case BusinessCategory.professional:
      case BusinessCategory.artCreative:
      case BusinessCategory.construction:
      case BusinessCategory.automotive:
      case BusinessCategory.realEstate:
      case BusinessCategory.travelTourism:
      case BusinessCategory.entertainment:
      case BusinessCategory.transportation:
      case BusinessCategory.agriculture:
      case BusinessCategory.manufacturing:
      case BusinessCategory.weddingEvents:
        // Other services-based businesses
        children.addAll([
          BusinessServicesTab(business: _business!, onRefresh: _refreshBusiness),
        ]);
        break;
      default:
        break;
    }

    // Messages and Profile always at the end
    children.addAll([
      BusinessMessagesTab(business: _business!),
      BusinessProfileTab(
        business: _business!,
        onRefresh: _refreshBusiness,
        onLogout: () async {
          final navigator = Navigator.of(context);
          await AuthService().signOut();
          if (mounted) {
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const ChooseAccountTypeScreen(),
              ),
              (route) => false,
            );
          }
        },
      ),
    ]);

    return children;
  }

  @override
  void initState() {
    super.initState();
    _loadBusinessData(resetTab: true);
  }

  Future<void> _loadBusinessData({bool resetTab = false}) async {
    setState(() => _isLoading = true);

    final business = await _businessService.getMyBusiness();
    if (mounted) {
      setState(() {
        _business = business;
        _isLoading = false;
        // Reset to home tab only on initial load to avoid index out of bounds
        if (resetTab) {
          _currentIndex = 0;
        }
      });
    }
  }

  void _refreshBusiness() {
    _loadBusinessData(resetTab: false);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D67D)),
        ),
      );
    }

    if (_business == null) {
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: _EmptyBusinessWidget(
            onSetup: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BusinessSetupScreen(
                    onComplete: () {
                      Navigator.pop(context);
                      _loadBusinessData();
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    final tabChildren = _buildTabChildren();
    // Ensure index is within bounds
    final safeIndex = _currentIndex.clamp(0, tabChildren.length - 1);

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      body: IndexedStack(
        index: safeIndex,
        children: tabChildren,
      ),
      bottomNavigationBar: _buildBottomNavBar(isDarkMode),
    );
  }

  Widget _buildBottomNavBar(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isSelected = _currentIndex == index;

              // Messages tab gets unread badge
              if (index == _messagesTabIndex && _business != null) {
                return _buildMessagesNavItem(item, isSelected, isDarkMode);
              }

              return _NavBarItem(
                icon: isSelected ? item.activeIcon : item.icon,
                label: item.label,
                isSelected: isSelected,
                isDarkMode: isDarkMode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _currentIndex = index);
                },
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesNavItem(_NavItem item, bool isSelected, bool isDarkMode) {
    return StreamBuilder<List<ConversationModel>>(
      stream: _conversationService.getBusinessConversations(_business!.id),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          for (var conv in snapshot.data!) {
            unreadCount += conv.getUnreadCount(_business!.userId);
          }
        }

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _currentIndex = _messagesTabIndex);
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00D67D).withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      size: 20,
                      color: isSelected
                          ? const Color(0xFF00D67D)
                          : (isDarkMode ? Colors.white54 : Colors.grey[600]),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? const Color(0xFF00D67D)
                        : (isDarkMode ? Colors.white54 : Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00D67D).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? const Color(0xFF00D67D)
                  : (isDarkMode ? Colors.white54 : Colors.grey[600]),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF00D67D)
                    : (isDarkMode ? Colors.white54 : Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBusinessWidget extends StatelessWidget {
  final VoidCallback onSetup;

  const _EmptyBusinessWidget({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF00D67D).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.store_rounded,
              size: 80,
              color: isDarkMode ? Colors.white24 : Colors.grey[300],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'No Business Profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create your business profile to start showcasing your products and services to customers.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white54 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onSetup,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D67D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.add_business),
            label: const Text(
              'Create Business Profile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
