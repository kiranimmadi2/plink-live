import 'package:cloud_firestore/cloud_firestore.dart';

/// Abstract base class for business category models.
/// Used by: ProductCategoryModel, MenuCategoryModel
///
/// Provides common properties for organizing items into categories
/// within a business context.
abstract class BaseCategoryModel {
  /// Unique identifier for the category
  String get id;

  /// Business this category belongs to
  String get businessId;

  /// Category name
  String get name;

  /// Optional description of the category
  String? get description;

  /// Optional image URL for the category
  String? get image;

  /// Sort order for display
  int get sortOrder;

  /// Whether the category is currently active
  bool get isActive;

  /// When the category was created
  DateTime get createdAt;

  /// When the category was last updated (optional)
  DateTime? get updatedAt;

  /// Convert to Firestore map
  Map<String, dynamic> toMap();

  /// Create a copy with updated fields
  BaseCategoryModel copyWith();

  /// Check if category has an image
  bool get hasImage => image != null && image!.isNotEmpty;

  /// Check if category has a description
  bool get hasDescription => description != null && description!.isNotEmpty;
}

/// Mixin for common category Firestore serialization
mixin CategoryFirestoreMixin {
  String get businessId;
  String get name;
  String? get description;
  String? get image;
  int get sortOrder;
  bool get isActive;
  DateTime get createdAt;
  DateTime? get updatedAt;

  /// Convert base category fields to map
  Map<String, dynamic> baseCategoryToMap() {
    return {
      'businessId': businessId,
      'name': name,
      'description': description,
      'image': image,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  /// Parse base category fields from map
  static Map<String, dynamic> parseBaseFields(Map<String, dynamic> map) {
    return {
      'businessId': map['businessId'] ?? '',
      'name': map['name'] ?? '',
      'description': map['description'],
      'image': map['image'],
      'sortOrder': map['sortOrder'] ?? 0,
      'isActive': map['isActive'] ?? true,
      'createdAt': map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      'updatedAt': map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    };
  }
}
