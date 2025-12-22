import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for blocking users and reporting inappropriate behavior
class BlockReportService {
  static final BlockReportService _instance = BlockReportService._internal();
  factory BlockReportService() => _instance;
  BlockReportService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== BLOCK FUNCTIONALITY ====================

  /// Block a user
  Future<Map<String, dynamic>> blockUser({
    required String blockedUserId,
    String? reason,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return {'success': false, 'message': 'User not authenticated'};
    }

    if (currentUserId == blockedUserId) {
      return {'success': false, 'message': 'Cannot block yourself'};
    }

    try {
      // Add to blocked users list
      await _firestore.collection('users').doc(currentUserId).update({
        'blockedUsers': FieldValue.arrayUnion([blockedUserId]),
      });

      // Create block record
      await _firestore.collection('blocks').add({
        'blockerId': currentUserId,
        'blockedId': blockedUserId,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Remove from favorites if exists
      await _firestore.collection('users').doc(currentUserId).update({
        'favoriteUsers': FieldValue.arrayRemove([blockedUserId]),
      });

      debugPrint(' User $blockedUserId blocked successfully');
      return {'success': true, 'message': 'User blocked successfully'};
    } catch (e) {
      debugPrint(' Error blocking user: $e');
      return {'success': false, 'message': 'Failed to block user: $e'};
    }
  }

  /// Unblock a user
  Future<Map<String, dynamic>> unblockUser(String blockedUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return {'success': false, 'message': 'User not authenticated'};
    }

    try {
      // Remove from blocked users list
      await _firestore.collection('users').doc(currentUserId).update({
        'blockedUsers': FieldValue.arrayRemove([blockedUserId]),
      });

      // Delete block record
      final blockDocs = await _firestore
          .collection('blocks')
          .where('blockerId', isEqualTo: currentUserId)
          .where('blockedId', isEqualTo: blockedUserId)
          .get();

      for (var doc in blockDocs.docs) {
        await doc.reference.delete();
      }

      debugPrint(' User $blockedUserId unblocked successfully');
      return {'success': true, 'message': 'User unblocked successfully'};
    } catch (e) {
      debugPrint(' Error unblocking user: $e');
      return {'success': false, 'message': 'Failed to unblock user: $e'};
    }
  }

  /// Check if a user is blocked
  Future<bool> isUserBlocked(String userId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      final blockedUsers = List<String>.from(
        userDoc.data()?['blockedUsers'] ?? [],
      );
      return blockedUsers.contains(userId);
    } catch (e) {
      debugPrint(' Error checking block status: $e');
      return false;
    }
  }

  /// Check if current user is blocked by another user
  Future<bool> isBlockedBy(String userId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final blockedUsers = List<String>.from(
        userDoc.data()?['blockedUsers'] ?? [],
      );
      return blockedUsers.contains(currentUserId);
    } catch (e) {
      debugPrint(' Error checking if blocked by user: $e');
      return false;
    }
  }

  /// Get list of blocked users
  Future<List<String>> getBlockedUsers() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      return List<String>.from(userDoc.data()?['blockedUsers'] ?? []);
    } catch (e) {
      debugPrint(' Error getting blocked users: $e');
      return [];
    }
  }

  /// Get blocked users stream
  Stream<List<String>> getBlockedUsersStream() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _firestore.collection('users').doc(currentUserId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return <String>[];
      return List<String>.from(doc.data()?['blockedUsers'] ?? []);
    });
  }

  // ==================== REPORT FUNCTIONALITY ====================

  /// Report a user for inappropriate behavior
  Future<Map<String, dynamic>> reportUser({
    required String reportedUserId,
    required String reason,
    required String
    category, // harassment, spam, inappropriate_content, fake_profile, other
    String? additionalDetails,
    List<String>? evidenceUrls,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return {'success': false, 'message': 'User not authenticated'};
    }

    if (currentUserId == reportedUserId) {
      return {'success': false, 'message': 'Cannot report yourself'};
    }

    try {
      // Create report
      await _firestore.collection('reports').add({
        'reporterId': currentUserId,
        'reportedUserId': reportedUserId,
        'reason': reason,
        'category': category,
        'additionalDetails': additionalDetails,
        'evidenceUrls': evidenceUrls ?? [],
        'status': 'pending', // pending, under_review, resolved, dismissed
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'reviewedBy': null,
        'reviewNotes': null,
      });

      // Increment report count on reported user
      await _firestore.collection('users').doc(reportedUserId).update({
        'reportCount': FieldValue.increment(1),
      });

      debugPrint(' User $reportedUserId reported successfully');
      return {
        'success': true,
        'message': 'Report submitted successfully. We will review it shortly.',
      };
    } catch (e) {
      debugPrint(' Error reporting user: $e');
      return {'success': false, 'message': 'Failed to submit report: $e'};
    }
  }

  /// Get available report categories
  static const List<Map<String, String>> reportCategories = [
    {
      'id': 'harassment',
      'title': 'Harassment or Bullying',
      'description': 'Threatening, intimidating, or abusive behavior',
    },
    {
      'id': 'spam',
      'title': 'Spam or Scam',
      'description': 'Unsolicited messages, links, or commercial content',
    },
    {
      'id': 'inappropriate_content',
      'title': 'Inappropriate Content',
      'description': 'Offensive, explicit, or disturbing content',
    },
    {
      'id': 'fake_profile',
      'title': 'Fake Profile',
      'description': 'Impersonation or misrepresentation',
    },
    {
      'id': 'safety_concern',
      'title': 'Safety Concern',
      'description': 'Potential danger to self or others',
    },
    {
      'id': 'other',
      'title': 'Other',
      'description': 'Other concerns not listed above',
    },
  ];

  /// Check if user has already reported another user
  Future<bool> hasReportedUser(String reportedUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      final reports = await _firestore
          .collection('reports')
          .where('reporterId', isEqualTo: currentUserId)
          .where('reportedUserId', isEqualTo: reportedUserId)
          .limit(1)
          .get();

      return reports.docs.isNotEmpty;
    } catch (e) {
      debugPrint(' Error checking report status: $e');
      return false;
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Filter out blocked users from a list
  Future<List<Map<String, dynamic>>> filterBlockedUsers(
    List<Map<String, dynamic>> users,
  ) async {
    final blockedUsers = await getBlockedUsers();

    return users.where((user) {
      final userId = user['userId'] as String?;
      return userId != null && !blockedUsers.contains(userId);
    }).toList();
  }

  /// Check mutual block status
  Future<bool> hasBlockRelationship(String userId) async {
    final isBlocked = await isUserBlocked(userId);
    final isBlockedByOther = await isBlockedBy(userId);
    return isBlocked || isBlockedByOther;
  }
}
