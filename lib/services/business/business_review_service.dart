import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/business_model.dart';

/// Service for managing business reviews
/// Handles adding reviews, replying to reviews, and calculating ratings
class BusinessReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final BusinessReviewService _instance = BusinessReviewService._internal();
  factory BusinessReviewService() => _instance;
  BusinessReviewService._internal();

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Add a review
  Future<String?> addReview(BusinessReview review) async {
    if (_currentUserId == null) return null;

    try {
      final docRef = await _firestore
          .collection('business_reviews')
          .add(review.toMap());

      // Update business rating
      await _updateBusinessRating(review.businessId);

      return docRef.id;
    } catch (e) {
      debugPrint('Error adding review: $e');
      return null;
    }
  }

  /// Reply to a review
  Future<bool> replyToReview(String reviewId, String reply) async {
    try {
      await _firestore.collection('business_reviews').doc(reviewId).update({
        'reply': reply,
        'replyAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error replying to review: $e');
      return false;
    }
  }

  /// Get reviews for a business
  Future<List<BusinessReview>> getBusinessReviews(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('business_reviews')
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => BusinessReview.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting reviews: $e');
      return [];
    }
  }

  /// Stream reviews for a business
  Stream<List<BusinessReview>> watchBusinessReviews(String businessId) {
    return _firestore
        .collection('business_reviews')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BusinessReview.fromFirestore(doc))
              .toList(),
        );
  }

  /// Update business rating based on reviews
  Future<void> _updateBusinessRating(String businessId) async {
    try {
      final reviews = await getBusinessReviews(businessId);
      if (reviews.isEmpty) return;

      final totalRating = reviews.fold<double>(
        0,
        (total, r) => total + r.rating,
      );
      final avgRating = totalRating / reviews.length;

      await _firestore.collection('businesses').doc(businessId).update({
        'rating': avgRating,
        'reviewCount': reviews.length,
      });
    } catch (e) {
      debugPrint('Error updating rating: $e');
    }
  }

  /// Delete a review
  Future<bool> deleteReview(String businessId, String reviewId) async {
    if (_currentUserId == null) return false;

    try {
      // Get the review to check ownership
      final reviewDoc = await _firestore.collection('business_reviews').doc(reviewId).get();
      if (!reviewDoc.exists) return false;

      final reviewData = reviewDoc.data()!;
      if (reviewData['userId'] != _currentUserId) {
        debugPrint('Unauthorized: Cannot delete review you did not create');
        return false;
      }

      await _firestore.collection('business_reviews').doc(reviewId).delete();

      // Update business rating
      await _updateBusinessRating(businessId);

      return true;
    } catch (e) {
      debugPrint('Error deleting review: $e');
      return false;
    }
  }

  /// Check if current user has reviewed a business
  Future<bool> hasUserReviewed(String businessId) async {
    if (_currentUserId == null) return false;

    try {
      final snapshot = await _firestore
          .collection('business_reviews')
          .where('businessId', isEqualTo: businessId)
          .where('userId', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking user review: $e');
      return false;
    }
  }

  /// Get user's review for a business
  Future<BusinessReview?> getUserReview(String businessId) async {
    if (_currentUserId == null) return null;

    try {
      final snapshot = await _firestore
          .collection('business_reviews')
          .where('businessId', isEqualTo: businessId)
          .where('userId', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return BusinessReview.fromFirestore(snapshot.docs.first);
    } catch (e) {
      debugPrint('Error getting user review: $e');
      return null;
    }
  }

  /// Update an existing review
  Future<bool> updateReview(String reviewId, double rating, String? comment) async {
    if (_currentUserId == null) return false;

    try {
      // Get the review to check ownership
      final reviewDoc = await _firestore.collection('business_reviews').doc(reviewId).get();
      if (!reviewDoc.exists) return false;

      final reviewData = reviewDoc.data()!;
      if (reviewData['userId'] != _currentUserId) {
        debugPrint('Unauthorized: Cannot update review you did not create');
        return false;
      }

      await _firestore.collection('business_reviews').doc(reviewId).update({
        'rating': rating,
        'comment': comment,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update business rating
      await _updateBusinessRating(reviewData['businessId']);

      return true;
    } catch (e) {
      debugPrint('Error updating review: $e');
      return false;
    }
  }
}
