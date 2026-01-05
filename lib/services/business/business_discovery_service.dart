import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/business_model.dart';

/// Service for discovering and searching businesses
/// Handles search, nearby businesses, and featured businesses
class BusinessDiscoveryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final BusinessDiscoveryService _instance = BusinessDiscoveryService._internal();
  factory BusinessDiscoveryService() => _instance;
  BusinessDiscoveryService._internal();

  /// Search businesses
  Future<List<BusinessModel>> searchBusinesses({
    String? query,
    String? type,
    String? industry,
    double? nearLat,
    double? nearLng,
    double radiusKm = 10,
    int limit = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> businessQuery = _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true);

      if (type != null && type.isNotEmpty) {
        businessQuery = businessQuery.where('businessType', isEqualTo: type);
      }

      if (industry != null && industry.isNotEmpty) {
        businessQuery = businessQuery.where('industry', isEqualTo: industry);
      }

      businessQuery = businessQuery.limit(limit);

      final snapshot = await businessQuery.get();
      var businesses = snapshot.docs
          .map((doc) => BusinessModel.fromFirestore(doc))
          .toList();

      // Client-side search if query provided
      if (query != null && query.isNotEmpty) {
        final lowerQuery = query.toLowerCase();
        businesses = businesses
            .where(
              (b) =>
                  b.businessName.toLowerCase().contains(lowerQuery) ||
                  (b.description?.toLowerCase().contains(lowerQuery) ??
                      false) ||
                  b.services.any((s) => s.toLowerCase().contains(lowerQuery)) ||
                  b.products.any((p) => p.toLowerCase().contains(lowerQuery)),
            )
            .toList();
      }

      // TODO: Add geo filtering if nearLat/nearLng provided

      return businesses;
    } catch (e) {
      debugPrint('Error searching businesses: $e');
      return [];
    }
  }

  /// Get nearby businesses
  Future<List<BusinessModel>> getNearbyBusinesses(
    double lat,
    double lng, {
    double radiusKm = 10,
    int limit = 20,
  }) async {
    // Simplified implementation - in production, use GeoFirestore
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .limit(limit * 2) // Get more and filter
          .get();

      return snapshot.docs
          .map((doc) => BusinessModel.fromFirestore(doc))
          .where((b) => b.address?.hasCoordinates ?? false)
          .take(limit)
          .toList();
    } catch (e) {
      debugPrint('Error getting nearby businesses: $e');
      return [];
    }
  }

  /// Get featured businesses
  Future<List<BusinessModel>> getFeaturedBusinesses({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .where('isVerified', isEqualTo: true)
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => BusinessModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting featured businesses: $e');
      return [];
    }
  }

  /// Get businesses by category
  Future<List<BusinessModel>> getBusinessesByCategory(
    String category, {
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .where('category', isEqualTo: category)
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => BusinessModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting businesses by category: $e');
      return [];
    }
  }

  /// Get businesses by type
  Future<List<BusinessModel>> getBusinessesByType(
    String businessType, {
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .where('businessType', isEqualTo: businessType)
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => BusinessModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting businesses by type: $e');
      return [];
    }
  }

  /// Get top rated businesses
  Future<List<BusinessModel>> getTopRatedBusinesses({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .where('reviewCount', isGreaterThan: 0)
          .orderBy('reviewCount')
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => BusinessModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting top rated businesses: $e');
      return [];
    }
  }

  /// Get recently added businesses
  Future<List<BusinessModel>> getRecentBusinesses({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => BusinessModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting recent businesses: $e');
      return [];
    }
  }

  /// Get online businesses
  Future<List<BusinessModel>> getOnlineBusinesses({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .where('isOnline', isEqualTo: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => BusinessModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting online businesses: $e');
      return [];
    }
  }
}
