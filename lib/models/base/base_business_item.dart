import 'package:cloud_firestore/cloud_firestore.dart';

/// Base class for all business items (Products, Menu Items, Rooms, Services).
/// Provides common properties and methods for Firestore serialization.
abstract class BaseBusinessItem {
  /// Unique identifier
  String get id;

  /// Business this item belongs to
  String get businessId;

  /// Item name/title
  String get name;

  /// Optional description
  String? get description;

  /// Primary image URL
  String? get imageUrl;

  /// Whether the item is currently active/available
  bool get isActive;

  /// Sort order for display
  int get sortOrder;

  /// When the item was created
  DateTime get createdAt;

  /// When the item was last updated
  DateTime? get updatedAt;

  /// Convert to Firestore map
  Map<String, dynamic> toMap();

  /// Create a copy with updated fields
  BaseBusinessItem copyWith();

  /// Firestore collection path for this item type
  String get collectionPath;
}

/// Mixin for Firestore timestamp handling
mixin FirestoreTimestamps {
  /// Convert DateTime to Firestore Timestamp
  static Timestamp? toTimestamp(DateTime? dateTime) {
    return dateTime != null ? Timestamp.fromDate(dateTime) : null;
  }

  /// Convert Firestore Timestamp to DateTime
  static DateTime? fromTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return null;
  }

  /// Get current timestamp for Firestore
  static Timestamp get now => Timestamp.now();
}

/// Mixin for items with availability tracking
mixin Availability {
  bool get isActive;
  int get stockCount;

  /// Check if item is in stock
  bool get isInStock => stockCount > 0 || stockCount == -1; // -1 = unlimited

  /// Check if item is available for purchase
  bool get isAvailable => isActive && isInStock;

  /// Get availability status text
  String get availabilityStatus {
    if (!isActive) return 'Unavailable';
    if (stockCount == 0) return 'Out of Stock';
    if (stockCount == -1) return 'In Stock';
    if (stockCount <= 5) return 'Low Stock ($stockCount left)';
    return 'In Stock';
  }

  /// Get stock badge color
  String get stockBadgeColor {
    if (!isActive || stockCount == 0) return 'red';
    if (stockCount <= 5 && stockCount != -1) return 'orange';
    return 'green';
  }
}

/// Mixin for items with category support
mixin Categorizable {
  String? get categoryId;
  String? get categoryName;

  bool get hasCategory => categoryId != null && categoryId!.isNotEmpty;
}

/// Mixin for items with image gallery
mixin ImageGallery {
  String? get imageUrl;
  List<String> get images;

  /// Get display image (primary or first from gallery)
  String? get displayImage => imageUrl ?? (images.isNotEmpty ? images.first : null);

  /// Check if item has images
  bool get hasImages => displayImage != null;

  /// Get all images including primary
  List<String> get allImages {
    final all = <String>[];
    if (imageUrl != null) all.add(imageUrl!);
    all.addAll(images.where((img) => img != imageUrl));
    return all;
  }
}

/// Mixin for items that can be featured/promoted
mixin Featurable {
  bool get isFeatured;
  DateTime? get featuredUntil;

  /// Check if feature is currently active
  bool get isCurrentlyFeatured {
    if (!isFeatured) return false;
    if (featuredUntil == null) return true;
    return featuredUntil!.isAfter(DateTime.now());
  }
}

/// Mixin for items with tags/labels
mixin Taggable {
  List<String> get tags;

  bool hasTag(String tag) => tags.contains(tag.toLowerCase());

  bool hasAnyTag(List<String> checkTags) =>
      checkTags.any((tag) => hasTag(tag));

  bool hasAllTags(List<String> checkTags) =>
      checkTags.every((tag) => hasTag(tag));
}
