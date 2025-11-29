import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../utils/photo_url_helper.dart';
import 'location_service.dart';
import 'user_manager.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Timeout for profile operations to prevent hanging
  static const Duration _profileTimeout = Duration(seconds: 10);

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update profile with timeout - don't block login indefinitely
      if (result.user != null) {
        final user = result.user!;
        try {
          await _updateUserProfileOnLogin(user, email)
              .timeout(_profileTimeout, onTimeout: () {
            debugPrint('⚠️ Profile update timed out, continuing with login');
          });
        } catch (e) {
          // Log but don't fail login
          debugPrint('⚠️ Profile update failed (non-fatal): $e');
        }
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found for that email.';
          break;
        case 'wrong-password':
          message = 'Wrong password provided.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'user-disabled':
          message = 'This user account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many login attempts. Please try again later.';
          break;
        default:
          message = e.message ?? 'An error occurred during sign in.';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create profile with timeout - essential for new users
      if (result.user != null) {
        final user = result.user!;
        try {
          await _createNewUserProfile(user, email)
              .timeout(_profileTimeout, onTimeout: () {
            debugPrint('⚠️ Profile creation timed out, continuing with signup');
          });
        } catch (e) {
          // Log but don't fail signup - profile will be created on next login
          debugPrint('⚠️ Profile creation failed (non-fatal): $e');
        }
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'weak-password':
          message = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists for that email.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'operation-not-allowed':
          message = 'Email/password accounts are not enabled.';
          break;
        default:
          message = e.message ?? 'An error occurred during sign up.';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      // Try silent sign-in first (better UX if user already signed in)
      GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();

      // If silent fails, show account picker
      googleUser ??= await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result =
          await _auth.signInWithCredential(credential);

      // Update Google profile with timeout
      if (result.user != null) {
        final user = result.user!;
        String? photoUrl = user.photoURL ?? googleUser.photoUrl;
        photoUrl = PhotoUrlHelper.getHighQualityGooglePhoto(photoUrl);
        try {
          await _updateGoogleUserProfile(user, googleUser, photoUrl)
              .timeout(_profileTimeout, onTimeout: () {
            debugPrint('⚠️ Google profile update timed out, continuing with login');
          });
        } catch (e) {
          debugPrint('⚠️ Google profile update failed (non-fatal): $e');
        }
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          message = 'An account already exists with the same email address.';
          break;
        case 'invalid-credential':
          message = 'The credential is invalid or has expired.';
          break;
        case 'operation-not-allowed':
          message = 'Google sign-in is not enabled.';
          break;
        case 'user-disabled':
          message = 'This user account has been disabled.';
          break;
        default:
          message = e.message ?? 'An error occurred during Google sign-in.';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Google sign-in failed: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    try {
      // Update user's online status to false before signing out
      final user = _auth.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'isOnline': false,
            'lastSeen': FieldValue.serverTimestamp(),
          }).timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint('⚠️ Failed to update online status on logout: $e');
        }
      }

      // Clear all service states
      _clearAllServices();

      // Sign out from Firebase and Google
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);

      debugPrint('✓ User signed out successfully');
    } catch (e) {
      // Still try to clear services even if signout fails
      _clearAllServices();
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  /// Clear all service states on logout
  void _clearAllServices() {
    try {
      // Reset location service
      LocationService().reset();

      // Clear user manager cache
      UserManager().signOut();

      debugPrint('✓ All services cleared');
    } catch (e) {
      debugPrint('⚠️ Error clearing services: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'user-not-found':
          message = 'No user found for that email.';
          break;
        default:
          message = e.message ?? 'An error occurred sending password reset.';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Password reset failed: ${e.toString()}');
    }
  }

  Future<void> deleteAccount() async {
    try {
      await currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'requires-recent-login':
          message = 'Please sign in again before deleting your account.';
          break;
        default:
          message = e.message ?? 'An error occurred deleting account.';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Account deletion failed: ${e.toString()}');
    }
  }

  Future<void> updateEmail(String newEmail) async {
    try {
      await currentUser?.verifyBeforeUpdateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'email-already-in-use':
          message = 'This email is already in use by another account.';
          break;
        case 'requires-recent-login':
          message = 'Please sign in again before updating your email.';
          break;
        default:
          message = e.message ?? 'An error occurred updating email.';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Email update failed: ${e.toString()}');
    }
  }

  /// Check if the current user has email/password authentication
  bool hasPasswordProvider() {
    final user = currentUser;
    if (user == null) return false;

    // Check if user has password provider
    for (var provider in user.providerData) {
      if (provider.providerId == 'password') {
        return true;
      }
    }
    return false;
  }

  /// Get the primary sign-in method for the current user
  String? getPrimarySignInMethod() {
    final user = currentUser;
    if (user == null || user.providerData.isEmpty) return null;
    return user.providerData.first.providerId;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = currentUser;
      if (user == null || user.email == null) {
        throw Exception('No user is currently signed in');
      }

      // Check if user has password authentication
      if (!hasPasswordProvider()) {
        final provider = getPrimarySignInMethod();
        if (provider == 'google.com') {
          throw Exception('You signed in with Google. Please use Google to manage your password.');
        } else {
          throw Exception('Password change is only available for email/password accounts.');
        }
      }

      // Validate password length
      if (newPassword.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password in Firebase Auth
      await user.updatePassword(newPassword);

      // Store password change metadata in Firestore
      await _recordPasswordChange(user.uid);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
          message = 'Current password is incorrect';
          break;
        case 'weak-password':
          message = 'The new password is too weak';
          break;
        case 'requires-recent-login':
          message = 'Please log out and log in again to change password';
          break;
        default:
          message = e.message ?? 'An error occurred changing password';
      }
      throw Exception(message);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Password change failed: ${e.toString()}');
    }
  }

  /// Record password change event in Firestore for security tracking
  Future<void> _recordPasswordChange(String userId) async {
    try {
      final now = FieldValue.serverTimestamp();

      // Update user document with last password change
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'lastPasswordChange': now,
        'passwordChangeCount': FieldValue.increment(1),
      });

      // Record security event
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('securityEvents')
          .add({
        'type': 'password_change',
        'timestamp': now,
        'success': true,
      });
    } catch (e) {
      // Don't fail the password change if logging fails
      debugPrint('Failed to record password change: $e');
    }
  }

  /// Create new user profile on signup
  Future<void> _createNewUserProfile(User user, String email) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': email.split('@')[0],
        'email': user.email ?? email,
        'profileImageUrl': null,
        'photoUrl': null,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        'discoveryModeEnabled': true,
        'interests': [],
        'connections': [],
        'connectionCount': 0,
        'blockedUsers': [],
        'connectionTypes': [],
        'activities': [],
      }, SetOptions(merge: true));
      debugPrint('✓ New user profile created');
    } catch (e) {
      debugPrint('⚠️ Failed to create profile on signup: $e');
      rethrow;
    }
  }

  /// Update user profile on login
  Future<void> _updateUserProfileOnLogin(User user, String email) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        // Create profile if it doesn't exist
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email ?? email,
          'name': user.displayName ?? email.split('@')[0],
          'profileImageUrl': user.photoURL,
          'photoUrl': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
          'discoveryModeEnabled': true,
          'interests': [],
          'connections': [],
          'connectionCount': 0,
          'blockedUsers': [],
          'connectionTypes': [],
          'activities': [],
        });
      } else {
        // Just update last seen
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
        });
      }
      debugPrint('✓ User profile updated on login');
    } catch (e) {
      debugPrint('⚠️ Failed to update profile on login: $e');
      rethrow;
    }
  }

  /// Update Google user profile on login
  Future<void> _updateGoogleUserProfile(
      User user, GoogleSignInAccount googleUser, String? photoUrl) async {
    try {
      // Check if this is a new user or existing user
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final isNewUser = !doc.exists;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': user.displayName ?? googleUser.displayName ?? '',
        'email': user.email ?? googleUser.email,
        'profileImageUrl': photoUrl,
        'photoUrl': photoUrl,
        'lastSeen': FieldValue.serverTimestamp(),
        if (isNewUser) 'createdAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        if (isNewUser) ...{
          'discoveryModeEnabled': true,
          'interests': [],
          'connections': [],
          'connectionCount': 0,
          'blockedUsers': [],
          'connectionTypes': [],
          'activities': [],
        },
      }, SetOptions(merge: true));

      // Also update the auth profile with fixed URL
      if (photoUrl != null && photoUrl != user.photoURL) {
        try {
          await user.updatePhotoURL(photoUrl);
        } catch (e) {
          debugPrint('Could not update auth photo URL: $e');
        }
      }
      debugPrint('✓ Google user profile updated on login');
    } catch (e) {
      debugPrint('⚠️ Failed to update Google profile on login: $e');
      rethrow;
    }
  }
}
