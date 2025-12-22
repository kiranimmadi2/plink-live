import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Optimized Firestore service with caching and efficient queries
class OptimizedFirestoreService {
  static final OptimizedFirestoreService _instance = OptimizedFirestoreService._internal();
  factory OptimizedFirestoreService() => _instance;
  OptimizedFirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache for frequently accessed documents
  final Map<String, CachedDocument> _documentCache = {};
  // ignore: unused_field
  final Duration _cacheExpiry = const Duration(minutes: 5);
  
  // Pagination helpers
  final Map<String, DocumentSnapshot?> _lastDocuments = {};
  
  /// Initialize Firestore with optimal settings
  void initialize() {
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }
  
  /// Get document with caching
  Future<DocumentSnapshot<Map<String, dynamic>>?> getCachedDocument(
    String collection,
    String documentId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = '$collection/$documentId';
    
    // Check cache first
    if (!forceRefresh && _documentCache.containsKey(cacheKey)) {
      final cached = _documentCache[cacheKey]!;
      if (cached.isValid) {
        return cached.document;
      }
    }
    
    try {
      // Fetch from Firestore
      final doc = await _firestore
          .collection(collection)
          .doc(documentId)
          .get();
      
      // Update cache
      _documentCache[cacheKey] = CachedDocument(doc, DateTime.now());
      
      return doc;
    } catch (e) {
      debugPrint('Error fetching document: $e');
      return null;
    }
  }
  
  /// Get paginated query results
  Future<QuerySnapshot<Map<String, dynamic>>> getPaginatedQuery(
    String queryKey,
    Query<Map<String, dynamic>> baseQuery, {
    int limit = 20,
    bool loadMore = false,
  }) async {
    try {
      Query<Map<String, dynamic>> query = baseQuery.limit(limit);
      
      // If loading more, start after last document
      if (loadMore && _lastDocuments.containsKey(queryKey)) {
        final lastDoc = _lastDocuments[queryKey];
        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }
      }
      
      final snapshot = await query.get();
      
      // Store last document for pagination
      if (snapshot.docs.isNotEmpty) {
        _lastDocuments[queryKey] = snapshot.docs.last;
      }
      
      return snapshot;
    } catch (e) {
      debugPrint('Error executing paginated query: $e');
      rethrow;
    }
  }
  
  /// Reset pagination for a query
  void resetPagination(String queryKey) {
    _lastDocuments.remove(queryKey);
  }
  
  /// Batch update with error handling
  Future<bool> batchUpdate(
    List<BatchOperation> operations, {
    int maxBatchSize = 500,
  }) async {
    try {
      final batches = <WriteBatch>[];
      
      for (int i = 0; i < operations.length; i += maxBatchSize) {
        final batch = _firestore.batch();
        final end = (i + maxBatchSize < operations.length) 
            ? i + maxBatchSize 
            : operations.length;
        
        for (int j = i; j < end; j++) {
          final op = operations[j];
          switch (op.type) {
            case OperationType.set:
              batch.set(op.reference, op.data!, op.setOptions);
              break;
            case OperationType.update:
              batch.update(op.reference, op.data!);
              break;
            case OperationType.delete:
              batch.delete(op.reference);
              break;
          }
        }
        
        batches.add(batch);
      }
      
      // Commit all batches
      await Future.wait(batches.map((batch) => batch.commit()));
      return true;
    } catch (e) {
      debugPrint('Batch update failed: $e');
      return false;
    }
  }
  
  /// Stream with automatic reconnection
  Stream<T> resilientStream<T>(
    Stream<T> Function() streamFactory, {
    Duration retryDelay = const Duration(seconds: 5),
    int maxRetries = 3,
  }) {
    StreamController<T>? controller;
    StreamSubscription<T>? subscription;
    int retryCount = 0;
    
    void startListening() {
      subscription?.cancel();
      subscription = streamFactory().listen(
        (data) {
          retryCount = 0; // Reset retry count on successful data
          controller?.add(data);
        },
        onError: (error) {
          debugPrint('Stream error: $error');
          
          if (retryCount < maxRetries) {
            retryCount++;
            Future.delayed(retryDelay * retryCount, () {
              if (controller != null && !controller.isClosed) {
                startListening();
              }
            });
          } else {
            controller?.addError(error);
          }
        },
        onDone: () {
          if (retryCount < maxRetries) {
            retryCount++;
            Future.delayed(retryDelay, () {
              if (controller != null && !controller.isClosed) {
                startListening();
              }
            });
          } else {
            controller?.close();
          }
        },
      );
    }
    
    controller = StreamController<T>.broadcast(
      onListen: startListening,
      onCancel: () {
        subscription?.cancel();
      },
    );
    
    return controller.stream;
  }
  
  /// Clear all caches
  void clearCache() {
    _documentCache.clear();
    _lastDocuments.clear();
  }
  
  /// Get collection with compound query optimization
  Future<QuerySnapshot<Map<String, dynamic>>> getOptimizedQuery(
    String collection, {
    List<QueryFilter>? filters,
    List<OrderBy>? orderBy,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(collection);
      
      // Apply filters efficiently
      if (filters != null) {
        // Sort filters by selectivity (most selective first)
        filters.sort((a, b) => a.priority.compareTo(b.priority));
        
        for (final filter in filters) {
          switch (filter.type) {
            case FilterType.equal:
              query = query.where(filter.field, isEqualTo: filter.value);
              break;
            case FilterType.notEqual:
              query = query.where(filter.field, isNotEqualTo: filter.value);
              break;
            case FilterType.greaterThan:
              query = query.where(filter.field, isGreaterThan: filter.value);
              break;
            case FilterType.lessThan:
              query = query.where(filter.field, isLessThan: filter.value);
              break;
            case FilterType.arrayContains:
              query = query.where(filter.field, arrayContains: filter.value);
              break;
            case FilterType.whereIn:
              query = query.where(filter.field, whereIn: filter.value as List);
              break;
          }
        }
      }
      
      // Apply ordering
      if (orderBy != null) {
        for (final order in orderBy) {
          query = query.orderBy(order.field, descending: order.descending);
        }
      }
      
      // Apply limit
      if (limit != null) {
        query = query.limit(limit);
      }
      
      return await query.get();
    } catch (e) {
      debugPrint('Optimized query failed: $e');
      
      // Fallback to simpler query if index is missing
      if (e.toString().contains('index')) {
        debugPrint('Falling back to simpler query without compound conditions');
        return await _firestore
            .collection(collection)
            .limit(limit ?? 20)
            .get();
      }
      
      rethrow;
    }
  }
}

/// Cached document wrapper
class CachedDocument {
  final DocumentSnapshot<Map<String, dynamic>> document;
  final DateTime cachedAt;
  
  CachedDocument(this.document, this.cachedAt);
  
  bool get isValid => 
      DateTime.now().difference(cachedAt) < const Duration(minutes: 5);
}

/// Batch operation wrapper
class BatchOperation {
  final DocumentReference reference;
  final OperationType type;
  final Map<String, dynamic>? data;
  final SetOptions? setOptions;
  
  BatchOperation({
    required this.reference,
    required this.type,
    this.data,
    this.setOptions,
  });
}

enum OperationType { set, update, delete }

/// Query filter wrapper
class QueryFilter {
  final String field;
  final FilterType type;
  final dynamic value;
  final int priority; // Lower number = higher priority
  
  QueryFilter({
    required this.field,
    required this.type,
    required this.value,
    this.priority = 5,
  });
}

enum FilterType {
  equal,
  notEqual,
  greaterThan,
  lessThan,
  arrayContains,
  whereIn,
}

/// Order by wrapper
class OrderBy {
  final String field;
  final bool descending;
  
  OrderBy(this.field, {this.descending = false});
}