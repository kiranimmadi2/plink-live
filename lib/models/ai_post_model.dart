import 'package:cloud_firestore/cloud_firestore.dart';

/// AI-driven post model without hardcoded categories
/// Everything is dynamically understood by AI
class AIPostModel {
  final String id;
  final String userId;
  final String originalPrompt; // User's original input
  final Map<String, dynamic> intentAnalysis; // AI's understanding
  final Map<String, dynamic> clarificationAnswers; // User's answers to AI questions
  final List<double> embedding; // Semantic embedding for matching
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;
  final String? location;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> metadata; // Flexible metadata
  final List<String> matchedUserIds;
  final int viewCount;

  AIPostModel({
    required this.id,
    required this.userId,
    required this.originalPrompt,
    required this.intentAnalysis,
    required this.clarificationAnswers,
    required this.embedding,
    required this.createdAt,
    this.expiresAt,
    this.isActive = true,
    this.location,
    this.latitude,
    this.longitude,
    required this.metadata,
    this.matchedUserIds = const [],
    this.viewCount = 0,
  });

  factory AIPostModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AIPostModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      originalPrompt: data['originalPrompt'] ?? '',
      intentAnalysis: data['intentAnalysis'] ?? {},
      clarificationAnswers: data['clarificationAnswers'] ?? {},
      embedding: data['embedding'] != null 
          ? List<double>.from(data['embedding']) 
          : [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: data['expiresAt'] != null 
          ? (data['expiresAt'] as Timestamp).toDate() 
          : null,
      isActive: data['isActive'] ?? true,
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      metadata: data['metadata'] ?? {},
      matchedUserIds: data['matchedUserIds'] != null 
          ? List<String>.from(data['matchedUserIds']) 
          : [],
      viewCount: data['viewCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'originalPrompt': originalPrompt,
      'intentAnalysis': intentAnalysis,
      'clarificationAnswers': clarificationAnswers,
      'embedding': embedding,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isActive': isActive,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'metadata': metadata,
      'matchedUserIds': matchedUserIds,
      'viewCount': viewCount,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  /// Get the primary intent from AI analysis
  String get primaryIntent {
    return intentAnalysis['primary_intent'] ?? originalPrompt;
  }

  /// Get action type (seeking/offering/neutral)
  String get actionType {
    return intentAnalysis['action_type'] ?? 'neutral';
  }

  /// Get extracted entities
  Map<String, dynamic> get entities {
    return intentAnalysis['entities'] ?? {};
  }

  /// Get search keywords for matching
  List<String> get searchKeywords {
    final keywords = intentAnalysis['search_keywords'];
    if (keywords is List) {
      return List<String>.from(keywords);
    }
    return originalPrompt.toLowerCase().split(' ');
  }

  /// Get a display title (AI-generated or extracted)
  String get displayTitle {
    // Try to get a concise version from entities or use primary intent
    final item = entities['item'];
    if (item != null && item.toString().isNotEmpty) {
      if (actionType == 'offering') {
        return 'Offering: $item';
      } else if (actionType == 'seeking') {
        return 'Looking for: $item';
      }
      return item.toString();
    }
    return primaryIntent;
  }

  /// Get a display description
  String get displayDescription {
    // Combine original prompt with key details
    List<String> details = [originalPrompt];
    
    if (entities['price'] != null) {
      details.add('Price: ${entities['price']}');
    }
    if (location != null && location!.isNotEmpty) {
      details.add('Location: $location');
    }
    if (entities['time'] != null) {
      details.add('Time: ${entities['time']}');
    }
    
    return details.join(' • ');
  }

  /// Check if this post needs more information
  bool get needsClarification {
    final clarificationsNeeded = intentAnalysis['clarifications_needed'];
    return clarificationsNeeded != null && 
           clarificationsNeeded is List && 
           clarificationsNeeded.isNotEmpty;
  }

  /// Get emotional tone for UI styling
  String get emotionalTone {
    return intentAnalysis['emotional_tone'] ?? 'casual';
  }

  /// Copy with updates
  AIPostModel copyWith({
    String? id,
    String? userId,
    String? originalPrompt,
    Map<String, dynamic>? intentAnalysis,
    Map<String, dynamic>? clarificationAnswers,
    List<double>? embedding,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isActive,
    String? location,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? metadata,
    List<String>? matchedUserIds,
    int? viewCount,
  }) {
    return AIPostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      originalPrompt: originalPrompt ?? this.originalPrompt,
      intentAnalysis: intentAnalysis ?? this.intentAnalysis,
      clarificationAnswers: clarificationAnswers ?? this.clarificationAnswers,
      embedding: embedding ?? this.embedding,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      metadata: metadata ?? this.metadata,
      matchedUserIds: matchedUserIds ?? this.matchedUserIds,
      viewCount: viewCount ?? this.viewCount,
    );
  }
}