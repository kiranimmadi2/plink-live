import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';

/// Unified Booking Service for ALL booking types
/// Replaces: OrderService, AppointmentService, ReservationService, etc.
///
/// Optimization features:
/// - In-memory cache with TTL (2 minutes for active bookings)
/// - Pagination (max 20 bookings per query)
/// - Denormalization (updates business stats on status changes)
/// - Batch operations for status updates
class BookingService {
  final FirebaseFirestore _firestore;

  // In-memory cache
  final Map<String, _CachedData<List<BookingModel>>> _bookingsCache = {};
  final Map<String, _CachedData<BookingModel>> _singleBookingCache = {};

  // Cache TTL in milliseconds (2 minutes for active bookings)
  static const int _cacheTTL = 2 * 60 * 1000;

  // Max bookings per query
  static const int _pageSize = 20;

  BookingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // === BOOKINGS CRUD ===

  /// Get bookings for a business with caching and pagination
  Future<List<BookingModel>> getBookings({
    required String businessId,
    BookingType? type,
    BookingStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = _pageSize,
    DocumentSnapshot? startAfter,
    bool forceRefresh = false,
  }) async {
    // Generate cache key
    final cacheKey = '$businessId:${type?.name ?? 'all'}:${status?.name ?? 'all'}';

    // Check cache (only for first page)
    if (!forceRefresh && startAfter == null) {
      final cached = _bookingsCache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }
    }

    // Build query
    Query query = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('bookings');

    // Filter by type
    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }

    // Filter by status
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    // Filter by date range
    if (fromDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate));
    }
    if (toDate != null) {
      query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(toDate));
    }

    // Order by creation date (newest first)
    query = query.orderBy('createdAt', descending: true);

    // Pagination
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    query = query.limit(limit);

    // Execute query
    final snapshot = await query.get();
    final bookings = snapshot.docs.map((doc) => BookingModel.fromFirestore(doc)).toList();

    // Cache first page results
    if (startAfter == null) {
      _bookingsCache[cacheKey] = _CachedData(bookings);
    }

    return bookings;
  }

  /// Get active bookings (pending, confirmed, in progress)
  Future<List<BookingModel>> getActiveBookings(String businessId, {BookingType? type}) async {
    Query query = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('bookings')
        .where('status', whereIn: ['pending', 'confirmed', 'inProgress']);

    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }

    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(_pageSize)
        .get();

    return snapshot.docs.map((doc) => BookingModel.fromFirestore(doc)).toList();
  }

  /// Get today's bookings
  Future<List<BookingModel>> getTodaysBookings(String businessId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('bookings')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('createdAt', isLessThan: Timestamp.fromDate(todayEnd))
        .orderBy('createdAt', descending: true)
        .limit(_pageSize)
        .get();

    return snapshot.docs.map((doc) => BookingModel.fromFirestore(doc)).toList();
  }

  /// Get a single booking by ID
  Future<BookingModel?> getBooking(String businessId, String bookingId, {bool forceRefresh = false}) async {
    final cacheKey = '$businessId:$bookingId';

    // Check cache
    if (!forceRefresh) {
      final cached = _singleBookingCache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }
    }

    final doc = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('bookings')
        .doc(bookingId)
        .get();

    if (!doc.exists) return null;

    final booking = BookingModel.fromFirestore(doc);
    _singleBookingCache[cacheKey] = _CachedData(booking);
    return booking;
  }

  /// Create a new booking
  Future<String?> createBooking(String businessId, BookingModel booking, {String? businessName, String? businessLogo}) async {
    try {
      // Create booking
      final docRef = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('bookings')
          .add(booking.toMap());

      // Add to customer's bookings (denormalized)
      if (booking.customerId.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(booking.customerId)
            .collection('my_bookings')
            .doc(docRef.id)
            .set(booking.toUserBooking(businessName ?? '', businessLogo));
      }

      // Update business stats
      await _updateBusinessStats(
        businessId,
        totalDelta: 1,
        pendingDelta: 1,
        todayDelta: 1,
        activeDelta: 1,
      );

      // Invalidate cache
      _invalidateBusinessCache(businessId);

      return docRef.id;
    } catch (e) {
      print('Error creating booking: $e');
      return null;
    }
  }

  /// Update booking status
  Future<bool> updateBookingStatus(
    String businessId,
    String bookingId,
    BookingStatus newStatus, {
    String? reason,
    double? earnings,
  }) async {
    try {
      // Get current booking for stats update
      final currentBooking = await getBooking(businessId, bookingId, forceRefresh: true);
      if (currentBooking == null) return false;

      final oldStatus = currentBooking.status;

      final updates = <String, dynamic>{
        'status': newStatus.name,
        'updatedAt': Timestamp.now(),
      };

      // Add completed timestamp
      if (newStatus == BookingStatus.completed) {
        updates['completedAt'] = Timestamp.now();
      }

      // Add cancellation reason
      if (newStatus == BookingStatus.cancelled && reason != null) {
        updates['cancellationReason'] = reason;
      }

      // Update booking
      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('bookings')
          .doc(bookingId)
          .update(updates);

      // Update customer's booking copy
      if (currentBooking.customerId.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(currentBooking.customerId)
            .collection('my_bookings')
            .doc(bookingId)
            .update({'status': newStatus.name});
      }

      // Update business stats based on status change
      await _handleStatusChange(businessId, oldStatus, newStatus, earnings ?? currentBooking.total);

      // Invalidate cache
      _invalidateBusinessCache(businessId);
      _singleBookingCache.remove('$businessId:$bookingId');

      return true;
    } catch (e) {
      print('Error updating booking status: $e');
      return false;
    }
  }

  /// Update booking details
  Future<bool> updateBooking(String businessId, String bookingId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('bookings')
          .doc(bookingId)
          .update(updates);

      // Invalidate cache
      _singleBookingCache.remove('$businessId:$bookingId');
      _invalidateBusinessCache(businessId);

      return true;
    } catch (e) {
      print('Error updating booking: $e');
      return false;
    }
  }

  /// Add business notes to booking
  Future<bool> addBusinessNotes(String businessId, String bookingId, String notes) async {
    return updateBooking(businessId, bookingId, {'businessNotes': notes});
  }

  /// Update payment status
  Future<bool> updatePaymentStatus(
    String businessId,
    String bookingId,
    PaymentStatus status, {
    String? paymentMethod,
  }) async {
    final updates = <String, dynamic>{
      'paymentStatus': status.name,
    };

    if (paymentMethod != null) {
      updates['paymentMethod'] = paymentMethod;
    }

    return updateBooking(businessId, bookingId, updates);
  }

  // === STATUS WORKFLOW ===

  /// Confirm a pending booking
  Future<bool> confirmBooking(String businessId, String bookingId) async {
    return updateBookingStatus(businessId, bookingId, BookingStatus.confirmed);
  }

  /// Start processing a booking
  Future<bool> startProcessing(String businessId, String bookingId) async {
    return updateBookingStatus(businessId, bookingId, BookingStatus.inProgress);
  }

  /// Complete a booking
  Future<bool> completeBooking(String businessId, String bookingId, {double? earnings}) async {
    return updateBookingStatus(businessId, bookingId, BookingStatus.completed, earnings: earnings);
  }

  /// Cancel a booking
  Future<bool> cancelBooking(String businessId, String bookingId, String reason) async {
    return updateBookingStatus(businessId, bookingId, BookingStatus.cancelled, reason: reason);
  }

  // === CUSTOMER BOOKINGS ===

  /// Get customer's bookings
  Future<List<Map<String, dynamic>>> getCustomerBookings(String customerId, {int limit = 20}) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(customerId)
        .collection('my_bookings')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  // === REAL-TIME STREAMS ===

  /// Watch new bookings in real-time
  Stream<List<BookingModel>> watchNewBookings(String businessId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('bookings')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => BookingModel.fromFirestore(doc)).toList());
  }

  /// Watch active bookings in real-time
  Stream<List<BookingModel>> watchActiveBookings(String businessId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('bookings')
        .where('status', whereIn: ['pending', 'confirmed', 'inProgress'])
        .orderBy('createdAt', descending: true)
        .limit(_pageSize)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => BookingModel.fromFirestore(doc)).toList());
  }

  /// Watch today's bookings count
  Stream<int> watchTodaysBookingCount(String businessId) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('bookings')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // === STATS & ANALYTICS ===

  /// Get booking stats for dashboard
  Future<Map<String, dynamic>> getBookingStats(String businessId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    // Run queries in parallel
    final results = await Future.wait([
      // Pending count
      _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('bookings')
          .where('status', isEqualTo: 'pending')
          .count()
          .get(),
      // Today's completed
      _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('bookings')
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .count()
          .get(),
      // Monthly completed
      _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('bookings')
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .count()
          .get(),
    ]);

    return {
      'pending': results[0].count ?? 0,
      'todayCompleted': results[1].count ?? 0,
      'monthlyCompleted': results[2].count ?? 0,
    };
  }

  /// Get bookings by date for calendar view
  Future<Map<DateTime, List<BookingModel>>> getBookingsByDate(
    String businessId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('bookings')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date')
        .limit(100) // Max for calendar view
        .get();

    final bookingsByDate = <DateTime, List<BookingModel>>{};

    for (final doc in snapshot.docs) {
      final booking = BookingModel.fromFirestore(doc);
      if (booking.date != null) {
        final dateKey = DateTime(booking.date!.year, booking.date!.month, booking.date!.day);
        bookingsByDate.putIfAbsent(dateKey, () => []).add(booking);
      }
    }

    return bookingsByDate;
  }

  // === HELPERS ===

  /// Handle status change for stats
  Future<void> _handleStatusChange(
    String businessId,
    BookingStatus oldStatus,
    BookingStatus newStatus,
    double amount,
  ) async {
    int pendingDelta = 0;
    int completedDelta = 0;
    int cancelledDelta = 0;
    int activeDelta = 0;
    double earningsDelta = 0;

    // Calculate deltas based on transition
    if (oldStatus == BookingStatus.pending && newStatus != BookingStatus.pending) {
      pendingDelta = -1;
    }

    if (newStatus == BookingStatus.completed && oldStatus != BookingStatus.completed) {
      completedDelta = 1;
      earningsDelta = amount;
      activeDelta = -1;
    }

    if (newStatus == BookingStatus.cancelled && oldStatus != BookingStatus.cancelled) {
      cancelledDelta = 1;
      activeDelta = -1;
    }

    await _updateBusinessStats(
      businessId,
      pendingDelta: pendingDelta,
      completedDelta: completedDelta,
      cancelledDelta: cancelledDelta,
      activeDelta: activeDelta,
      earningsDelta: earningsDelta,
    );
  }

  /// Update business stats
  Future<void> _updateBusinessStats(
    String businessId, {
    int totalDelta = 0,
    int pendingDelta = 0,
    int completedDelta = 0,
    int cancelledDelta = 0,
    int todayDelta = 0,
    int activeDelta = 0,
    double earningsDelta = 0,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (totalDelta != 0) updates['totalOrders'] = FieldValue.increment(totalDelta);
      if (pendingDelta != 0) updates['pendingOrders'] = FieldValue.increment(pendingDelta);
      if (completedDelta != 0) updates['completedOrders'] = FieldValue.increment(completedDelta);
      if (cancelledDelta != 0) updates['cancelledOrders'] = FieldValue.increment(cancelledDelta);
      if (todayDelta != 0) updates['todayOrders'] = FieldValue.increment(todayDelta);
      if (activeDelta != 0) updates['activeBookings'] = FieldValue.increment(activeDelta);
      if (earningsDelta != 0) {
        updates['totalEarnings'] = FieldValue.increment(earningsDelta);
        updates['monthlyEarnings'] = FieldValue.increment(earningsDelta);
        updates['todayEarnings'] = FieldValue.increment(earningsDelta);
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('businesses').doc(businessId).update(updates);
      }
    } catch (e) {
      print('Error updating business stats: $e');
    }
  }

  /// Invalidate all cache for a business
  void _invalidateBusinessCache(String businessId) {
    _bookingsCache.removeWhere((key, _) => key.startsWith('$businessId:'));
    _singleBookingCache.removeWhere((key, _) => key.startsWith('$businessId:'));
  }

  /// Clear all cache
  void clearCache() {
    _bookingsCache.clear();
    _singleBookingCache.clear();
  }

  /// Get booking count by status
  Future<Map<String, int>> getBookingCountsByStatus(String businessId) async {
    final results = await Future.wait([
      _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('bookings')
          .where('status', isEqualTo: 'pending')
          .count()
          .get(),
      _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('bookings')
          .where('status', isEqualTo: 'confirmed')
          .count()
          .get(),
      _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('bookings')
          .where('status', isEqualTo: 'inProgress')
          .count()
          .get(),
      _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('bookings')
          .where('status', isEqualTo: 'completed')
          .count()
          .get(),
      _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('bookings')
          .where('status', isEqualTo: 'cancelled')
          .count()
          .get(),
    ]);

    return {
      'pending': results[0].count ?? 0,
      'confirmed': results[1].count ?? 0,
      'inProgress': results[2].count ?? 0,
      'completed': results[3].count ?? 0,
      'cancelled': results[4].count ?? 0,
    };
  }
}

/// Cache data wrapper with TTL
class _CachedData<T> {
  final T data;
  final int timestamp;

  _CachedData(this.data) : timestamp = DateTime.now().millisecondsSinceEpoch;

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch - timestamp > BookingService._cacheTTL;
}
