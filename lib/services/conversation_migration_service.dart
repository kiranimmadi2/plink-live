import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to migrate and fix corrupted conversation documents
///
/// This service fixes conversations where the participants array is missing
/// or doesn't contain the correct user IDs, which prevents conversations
/// from appearing in the Messages screen.
class ConversationMigrationService {
  static const String _migrationKey = 'conversation_migration_v1_completed';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if migration has already been completed
  Future<bool> isMigrationCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_migrationKey) ?? false;
    } catch (e) {
      print('ConversationMigration: Error checking migration status: $e');
      return false;
    }
  }

  /// Mark migration as completed
  Future<void> _markMigrationCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_migrationKey, true);
      print('ConversationMigration: Migration marked as completed');
    } catch (e) {
      print('ConversationMigration: Error marking migration as completed: $e');
    }
  }

  /// Run the migration to fix all corrupted conversations
  ///
  /// Returns a map with migration results:
  /// - 'success': bool
  /// - 'fixed': number of conversations fixed
  /// - 'scanned': number of conversations scanned
  /// - 'errors': list of error messages
  Future<Map<String, dynamic>> runMigration() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      print('ConversationMigration: ERROR - No authenticated user');
      return {
        'success': false,
        'fixed': 0,
        'scanned': 0,
        'errors': ['No authenticated user'],
      };
    }

    print('ConversationMigration: Starting migration for user: $currentUserId');

    int scanned = 0;
    int fixed = 0;
    List<String> errors = [];

    try {
      // Get all conversations where the conversation ID contains the current user's ID
      // Conversation IDs follow format: {userId1}_{userId2}
      final allConversationsSnapshot = await _firestore
          .collection('conversations')
          .get();

      print('ConversationMigration: Found ${allConversationsSnapshot.docs.length} total conversations');

      for (var doc in allConversationsSnapshot.docs) {
        try {
          final conversationId = doc.id;

          // Check if this conversation should include the current user
          // based on the conversation ID format
          if (!conversationId.contains(currentUserId)) {
            continue; // This conversation doesn't involve the current user
          }

          scanned++;
          final data = doc.data();
          final participants = data['participants'] as List<dynamic>?;

          print('ConversationMigration: Scanning conversation: $conversationId');
          print('ConversationMigration: Current participants: $participants');

          // Check if participants array is missing or corrupted
          bool needsFix = false;

          if (participants == null || participants.isEmpty) {
            print('ConversationMigration: CORRUPTED - participants array is null or empty');
            needsFix = true;
          } else if (!participants.contains(currentUserId)) {
            print('ConversationMigration: CORRUPTED - participants array missing current user');
            needsFix = true;
          } else if (participants.length != 2) {
            print('ConversationMigration: CORRUPTED - participants array has incorrect length: ${participants.length}');
            needsFix = true;
          }

          if (needsFix) {
            // Extract user IDs from conversation ID
            final userIds = conversationId.split('_');
            if (userIds.length != 2) {
              print('ConversationMigration: ERROR - Invalid conversation ID format: $conversationId');
              errors.add('Invalid conversation ID format: $conversationId');
              continue;
            }

            // Fix the participants array
            await doc.reference.update({
              'participants': userIds,
            });

            fixed++;
            print('ConversationMigration: FIXED conversation: $conversationId');
            print('ConversationMigration: Updated participants to: $userIds');
          } else {
            print('ConversationMigration: OK - conversation is valid');
          }
        } catch (e) {
          print('ConversationMigration: ERROR processing conversation ${doc.id}: $e');
          errors.add('Error processing ${doc.id}: $e');
        }
      }

      print('ConversationMigration: Migration completed');
      print('ConversationMigration: Scanned: $scanned, Fixed: $fixed, Errors: ${errors.length}');

      // Mark migration as completed
      await _markMigrationCompleted();

      return {
        'success': true,
        'fixed': fixed,
        'scanned': scanned,
        'errors': errors,
      };
    } catch (e) {
      print('ConversationMigration: FATAL ERROR during migration: $e');
      return {
        'success': false,
        'fixed': fixed,
        'scanned': scanned,
        'errors': [...errors, 'Fatal error: $e'],
      };
    }
  }

  /// Force run migration again (ignores completed status)
  /// Useful for testing or manual fixes
  Future<Map<String, dynamic>> forceRunMigration() async {
    print('ConversationMigration: Force running migration...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_migrationKey);
    return await runMigration();
  }

  /// Validate a specific conversation and fix if needed
  /// Returns true if conversation was fixed, false if it was already valid
  Future<bool> validateAndFixConversation(String conversationId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      print('ConversationMigration: ERROR - No authenticated user');
      return false;
    }

    try {
      final doc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!doc.exists) {
        print('ConversationMigration: Conversation does not exist: $conversationId');
        return false;
      }

      final data = doc.data()!;
      final participants = data['participants'] as List<dynamic>?;

      // Check if needs fixing
      bool needsFix = false;

      if (participants == null || participants.isEmpty) {
        needsFix = true;
      } else if (!participants.contains(currentUserId)) {
        needsFix = true;
      } else if (participants.length != 2) {
        needsFix = true;
      }

      if (needsFix) {
        // Extract user IDs from conversation ID
        final userIds = conversationId.split('_');
        if (userIds.length != 2) {
          print('ConversationMigration: ERROR - Invalid conversation ID format: $conversationId');
          return false;
        }

        // Fix the participants array
        await doc.reference.update({
          'participants': userIds,
        });

        print('ConversationMigration: Fixed conversation: $conversationId');
        return true;
      }

      return false;
    } catch (e) {
      print('ConversationMigration: ERROR validating conversation $conversationId: $e');
      return false;
    }
  }
}
