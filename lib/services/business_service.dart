import 'dart:io';
import '../models/business_model.dart';
import '../models/business_post_model.dart';
import '../models/business_order_model.dart';
import '../models/room_model.dart';
import '../models/menu_model.dart';
import '../models/product_model.dart';

// Import all the new focused services
import 'business/business_profile_service.dart';
import 'business/business_media_service.dart';
import 'business/business_listing_service.dart';
import 'business/business_review_service.dart';
import 'business/business_post_service.dart';
import 'business/business_order_service.dart';
import 'business/business_discovery_service.dart';
import 'business/business_follow_service.dart';

/// Facade service for managing business operations
///
/// This class delegates to specialized services for different domains:
/// - [BusinessProfileService] - Business profile CRUD operations
/// - [BusinessMediaService] - Image uploads for all business media
/// - [BusinessListingService] - Products, services, rooms, menu items
/// - [BusinessReviewService] - Reviews and ratings
/// - [BusinessPostService] - Business posts and promotions
/// - [BusinessOrderService] - Orders and bookings
/// - [BusinessDiscoveryService] - Search and discovery
/// - [BusinessFollowService] - Following businesses
///
/// Usage: You can either use BusinessService as a facade, or import
/// the individual services directly for more focused functionality.
class BusinessService {
  // Singleton pattern
  static final BusinessService _instance = BusinessService._internal();
  factory BusinessService() => _instance;
  BusinessService._internal();

  // Specialized services
  final BusinessProfileService _profileService = BusinessProfileService();
  final BusinessMediaService _mediaService = BusinessMediaService();
  final BusinessListingService _listingService = BusinessListingService();
  final BusinessReviewService _reviewService = BusinessReviewService();
  final BusinessPostService _postService = BusinessPostService();
  final BusinessOrderService _orderService = BusinessOrderService();
  final BusinessDiscoveryService _discoveryService = BusinessDiscoveryService();
  final BusinessFollowService _followService = BusinessFollowService();

  // ============================================================
  // PROFILE OPERATIONS (delegated to BusinessProfileService)
  // ============================================================

  Future<String?> createBusiness(BusinessModel business) =>
      _profileService.createBusiness(business);

  Future<bool> updateBusiness(String businessId, BusinessModel business) =>
      _profileService.updateBusiness(businessId, business);

  Future<BusinessModel?> getBusiness(String businessId) =>
      _profileService.getBusiness(businessId);

  Future<BusinessModel?> getMyBusiness() =>
      _profileService.getMyBusiness();

  Stream<BusinessModel?> watchMyBusiness() =>
      _profileService.watchMyBusiness();

  Future<bool> isBusinessSetupComplete() =>
      _profileService.isBusinessSetupComplete();

  Future<bool> deleteBusiness(String businessId) =>
      _profileService.deleteBusiness(businessId);

  Future<bool> updateOnlineStatus(String businessId, bool isOnline) =>
      _profileService.updateOnlineStatus(businessId, isOnline);

  Future<bool> updateBankAccount(String businessId, BankAccount bankAccount) =>
      _profileService.updateBankAccount(businessId, bankAccount);

  Future<bool> removeBankAccount(String businessId) =>
      _profileService.removeBankAccount(businessId);

  Future<String> generateBusinessId() =>
      _profileService.generateBusinessId();

  Future<void> incrementViewCount(String businessId) =>
      _profileService.incrementViewCount(businessId);

  // ============================================================
  // MEDIA OPERATIONS (delegated to BusinessMediaService)
  // ============================================================

  Future<String?> uploadLogo(File imageFile) =>
      _mediaService.uploadLogo(imageFile);

  Future<String?> uploadCoverImage(File imageFile) =>
      _mediaService.uploadCoverImage(imageFile);

  Future<String?> uploadListingImage(File imageFile) =>
      _mediaService.uploadListingImage(imageFile);

  Future<String?> uploadGalleryImage(File imageFile) =>
      _mediaService.uploadGalleryImage(imageFile);

  Future<String?> uploadRoomImage(String businessId, String roomId, File imageFile) =>
      _mediaService.uploadRoomImage(businessId, roomId, imageFile);

  Future<String?> uploadMenuItemImage(String businessId, String itemId, File imageFile) =>
      _mediaService.uploadMenuItemImage(businessId, itemId, imageFile);

  Future<String?> uploadProductImage(String businessId, String productId, File imageFile) =>
      _mediaService.uploadProductImage(businessId, productId, imageFile);

  // ============================================================
  // LISTING OPERATIONS (delegated to BusinessListingService)
  // ============================================================

  Future<String?> createListing(BusinessListing listing) =>
      _listingService.createListing(listing);

  Future<bool> updateListing(String listingId, BusinessListing listing) =>
      _listingService.updateListing(listingId, listing);

  Future<bool> deleteListing(String businessId, String listingId) =>
      _listingService.deleteListing(businessId, listingId);

  Future<List<BusinessListing>> getBusinessListings(String businessId) =>
      _listingService.getBusinessListings(businessId);

  Stream<List<BusinessListing>> watchBusinessListings(String businessId) =>
      _listingService.watchBusinessListings(businessId);

  Future<bool> toggleListingAvailability(String businessId, String listingId, bool isAvailable) =>
      _listingService.toggleListingAvailability(businessId, listingId, isAvailable);

  // Room operations
  Future<String?> createRoom(RoomModel room) =>
      _listingService.createRoom(room);

  Future<bool> updateRoom(String businessId, String roomId, RoomModel room) =>
      _listingService.updateRoom(businessId, roomId, room);

  Future<bool> deleteRoom(String businessId, String roomId) =>
      _listingService.deleteRoom(businessId, roomId);

  Future<List<RoomModel>> getRooms(String businessId) =>
      _listingService.getRooms(businessId);

  Stream<List<RoomModel>> watchRooms(String businessId) =>
      _listingService.watchRooms(businessId);

  Future<bool> toggleRoomAvailability(String businessId, String roomId, bool isAvailable) =>
      _listingService.toggleRoomAvailability(businessId, roomId, isAvailable);

  // Menu operations
  Future<String?> createMenuCategory(MenuCategoryModel category) =>
      _listingService.createMenuCategory(category);

  Future<bool> updateMenuCategory(String businessId, String categoryId, MenuCategoryModel category) =>
      _listingService.updateMenuCategory(businessId, categoryId, category);

  Future<bool> deleteMenuCategory(String businessId, String categoryId) =>
      _listingService.deleteMenuCategory(businessId, categoryId);

  Future<List<MenuCategoryModel>> getMenuCategories(String businessId) =>
      _listingService.getMenuCategories(businessId);

  Stream<List<MenuCategoryModel>> watchMenuCategories(String businessId) =>
      _listingService.watchMenuCategories(businessId);

  Future<String?> createMenuItem(MenuItemModel item) =>
      _listingService.createMenuItem(item);

  Future<bool> updateMenuItem(String businessId, String itemId, MenuItemModel item) =>
      _listingService.updateMenuItem(businessId, itemId, item);

  Future<bool> deleteMenuItem(String businessId, String itemId) =>
      _listingService.deleteMenuItem(businessId, itemId);

  Future<List<MenuItemModel>> getMenuItems(String businessId, {String? categoryId}) =>
      _listingService.getMenuItems(businessId, categoryId: categoryId);

  Stream<List<MenuItemModel>> watchMenuItems(String businessId, {String? categoryId}) =>
      _listingService.watchMenuItems(businessId, categoryId: categoryId);

  Future<bool> toggleMenuItemAvailability(String businessId, String itemId, bool isAvailable) =>
      _listingService.toggleMenuItemAvailability(businessId, itemId, isAvailable);

  // Product operations
  Future<String?> createProductCategory(ProductCategoryModel category) =>
      _listingService.createProductCategory(category);

  Future<bool> updateProductCategory(String businessId, String categoryId, ProductCategoryModel category) =>
      _listingService.updateProductCategory(businessId, categoryId, category);

  Future<bool> deleteProductCategory(String businessId, String categoryId) =>
      _listingService.deleteProductCategory(businessId, categoryId);

  Future<List<ProductCategoryModel>> getProductCategories(String businessId) =>
      _listingService.getProductCategories(businessId);

  Stream<List<ProductCategoryModel>> watchProductCategories(String businessId) =>
      _listingService.watchProductCategories(businessId);

  Future<String?> createProduct(ProductModel product) =>
      _listingService.createProduct(product);

  Future<bool> updateProduct(String businessId, String productId, ProductModel product) =>
      _listingService.updateProduct(businessId, productId, product);

  Future<bool> deleteProduct(String businessId, String productId, String categoryId) =>
      _listingService.deleteProduct(businessId, productId, categoryId);

  Future<List<ProductModel>> getProducts(String businessId, {String? categoryId}) =>
      _listingService.getProducts(businessId, categoryId: categoryId);

  Stream<List<ProductModel>> watchProducts(String businessId, {String? categoryId}) =>
      _listingService.watchProducts(businessId, categoryId: categoryId);

  Future<bool> toggleProductAvailability(String businessId, String productId, bool inStock) =>
      _listingService.toggleProductAvailability(businessId, productId, inStock);

  Future<bool> updateProductStock(String businessId, String productId, int stock) =>
      _listingService.updateProductStock(businessId, productId, stock);

  // ============================================================
  // REVIEW OPERATIONS (delegated to BusinessReviewService)
  // ============================================================

  Future<String?> addReview(BusinessReview review) =>
      _reviewService.addReview(review);

  Future<bool> replyToReview(String reviewId, String reply) =>
      _reviewService.replyToReview(reviewId, reply);

  Future<List<BusinessReview>> getBusinessReviews(String businessId) =>
      _reviewService.getBusinessReviews(businessId);

  Stream<List<BusinessReview>> watchBusinessReviews(String businessId) =>
      _reviewService.watchBusinessReviews(businessId);

  // ============================================================
  // POST OPERATIONS (delegated to BusinessPostService)
  // ============================================================

  Future<String?> createPost(BusinessPost post) =>
      _postService.createPost(post);

  Future<bool> updatePost(String postId, BusinessPost post) =>
      _postService.updatePost(postId, post);

  Future<bool> deletePost(String businessId, String postId) =>
      _postService.deletePost(businessId, postId);

  Future<bool> togglePostActive(String businessId, String postId, bool isActive) =>
      _postService.togglePostActive(businessId, postId, isActive);

  Future<List<BusinessPost>> getBusinessPosts(String businessId) =>
      _postService.getBusinessPosts(businessId);

  Stream<List<BusinessPost>> watchBusinessPosts(String businessId) =>
      _postService.watchBusinessPosts(businessId);

  // ============================================================
  // ORDER OPERATIONS (delegated to BusinessOrderService)
  // ============================================================

  Future<String?> createOrder(BusinessOrder order) =>
      _orderService.createOrder(order);

  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) =>
      _orderService.updateOrderStatus(orderId, newStatus);

  Future<List<BusinessOrder>> getBusinessOrders(String businessId) =>
      _orderService.getBusinessOrders(businessId);

  Stream<List<BusinessOrder>> watchBusinessOrders(String businessId) =>
      _orderService.watchBusinessOrders(businessId);

  Future<BusinessOrder?> getOrder(String orderId) =>
      _orderService.getOrder(orderId);

  Future<bool> addOrderNotes(String orderId, String notes) =>
      _orderService.addOrderNotes(orderId, notes);

  Future<bool> cancelOrder(String orderId, String reason, String cancelledBy) =>
      _orderService.cancelOrder(orderId, reason, cancelledBy);

  Stream<List<RoomBookingModel>> watchRoomBookings(String businessId) =>
      _orderService.watchRoomBookings(businessId);

  Future<bool> updateRoomBookingStatus(String businessId, String bookingId, BookingStatus status) =>
      _orderService.updateRoomBookingStatus(businessId, bookingId, status);

  Stream<List<FoodOrderModel>> watchFoodOrders(String businessId) =>
      _orderService.watchFoodOrders(businessId);

  Future<bool> updateFoodOrderStatus(String businessId, String orderId, FoodOrderStatus status) =>
      _orderService.updateFoodOrderStatus(businessId, orderId, status);

  Future<Map<String, dynamic>> getBusinessStats(String businessId) =>
      _orderService.getBusinessStats(businessId);

  // ============================================================
  // DISCOVERY OPERATIONS (delegated to BusinessDiscoveryService)
  // ============================================================

  Future<List<BusinessModel>> searchBusinesses({
    String? query,
    String? type,
    String? industry,
    double? nearLat,
    double? nearLng,
    double radiusKm = 10,
    int limit = 20,
  }) => _discoveryService.searchBusinesses(
    query: query,
    type: type,
    industry: industry,
    nearLat: nearLat,
    nearLng: nearLng,
    radiusKm: radiusKm,
    limit: limit,
  );

  Future<List<BusinessModel>> getNearbyBusinesses(double lat, double lng, {double radiusKm = 10, int limit = 20}) =>
      _discoveryService.getNearbyBusinesses(lat, lng, radiusKm: radiusKm, limit: limit);

  Future<List<BusinessModel>> getFeaturedBusinesses({int limit = 10}) =>
      _discoveryService.getFeaturedBusinesses(limit: limit);

  // ============================================================
  // FOLLOW OPERATIONS (delegated to BusinessFollowService)
  // ============================================================

  Future<bool> followBusiness(String businessId) =>
      _followService.followBusiness(businessId);

  Future<bool> unfollowBusiness(String businessId) =>
      _followService.unfollowBusiness(businessId);

  Future<bool> isFollowing(String businessId) =>
      _followService.isFollowing(businessId);
}
