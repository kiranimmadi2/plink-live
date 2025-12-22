import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../other services/vector_service.dart';

class MigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final VectorService _vectorService = VectorService();

  static final MigrationService _instance = MigrationService._internal();
  factory MigrationService() => _instance;
  MigrationService._internal();

  // Migrate existing posts to add embeddings and keywords
  Future<void> migrateExistingPosts({
    int batchSize = 10,
    Function(int, int)? onProgress,
  }) async {
    try {
      debugPrint('Starting migration of existing posts...');

      // Get all posts without embeddings
      final postsQuery = await _firestore
          .collection('posts')
          .where('embedding', isNull: true)
          .get();

      final totalPosts = postsQuery.docs.length;
      debugPrint('Found $totalPosts posts to migrate');

      if (totalPosts == 0) {
        debugPrint('No posts need migration');
        return;
      }

      int processed = 0;
      final batch = _firestore.batch();
      int batchCount = 0;

      for (final doc in postsQuery.docs) {
        try {
          final data = doc.data();

          // Extract dynamic domain and action type from intentAnalysis if available
          final intentAnalysis =
              data['intentAnalysis'] as Map<String, dynamic>?;
          final domain = intentAnalysis?['domain'] as String?;
          final actionType = intentAnalysis?['action_type'] as String?;

          // Create text for embedding (no hardcoded categories!)
          final text = _vectorService.createTextForEmbedding(
            title: data['title'] ?? '',
            description: data['description'] ?? data['originalPrompt'] ?? '',
            location: data['location'],
            domain: domain,
            actionType: actionType,
            keywords: data['keywords'] != null
                ? List<String>.from(data['keywords'])
                : null,
          );

          // Generate embedding
          final embedding = await _vectorService.generateEmbedding(text);

          // Extract keywords
          final keywords = _vectorService.extractKeywords(
            '${data['title'] ?? ''} ${data['description'] ?? data['originalPrompt'] ?? ''}',
          );

          // Update document
          batch.update(doc.reference, {
            'embedding': embedding,
            'keywords': keywords,
            'embeddingUpdatedAt': FieldValue.serverTimestamp(),
          });

          batchCount++;
          processed++;

          // Report progress
          if (onProgress != null) {
            onProgress(processed, totalPosts);
          }

          // Commit batch when it reaches the size limit
          if (batchCount >= batchSize) {
            await batch.commit();
            batchCount = 0;
            debugPrint('Migrated $processed/$totalPosts posts');

            // Small delay to avoid overwhelming the API
            await Future.delayed(const Duration(milliseconds: 500));
          }
        } catch (e) {
          debugPrint('Error migrating post ${doc.id}: $e');
          // Continue with next post
        }
      }

      // Commit any remaining updates
      if (batchCount > 0) {
        await batch.commit();
        debugPrint('Migrated $processed/$totalPosts posts');
      }

      debugPrint('Migration completed successfully!');
    } catch (e) {
      debugPrint('Migration failed: $e');
      rethrow;
    }
  }

  // Check migration status
  Future<Map<String, int>> getMigrationStatus() async {
    try {
      // Count posts with embeddings
      final withEmbeddings = await _firestore
          .collection('posts')
          .where('embedding', isNull: false)
          .count()
          .get();

      // Count posts without embeddings
      final withoutEmbeddings = await _firestore
          .collection('posts')
          .where('embedding', isNull: true)
          .count()
          .get();

      return {
        'migrated': withEmbeddings.count ?? 0,
        'pending': withoutEmbeddings.count ?? 0,
        'total': (withEmbeddings.count ?? 0) + (withoutEmbeddings.count ?? 0),
      };
    } catch (e) {
      debugPrint('Error getting migration status: $e');
      return {'migrated': 0, 'pending': 0, 'total': 0};
    }
  }

  // Clean up orphaned embeddings
  Future<void> cleanupOrphanedEmbeddings() async {
    try {
      debugPrint('Cleaning up orphaned embeddings...');

      final embeddingsSnapshot = await _firestore
          .collection('embeddings')
          .get();

      int deleted = 0;
      final batch = _firestore.batch();
      int batchCount = 0;

      for (final doc in embeddingsSnapshot.docs) {
        final postId = doc.data()['postId'];
        if (postId != null) {
          // Check if corresponding post exists
          final postDoc = await _firestore
              .collection('posts')
              .doc(postId)
              .get();

          if (!postDoc.exists) {
            // Delete orphaned embedding
            batch.delete(doc.reference);
            batchCount++;
            deleted++;

            if (batchCount >= 10) {
              await batch.commit();
              batchCount = 0;
            }
          }
        }
      }

      // Commit remaining deletions
      if (batchCount > 0) {
        await batch.commit();
      }

      debugPrint('Deleted $deleted orphaned embeddings');
    } catch (e) {
      debugPrint('Error cleaning up embeddings: $e');
    }
  }

  // Recalculate embeddings for specific posts
  Future<void> recalculateEmbeddings(List<String> postIds) async {
    try {
      for (final postId in postIds) {
        final doc = await _firestore.collection('posts').doc(postId).get();

        if (doc.exists) {
          final data = doc.data()!;

          // Extract dynamic domain and action type from intentAnalysis if available
          final intentAnalysis =
              data['intentAnalysis'] as Map<String, dynamic>?;
          final domain = intentAnalysis?['domain'] as String?;
          final actionType = intentAnalysis?['action_type'] as String?;

          // Create text for embedding (no hardcoded categories!)
          final text = _vectorService.createTextForEmbedding(
            title: data['title'] ?? '',
            description: data['description'] ?? data['originalPrompt'] ?? '',
            location: data['location'],
            domain: domain,
            actionType: actionType,
            keywords: data['keywords'] != null
                ? List<String>.from(data['keywords'])
                : null,
          );

          // Generate new embedding
          final embedding = await _vectorService.generateEmbedding(text);

          // Extract keywords
          final keywords = _vectorService.extractKeywords(
            '${data['title'] ?? ''} ${data['description'] ?? data['originalPrompt'] ?? ''}',
          );

          // Update post
          await doc.reference.update({
            'embedding': embedding,
            'keywords': keywords,
            'embeddingUpdatedAt': FieldValue.serverTimestamp(),
          });

          // Update embedding document
          await _vectorService.storeEmbedding(
            documentId: postId,
            collection: 'embeddings',
            embedding: embedding,
            metadata: {
              'postId': postId,
              'category': data['category'],
              'keywords': keywords,
            },
          );

          debugPrint('Recalculated embedding for post $postId');
        }
      }
    } catch (e) {
      debugPrint('Error recalculating embeddings: $e');
      rethrow;
    }
  }
}
