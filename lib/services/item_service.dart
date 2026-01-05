import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item_model.dart';

/// Unified Item Service with caching for ALL item types
/// Replaces: ProductService, MenuService, RoomService, etc.
///
/// Optimization features:
/// - In-memory cache with TTL (5 minutes)
/// - Pagination (max 20 items per query)
/// - Single collection queries
/// - Denormalization support (update business stats when items change)
class ItemService {
  final FirebaseFirestore _firestore;

  // In-memory cache
  final Map<String, _CachedData<List<ItemModel>>> _itemsCache = {};
  final Map<String, _CachedData<ItemModel>> _singleItemCache = {};
  final Map<String, _CachedData<List<ItemCategory>>> _categoriesCache = {};

  // Cache TTL in milliseconds (5 minutes)
  static const int _cacheTTL = 5 * 60 * 1000;

  // Max items per query
  static const int _pageSize = 20;

  ItemService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // === ITEMS CRUD ===

  /// Get items for a business with caching and pagination
  /// Returns cached data if available and not expired
  Future<List<ItemModel>> getItems({
    required String businessId,
    ItemType? type,
    String? category,
    bool activeOnly = true,
    int limit = _pageSize,
    DocumentSnapshot? startAfter,
    bool forceRefresh = false,
  }) async {
    // Generate cache key
    final cacheKey = '$businessId:${type?.name ?? 'all'}:${category ?? 'all'}:$activeOnly';

    // Check cache (only for first page without startAfter)
    if (!forceRefresh && startAfter == null) {
      final cached = _itemsCache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }
    }

    // Build query
    Query query = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('items');

    // Filter by type
    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }

    // Filter by category
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    // Filter active only
    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }

    // Order by sort order then created date
    query = query.orderBy('sortOrder').orderBy('createdAt', descending: true);

    // Pagination
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    query = query.limit(limit);

    // Execute query
    final snapshot = await query.get();
    final items = snapshot.docs.map((doc) => ItemModel.fromFirestore(doc)).toList();

    // Cache first page results
    if (startAfter == null) {
      _itemsCache[cacheKey] = _CachedData(items);
    }

    return items;
  }

  /// Get a single item by ID with caching
  Future<ItemModel?> getItem(String businessId, String itemId, {bool forceRefresh = false}) async {
    final cacheKey = '$businessId:$itemId';

    // Check cache
    if (!forceRefresh) {
      final cached = _singleItemCache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }
    }

    final doc = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('items')
        .doc(itemId)
        .get();

    if (!doc.exists) return null;

    final item = ItemModel.fromFirestore(doc);
    _singleItemCache[cacheKey] = _CachedData(item);
    return item;
  }

  /// Create a new item
  Future<String?> createItem(String businessId, ItemModel item) async {
    try {
      final docRef = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('items')
          .add(item.toMap());

      // Invalidate cache
      _invalidateBusinessCache(businessId);

      // Update business item count
      await _updateBusinessStats(businessId, itemCountDelta: 1);

      return docRef.id;
    } catch (e) {
      print('Error creating item: $e');
      return null;
    }
  }

  /// Update an existing item
  Future<bool> updateItem(String businessId, String itemId, ItemModel item) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('items')
          .doc(itemId)
          .update({
        ...item.toMap(),
        'updatedAt': Timestamp.now(),
      });

      // Invalidate cache
      _invalidateBusinessCache(businessId);
      _singleItemCache.remove('$businessId:$itemId');

      return true;
    } catch (e) {
      print('Error updating item: $e');
      return false;
    }
  }

  /// Delete an item
  Future<bool> deleteItem(String businessId, String itemId) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('items')
          .doc(itemId)
          .delete();

      // Invalidate cache
      _invalidateBusinessCache(businessId);
      _singleItemCache.remove('$businessId:$itemId');

      // Update business item count
      await _updateBusinessStats(businessId, itemCountDelta: -1);

      return true;
    } catch (e) {
      print('Error deleting item: $e');
      return false;
    }
  }

  /// Toggle item availability
  Future<bool> toggleItemAvailability(String businessId, String itemId, bool isActive) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('items')
          .doc(itemId)
          .update({
        'isActive': isActive,
        'updatedAt': Timestamp.now(),
      });

      // Invalidate cache
      _invalidateBusinessCache(businessId);
      _singleItemCache.remove('$businessId:$itemId');

      return true;
    } catch (e) {
      print('Error toggling item availability: $e');
      return false;
    }
  }

  /// Toggle featured status
  Future<bool> toggleFeatured(String businessId, String itemId, bool isFeatured) async {
    try {
      final batch = _firestore.batch();

      // Update item
      batch.update(
        _firestore.collection('businesses').doc(businessId).collection('items').doc(itemId),
        {
          'isFeatured': isFeatured,
          'updatedAt': Timestamp.now(),
        },
      );

      // Update business featured items list
      if (isFeatured) {
        // Get item data
        final item = await getItem(businessId, itemId);
        if (item != null) {
          batch.update(
            _firestore.collection('businesses').doc(businessId),
            {
              'featuredItems': FieldValue.arrayUnion([item.toMinimal()]),
            },
          );
        }
      } else {
        // Remove from featured - need to get current list and filter
        final businessDoc = await _firestore.collection('businesses').doc(businessId).get();
        final featuredItems = List<Map<String, dynamic>>.from(businessDoc.data()?['featuredItems'] ?? []);
        featuredItems.removeWhere((item) => item['id'] == itemId);
        batch.update(
          _firestore.collection('businesses').doc(businessId),
          {'featuredItems': featuredItems},
        );
      }

      await batch.commit();

      // Invalidate cache
      _invalidateBusinessCache(businessId);
      _singleItemCache.remove('$businessId:$itemId');

      return true;
    } catch (e) {
      print('Error toggling featured: $e');
      return false;
    }
  }

  /// Update item stock
  Future<bool> updateStock(String businessId, String itemId, int newStock) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('items')
          .doc(itemId)
          .update({
        'stock': newStock,
        'updatedAt': Timestamp.now(),
      });

      // Invalidate cache
      _singleItemCache.remove('$businessId:$itemId');

      return true;
    } catch (e) {
      print('Error updating stock: $e');
      return false;
    }
  }

  /// Decrease stock after purchase
  Future<bool> decreaseStock(String businessId, String itemId, int quantity) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('items')
            .doc(itemId);

        final doc = await transaction.get(docRef);
        if (!doc.exists) throw Exception('Item not found');

        final currentStock = doc.data()?['stock'] ?? -1;
        if (currentStock == -1) return; // Unlimited stock

        final newStock = currentStock - quantity;
        if (newStock < 0) throw Exception('Insufficient stock');

        transaction.update(docRef, {
          'stock': newStock,
          'updatedAt': Timestamp.now(),
        });
      });

      // Invalidate cache
      _singleItemCache.remove('$businessId:$itemId');

      return true;
    } catch (e) {
      print('Error decreasing stock: $e');
      return false;
    }
  }

  // === CATEGORIES ===

  /// Get categories for a business
  Future<List<ItemCategory>> getCategories(String businessId, {bool forceRefresh = false}) async {
    final cacheKey = businessId;

    // Check cache
    if (!forceRefresh) {
      final cached = _categoriesCache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }
    }

    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .limit(50) // Max categories
        .get();

    final categories = snapshot.docs.map((doc) => ItemCategory.fromFirestore(doc)).toList();
    _categoriesCache[cacheKey] = _CachedData(categories);
    return categories;
  }

  /// Create a category
  Future<String?> createCategory(String businessId, ItemCategory category) async {
    try {
      final docRef = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('categories')
          .add(category.toMap());

      _categoriesCache.remove(businessId);
      return docRef.id;
    } catch (e) {
      print('Error creating category: $e');
      return null;
    }
  }

  /// Update a category
  Future<bool> updateCategory(String businessId, String categoryId, ItemCategory category) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('categories')
          .doc(categoryId)
          .update(category.toMap());

      _categoriesCache.remove(businessId);
      return true;
    } catch (e) {
      print('Error updating category: $e');
      return false;
    }
  }

  /// Delete a category
  Future<bool> deleteCategory(String businessId, String categoryId) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('categories')
          .doc(categoryId)
          .delete();

      _categoriesCache.remove(businessId);
      return true;
    } catch (e) {
      print('Error deleting category: $e');
      return false;
    }
  }

  // === SEARCH ===

  /// Search items by name or tags
  Future<List<ItemModel>> searchItems(String businessId, String query, {ItemType? type}) async {
    if (query.length < 2) return [];

    final searchTerms = query.toLowerCase().split(' ').where((t) => t.length > 1).toList();
    if (searchTerms.isEmpty) return [];

    Query firestoreQuery = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('items')
        .where('isActive', isEqualTo: true);

    if (type != null) {
      firestoreQuery = firestoreQuery.where('type', isEqualTo: type.name);
    }

    // Search by searchTerms array-contains-any (max 10 terms)
    firestoreQuery = firestoreQuery
        .where('searchTerms', arrayContainsAny: searchTerms.take(10).toList())
        .limit(_pageSize);

    final snapshot = await firestoreQuery.get();
    return snapshot.docs.map((doc) => ItemModel.fromFirestore(doc)).toList();
  }

  // === REAL-TIME STREAMS ===

  /// Watch items in real-time
  Stream<List<ItemModel>> watchItems({
    required String businessId,
    ItemType? type,
    bool activeOnly = true,
  }) {
    Query query = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('items');

    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }

    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }

    return query
        .orderBy('sortOrder')
        .limit(_pageSize)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ItemModel.fromFirestore(doc)).toList());
  }

  /// Watch featured items only
  Stream<List<ItemModel>> watchFeaturedItems(String businessId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('items')
        .where('isFeatured', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .limit(6)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ItemModel.fromFirestore(doc)).toList());
  }

  // === BATCH OPERATIONS ===

  /// Reorder items
  Future<bool> reorderItems(String businessId, List<String> itemIds) async {
    try {
      final batch = _firestore.batch();

      for (int i = 0; i < itemIds.length; i++) {
        batch.update(
          _firestore.collection('businesses').doc(businessId).collection('items').doc(itemIds[i]),
          {'sortOrder': i},
        );
      }

      await batch.commit();
      _invalidateBusinessCache(businessId);
      return true;
    } catch (e) {
      print('Error reordering items: $e');
      return false;
    }
  }

  /// Bulk toggle availability
  Future<bool> bulkToggleAvailability(String businessId, List<String> itemIds, bool isActive) async {
    try {
      final batch = _firestore.batch();

      for (final itemId in itemIds) {
        batch.update(
          _firestore.collection('businesses').doc(businessId).collection('items').doc(itemId),
          {
            'isActive': isActive,
            'updatedAt': Timestamp.now(),
          },
        );
      }

      await batch.commit();
      _invalidateBusinessCache(businessId);
      return true;
    } catch (e) {
      print('Error bulk toggling availability: $e');
      return false;
    }
  }

  // === HELPERS ===

  /// Invalidate all cache for a business
  void _invalidateBusinessCache(String businessId) {
    _itemsCache.removeWhere((key, _) => key.startsWith('$businessId:'));
    _singleItemCache.removeWhere((key, _) => key.startsWith('$businessId:'));
  }

  /// Update business stats (item count)
  Future<void> _updateBusinessStats(String businessId, {int itemCountDelta = 0}) async {
    try {
      await _firestore.collection('businesses').doc(businessId).update({
        'itemCount': FieldValue.increment(itemCountDelta),
      });
    } catch (e) {
      print('Error updating business stats: $e');
    }
  }

  /// Clear all cache (call when user logs out)
  void clearCache() {
    _itemsCache.clear();
    _singleItemCache.clear();
    _categoriesCache.clear();
  }

  /// Get items count for business
  Future<int> getItemCount(String businessId, {ItemType? type}) async {
    AggregateQuery query;

    if (type != null) {
      query = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('items')
          .where('type', isEqualTo: type.name)
          .count();
    } else {
      query = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('items')
          .count();
    }

    final snapshot = await query.get();
    return snapshot.count ?? 0;
  }

  /// Get low stock items
  Future<List<ItemModel>> getLowStockItems(String businessId) async {
    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('items')
        .where('stock', isGreaterThan: 0)
        .where('stock', isLessThanOrEqualTo: 10)
        .where('isActive', isEqualTo: true)
        .limit(20)
        .get();

    return snapshot.docs.map((doc) => ItemModel.fromFirestore(doc)).toList();
  }
}

/// Cache data wrapper with TTL
class _CachedData<T> {
  final T data;
  final int timestamp;

  _CachedData(this.data) : timestamp = DateTime.now().millisecondsSinceEpoch;

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch - timestamp > ItemService._cacheTTL;
}
