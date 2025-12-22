import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User Migration Service
/// Adds missing fields to existing users for new features
class UserMigrationService {
  static final UserMigrationService _instance =
      UserMigrationService._internal();
  factory UserMigrationService() => _instance;
  UserMigrationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _migrationKey = 'user_migration_v1_done';

  /// Check if migration is needed and run it
  Future<void> checkAndRunMigration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final migrationDone = prefs.getBool(_migrationKey) ?? false;

      if (migrationDone) {
        debugPrint('User migration already completed');
        return;
      }

      debugPrint(' Starting user migration...');
      await _runMigration();

      // Mark as complete
      await prefs.setBool(_migrationKey, true);
      debugPrint(' User migration completed successfully');
    } catch (e) {
      debugPrint(' Error during user migration: $e');
      // Don't throw - allow app to continue even if migration fails
    }
  }

  /// Run the actual migration
  Future<void> _runMigration() async {
    try {
      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();

      debugPrint(' Found ${usersSnapshot.docs.length} users to migrate');

      // Process in batches of 500 (Firestore batch limit)
      const batchSize = 500;
      for (int i = 0; i < usersSnapshot.docs.length; i += batchSize) {
        final batch = _firestore.batch();
        final batchDocs = usersSnapshot.docs.skip(i).take(batchSize).toList();

        for (var doc in batchDocs) {
          final userData = doc.data();
          final updates = <String, dynamic>{};

          // Add discoveryModeEnabled if missing
          if (!userData.containsKey('discoveryModeEnabled')) {
            updates['discoveryModeEnabled'] = true; // Default to true
          }

          // Add blockedUsers if missing
          if (!userData.containsKey('blockedUsers')) {
            updates['blockedUsers'] = [];
          }

          // Add connections if missing
          if (!userData.containsKey('connections')) {
            updates['connections'] = [];
          }

          // Add connectionCount if missing
          if (!userData.containsKey('connectionCount')) {
            updates['connectionCount'] = 0;
          }

          // Add reportCount if missing
          if (!userData.containsKey('reportCount')) {
            updates['reportCount'] = 0;
          }

          // Add connectionTypes if missing
          if (!userData.containsKey('connectionTypes')) {
            updates['connectionTypes'] = [];
          }

          // Add activities if missing
          if (!userData.containsKey('activities')) {
            updates['activities'] = [];
          }

          // Only update if there are fields to add
          if (updates.isNotEmpty) {
            batch.update(doc.reference, updates);
          }
        }

        // Commit this batch
        await batch.commit();
        debugPrint(' Migrated batch ${(i ~/ batchSize) + 1}');
      }

      debugPrint(' All users migrated successfully');
    } catch (e) {
      debugPrint(' Error running migration: $e');
      throw Exception('Migration failed: $e');
    }
  }

  /// Force migration (for admin/debug purposes)
  Future<void> forceMigration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_migrationKey);
    await checkAndRunMigration();
  }

  /// Get migration status
  Future<Map<String, dynamic>> getMigrationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final migrationDone = prefs.getBool(_migrationKey) ?? false;

      // Count users without required fields
      int usersNeedingMigration = 0;

      try {
        final usersSnapshot = await _firestore
            .collection('users')
            .limit(100) // Check sample of 100
            .get();

        for (var doc in usersSnapshot.docs) {
          final data = doc.data();
          if (!data.containsKey('discoveryModeEnabled') ||
              !data.containsKey('blockedUsers') ||
              !data.containsKey('connections')) {
            usersNeedingMigration++;
          }
        }
      } catch (e) {
        debugPrint('Error checking migration status: $e');
      }

      return {
        'migrationDone': migrationDone,
        'usersNeedingMigration': usersNeedingMigration,
        'sampleSize': 100,
      };
    } catch (e) {
      debugPrint(' Error getting migration status: $e');
      return {'migrationDone': false, 'error': e.toString()};
    }
  }

  /// Migrate single user (for real-time use)
  Future<void> migrateSingleUser(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() ?? {};
      final updates = <String, dynamic>{};

      // Add missing fields
      if (!userData.containsKey('discoveryModeEnabled')) {
        updates['discoveryModeEnabled'] = true;
      }
      if (!userData.containsKey('blockedUsers')) {
        updates['blockedUsers'] = [];
      }
      if (!userData.containsKey('connections')) {
        updates['connections'] = [];
      }
      if (!userData.containsKey('connectionCount')) {
        updates['connectionCount'] = 0;
      }
      if (!userData.containsKey('reportCount')) {
        updates['reportCount'] = 0;
      }
      if (!userData.containsKey('connectionTypes')) {
        updates['connectionTypes'] = [];
      }
      if (!userData.containsKey('activities')) {
        updates['activities'] = [];
      }

      if (updates.isNotEmpty) {
        await userRef.update(updates);
        debugPrint('Migrated user $userId with ${updates.length} fields');
      }
    } catch (e) {
      debugPrint(' Error migrating user $userId: $e');
    }
  }
}
