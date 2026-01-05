import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Service for managing business media uploads
/// Handles image uploads for logos, covers, galleries, rooms, menu items, and products
class BusinessMediaService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Singleton pattern
  static final BusinessMediaService _instance = BusinessMediaService._internal();
  factory BusinessMediaService() => _instance;
  BusinessMediaService._internal();

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Upload business logo
  Future<String?> uploadLogo(File imageFile) async {
    return _uploadImage(imageFile, 'business_logos');
  }

  /// Upload business cover image
  Future<String?> uploadCoverImage(File imageFile) async {
    return _uploadImage(imageFile, 'business_covers');
  }

  /// Upload listing image
  Future<String?> uploadListingImage(File imageFile) async {
    return _uploadImage(imageFile, 'business_listings');
  }

  /// Upload business gallery image
  Future<String?> uploadGalleryImage(File imageFile) async {
    return _uploadImage(imageFile, 'business_gallery');
  }

  /// Generic image upload to a folder
  Future<String?> _uploadImage(File imageFile, String folder) async {
    if (_currentUserId == null) return null;

    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      final ref = _storage.ref().child('$folder/$_currentUserId/$fileName');

      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  /// Upload room image
  Future<String?> uploadRoomImage(String businessId, String roomId, File imageFile) async {
    try {
      final ref = _storage.ref().child('businesses/$businessId/rooms/$roomId/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading room image: $e');
      return null;
    }
  }

  /// Upload menu item image
  Future<String?> uploadMenuItemImage(String businessId, String itemId, File imageFile) async {
    try {
      final ref = _storage.ref().child('businesses/$businessId/menu/$itemId/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading menu item image: $e');
      return null;
    }
  }

  /// Upload product image
  Future<String?> uploadProductImage(String businessId, String productId, File imageFile) async {
    try {
      final ref = _storage.ref().child('businesses/$businessId/products/$productId/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading product image: $e');
      return null;
    }
  }

  /// Delete image by URL
  Future<bool> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting image: $e');
      return false;
    }
  }

  /// Upload multiple images and return list of URLs
  Future<List<String>> uploadMultipleImages(List<File> imageFiles, String folder) async {
    final urls = <String>[];
    for (final file in imageFiles) {
      final url = await _uploadImage(file, folder);
      if (url != null) {
        urls.add(url);
      }
    }
    return urls;
  }

  /// Upload post image
  Future<String?> uploadPostImage(File imageFile) async {
    return _uploadImage(imageFile, 'business_posts');
  }
}
