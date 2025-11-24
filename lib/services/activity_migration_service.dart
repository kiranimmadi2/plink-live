import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to migrate activities from old Map format to new String format
class ActivityMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Migrate current user's activities from Map format to String format
  Future<Map<String, dynamic>> migrateCurrentUserActivities() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return {
          'success': false,
          'message': 'User document not found',
        };
      }

      final data = userDoc.data();
      final activitiesData = data?['activities'];

      if (activitiesData == null || activitiesData is! List) {
        return {
          'success': true,
          'message': 'No activities to migrate',
          'migrated': 0,
        };
      }

      // Convert activities to simple string format
      List<String> migratedActivities = [];
      int migratedCount = 0;

      for (var item in activitiesData) {
        if (item is Map) {
          // Old format: {"name": "Running", "level": "intermediate"}
          final name = item['name']?.toString();
          if (name != null && name.isNotEmpty) {
            migratedActivities.add(name);
            migratedCount++;
          }
        } else if (item is String) {
          // Already in new format
          migratedActivities.add(item);
        }
      }

      // Update Firestore with clean string format
      await _firestore.collection('users').doc(userId).update({
        'activities': migratedActivities,
      });

      return {
        'success': true,
        'message': 'Activities migrated successfully',
        'migrated': migratedCount,
        'total': migratedActivities.length,
        'activities': migratedActivities,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error migrating activities: $e',
      };
    }
  }

  /// Migrate ALL users' activities (admin function)
  Future<Map<String, dynamic>> migrateAllUsersActivities() async {
    try {
      int totalUsers = 0;
      int migratedUsers = 0;
      int totalActivitiesMigrated = 0;

      final usersSnapshot = await _firestore.collection('users').get();

      for (var userDoc in usersSnapshot.docs) {
        totalUsers++;

        final data = userDoc.data();
        final activitiesData = data['activities'];

        if (activitiesData == null || activitiesData is! List) {
          continue;
        }

        bool needsMigration = false;
        List<String> migratedActivities = [];

        for (var item in activitiesData) {
          if (item is Map) {
            needsMigration = true;
            final name = item['name']?.toString();
            if (name != null && name.isNotEmpty) {
              migratedActivities.add(name);
              totalActivitiesMigrated++;
            }
          } else if (item is String) {
            migratedActivities.add(item);
          }
        }

        if (needsMigration) {
          await _firestore.collection('users').doc(userDoc.id).update({
            'activities': migratedActivities,
          });
          migratedUsers++;
        }
      }

      return {
        'success': true,
        'totalUsers': totalUsers,
        'migratedUsers': migratedUsers,
        'totalActivitiesMigrated': totalActivitiesMigrated,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error migrating all users: $e',
      };
    }
  }

  /// Clear all activities for current user (for testing)
  Future<Map<String, dynamic>> clearCurrentUserActivities() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      await _firestore.collection('users').doc(userId).update({
        'activities': [],
      });

      return {
        'success': true,
        'message': 'Activities cleared successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error clearing activities: $e',
      };
    }
  }
}
