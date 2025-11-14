import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/photo_url_helper.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update last seen and ensure profile exists
      if (result.user != null) {
        final user = result.user!;
        
        // Check if profile exists
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        
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
          });
        } else {
          // Just update last seen
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'lastSeen': FieldValue.serverTimestamp(),
            'isOnline': true,
          });
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
      
      // Create initial Firestore profile for email signup
      if (result.user != null) {
        final user = result.user!;
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': email.split('@')[0], // Use email prefix as initial name
          'email': user.email ?? email,
          'profileImageUrl': null,
          'photoUrl': null, // Keep for backward compatibility
          'lastSeen': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'isOnline': true,
        }, SetOptions(merge: true));
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
      // Check if already signed in
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
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
      
      // Save Google profile photo URL to Firestore
      if (result.user != null) {
        final user = result.user!;
        
        // Fix Google photo URL to get higher quality version
        String? photoUrl = user.photoURL ?? googleUser.photoUrl;
        photoUrl = PhotoUrlHelper.getHighQualityGooglePhoto(photoUrl);
        
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': user.displayName ?? googleUser.displayName ?? '',
          'email': user.email ?? googleUser.email,
          'profileImageUrl': photoUrl,
          'photoUrl': photoUrl, // Keep for backward compatibility
          'lastSeen': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'isOnline': true,
        }, SetOptions(merge: true));
        
        // Also update the auth profile with fixed URL
        if (photoUrl != null && photoUrl != user.photoURL) {
          try {
            await user.updatePhotoURL(photoUrl);
          } catch (e) {
            print('Could not update auth photo URL: $e');
          }
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
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
      
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
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
}