import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Real-time presence tracking service
/// Manages user online/offline status and last seen timestamps
class PresenceService {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _heartbeatTimer;
  bool _isInitialized = false;

  /// Initialize presence tracking
  Future<void> initialize() async {
    if (_isInitialized) return;

    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // Set user online
      await setOnline();

      // Start heartbeat (update every 30 seconds)
      _startHeartbeat();

      // Listen for app lifecycle changes
      _setupLifecycleListener();

      _isInitialized = true;
      debugPrint('PresenceService initialized');
    } catch (e) {
      debugPrint(' Error initializing PresenceService: $e');
    }
  }

  /// Set user as online
  Future<void> setOnline() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      debugPrint(' User set to online');
    } catch (e) {
      debugPrint(' Error setting user online: $e');
    }
  }

  /// Set user as offline
  Future<void> setOffline() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      debugPrint(' User set to offline');
    } catch (e) {
      debugPrint(' Error setting user offline: $e');
    }
  }

  /// Start heartbeat to keep user online
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateHeartbeat();
    });
  }

  /// Update heartbeat timestamp
  Future<void> _updateHeartbeat() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      });
    } catch (e) {
      debugPrint(' Heartbeat update failed: $e');
    }
  }

  /// Setup lifecycle listener for app state changes
  void _setupLifecycleListener() {
    // Note: This would require WidgetsBindingObserver in the actual implementation
    // For now, we'll handle it through manual calls in the app lifecycle
  }

  /// Get online status stream for a user
  Stream<bool> getOnlineStatusStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      final isOnline = data['isOnline'] ?? false;
      final lastSeen = data['lastSeen'] as Timestamp?;

      // Consider user offline if last seen was more than 2 minutes ago
      if (lastSeen != null) {
        final lastSeenTime = lastSeen.toDate();
        final difference = DateTime.now().difference(lastSeenTime);
        if (difference.inMinutes > 2) {
          return false;
        }
      }

      return isOnline;
    });
  }

  /// Check if user was recently active (within last 5 minutes)
  Future<bool> isRecentlyActive(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      final lastSeen = data['lastSeen'] as Timestamp?;
      if (lastSeen == null) return false;

      final difference = DateTime.now().difference(lastSeen.toDate());
      return difference.inMinutes <= 5;
    } catch (e) {
      return false;
    }
  }

  /// Dispose and cleanup
  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    await setOffline();
    _isInitialized = false;
  }
}
