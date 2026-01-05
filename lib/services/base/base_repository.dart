import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Generic repository base class for Firestore CRUD operations.
/// Eliminates duplicate CRUD code across different item types.
///
/// Usage:
/// ```dart
/// class ProductRepository extends BaseRepository<ProductModel> {
///   ProductRepository() : super('products');
///
///   @override
///   ProductModel fromFirestore(DocumentSnapshot doc) =>
///       ProductModel.fromFirestore(doc);
///
///   @override
///   Map<String, dynamic> toMap(ProductModel item) => item.toMap();
/// }
/// ```
abstract class BaseRepository<T> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName;

  BaseRepository(this.collectionName);

  /// Convert Firestore document to model
  T fromFirestore(DocumentSnapshot doc);

  /// Convert model to Firestore map
  Map<String, dynamic> toMap(T item);

  /// Get collection reference for a business
  CollectionReference<Map<String, dynamic>> _getCollection(String businessId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection(collectionName);
  }

  // ============ CREATE ============

  /// Create a new item
  Future<String?> create(String businessId, T item) async {
    try {
      final docRef = await _getCollection(businessId).add({
        ...toMap(item),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('[$collectionName] Create error: $e');
      return null;
    }
  }

  /// Create with specific ID
  Future<bool> createWithId(String businessId, String itemId, T item) async {
    try {
      await _getCollection(businessId).doc(itemId).set({
        ...toMap(item),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[$collectionName] CreateWithId error: $e');
      return false;
    }
  }

  // ============ READ ============

  /// Get single item by ID
  Future<T?> getById(String businessId, String itemId) async {
    try {
      final doc = await _getCollection(businessId).doc(itemId).get();
      if (!doc.exists) return null;
      return fromFirestore(doc);
    } catch (e) {
      debugPrint('[$collectionName] GetById error: $e');
      return null;
    }
  }

  /// Get all items for a business
  Future<List<T>> getAll(String businessId) async {
    try {
      final snapshot = await _getCollection(businessId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('[$collectionName] GetAll error: $e');
      return [];
    }
  }

  /// Get items with custom query
  Future<List<T>> getWhere(
    String businessId, {
    required String field,
    required dynamic isEqualTo,
    String? orderBy,
    bool descending = true,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _getCollection(businessId).where(field, isEqualTo: isEqualTo);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('[$collectionName] GetWhere error: $e');
      return [];
    }
  }

  /// Get active items only
  Future<List<T>> getActive(String businessId) async {
    return getWhere(businessId, field: 'isActive', isEqualTo: true);
  }

  /// Get items by category
  Future<List<T>> getByCategory(String businessId, String categoryId) async {
    return getWhere(businessId, field: 'categoryId', isEqualTo: categoryId);
  }

  // ============ WATCH (STREAMS) ============

  /// Watch all items in real-time
  Stream<List<T>> watchAll(String businessId) {
    return _getCollection(businessId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => fromFirestore(doc)).toList());
  }

  /// Watch active items only
  Stream<List<T>> watchActive(String businessId) {
    return _getCollection(businessId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => fromFirestore(doc)).toList());
  }

  /// Watch items by category
  Stream<List<T>> watchByCategory(String businessId, String categoryId) {
    return _getCollection(businessId)
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => fromFirestore(doc)).toList());
  }

  /// Watch single item
  Stream<T?> watchById(String businessId, String itemId) {
    return _getCollection(businessId).doc(itemId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return fromFirestore(doc);
    });
  }

  // ============ UPDATE ============

  /// Update entire item
  Future<bool> update(String businessId, String itemId, T item) async {
    try {
      await _getCollection(businessId).doc(itemId).update({
        ...toMap(item),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[$collectionName] Update error: $e');
      return false;
    }
  }

  /// Update specific fields
  Future<bool> updateFields(
    String businessId,
    String itemId,
    Map<String, dynamic> fields,
  ) async {
    try {
      await _getCollection(businessId).doc(itemId).update({
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[$collectionName] UpdateFields error: $e');
      return false;
    }
  }

  /// Toggle availability
  Future<bool> toggleAvailability(
    String businessId,
    String itemId,
    bool isActive,
  ) async {
    return updateFields(businessId, itemId, {'isActive': isActive});
  }

  /// Update sort order
  Future<bool> updateSortOrder(
    String businessId,
    String itemId,
    int sortOrder,
  ) async {
    return updateFields(businessId, itemId, {'sortOrder': sortOrder});
  }

  /// Increment a numeric field
  Future<bool> incrementField(
    String businessId,
    String itemId,
    String field, {
    int amount = 1,
  }) async {
    try {
      await _getCollection(businessId).doc(itemId).update({
        field: FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[$collectionName] IncrementField error: $e');
      return false;
    }
  }

  // ============ DELETE ============

  /// Delete single item
  Future<bool> delete(String businessId, String itemId) async {
    try {
      await _getCollection(businessId).doc(itemId).delete();
      return true;
    } catch (e) {
      debugPrint('[$collectionName] Delete error: $e');
      return false;
    }
  }

  /// Delete multiple items
  Future<bool> deleteMultiple(String businessId, List<String> itemIds) async {
    try {
      final batch = _firestore.batch();
      for (final itemId in itemIds) {
        batch.delete(_getCollection(businessId).doc(itemId));
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('[$collectionName] DeleteMultiple error: $e');
      return false;
    }
  }

  /// Delete all items in a category
  Future<bool> deleteByCategory(String businessId, String categoryId) async {
    try {
      final snapshot = await _getCollection(businessId)
          .where('categoryId', isEqualTo: categoryId)
          .get();

      if (snapshot.docs.isEmpty) return true;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('[$collectionName] DeleteByCategory error: $e');
      return false;
    }
  }

  // ============ BATCH OPERATIONS ============

  /// Create multiple items
  Future<List<String>> createBatch(String businessId, List<T> items) async {
    try {
      final batch = _firestore.batch();
      final ids = <String>[];

      for (final item in items) {
        final docRef = _getCollection(businessId).doc();
        ids.add(docRef.id);
        batch.set(docRef, {
          ...toMap(item),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return ids;
    } catch (e) {
      debugPrint('[$collectionName] CreateBatch error: $e');
      return [];
    }
  }

  /// Update sort order for multiple items
  Future<bool> updateSortOrders(
    String businessId,
    Map<String, int> itemSortOrders,
  ) async {
    try {
      final batch = _firestore.batch();

      for (final entry in itemSortOrders.entries) {
        batch.update(_getCollection(businessId).doc(entry.key), {
          'sortOrder': entry.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('[$collectionName] UpdateSortOrders error: $e');
      return false;
    }
  }

  // ============ COUNT & STATS ============

  /// Get item count
  Future<int> getCount(String businessId) async {
    try {
      final snapshot = await _getCollection(businessId).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('[$collectionName] GetCount error: $e');
      return 0;
    }
  }

  /// Get active item count
  Future<int> getActiveCount(String businessId) async {
    try {
      final snapshot = await _getCollection(businessId)
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('[$collectionName] GetActiveCount error: $e');
      return 0;
    }
  }
}

/// Repository for managing categories (used by products, menu items, etc.)
abstract class BaseCategoryRepository<T> extends BaseRepository<T> {
  BaseCategoryRepository(super.collectionName);

  /// Delete category and all its items
  Future<bool> deleteCategoryWithItems(
    String businessId,
    String categoryId,
    String itemsCollectionName,
  ) async {
    try {
      // First delete all items in category
      final itemsSnapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection(itemsCollectionName)
          .where('categoryId', isEqualTo: categoryId)
          .get();

      final batch = _firestore.batch();

      // Delete items
      for (final doc in itemsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete category
      batch.delete(_getCollection(businessId).doc(categoryId));

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('[$collectionName] DeleteCategoryWithItems error: $e');
      return false;
    }
  }
}
