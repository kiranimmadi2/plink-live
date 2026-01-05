import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/business_order_model.dart';
import '../../models/room_model.dart';
import '../../models/menu_model.dart';
import 'business_profile_service.dart';
import 'business_listing_service.dart';
import 'business_review_service.dart';

/// Service for managing business orders
/// Handles order creation, status updates, and order statistics
class BusinessOrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BusinessProfileService _profileService = BusinessProfileService();

  // Singleton pattern
  static final BusinessOrderService _instance = BusinessOrderService._internal();
  factory BusinessOrderService() => _instance;
  BusinessOrderService._internal();

  String? get _currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // GENERAL ORDER OPERATIONS
  // ============================================================

  /// Create a new order (using batch transaction for atomic operation)
  Future<String?> createOrder(BusinessOrder order) async {
    if (_currentUserId == null) return null;

    try {
      // Use batch for atomic operation
      final batch = _firestore.batch();

      // Create order document
      final orderRef = _firestore.collection('business_orders').doc();
      batch.set(orderRef, order.toMap());

      // Get business to check if daily reset is needed
      final businessRef = _firestore.collection('businesses').doc(order.businessId);
      final businessDoc = await businessRef.get();

      if (businessDoc.exists) {
        final businessData = businessDoc.data()!;
        final lastDailyReset = businessData['lastDailyReset'] as Timestamp?;

        // Check if daily stats need reset (client-side fallback)
        final now = DateTime.now();
        final todayMidnight = DateTime(now.year, now.month, now.day);
        final needsReset = lastDailyReset == null ||
            lastDailyReset.toDate().isBefore(todayMidnight);

        if (needsReset) {
          // Reset daily stats and then increment
          batch.update(businessRef, {
            'totalOrders': FieldValue.increment(1),
            'todayOrders': 1, // Reset to 1 (this order)
            'todayEarnings': 0, // Reset to 0
            'pendingOrders': FieldValue.increment(1),
            'lastDailyReset': FieldValue.serverTimestamp(),
          });
        } else {
          // Normal increment
          batch.update(businessRef, {
            'totalOrders': FieldValue.increment(1),
            'todayOrders': FieldValue.increment(1),
            'pendingOrders': FieldValue.increment(1),
          });
        }
      }

      await batch.commit();
      return orderRef.id;
    } catch (e) {
      debugPrint('Error creating order: $e');
      return null;
    }
  }

  /// Update order status (using batch transaction for atomic operation)
  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      final orderDoc = await _firestore.collection('business_orders').doc(orderId).get();
      if (!orderDoc.exists) return false;

      final order = BusinessOrder.fromFirestore(orderDoc);
      final oldStatus = order.status;

      // Don't update if status is the same
      if (oldStatus == newStatus) return true;

      // Use batch for atomic operation
      final batch = _firestore.batch();

      // Update order
      final orderRef = _firestore.collection('business_orders').doc(orderId);
      final orderUpdates = <String, dynamic>{
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (newStatus == OrderStatus.completed) {
        orderUpdates['completedDate'] = FieldValue.serverTimestamp();
      }
      batch.update(orderRef, orderUpdates);

      // Build business updates
      final businessRef = _firestore.collection('businesses').doc(order.businessId);
      final businessDoc = await businessRef.get();
      final updates = <String, dynamic>{};

      // Check if daily/monthly reset is needed (client-side fallback)
      bool needsDailyReset = false;
      bool needsMonthlyReset = false;

      if (businessDoc.exists) {
        final businessData = businessDoc.data()!;
        final lastDailyReset = businessData['lastDailyReset'] as Timestamp?;
        final lastMonthlyReset = businessData['lastMonthlyReset'] as Timestamp?;

        final now = DateTime.now();
        final todayMidnight = DateTime(now.year, now.month, now.day);
        final thisMonthFirst = DateTime(now.year, now.month, 1);

        needsDailyReset = lastDailyReset == null ||
            lastDailyReset.toDate().isBefore(todayMidnight);
        needsMonthlyReset = lastMonthlyReset == null ||
            lastMonthlyReset.toDate().isBefore(thisMonthFirst);
      }

      // Decrement old status count
      if (oldStatus == OrderStatus.pending || oldStatus == OrderStatus.newOrder) {
        updates['pendingOrders'] = FieldValue.increment(-1);
      }

      // Increment new status count
      if (newStatus == OrderStatus.completed) {
        updates['completedOrders'] = FieldValue.increment(1);
        updates['totalEarnings'] = FieldValue.increment(order.totalAmount);

        // Handle daily earnings with reset check
        if (needsDailyReset) {
          updates['todayEarnings'] = order.totalAmount;
          updates['lastDailyReset'] = FieldValue.serverTimestamp();
        } else {
          updates['todayEarnings'] = FieldValue.increment(order.totalAmount);
        }

        // Handle monthly earnings with reset check
        if (needsMonthlyReset) {
          updates['monthlyEarnings'] = order.totalAmount;
          updates['lastMonthlyReset'] = FieldValue.serverTimestamp();
        } else {
          updates['monthlyEarnings'] = FieldValue.increment(order.totalAmount);
        }
      } else if (newStatus == OrderStatus.cancelled) {
        updates['cancelledOrders'] = FieldValue.increment(1);

        // If order was previously completed, decrement earnings
        if (oldStatus == OrderStatus.completed) {
          updates['completedOrders'] = FieldValue.increment(-1);
          updates['totalEarnings'] = FieldValue.increment(-order.totalAmount);
          // Note: We don't decrement daily/monthly if already reset,
          // as those are historical for that period
        }
      }

      if (updates.isNotEmpty) {
        batch.update(businessRef, updates);
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      return false;
    }
  }

  /// Get orders for a business
  Future<List<BusinessOrder>> getBusinessOrders(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('business_orders')
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => BusinessOrder.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting orders: $e');
      return [];
    }
  }

  /// Stream orders for a business
  Stream<List<BusinessOrder>> watchBusinessOrders(String businessId) {
    return _firestore
        .collection('business_orders')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BusinessOrder.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get order by ID
  Future<BusinessOrder?> getOrder(String orderId) async {
    try {
      final doc = await _firestore.collection('business_orders').doc(orderId).get();
      if (!doc.exists) return null;
      return BusinessOrder.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting order: $e');
      return null;
    }
  }

  /// Add order notes
  Future<bool> addOrderNotes(String orderId, String notes) async {
    try {
      await _firestore.collection('business_orders').doc(orderId).update({
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding order notes: $e');
      return false;
    }
  }

  /// Cancel order with reason
  Future<bool> cancelOrder(String orderId, String reason, String cancelledBy) async {
    try {
      await _firestore.collection('business_orders').doc(orderId).update({
        'status': OrderStatus.cancelled.name,
        'cancellationReason': reason,
        'cancelledBy': cancelledBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      return false;
    }
  }

  // ============================================================
  // HOSPITALITY - BOOKING MANAGEMENT
  // ============================================================

  /// Stream room bookings for a business
  Stream<List<RoomBookingModel>> watchRoomBookings(String businessId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('room_bookings')
        .orderBy('checkIn', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => RoomBookingModel.fromFirestore(doc)).toList());
  }

  /// Update room booking status
  Future<bool> updateRoomBookingStatus(
    String businessId,
    String bookingId,
    BookingStatus status,
  ) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot update room booking status for business you do not own');
        return false;
      }

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('room_bookings')
          .doc(bookingId)
          .update({
        'status': status.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating room booking status: $e');
      return false;
    }
  }

  /// Get room bookings for a date range
  Future<List<RoomBookingModel>> getRoomBookingsForDateRange(
    String businessId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('room_bookings')
          .where('checkIn', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('checkIn', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('checkIn')
          .limit(100)
          .get();

      return snapshot.docs.map((doc) => RoomBookingModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting room bookings for date range: $e');
      return [];
    }
  }

  // ============================================================
  // FOOD & BEVERAGE - ORDER MANAGEMENT
  // ============================================================

  /// Stream food orders for a business
  Stream<List<FoodOrderModel>> watchFoodOrders(String businessId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('food_orders')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FoodOrderModel.fromFirestore(doc)).toList());
  }

  /// Update food order status
  Future<bool> updateFoodOrderStatus(
    String businessId,
    String orderId,
    FoodOrderStatus status,
  ) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot update food order status for business you do not own');
        return false;
      }

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('food_orders')
          .doc(orderId)
          .update({
        'status': status.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating food order status: $e');
      return false;
    }
  }

  // ============================================================
  // BUSINESS STATISTICS
  // ============================================================

  /// Get business statistics
  Future<Map<String, dynamic>> getBusinessStats(String businessId) async {
    try {
      final listingService = BusinessListingService();
      final reviewService = BusinessReviewService();

      final listings = await listingService.getBusinessListings(businessId);
      final reviews = await reviewService.getBusinessReviews(businessId);

      final products = listings.where((l) => l.type == 'product').length;
      final services = listings.where((l) => l.type == 'service').length;

      return {
        'totalListings': listings.length,
        'products': products,
        'services': services,
        'reviews': reviews.length,
        'avgRating': reviews.isEmpty
            ? 0.0
            : reviews.fold<double>(0, (total, r) => total + r.rating) /
                  reviews.length,
      };
    } catch (e) {
      debugPrint('Error getting stats: $e');
      return {
        'totalListings': 0,
        'products': 0,
        'services': 0,
        'reviews': 0,
        'avgRating': 0.0,
      };
    }
  }

  /// Get order statistics for a business
  Future<Map<String, dynamic>> getOrderStats(String businessId) async {
    try {
      final orders = await getBusinessOrders(businessId);

      final pending = orders.where((o) =>
        o.status == OrderStatus.pending || o.status == OrderStatus.newOrder
      ).length;
      final inProgress = orders.where((o) =>
        o.status == OrderStatus.inProgress || o.status == OrderStatus.accepted
      ).length;
      final completed = orders.where((o) => o.status == OrderStatus.completed).length;
      final cancelled = orders.where((o) => o.status == OrderStatus.cancelled).length;

      final totalRevenue = orders
          .where((o) => o.status == OrderStatus.completed)
          .fold<double>(0, (total, o) => total + o.totalAmount);

      return {
        'total': orders.length,
        'pending': pending,
        'inProgress': inProgress,
        'completed': completed,
        'cancelled': cancelled,
        'totalRevenue': totalRevenue,
      };
    } catch (e) {
      debugPrint('Error getting order stats: $e');
      return {
        'total': 0,
        'pending': 0,
        'inProgress': 0,
        'completed': 0,
        'cancelled': 0,
        'totalRevenue': 0.0,
      };
    }
  }

  /// Get today's order statistics
  Future<Map<String, dynamic>> getTodayOrderStats(String businessId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final snapshot = await _firestore
          .collection('business_orders')
          .where('businessId', isEqualTo: businessId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .limit(100)
          .get();

      final orders = snapshot.docs
          .map((doc) => BusinessOrder.fromFirestore(doc))
          .toList();

      final completed = orders.where((o) => o.status == OrderStatus.completed).length;
      final totalRevenue = orders
          .where((o) => o.status == OrderStatus.completed)
          .fold<double>(0, (total, o) => total + o.totalAmount);

      return {
        'total': orders.length,
        'completed': completed,
        'revenue': totalRevenue,
      };
    } catch (e) {
      debugPrint('Error getting today order stats: $e');
      return {
        'total': 0,
        'completed': 0,
        'revenue': 0.0,
      };
    }
  }
}
