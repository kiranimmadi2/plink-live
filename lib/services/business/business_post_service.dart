import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/business_post_model.dart';
import 'business_profile_service.dart';

/// Service for managing business posts
/// Handles creating, updating, deleting, and streaming business posts
class BusinessPostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BusinessProfileService _profileService = BusinessProfileService();

  // Singleton pattern
  static final BusinessPostService _instance = BusinessPostService._internal();
  factory BusinessPostService() => _instance;
  BusinessPostService._internal();

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Create a new post
  Future<String?> createPost(BusinessPost post) async {
    if (_currentUserId == null) return null;

    try {
      final docRef = await _firestore
          .collection('business_posts')
          .add(post.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating post: $e');
      return null;
    }
  }

  /// Update post
  Future<bool> updatePost(String postId, BusinessPost post) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(post.businessId)) {
        debugPrint('Unauthorized: Cannot update post for business you do not own');
        return false;
      }

      await _firestore
          .collection('business_posts')
          .doc(postId)
          .update(post.copyWith(updatedAt: DateTime.now()).toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating post: $e');
      return false;
    }
  }

  /// Delete post
  Future<bool> deletePost(String businessId, String postId) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot delete post for business you do not own');
        return false;
      }

      await _firestore.collection('business_posts').doc(postId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting post: $e');
      return false;
    }
  }

  /// Toggle post active status
  Future<bool> togglePostActive(String businessId, String postId, bool isActive) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot toggle post for business you do not own');
        return false;
      }

      await _firestore.collection('business_posts').doc(postId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error toggling post: $e');
      return false;
    }
  }

  /// Get posts for a business
  Future<List<BusinessPost>> getBusinessPosts(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('business_posts')
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => BusinessPost.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting posts: $e');
      return [];
    }
  }

  /// Stream posts for a business
  Stream<List<BusinessPost>> watchBusinessPosts(String businessId) {
    return _firestore
        .collection('business_posts')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BusinessPost.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get a single post by ID
  Future<BusinessPost?> getPost(String postId) async {
    try {
      final doc = await _firestore.collection('business_posts').doc(postId).get();
      if (!doc.exists) return null;
      return BusinessPost.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting post: $e');
      return null;
    }
  }

  /// Increment post view count
  Future<void> incrementViewCount(String postId) async {
    try {
      await _firestore.collection('business_posts').doc(postId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing post views: $e');
    }
  }

  /// Like a post
  Future<bool> likePost(String postId) async {
    if (_currentUserId == null) return false;

    try {
      await _firestore.collection('business_posts').doc(postId).update({
        'likes': FieldValue.increment(1),
      });
      return true;
    } catch (e) {
      debugPrint('Error liking post: $e');
      return false;
    }
  }

  /// Share a post
  Future<bool> sharePost(String postId) async {
    try {
      await _firestore.collection('business_posts').doc(postId).update({
        'shares': FieldValue.increment(1),
      });
      return true;
    } catch (e) {
      debugPrint('Error sharing post: $e');
      return false;
    }
  }

  /// Pin a post
  Future<bool> pinPost(String businessId, String postId, bool isPinned) async {
    if (_currentUserId == null) return false;

    try {
      if (!await _profileService.isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot pin post for business you do not own');
        return false;
      }

      await _firestore.collection('business_posts').doc(postId).update({
        'isPinned': isPinned,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error pinning post: $e');
      return false;
    }
  }

  /// Get active promotions for a business
  Future<List<BusinessPost>> getActivePromotions(String businessId) async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('business_posts')
          .where('businessId', isEqualTo: businessId)
          .where('type', isEqualTo: 'promotion')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => BusinessPost.fromFirestore(doc))
          .where((post) {
            // Filter by valid date range
            if (post.validFrom != null && now.isBefore(post.validFrom!)) return false;
            if (post.validUntil != null && now.isAfter(post.validUntil!)) return false;
            return true;
          })
          .toList();
    } catch (e) {
      debugPrint('Error getting active promotions: $e');
      return [];
    }
  }

  /// Get posts by type
  Future<List<BusinessPost>> getPostsByType(String businessId, PostType type) async {
    try {
      final snapshot = await _firestore
          .collection('business_posts')
          .where('businessId', isEqualTo: businessId)
          .where('type', isEqualTo: type.name)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => BusinessPost.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting posts by type: $e');
      return [];
    }
  }
}
