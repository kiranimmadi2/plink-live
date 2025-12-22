import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service for managing library items (saved chats, favorites, archived, downloads, images, shared links)
class LibraryService {
  static final LibraryService _instance = LibraryService._internal();
  factory LibraryService() => _instance;
  LibraryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // ==================== SAVED CHATS ====================

  /// Get all saved chats for the current user
  Future<List<SavedChatItem>> getSavedChats() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('saved_chats')
          .orderBy('savedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => SavedChatItem.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting saved chats: $e');
      return [];
    }
  }

  /// Save a chat to library
  Future<bool> saveChat({
    required String conversationId,
    required String title,
    required String lastMessage,
    String? otherUserName,
    String? otherUserPhoto,
  }) async {
    if (_userId == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('saved_chats')
          .doc(conversationId)
          .set({
        'conversationId': conversationId,
        'title': title,
        'lastMessage': lastMessage,
        'otherUserName': otherUserName,
        'otherUserPhoto': otherUserPhoto,
        'savedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error saving chat: $e');
      return false;
    }
  }

  /// Remove a saved chat
  Future<bool> removeSavedChat(String conversationId) async {
    if (_userId == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('saved_chats')
          .doc(conversationId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error removing saved chat: $e');
      return false;
    }
  }

  // ==================== FAVORITES ====================

  /// Get all favorite items
  Future<List<FavoriteItem>> getFavorites() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('favorites')
          .orderBy('addedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => FavoriteItem.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting favorites: $e');
      return [];
    }
  }

  /// Add item to favorites
  Future<bool> addToFavorites({
    required String itemId,
    required String type, // 'message', 'post', 'image', 'link'
    required String title,
    String? content,
    String? imageUrl,
  }) async {
    if (_userId == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('favorites')
          .doc(itemId)
          .set({
        'itemId': itemId,
        'type': type,
        'title': title,
        'content': content,
        'imageUrl': imageUrl,
        'addedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding to favorites: $e');
      return false;
    }
  }

  /// Remove from favorites
  Future<bool> removeFromFavorites(String itemId) async {
    if (_userId == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('favorites')
          .doc(itemId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error removing from favorites: $e');
      return false;
    }
  }

  // ==================== ARCHIVED ====================

  /// Get all archived conversations
  Future<List<ArchivedItem>> getArchivedItems() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('archived')
          .orderBy('archivedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => ArchivedItem.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting archived items: $e');
      return [];
    }
  }

  /// Archive an item
  Future<bool> archiveItem({
    required String itemId,
    required String type, // 'conversation', 'post'
    required String title,
    String? preview,
  }) async {
    if (_userId == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('archived')
          .doc(itemId)
          .set({
        'itemId': itemId,
        'type': type,
        'title': title,
        'preview': preview,
        'archivedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error archiving item: $e');
      return false;
    }
  }

  /// Unarchive an item
  Future<bool> unarchiveItem(String itemId) async {
    if (_userId == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('archived')
          .doc(itemId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error unarchiving item: $e');
      return false;
    }
  }

  // ==================== DOWNLOADS ====================

  /// Get all downloaded files (stored locally)
  Future<List<DownloadedItem>> getDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadsJson = prefs.getStringList('downloads') ?? [];

      final downloads = <DownloadedItem>[];
      for (final json in downloadsJson) {
        try {
          final data = jsonDecode(json) as Map<String, dynamic>;
          final item = DownloadedItem.fromJson(data);
          // Check if file still exists
          if (await File(item.filePath).exists()) {
            downloads.add(item);
          }
        } catch (e) {
          debugPrint('Error parsing download item: $e');
        }
      }

      return downloads;
    } catch (e) {
      debugPrint('Error getting downloads: $e');
      return [];
    }
  }

  /// Add a downloaded file
  Future<bool> addDownload({
    required String fileName,
    required String filePath,
    required String fileType,
    int? fileSize,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadsJson = prefs.getStringList('downloads') ?? [];

      final newItem = DownloadedItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: fileName,
        filePath: filePath,
        fileType: fileType,
        fileSize: fileSize ?? 0,
        downloadedAt: DateTime.now(),
      );

      downloadsJson.add(jsonEncode(newItem.toJson()));
      await prefs.setStringList('downloads', downloadsJson);
      return true;
    } catch (e) {
      debugPrint('Error adding download: $e');
      return false;
    }
  }

  /// Delete a downloaded file
  Future<bool> deleteDownload(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadsJson = prefs.getStringList('downloads') ?? [];

      final updatedList = <String>[];
      for (final json in downloadsJson) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        if (data['id'] != id) {
          updatedList.add(json);
        } else {
          // Delete the actual file
          try {
            final file = File(data['filePath'] as String);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            debugPrint('Error deleting file: $e');
          }
        }
      }

      await prefs.setStringList('downloads', updatedList);
      return true;
    } catch (e) {
      debugPrint('Error deleting download: $e');
      return false;
    }
  }

  /// Get downloads directory path
  Future<String> getDownloadsPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${directory.path}/Downloads');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir.path;
  }

  // ==================== IMAGES ====================

  /// Get all saved images from conversations
  Future<List<ImageItem>> getSavedImages() async {
    if (_userId == null) return [];

    try {
      // Get images from conversations where user is a participant
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: _userId)
          .get();

      final images = <ImageItem>[];

      for (final convDoc in conversationsSnapshot.docs) {
        final messagesSnapshot = await convDoc.reference
            .collection('messages')
            .where('imageUrl', isNull: false)
            .orderBy('timestamp', descending: true)
            .limit(50)
            .get();

        for (final msgDoc in messagesSnapshot.docs) {
          final data = msgDoc.data();
          final imageUrl = data['imageUrl'] as String?;
          if (imageUrl != null && imageUrl.isNotEmpty) {
            images.add(ImageItem(
              id: msgDoc.id,
              imageUrl: imageUrl,
              conversationId: convDoc.id,
              senderId: data['senderId'] as String? ?? '',
              timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            ));
          }
        }
      }

      // Sort by timestamp
      images.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return images;
    } catch (e) {
      debugPrint('Error getting saved images: $e');
      return [];
    }
  }

  // ==================== SHARED LINKS ====================

  /// Get all shared links
  Future<List<SharedLinkItem>> getSharedLinks() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('shared_links')
          .orderBy('sharedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => SharedLinkItem.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting shared links: $e');
      return [];
    }
  }

  /// Save a shared link
  Future<bool> saveSharedLink({
    required String url,
    String? title,
    String? description,
    String? imageUrl,
  }) async {
    if (_userId == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('shared_links')
          .add({
        'url': url,
        'title': title ?? url,
        'description': description,
        'imageUrl': imageUrl,
        'sharedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error saving shared link: $e');
      return false;
    }
  }

  /// Delete a shared link
  Future<bool> deleteSharedLink(String linkId) async {
    if (_userId == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('shared_links')
          .doc(linkId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting shared link: $e');
      return false;
    }
  }

  // ==================== ITEM COUNTS ====================

  /// Get counts for all library categories
  Future<Map<String, int>> getLibraryCounts() async {
    if (_userId == null) {
      return {
        'savedChats': 0,
        'favorites': 0,
        'archived': 0,
        'downloads': 0,
        'images': 0,
        'sharedLinks': 0,
      };
    }

    try {
      final results = await Future.wait([
        _firestore.collection('users').doc(_userId).collection('saved_chats').count().get(),
        _firestore.collection('users').doc(_userId).collection('favorites').count().get(),
        _firestore.collection('users').doc(_userId).collection('archived').count().get(),
        getDownloads(),
        getSavedImages(),
        _firestore.collection('users').doc(_userId).collection('shared_links').count().get(),
      ]);

      return {
        'savedChats': (results[0] as AggregateQuerySnapshot).count ?? 0,
        'favorites': (results[1] as AggregateQuerySnapshot).count ?? 0,
        'archived': (results[2] as AggregateQuerySnapshot).count ?? 0,
        'downloads': (results[3] as List<DownloadedItem>).length,
        'images': (results[4] as List<ImageItem>).length,
        'sharedLinks': (results[5] as AggregateQuerySnapshot).count ?? 0,
      };
    } catch (e) {
      debugPrint('Error getting library counts: $e');
      return {
        'savedChats': 0,
        'favorites': 0,
        'archived': 0,
        'downloads': 0,
        'images': 0,
        'sharedLinks': 0,
      };
    }
  }
}

// ==================== DATA MODELS ====================

class SavedChatItem {
  final String id;
  final String conversationId;
  final String title;
  final String lastMessage;
  final String? otherUserName;
  final String? otherUserPhoto;
  final DateTime savedAt;

  SavedChatItem({
    required this.id,
    required this.conversationId,
    required this.title,
    required this.lastMessage,
    this.otherUserName,
    this.otherUserPhoto,
    required this.savedAt,
  });

  factory SavedChatItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavedChatItem(
      id: doc.id,
      conversationId: data['conversationId'] ?? doc.id,
      title: data['title'] ?? 'Untitled Chat',
      lastMessage: data['lastMessage'] ?? '',
      otherUserName: data['otherUserName'],
      otherUserPhoto: data['otherUserPhoto'],
      savedAt: (data['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class FavoriteItem {
  final String id;
  final String itemId;
  final String type;
  final String title;
  final String? content;
  final String? imageUrl;
  final DateTime addedAt;

  FavoriteItem({
    required this.id,
    required this.itemId,
    required this.type,
    required this.title,
    this.content,
    this.imageUrl,
    required this.addedAt,
  });

  factory FavoriteItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FavoriteItem(
      id: doc.id,
      itemId: data['itemId'] ?? doc.id,
      type: data['type'] ?? 'unknown',
      title: data['title'] ?? 'Untitled',
      content: data['content'],
      imageUrl: data['imageUrl'],
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ArchivedItem {
  final String id;
  final String itemId;
  final String type;
  final String title;
  final String? preview;
  final DateTime archivedAt;

  ArchivedItem({
    required this.id,
    required this.itemId,
    required this.type,
    required this.title,
    this.preview,
    required this.archivedAt,
  });

  factory ArchivedItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ArchivedItem(
      id: doc.id,
      itemId: data['itemId'] ?? doc.id,
      type: data['type'] ?? 'unknown',
      title: data['title'] ?? 'Untitled',
      preview: data['preview'],
      archivedAt: (data['archivedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class DownloadedItem {
  final String id;
  final String fileName;
  final String filePath;
  final String fileType;
  final int fileSize;
  final DateTime downloadedAt;

  DownloadedItem({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileType,
    required this.fileSize,
    required this.downloadedAt,
  });

  factory DownloadedItem.fromJson(Map<String, dynamic> json) {
    return DownloadedItem(
      id: json['id'] ?? '',
      fileName: json['fileName'] ?? 'Unknown',
      filePath: json['filePath'] ?? '',
      fileType: json['fileType'] ?? 'unknown',
      fileSize: json['fileSize'] ?? 0,
      downloadedAt: DateTime.tryParse(json['downloadedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'fileType': fileType,
      'fileSize': fileSize,
      'downloadedAt': downloadedAt.toIso8601String(),
    };
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class ImageItem {
  final String id;
  final String imageUrl;
  final String conversationId;
  final String senderId;
  final DateTime timestamp;

  ImageItem({
    required this.id,
    required this.imageUrl,
    required this.conversationId,
    required this.senderId,
    required this.timestamp,
  });
}

class SharedLinkItem {
  final String id;
  final String url;
  final String title;
  final String? description;
  final String? imageUrl;
  final DateTime sharedAt;

  SharedLinkItem({
    required this.id,
    required this.url,
    required this.title,
    this.description,
    this.imageUrl,
    required this.sharedAt,
  });

  factory SharedLinkItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SharedLinkItem(
      id: doc.id,
      url: data['url'] ?? '',
      title: data['title'] ?? data['url'] ?? 'Untitled',
      description: data['description'],
      imageUrl: data['imageUrl'],
      sharedAt: (data['sharedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
