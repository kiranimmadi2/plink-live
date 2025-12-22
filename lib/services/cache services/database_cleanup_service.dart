import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Database Cleanup Service
///
/// Handles one-time cleanup of old collections and data migration
/// This ensures the app uses only the new unified structure
class DatabaseCleanupService {
  static final DatabaseCleanupService _instance =
      DatabaseCleanupService._internal();
  factory DatabaseCleanupService() => _instance;
  DatabaseCleanupService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _cleanupKey = 'database_cleanup_v2_done';

  /// Check if cleanup is needed and run it
  Future<void> checkAndRunCleanup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cleanupDone = prefs.getBool(_cleanupKey) ?? false;

      if (cleanupDone) {
        debugPrint(' Database cleanup already completed');
        return;
      }

      debugPrint(' Starting database cleanup...');
      await _runCleanup();

      // Mark as complete
      await prefs.setBool(_cleanupKey, true);
      debugPrint(' Database cleanup completed successfully');
    } catch (e) {
      debugPrint(' Error during database cleanup: $e');
      // Don't throw - allow app to continue even if cleanup fails
    }
  }

  /// Run the actual cleanup
  Future<void> _runCleanup() async {
    // Step 1: Delete old collections data
    await _deleteOldCollections();

    // Step 2: Clean up any orphaned data
    await _cleanupOrphanedData();

    debugPrint(' All cleanup tasks completed');
  }

  /// Delete old collections that are no longer used
  Future<void> _deleteOldCollections() async {
    try {
      debugPrint(' Deleting old collections...');

      // Collections to clean up (old/unused data)
      final collectionsToDelete = [
        'ai_generated_questions', // Old AI system
        'chats', // Old chat structure (replaced by conversations)
        'embeddings', // Old embedding cache
        'error_analytics', // Debug data
        'intent_conversations', // Old intent system
        'intents', // Old intent structure
        // 'posts' - REMOVED: This collection is ACTIVELY USED, DO NOT DELETE!
        'processed_intents', // Old processing history
        'user_intents', // Old user intents (replaced by posts)
      ];

      for (final collectionName in collectionsToDelete) {
        await _deleteCollection(collectionName);
      }

      debugPrint(' Old collections deleted');
    } catch (e) {
      debugPrint(' Error deleting old collections: $e');
    }
  }

  /// Delete all documents in a collection
  Future<void> _deleteCollection(String collectionName) async {
    try {
      debugPrint(' Deleting collection: $collectionName');

      // Get all documents in collection
      final snapshot = await _firestore
          .collection(collectionName)
          .limit(500) // Process in batches
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint(
          ' Collection $collectionName is already empty or doesn\'t exist',
        );
        return;
      }

      // Delete in batches
      WriteBatch batch = _firestore.batch();
      int count = 0;

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
        count++;

        // Commit batch every 500 documents
        if (count >= 500) {
          await batch.commit();
          batch = _firestore.batch();
          count = 0;
        }
      }

      // Commit remaining documents
      if (count > 0) {
        await batch.commit();
      }

      debugPrint(
        ' Deleted ${snapshot.docs.length} documents from $collectionName',
      );

      // If there are more documents, recursively delete
      if (snapshot.docs.length >= 500) {
        await _deleteCollection(collectionName);
      }
    } catch (e) {
      debugPrint(' Error deleting collection $collectionName: $e');
    }
  }

  /// Clean up orphaned data
  Future<void> _cleanupOrphanedData() async {
    try {
      debugPrint(' Cleaning up orphaned data...');

      // Delete posts with no userId
      await _deletePostsWithoutUser();

      // Delete expired posts
      await _deleteExpiredPosts();

      debugPrint(' Orphaned data cleaned up');
    } catch (e) {
      debugPrint(' Error cleaning orphaned data: $e');
    }
  }

  /// Delete posts that have no userId (skip - posts collection is deleted)
  Future<void> _deletePostsWithoutUser() async {
    // Skip - posts collection is being deleted entirely
    debugPrint(' Skipped orphaned posts cleanup (collection deleted)');
  }

  /// Delete expired posts (skip - posts collection is deleted)
  Future<void> _deleteExpiredPosts() async {
    // Skip - posts collection is being deleted entirely
    debugPrint(' Skipped expired posts cleanup (collection deleted)');
  }

  /// Force cleanup (for admin/debug purposes)
  Future<void> forceCleanup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cleanupKey);
    await checkAndRunCleanup();
  }

  /// Get cleanup status
  Future<Map<String, dynamic>> getCleanupStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cleanupDone = prefs.getBool(_cleanupKey) ?? false;

      // Count documents in old collections
      int userIntentsCount = 0;
      int intentsCount = 0;
      int processedIntentsCount = 0;

      try {
        final userIntentsSnapshot = await _firestore
            .collection('user_intents')
            .limit(1)
            .get();
        userIntentsCount = userIntentsSnapshot.docs.length;
      } catch (e) {
        // Collection doesn't exist
      }

      try {
        final intentsSnapshot = await _firestore
            .collection('intents')
            .limit(1)
            .get();
        intentsCount = intentsSnapshot.docs.length;
      } catch (e) {
        // Collection doesn't exist
      }

      try {
        final processedSnapshot = await _firestore
            .collection('processed_intents')
            .limit(1)
            .get();
        processedIntentsCount = processedSnapshot.docs.length;
      } catch (e) {
        // Collection doesn't exist
      }

      // Count posts
      final postsSnapshot = await _firestore.collection('posts').count().get();

      return {
        'cleanupDone': cleanupDone,
        'oldCollectionsExist':
            userIntentsCount > 0 ||
            intentsCount > 0 ||
            processedIntentsCount > 0,
        'postsCount': postsSnapshot.count ?? 0,
        'userIntentsCount': userIntentsCount,
        'intentsCount': intentsCount,
        'processedIntentsCount': processedIntentsCount,
      };
    } catch (e) {
      debugPrint(' Error getting cleanup status: $e');
      return {'cleanupDone': false, 'error': e.toString()};
    }
  }
}
