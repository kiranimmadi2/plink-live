import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/business_model.dart';
import '../../models/room_model.dart';
import '../../models/menu_model.dart';
import '../../models/product_model.dart';
import 'business_profile_service.dart';

/// Service for managing business listings
/// Handles products, services, rooms, menu items, and product categories
class BusinessListingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BusinessProfileService _profileService = BusinessProfileService();

  // Singleton pattern
  static final BusinessListingService _instance = BusinessListingService._internal();
  factory BusinessListingService() => _instance;
  BusinessListingService._internal();

  String? get _currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // GENERIC LISTING OPERATIONS (Products & Services)
  // ============================================================

  /// Create a new listing
  Future<String?> createListing(BusinessListing listing) async {
    if (_currentUserId == null) return null;

    try {
      if (!await _profileService.isBusinessOwner(listing.businessId)) {
        debugPrint('Unauthorized: Cannot create listing for business you do not own');
        return null;
      }

      final docRef = await _firestore
          .collection('business_listings')
          .add(listing.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating listing: $e');
      return null;
    }
  }

  /// Update listing
  Future<bool> updateListing(String listingId, BusinessListing listing) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(listing.businessId)) {
        debugPrint('Unauthorized: Cannot update listing for business you do not own');
        return false;
      }

      await _firestore
          .collection('business_listings')
          .doc(listingId)
          .update(listing.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating listing: $e');
      return false;
    }
  }

  /// Delete listing
  Future<bool> deleteListing(String businessId, String listingId) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot delete listing for business you do not own');
        return false;
      }

      await _firestore.collection('business_listings').doc(listingId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting listing: $e');
      return false;
    }
  }

  /// Get listings for a business
  Future<List<BusinessListing>> getBusinessListings(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('business_listings')
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => BusinessListing.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting listings: $e');
      return [];
    }
  }

  /// Stream listings for a business
  Stream<List<BusinessListing>> watchBusinessListings(String businessId) {
    return _firestore
        .collection('business_listings')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BusinessListing.fromFirestore(doc))
              .toList(),
        );
  }

  /// Toggle listing availability
  Future<bool> toggleListingAvailability(
    String businessId,
    String listingId,
    bool isAvailable,
  ) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot toggle listing for business you do not own');
        return false;
      }

      await _firestore.collection('business_listings').doc(listingId).update({
        'isAvailable': isAvailable,
      });
      return true;
    } catch (e) {
      debugPrint('Error toggling listing: $e');
      return false;
    }
  }

  // ============================================================
  // HOSPITALITY - ROOM MANAGEMENT
  // ============================================================

  /// Create a new room
  Future<String?> createRoom(RoomModel room) async {
    if (_currentUserId == null) return null;

    try {
      if (!await _profileService.isBusinessOwner(room.businessId)) {
        debugPrint('Unauthorized: Cannot create room for business you do not own');
        return null;
      }

      final docRef = await _firestore
          .collection('businesses')
          .doc(room.businessId)
          .collection('rooms')
          .add(room.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating room: $e');
      return null;
    }
  }

  /// Update room
  Future<bool> updateRoom(String businessId, String roomId, RoomModel room) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot update room for business you do not own');
        return false;
      }

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('rooms')
          .doc(roomId)
          .update(room.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating room: $e');
      return false;
    }
  }

  /// Delete room
  Future<bool> deleteRoom(String businessId, String roomId) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot delete room for business you do not own');
        return false;
      }

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('rooms')
          .doc(roomId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting room: $e');
      return false;
    }
  }

  /// Get all rooms for a business
  Future<List<RoomModel>> getRooms(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('rooms')
          .orderBy('sortOrder')
          .limit(100)
          .get();
      return snapshot.docs.map((doc) => RoomModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting rooms: $e');
      return [];
    }
  }

  /// Stream rooms for a business
  Stream<List<RoomModel>> watchRooms(String businessId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('rooms')
        .orderBy('sortOrder')
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => RoomModel.fromFirestore(doc)).toList());
  }

  /// Toggle room availability
  Future<bool> toggleRoomAvailability(String businessId, String roomId, bool isAvailable) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot toggle room availability for business you do not own');
        return false;
      }

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('rooms')
          .doc(roomId)
          .update({
        'isAvailable': isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error toggling room availability: $e');
      return false;
    }
  }

  // ============================================================
  // FOOD & BEVERAGE - MENU MANAGEMENT
  // ============================================================

  /// Create a menu category
  Future<String?> createMenuCategory(MenuCategoryModel category) async {
    if (_currentUserId == null) return null;

    try {
      if (!await _profileService.isBusinessOwner(category.businessId)) {
        debugPrint('Unauthorized: Cannot create menu category for business you do not own');
        return null;
      }

      final docRef = await _firestore
          .collection('businesses')
          .doc(category.businessId)
          .collection('menu_categories')
          .add(category.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating menu category: $e');
      return null;
    }
  }

  /// Update menu category
  Future<bool> updateMenuCategory(String businessId, String categoryId, MenuCategoryModel category) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot update menu category for business you do not own');
        return false;
      }

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('menu_categories')
          .doc(categoryId)
          .update(category.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating menu category: $e');
      return false;
    }
  }

  /// Delete menu category
  Future<bool> deleteMenuCategory(String businessId, String categoryId) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot delete menu category for business you do not own');
        return false;
      }

      // Delete category and all its items
      final batch = _firestore.batch();

      // Delete items in this category
      final itemsSnapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('menu_items')
          .where('categoryId', isEqualTo: categoryId)
          .limit(100)
          .get();

      for (final doc in itemsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete category
      batch.delete(_firestore
          .collection('businesses')
          .doc(businessId)
          .collection('menu_categories')
          .doc(categoryId));

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error deleting menu category: $e');
      return false;
    }
  }

  /// Get all menu categories for a business
  Future<List<MenuCategoryModel>> getMenuCategories(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('menu_categories')
          .limit(100)
          .get();
      final categories = snapshot.docs
          .map((doc) => MenuCategoryModel.fromFirestore(doc))
          .toList();
      // Sort client-side to avoid Firestore index requirement
      categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return categories;
    } catch (e) {
      debugPrint('Error getting menu categories: $e');
      return [];
    }
  }

  /// Stream menu categories
  Stream<List<MenuCategoryModel>> watchMenuCategories(String businessId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('menu_categories')
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final categories = snapshot.docs
              .map((doc) => MenuCategoryModel.fromFirestore(doc))
              .toList();
          // Sort client-side to avoid Firestore index requirement
          categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          return categories;
        })
        .handleError((error) {
          debugPrint('Error watching menu categories: $error');
          return <MenuCategoryModel>[];
        });
  }

  /// Create a menu item
  Future<String?> createMenuItem(MenuItemModel item) async {
    if (_currentUserId == null) return null;

    try {
      if (!await _profileService.isBusinessOwner(item.businessId)) {
        debugPrint('Unauthorized: Cannot create menu item for business you do not own');
        return null;
      }

      final docRef = await _firestore
          .collection('businesses')
          .doc(item.businessId)
          .collection('menu_items')
          .add(item.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating menu item: $e');
      return null;
    }
  }

  /// Update menu item
  Future<bool> updateMenuItem(String businessId, String itemId, MenuItemModel item) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot update menu item for business you do not own');
        return false;
      }

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('menu_items')
          .doc(itemId)
          .update(item.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating menu item: $e');
      return false;
    }
  }

  /// Delete menu item
  Future<bool> deleteMenuItem(String businessId, String itemId) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot delete menu item for business you do not own');
        return false;
      }

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('menu_items')
          .doc(itemId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting menu item: $e');
      return false;
    }
  }

  /// Get all menu items for a business
  Future<List<MenuItemModel>> getMenuItems(String businessId, {String? categoryId}) async {
    try {
      Query query = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('menu_items');

      if (categoryId != null) {
        query = query.where('categoryId', isEqualTo: categoryId);
      }

      final snapshot = await query.limit(100).get();
      final items = snapshot.docs
          .map((doc) => MenuItemModel.fromFirestore(doc))
          .toList();
      // Sort client-side to avoid Firestore index requirement
      items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return items;
    } catch (e) {
      debugPrint('Error getting menu items: $e');
      return [];
    }
  }

  /// Stream menu items
  Stream<List<MenuItemModel>> watchMenuItems(String businessId, {String? categoryId}) {
    Query query = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('menu_items');

    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }

    return query.limit(100).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => MenuItemModel.fromFirestore(doc))
          .toList();
      // Sort client-side to avoid Firestore index requirement
      items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return items;
    }).handleError((error) {
      debugPrint('Error watching menu items: $error');
      return <MenuItemModel>[];
    });
  }

  /// Toggle menu item availability
  Future<bool> toggleMenuItemAvailability(String businessId, String itemId, bool isAvailable) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot toggle menu item availability for business you do not own');
        return false;
      }

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('menu_items')
          .doc(itemId)
          .update({
        'isAvailable': isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error toggling menu item availability: $e');
      return false;
    }
  }

  // ============================================================
  // RETAIL - PRODUCT MANAGEMENT
  // ============================================================

  /// Create a product category
  Future<String?> createProductCategory(ProductCategoryModel category) async {
    if (_currentUserId == null) return null;

    try {
      if (!await _profileService.isBusinessOwner(category.businessId)) {
        debugPrint('Unauthorized: Cannot create product category for business you do not own');
        return null;
      }

      final docRef = await _firestore
          .collection('businesses')
          .doc(category.businessId)
          .collection('product_categories')
          .add(category.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating product category: $e');
      return null;
    }
  }

  /// Update product category
  Future<bool> updateProductCategory(String businessId, String categoryId, ProductCategoryModel category) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot update product category for business you do not own');
        return false;
      }

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('product_categories')
          .doc(categoryId)
          .update(category.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating product category: $e');
      return false;
    }
  }

  /// Delete product category
  Future<bool> deleteProductCategory(String businessId, String categoryId) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot delete product category for business you do not own');
        return false;
      }

      final batch = _firestore.batch();

      // Delete products in this category
      final productsSnapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .where('categoryId', isEqualTo: categoryId)
          .limit(100)
          .get();

      for (final doc in productsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete category
      batch.delete(_firestore
          .collection('businesses')
          .doc(businessId)
          .collection('product_categories')
          .doc(categoryId));

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error deleting product category: $e');
      return false;
    }
  }

  /// Get all product categories for a business
  Future<List<ProductCategoryModel>> getProductCategories(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('product_categories')
          .orderBy('sortOrder')
          .limit(100)
          .get();
      return snapshot.docs.map((doc) => ProductCategoryModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting product categories: $e');
      return [];
    }
  }

  /// Stream product categories
  Stream<List<ProductCategoryModel>> watchProductCategories(String businessId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('product_categories')
        .orderBy('sortOrder')
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ProductCategoryModel.fromFirestore(doc)).toList());
  }

  /// Create a product
  Future<String?> createProduct(ProductModel product) async {
    if (_currentUserId == null) return null;

    try {
      if (!await _profileService.isBusinessOwner(product.businessId)) {
        debugPrint('Unauthorized: Cannot create product for business you do not own');
        return null;
      }

      final docRef = await _firestore
          .collection('businesses')
          .doc(product.businessId)
          .collection('products')
          .add(product.toMap());

      // Update category product count
      await _firestore
          .collection('businesses')
          .doc(product.businessId)
          .collection('product_categories')
          .doc(product.categoryId)
          .update({
        'productCount': FieldValue.increment(1),
      });

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating product: $e');
      return null;
    }
  }

  /// Update product
  Future<bool> updateProduct(String businessId, String productId, ProductModel product) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot update product for business you do not own');
        return false;
      }

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc(productId)
          .update(product.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating product: $e');
      return false;
    }
  }

  /// Delete product
  Future<bool> deleteProduct(String businessId, String productId, String categoryId) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot delete product for business you do not own');
        return false;
      }

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc(productId)
          .delete();

      // Update category product count
      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('product_categories')
          .doc(categoryId)
          .update({
        'productCount': FieldValue.increment(-1),
      });

      return true;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }

  /// Get all products for a business
  Future<List<ProductModel>> getProducts(String businessId, {String? categoryId}) async {
    try {
      Query query = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('products');

      if (categoryId != null) {
        query = query.where('categoryId', isEqualTo: categoryId);
      }

      final snapshot = await query.orderBy('sortOrder').limit(100).get();
      return snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting products: $e');
      return [];
    }
  }

  /// Stream products
  Stream<List<ProductModel>> watchProducts(String businessId, {String? categoryId}) {
    Query query = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('products');

    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }

    return query.orderBy('sortOrder').limit(100).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList());
  }

  /// Toggle product availability
  Future<bool> toggleProductAvailability(String businessId, String productId, bool inStock) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot toggle product availability for business you do not own');
        return false;
      }

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc(productId)
          .update({
        'inStock': inStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error toggling product availability: $e');
      return false;
    }
  }

  /// Update product stock
  Future<bool> updateProductStock(String businessId, String productId, int stock) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot update product stock for business you do not own');
        return false;
      }

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('products')
          .doc(productId)
          .update({
        'stock': stock,
        'inStock': stock > 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating product stock: $e');
      return false;
    }
  }
}
