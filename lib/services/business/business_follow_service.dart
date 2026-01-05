import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for managing business follow/unfollow operations
/// Handles following businesses and tracking follower counts
class BusinessFollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final BusinessFollowService _instance = BusinessFollowService._internal();
  factory BusinessFollowService() => _instance;
  BusinessFollowService._internal();

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Follow a business
  Future<bool> followBusiness(String businessId) async {
    if (_currentUserId == null) return false;

    try {
      // Check if already following
      if (await isFollowing(businessId)) {
        debugPrint('Already following this business');
        return true;
      }

      await _firestore.collection('business_followers').add({
        'businessId': businessId,
        'userId': _currentUserId,
        'followedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('businesses').doc(businessId).update({
        'followerCount': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      debugPrint('Error following business: $e');
      return false;
    }
  }

  /// Unfollow a business
  Future<bool> unfollowBusiness(String businessId) async {
    if (_currentUserId == null) return false;

    try {
      final snapshot = await _firestore
          .collection('business_followers')
          .where('businessId', isEqualTo: businessId)
          .where('userId', isEqualTo: _currentUserId)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      await _firestore.collection('businesses').doc(businessId).update({
        'followerCount': FieldValue.increment(-1),
      });

      return true;
    } catch (e) {
      debugPrint('Error unfollowing business: $e');
      return false;
    }
  }

  /// Check if user follows a business
  Future<bool> isFollowing(String businessId) async {
    if (_currentUserId == null) return false;

    try {
      final snapshot = await _firestore
          .collection('business_followers')
          .where('businessId', isEqualTo: businessId)
          .where('userId', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Toggle follow status
  Future<bool> toggleFollow(String businessId) async {
    if (await isFollowing(businessId)) {
      return unfollowBusiness(businessId);
    } else {
      return followBusiness(businessId);
    }
  }

  /// Get list of businesses user is following
  Future<List<String>> getFollowedBusinessIds() async {
    if (_currentUserId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('business_followers')
          .where('userId', isEqualTo: _currentUserId)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['businessId'] as String)
          .toList();
    } catch (e) {
      debugPrint('Error getting followed businesses: $e');
      return [];
    }
  }

  /// Stream follow status for a business
  Stream<bool> watchFollowStatus(String businessId) {
    if (_currentUserId == null) {
      return Stream.value(false);
    }

    return _firestore
        .collection('business_followers')
        .where('businessId', isEqualTo: businessId)
        .where('userId', isEqualTo: _currentUserId)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  /// Get follower count for a business
  Future<int> getFollowerCount(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('business_followers')
          .where('businessId', isEqualTo: businessId)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting follower count: $e');
      return 0;
    }
  }

  /// Get list of followers for a business (for business owners)
  Future<List<Map<String, dynamic>>> getBusinessFollowers(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('business_followers')
          .where('businessId', isEqualTo: businessId)
          .orderBy('followedAt', descending: true)
          .limit(100)
          .get();

      final followers = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final userId = doc.data()['userId'] as String;
        final userDoc = await _firestore.collection('users').doc(userId).get();

        if (userDoc.exists) {
          followers.add({
            'userId': userId,
            'followedAt': (doc.data()['followedAt'] as Timestamp?)?.toDate(),
            'user': userDoc.data(),
          });
        }
      }

      return followers;
    } catch (e) {
      debugPrint('Error getting business followers: $e');
      return [];
    }
  }
}
