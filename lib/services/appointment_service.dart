import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart';

/// Service for managing appointments for service-based businesses
class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final AppointmentService _instance = AppointmentService._internal();
  factory AppointmentService() => _instance;
  AppointmentService._internal();

  String? get _currentUserId => _auth.currentUser?.uid;

  // Collection references
  CollectionReference<Map<String, dynamic>> _appointmentsCollection(String businessId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('appointments');
  }

  // ============================================================
  // CRUD OPERATIONS
  // ============================================================

  /// Create a new appointment
  Future<String?> createAppointment(AppointmentModel appointment) async {
    try {
      // Check for conflicts before creating
      final hasConflict = await _checkForConflicts(
        businessId: appointment.businessId,
        date: appointment.appointmentDate,
        startTime: appointment.startTime,
        endTime: appointment.endTime,
        staffId: appointment.staffId,
      );

      if (hasConflict) {
        debugPrint('Appointment conflict detected');
        return null;
      }

      final docRef = await _appointmentsCollection(appointment.businessId).add(
        appointment.toMap(),
      );

      // Update business appointment count
      await _firestore.collection('businesses').doc(appointment.businessId).update({
        'pendingAppointments': FieldValue.increment(1),
        'totalAppointments': FieldValue.increment(1),
      });

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating appointment: $e');
      return null;
    }
  }

  /// Get appointment by ID
  Future<AppointmentModel?> getAppointment(String businessId, String appointmentId) async {
    try {
      final doc = await _appointmentsCollection(businessId).doc(appointmentId).get();
      if (!doc.exists) return null;
      return AppointmentModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting appointment: $e');
      return null;
    }
  }

  /// Update appointment
  Future<bool> updateAppointment(
    String businessId,
    String appointmentId,
    AppointmentModel appointment,
  ) async {
    try {
      // Check for conflicts if time changed
      final existingAppointment = await getAppointment(businessId, appointmentId);
      if (existingAppointment != null &&
          (existingAppointment.startTime != appointment.startTime ||
              existingAppointment.endTime != appointment.endTime ||
              existingAppointment.appointmentDate != appointment.appointmentDate)) {
        final hasConflict = await _checkForConflicts(
          businessId: businessId,
          date: appointment.appointmentDate,
          startTime: appointment.startTime,
          endTime: appointment.endTime,
          staffId: appointment.staffId,
          excludeAppointmentId: appointmentId,
        );

        if (hasConflict) {
          debugPrint('Appointment conflict detected');
          return false;
        }
      }

      await _appointmentsCollection(businessId).doc(appointmentId).update(
        appointment.copyWith(updatedAt: DateTime.now()).toMap(),
      );
      return true;
    } catch (e) {
      debugPrint('Error updating appointment: $e');
      return false;
    }
  }

  /// Delete appointment
  Future<bool> deleteAppointment(String businessId, String appointmentId) async {
    try {
      final appointment = await getAppointment(businessId, appointmentId);
      if (appointment == null) return false;

      await _appointmentsCollection(businessId).doc(appointmentId).delete();

      // Update business counts
      final updates = <String, dynamic>{};
      if (appointment.status == AppointmentStatus.pending ||
          appointment.status == AppointmentStatus.confirmed) {
        updates['pendingAppointments'] = FieldValue.increment(-1);
      }
      updates['totalAppointments'] = FieldValue.increment(-1);

      if (updates.isNotEmpty) {
        await _firestore.collection('businesses').doc(businessId).update(updates);
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting appointment: $e');
      return false;
    }
  }

  // ============================================================
  // STATUS UPDATES
  // ============================================================

  /// Update appointment status
  Future<bool> updateAppointmentStatus(
    String businessId,
    String appointmentId,
    AppointmentStatus newStatus, {
    String? cancellationReason,
    String? cancelledBy,
  }) async {
    try {
      final appointment = await getAppointment(businessId, appointmentId);
      if (appointment == null) return false;

      final oldStatus = appointment.status;
      final updateData = <String, dynamic>{
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == AppointmentStatus.cancelled) {
        updateData['cancellationReason'] = cancellationReason;
        updateData['cancelledBy'] = cancelledBy ?? 'business';
      }

      await _appointmentsCollection(businessId).doc(appointmentId).update(updateData);

      // Update business counts
      final businessUpdates = <String, dynamic>{};

      // Decrement old status count
      if (oldStatus == AppointmentStatus.pending ||
          oldStatus == AppointmentStatus.confirmed) {
        businessUpdates['pendingAppointments'] = FieldValue.increment(-1);
      }

      // Increment new status count
      if (newStatus == AppointmentStatus.completed) {
        businessUpdates['completedAppointments'] = FieldValue.increment(1);
        if (appointment.price != null) {
          businessUpdates['todayEarnings'] = FieldValue.increment(appointment.price!);
        }
      } else if (newStatus == AppointmentStatus.cancelled) {
        businessUpdates['cancelledAppointments'] = FieldValue.increment(1);
      } else if (newStatus == AppointmentStatus.noShow) {
        businessUpdates['noShowAppointments'] = FieldValue.increment(1);
      }

      if (businessUpdates.isNotEmpty) {
        await _firestore.collection('businesses').doc(businessId).update(businessUpdates);
      }

      return true;
    } catch (e) {
      debugPrint('Error updating appointment status: $e');
      return false;
    }
  }

  /// Confirm appointment
  Future<bool> confirmAppointment(String businessId, String appointmentId) async {
    return updateAppointmentStatus(businessId, appointmentId, AppointmentStatus.confirmed);
  }

  /// Start appointment (mark as in progress)
  Future<bool> startAppointment(String businessId, String appointmentId) async {
    return updateAppointmentStatus(businessId, appointmentId, AppointmentStatus.inProgress);
  }

  /// Complete appointment
  Future<bool> completeAppointment(String businessId, String appointmentId) async {
    return updateAppointmentStatus(businessId, appointmentId, AppointmentStatus.completed);
  }

  /// Cancel appointment
  Future<bool> cancelAppointment(
    String businessId,
    String appointmentId, {
    String? reason,
    String? cancelledBy,
  }) async {
    return updateAppointmentStatus(
      businessId,
      appointmentId,
      AppointmentStatus.cancelled,
      cancellationReason: reason,
      cancelledBy: cancelledBy,
    );
  }

  /// Mark as no-show
  Future<bool> markAsNoShow(String businessId, String appointmentId) async {
    return updateAppointmentStatus(businessId, appointmentId, AppointmentStatus.noShow);
  }

  // ============================================================
  // QUERY METHODS
  // ============================================================

  /// Get appointments by date
  Future<List<AppointmentModel>> getAppointmentsByDate(
    String businessId,
    DateTime date,
  ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await _appointmentsCollection(businessId)
          .where('appointmentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('appointmentDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('appointmentDate')
          .orderBy('startTime')
          .get();

      return snapshot.docs
          .map((doc) => AppointmentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting appointments by date: $e');
      return [];
    }
  }

  /// Get appointments by customer
  Future<List<AppointmentModel>> getAppointmentsByCustomer(
    String businessId,
    String customerId,
  ) async {
    try {
      final snapshot = await _appointmentsCollection(businessId)
          .where('customerId', isEqualTo: customerId)
          .orderBy('appointmentDate', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => AppointmentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting appointments by customer: $e');
      return [];
    }
  }

  /// Get appointments by status
  Future<List<AppointmentModel>> getAppointmentsByStatus(
    String businessId,
    AppointmentStatus status, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _appointmentsCollection(businessId)
          .where('status', isEqualTo: status.name)
          .orderBy('appointmentDate', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => AppointmentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting appointments by status: $e');
      return [];
    }
  }

  /// Get upcoming appointments
  Future<List<AppointmentModel>> getUpcomingAppointments(
    String businessId, {
    int limit = 20,
  }) async {
    try {
      final now = DateTime.now();
      final snapshot = await _appointmentsCollection(businessId)
          .where('appointmentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('status', whereIn: ['pending', 'confirmed'])
          .orderBy('appointmentDate')
          .orderBy('startTime')
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => AppointmentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting upcoming appointments: $e');
      return [];
    }
  }

  /// Get today's appointments
  Future<List<AppointmentModel>> getTodayAppointments(String businessId) async {
    return getAppointmentsByDate(businessId, DateTime.now());
  }

  // ============================================================
  // STREAM METHODS
  // ============================================================

  /// Stream appointments for a business
  Stream<List<AppointmentModel>> watchAppointments(
    String businessId, {
    AppointmentStatus? status,
  }) {
    Query<Map<String, dynamic>> query = _appointmentsCollection(businessId)
        .orderBy('appointmentDate', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    return query.limit(100).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => AppointmentModel.fromFirestore(doc)).toList());
  }

  /// Stream appointments by date
  Stream<List<AppointmentModel>> watchAppointmentsByDate(
    String businessId,
    DateTime date,
  ) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _appointmentsCollection(businessId)
        .where('appointmentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('appointmentDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('appointmentDate')
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AppointmentModel.fromFirestore(doc)).toList());
  }

  /// Stream today's appointments
  Stream<List<AppointmentModel>> watchTodayAppointments(String businessId) {
    return watchAppointmentsByDate(businessId, DateTime.now());
  }

  // ============================================================
  // AVAILABILITY & TIME SLOTS
  // ============================================================

  /// Get available time slots for a date
  Future<List<TimeSlot>> getAvailableSlots(
    String businessId,
    DateTime date, {
    int slotDurationMinutes = 30,
    String? staffId,
    String startHour = '09:00',
    String endHour = '18:00',
  }) async {
    try {
      // Get existing appointments for the date
      final existingAppointments = await getAppointmentsByDate(businessId, date);

      // Filter by staff if specified
      final filteredAppointments = staffId != null
          ? existingAppointments.where((a) => a.staffId == staffId).toList()
          : existingAppointments;

      // Generate all possible slots
      final allSlots = _generateTimeSlots(startHour, endHour, slotDurationMinutes);

      // Mark booked slots
      return allSlots.map((slot) {
        final isBooked = filteredAppointments.any((apt) =>
            _timeSlotsOverlap(
              slot.startTime,
              slot.endTime,
              apt.startTime,
              apt.endTime,
            ) &&
            apt.status != AppointmentStatus.cancelled);

        return slot.copyWith(
          isAvailable: !isBooked,
          appointmentId: isBooked
              ? filteredAppointments
                  .firstWhere((apt) =>
                      _timeSlotsOverlap(
                        slot.startTime,
                        slot.endTime,
                        apt.startTime,
                        apt.endTime,
                      ) &&
                      apt.status != AppointmentStatus.cancelled)
                  .id
              : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting available slots: $e');
      return [];
    }
  }

  /// Generate time slots for a day
  List<TimeSlot> _generateTimeSlots(String startHour, String endHour, int durationMinutes) {
    final slots = <TimeSlot>[];
    final startMinutes = _parseTimeToMinutes(startHour);
    final endMinutes = _parseTimeToMinutes(endHour);

    if (startMinutes == null || endMinutes == null) return slots;

    int currentMinutes = startMinutes;
    while (currentMinutes + durationMinutes <= endMinutes) {
      slots.add(TimeSlot(
        startTime: _minutesToTimeString(currentMinutes),
        endTime: _minutesToTimeString(currentMinutes + durationMinutes),
        isAvailable: true,
      ));
      currentMinutes += durationMinutes;
    }

    return slots;
  }

  int? _parseTimeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    if (hours == null || minutes == null) return null;
    return hours * 60 + minutes;
  }

  String _minutesToTimeString(int minutes) {
    final hours = (minutes ~/ 60).toString().padLeft(2, '0');
    final mins = (minutes % 60).toString().padLeft(2, '0');
    return '$hours:$mins';
  }

  /// Check if two time slots overlap
  bool _timeSlotsOverlap(String start1, String end1, String start2, String end2) {
    final s1 = _parseTimeToMinutes(start1);
    final e1 = _parseTimeToMinutes(end1);
    final s2 = _parseTimeToMinutes(start2);
    final e2 = _parseTimeToMinutes(end2);

    if (s1 == null || e1 == null || s2 == null || e2 == null) return false;

    // Two intervals overlap if one starts before the other ends
    return s1 < e2 && s2 < e1;
  }

  /// Check for appointment conflicts
  Future<bool> _checkForConflicts({
    required String businessId,
    required DateTime date,
    required String startTime,
    required String endTime,
    String? staffId,
    String? excludeAppointmentId,
  }) async {
    try {
      final existingAppointments = await getAppointmentsByDate(businessId, date);

      for (final appointment in existingAppointments) {
        // Skip cancelled appointments
        if (appointment.status == AppointmentStatus.cancelled) continue;

        // Skip the appointment being updated
        if (excludeAppointmentId != null && appointment.id == excludeAppointmentId) continue;

        // If staff is specified, only check same staff
        if (staffId != null && appointment.staffId != staffId) continue;

        // Check for time overlap
        if (_timeSlotsOverlap(startTime, endTime, appointment.startTime, appointment.endTime)) {
          return true; // Conflict found
        }
      }

      return false; // No conflict
    } catch (e) {
      debugPrint('Error checking for conflicts: $e');
      return false;
    }
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  /// Get appointment statistics for a business
  Future<Map<String, dynamic>> getAppointmentStats(String businessId) async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);

      // Get all appointments
      final snapshot = await _appointmentsCollection(businessId).get();
      final appointments = snapshot.docs
          .map((doc) => AppointmentModel.fromFirestore(doc))
          .toList();

      // Calculate stats
      final todayAppointments = appointments
          .where((a) => a.appointmentDate.isAfter(startOfToday))
          .length;

      final weekAppointments = appointments
          .where((a) => a.appointmentDate.isAfter(startOfWeek))
          .length;

      final monthAppointments = appointments
          .where((a) => a.appointmentDate.isAfter(startOfMonth))
          .length;

      final pendingCount = appointments
          .where((a) => a.status == AppointmentStatus.pending)
          .length;

      final confirmedCount = appointments
          .where((a) => a.status == AppointmentStatus.confirmed)
          .length;

      final completedCount = appointments
          .where((a) => a.status == AppointmentStatus.completed)
          .length;

      final cancelledCount = appointments
          .where((a) => a.status == AppointmentStatus.cancelled)
          .length;

      final noShowCount = appointments
          .where((a) => a.status == AppointmentStatus.noShow)
          .length;

      // Calculate revenue
      final completedRevenue = appointments
          .where((a) => a.status == AppointmentStatus.completed && a.price != null)
          .fold<double>(0, (sum, a) => sum + (a.price ?? 0));

      return {
        'total': appointments.length,
        'today': todayAppointments,
        'thisWeek': weekAppointments,
        'thisMonth': monthAppointments,
        'pending': pendingCount,
        'confirmed': confirmedCount,
        'completed': completedCount,
        'cancelled': cancelledCount,
        'noShow': noShowCount,
        'completedRevenue': completedRevenue,
      };
    } catch (e) {
      debugPrint('Error getting appointment stats: $e');
      return {
        'total': 0,
        'today': 0,
        'thisWeek': 0,
        'thisMonth': 0,
        'pending': 0,
        'confirmed': 0,
        'completed': 0,
        'cancelled': 0,
        'noShow': 0,
        'completedRevenue': 0.0,
      };
    }
  }

  /// Get dates with appointments in a month
  Future<List<DateTime>> getAppointmentDatesInMonth(
    String businessId,
    int year,
    int month,
  ) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

      final snapshot = await _appointmentsCollection(businessId)
          .where('appointmentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('appointmentDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      final dates = <DateTime>{};
      for (final doc in snapshot.docs) {
        final appointment = AppointmentModel.fromFirestore(doc);
        dates.add(DateTime(
          appointment.appointmentDate.year,
          appointment.appointmentDate.month,
          appointment.appointmentDate.day,
        ));
      }

      return dates.toList()..sort();
    } catch (e) {
      debugPrint('Error getting appointment dates: $e');
      return [];
    }
  }

  // ============================================================
  // CUSTOMER MANAGEMENT
  // ============================================================

  /// Get customer's appointment history
  Future<List<AppointmentModel>> getCustomerHistory(
    String businessId,
    String customerId, {
    int limit = 20,
  }) async {
    try {
      final snapshot = await _appointmentsCollection(businessId)
          .where('customerId', isEqualTo: customerId)
          .orderBy('appointmentDate', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => AppointmentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting customer history: $e');
      return [];
    }
  }

  /// Search appointments by customer name or phone
  Future<List<AppointmentModel>> searchAppointments(
    String businessId,
    String query, {
    int limit = 20,
  }) async {
    try {
      // Search by customer name (prefix match)
      final snapshot = await _appointmentsCollection(businessId)
          .orderBy('customerName')
          .startAt([query])
          .endAt([query + '\uf8ff'])
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => AppointmentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error searching appointments: $e');
      return [];
    }
  }
}
