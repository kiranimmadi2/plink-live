import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/business_model.dart';

/// Service for managing business profiles
/// Handles CRUD operations for business profiles and related user flags
class BusinessProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final BusinessProfileService _instance = BusinessProfileService._internal();
  factory BusinessProfileService() => _instance;
  BusinessProfileService._internal();

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Check if current user owns the business
  Future<bool> isBusinessOwner(String businessId) async {
    if (_currentUserId == null) return false;
    try {
      final doc = await _firestore.collection('businesses').doc(businessId).get();
      if (!doc.exists) return false;
      return doc.data()?['userId'] == _currentUserId;
    } catch (e) {
      debugPrint('Error checking business ownership: $e');
      return false;
    }
  }

  /// Verify ownership and throw if unauthorized
  Future<void> verifyOwnership(String businessId) async {
    if (!await isBusinessOwner(businessId)) {
      throw Exception('Unauthorized: You do not own this business');
    }
  }

  /// Create a new business profile
  Future<String?> createBusiness(BusinessModel business) async {
    if (_currentUserId == null) return null;

    try {
      final docRef = await _firestore
          .collection('businesses')
          .add(
            business
                .copyWith(
                  userId: _currentUserId,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                )
                .toMap(),
          );

      // Update user's business flag
      await _firestore.collection('users').doc(_currentUserId).update({
        'businessId': docRef.id,
        'businessSetupComplete': true,
      });

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating business: $e');
      return null;
    }
  }

  /// Update business profile
  Future<bool> updateBusiness(String businessId, BusinessModel business) async {
    if (_currentUserId == null) return false;

    try {
      // Verify ownership before update
      if (!await isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot update business you do not own');
        return false;
      }

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .update(business.copyWith(updatedAt: DateTime.now()).toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating business: $e');
      return false;
    }
  }

  /// Get business by ID
  Future<BusinessModel?> getBusiness(String businessId) async {
    try {
      final doc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .get();
      if (!doc.exists) return null;
      return BusinessModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting business: $e');
      return null;
    }
  }

  /// Get current user's business
  Future<BusinessModel?> getMyBusiness() async {
    if (_currentUserId == null) return null;

    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('userId', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return BusinessModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      debugPrint('Error getting my business: $e');
      return null;
    }
  }

  /// Stream current user's business
  Stream<BusinessModel?> watchMyBusiness() {
    if (_currentUserId == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection('businesses')
        .where('userId', isEqualTo: _currentUserId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return BusinessModel.fromFirestore(snapshot.docs.first);
        });
  }

  /// Check if business setup is complete
  Future<bool> isBusinessSetupComplete() async {
    if (_currentUserId == null) return false;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .get();
      return doc.data()?['businessSetupComplete'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Delete business with full cascade delete of all related data
  Future<bool> deleteBusiness(String businessId) async {
    if (_currentUserId == null) return false;

    try {
      // Verify ownership before delete
      if (!await isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot delete business you do not own');
        return false;
      }

      final businessRef = _firestore.collection('businesses').doc(businessId);

      // Helper function to delete subcollection documents
      Future<void> deleteSubcollection(String subcollectionName) async {
        final docs = await businessRef
            .collection(subcollectionName)
            .limit(500)
            .get();
        for (final doc in docs.docs) {
          await doc.reference.delete();
        }
      }

      // Helper function to delete top-level collection documents by businessId
      Future<void> deleteRelatedCollection(String collectionName) async {
        final docs = await _firestore
            .collection(collectionName)
            .where('businessId', isEqualTo: businessId)
            .limit(500)
            .get();
        for (final doc in docs.docs) {
          await doc.reference.delete();
        }
      }

      // Delete all subcollections under businesses/{businessId}
      await deleteSubcollection('rooms');
      await deleteSubcollection('menu_categories');
      await deleteSubcollection('menu_items');
      await deleteSubcollection('product_categories');
      await deleteSubcollection('products');
      await deleteSubcollection('appointments');

      // Delete related top-level collections
      await deleteRelatedCollection('business_listings');
      await deleteRelatedCollection('business_posts');
      await deleteRelatedCollection('business_orders');
      await deleteRelatedCollection('business_reviews');
      await deleteRelatedCollection('business_followers');

      // Delete the business document itself
      await businessRef.delete();

      // Update user document
      await _firestore.collection('users').doc(_currentUserId).update({
        'businessId': FieldValue.delete(),
        'businessSetupComplete': false,
      });

      return true;
    } catch (e) {
      debugPrint('Error deleting business: $e');
      return false;
    }
  }

  /// Update business online status
  Future<bool> updateOnlineStatus(String businessId, bool isOnline) async {
    if (_currentUserId == null) return false;

    try {
      if (!await isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot update online status for business you do not own');
        return false;
      }

      await _firestore.collection('businesses').doc(businessId).update({
        'isOnline': isOnline,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating online status: $e');
      return false;
    }
  }

  /// Update bank account details
  Future<bool> updateBankAccount(String businessId, BankAccount bankAccount) async {
    if (_currentUserId == null) return false;

    try {
      if (!await isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot update bank account for business you do not own');
        return false;
      }

      await _firestore.collection('businesses').doc(businessId).update({
        'bankAccount': bankAccount.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating bank account: $e');
      return false;
    }
  }

  /// Remove bank account
  Future<bool> removeBankAccount(String businessId) async {
    if (_currentUserId == null) return false;

    try {
      if (!await isBusinessOwner(businessId)) {
        debugPrint('Unauthorized: Cannot remove bank account for business you do not own');
        return false;
      }

      await _firestore.collection('businesses').doc(businessId).update({
        'bankAccount': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error removing bank account: $e');
      return false;
    }
  }

  /// Generate a unique business ID
  Future<String> generateBusinessId() async {
    final year = DateTime.now().year;
    final random = DateTime.now().millisecondsSinceEpoch % 100000;
    return 'BIZ-$year-${random.toString().padLeft(5, '0')}';
  }

  /// Increment business view count
  Future<void> incrementViewCount(String businessId) async {
    try {
      await _firestore.collection('businesses').doc(businessId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing views: $e');
    }
  }
}
