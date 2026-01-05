import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';

/// Service for handling username validation, availability, and management
class UsernameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final UsernameService _instance = UsernameService._internal();
  factory UsernameService() => _instance;
  UsernameService._internal();

  /// Username validation rules
  static const int minLength = 3;
  static const int maxLength = 20;
  static final RegExp _usernameRegex = RegExp(r'^[a-z0-9_]+$');

  /// Reserved usernames that cannot be claimed
  static const List<String> _reservedUsernames = [
    'admin',
    'administrator',
    'support',
    'help',
    'info',
    'contact',
    'system',
    'moderator',
    'mod',
    'official',
    'supper',
    'supperapp',
    'plink',
    'null',
    'undefined',
    'test',
    'user',
    'username',
    'guest',
    'anonymous',
  ];

  /// Validate username format
  /// Returns null if valid, error message if invalid
  String? validateUsernameFormat(String username) {
    if (username.isEmpty) {
      return 'Username cannot be empty';
    }

    if (username.length < minLength) {
      return 'Username must be at least $minLength characters';
    }

    if (username.length > maxLength) {
      return 'Username must be at most $maxLength characters';
    }

    if (!_usernameRegex.hasMatch(username)) {
      return 'Username can only contain lowercase letters, numbers, and underscores';
    }

    if (username.startsWith('_') || username.endsWith('_')) {
      return 'Username cannot start or end with underscore';
    }

    if (username.contains('__')) {
      return 'Username cannot contain consecutive underscores';
    }

    if (_reservedUsernames.contains(username.toLowerCase())) {
      return 'This username is reserved';
    }

    return null;
  }

  /// Check if a username is available
  /// Returns true if available, false if taken
  Future<bool> isUsernameAvailable(String username) async {
    final normalizedUsername = username.toLowerCase().trim();

    // First validate format
    if (validateUsernameFormat(normalizedUsername) != null) {
      return false;
    }

    try {
      // Check in usernames collection (for fast lookup)
      final usernameDoc = await _firestore
          .collection('usernames')
          .doc(normalizedUsername)
          .get();

      if (usernameDoc.exists) {
        // Check if it belongs to current user (they can keep their own username)
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId != null && usernameDoc.data()?['userId'] == currentUserId) {
          return true;
        }
        return false;
      }

      return true;
    } catch (e) {
      // If error, assume not available for safety
      return false;
    }
  }

  /// Claim a username for the current user
  /// Uses a transaction to ensure atomicity
  Future<UsernameClaimResult> claimUsername(String username) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return UsernameClaimResult(
        success: false,
        error: 'You must be logged in to claim a username',
      );
    }

    final normalizedUsername = username.toLowerCase().trim();

    // Validate format
    final formatError = validateUsernameFormat(normalizedUsername);
    if (formatError != null) {
      return UsernameClaimResult(success: false, error: formatError);
    }

    try {
      // Use a transaction to ensure atomicity
      return await _firestore.runTransaction<UsernameClaimResult>((transaction) async {
        // Check if username is already taken
        final usernameDocRef = _firestore.collection('usernames').doc(normalizedUsername);
        final usernameDoc = await transaction.get(usernameDocRef);

        if (usernameDoc.exists) {
          final existingUserId = usernameDoc.data()?['userId'];
          if (existingUserId != currentUserId) {
            return UsernameClaimResult(
              success: false,
              error: 'This username is already taken',
            );
          }
          // User already has this username, no change needed
          return UsernameClaimResult(success: true, username: normalizedUsername);
        }

        // Get current user's existing username (if any)
        final userDocRef = _firestore.collection('users').doc(currentUserId);
        final userDoc = await transaction.get(userDocRef);
        final oldUsername = userDoc.data()?['username'] as String?;

        // Release old username if exists
        if (oldUsername != null && oldUsername.isNotEmpty && oldUsername != normalizedUsername) {
          final oldUsernameDocRef = _firestore.collection('usernames').doc(oldUsername);
          transaction.delete(oldUsernameDocRef);
        }

        // Claim new username
        transaction.set(usernameDocRef, {
          'userId': currentUserId,
          'username': normalizedUsername,
          'claimedAt': FieldValue.serverTimestamp(),
        });

        // Update user document
        transaction.update(userDocRef, {
          'username': normalizedUsername,
          'usernameUpdatedAt': FieldValue.serverTimestamp(),
        });

        return UsernameClaimResult(success: true, username: normalizedUsername);
      });
    } catch (e) {
      return UsernameClaimResult(
        success: false,
        error: 'Failed to claim username. Please try again.',
      );
    }
  }

  /// Get the current user's username
  Future<String?> getCurrentUsername() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(currentUserId).get();
      return userDoc.data()?['username'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Search users by username or name
  /// Returns a list of matching users
  Future<List<UserProfile>> searchUsers({
    required String query,
    int limit = 20,
  }) async {
    if (query.isEmpty) return [];

    final normalizedQuery = query.toLowerCase().trim();
    final currentUserId = _auth.currentUser?.uid;

    try {
      final results = <UserProfile>[];
      final seenIds = <String>{};

      // Remove @ if present
      final searchTerm = normalizedQuery.startsWith('@')
          ? normalizedQuery.substring(1)
          : normalizedQuery;

      // Search by username (exact prefix match)
      if (searchTerm.isNotEmpty) {
        final usernameResults = await _firestore
            .collection('users')
            .where('username', isGreaterThanOrEqualTo: searchTerm)
            .where('username', isLessThan: '${searchTerm}z')
            .limit(limit)
            .get();

        for (final doc in usernameResults.docs) {
          if (doc.id != currentUserId && !seenIds.contains(doc.id)) {
            seenIds.add(doc.id);
            results.add(UserProfile.fromFirestore(doc));
          }
        }
      }

      // Search by name (if we haven't reached limit)
      if (results.length < limit) {
        final nameResults = await _firestore
            .collection('users')
            .where('nameLower', isGreaterThanOrEqualTo: normalizedQuery)
            .where('nameLower', isLessThan: '${normalizedQuery}z')
            .limit(limit - results.length)
            .get();

        for (final doc in nameResults.docs) {
          if (doc.id != currentUserId && !seenIds.contains(doc.id)) {
            seenIds.add(doc.id);
            results.add(UserProfile.fromFirestore(doc));
          }
        }
      }

      return results;
    } catch (e) {
      return [];
    }
  }

  /// Get user by username
  Future<UserProfile?> getUserByUsername(String username) async {
    final normalizedUsername = username.toLowerCase().trim();

    try {
      // Look up in usernames collection for fast access
      final usernameDoc = await _firestore
          .collection('usernames')
          .doc(normalizedUsername)
          .get();

      if (!usernameDoc.exists) return null;

      final userId = usernameDoc.data()?['userId'] as String?;
      if (userId == null) return null;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      return UserProfile.fromFirestore(userDoc);
    } catch (e) {
      return null;
    }
  }

  /// Generate username suggestions based on name
  Future<List<String>> generateUsernameSuggestions(String name) async {
    final suggestions = <String>[];
    final baseName = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    if (baseName.isEmpty) return suggestions;

    // Generate potential usernames
    final potentials = <String>[
      baseName,
      '${baseName}_',
      '_$baseName',
      '${baseName}1',
      '${baseName}2',
      '${baseName}123',
      '${baseName}_app',
      'the_$baseName',
      '${baseName}_official',
    ];

    // Check availability for each
    for (final potential in potentials) {
      if (potential.length >= minLength && potential.length <= maxLength) {
        if (await isUsernameAvailable(potential)) {
          suggestions.add(potential);
          if (suggestions.length >= 5) break;
        }
      }
    }

    return suggestions;
  }
}

/// Result of username claim operation
class UsernameClaimResult {
  final bool success;
  final String? username;
  final String? error;

  UsernameClaimResult({
    required this.success,
    this.username,
    this.error,
  });
}
