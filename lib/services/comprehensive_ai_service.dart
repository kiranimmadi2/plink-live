import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/user_profile.dart';
import '../models/ai_post_model.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import 'location_service.dart';
import 'profile_service.dart';
import 'conversation_service.dart';
import 'notification_service.dart';
import '../config/api_config.dart';

/// Comprehensive AI service that handles everything from understanding user intent
/// to finding the best matching profiles based on location, price, and context
class ComprehensiveAIService {
  static final ComprehensiveAIService _instance = ComprehensiveAIService._internal();
  factory ComprehensiveAIService() => _instance;
  ComprehensiveAIService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileService _profileService = ProfileService();
  final LocationService _locationService = LocationService();
  final ConversationService _conversationService = ConversationService();
  final NotificationService _notificationService = NotificationService();

  late GenerativeModel _model;
  late GenerativeModel _embeddingModel;

  // Collections
  static const String POSTS_COLLECTION = 'ai_posts';
  static const String USERS_COLLECTION = 'users';
  static const String CONVERSATIONS_COLLECTION = 'conversations';
  static const String MESSAGES_COLLECTION = 'messages';
  static const String MATCHES_COLLECTION = 'ai_matches';

  Future<void> initialize() async {
    _model = GenerativeModel(
      model: ApiConfig.geminiFlashModel,
      apiKey: ApiConfig.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: ApiConfig.temperature,
        topK: ApiConfig.topK,
        topP: ApiConfig.topP,
        maxOutputTokens: ApiConfig.maxOutputTokens,
      ),
    );

    _embeddingModel = GenerativeModel(
      model: ApiConfig.geminiEmbeddingModel,
      apiKey: ApiConfig.geminiApiKey,
    );
  }

  /// Main entry point: Create a post with full AI understanding
  Future<CreatePostResult> createSmartPost(String userInput) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // 1. Get user profile and context
      final userProfile = await _profileService.getUserProfile(userId);
      if (userProfile == null) throw Exception('User profile not found');

      // 2. Get user's location SILENTLY in background
      final position = await _locationService.getCurrentLocation(silent: true);
      LocationInfo? location;
      if (position != null) {
        location = LocationInfo(
          latitude: position.latitude,
          longitude: position.longitude,
          address: '',
          city: '',
          country: '',
        );
      }

      // 3. Analyze user's chat history for context
      final userContext = await _analyzeUserContext(userId);

      // 4. Understand intent with full context
      final intentAnalysis = await _understandIntentWithContext(
        userInput,
        userProfile,
        location,
        userContext,
      );

      // 5. Generate embedding for semantic matching
      final embedding = await _generateEmbedding(intentAnalysis);

      // 6. Create the post
      final post = AIPostModel(
        id: '',
        userId: userId,
        originalPrompt: userInput,
        intentAnalysis: intentAnalysis,
        clarificationAnswers: {},
        embedding: embedding,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        isActive: true,
        location: location?.address.isEmpty == false ? location?.address : null,
        latitude: location?.latitude,
        longitude: location?.longitude,
        metadata: {
          'userProfile': {
            'name': userProfile['name'] ?? '',
            'bio': userProfile['bio'] ?? '',
            'interests': userProfile['interests'] ?? [],
            'verified': userProfile['isVerified'] ?? false,
          },
          'context': userContext,
        },
      );

      // 7. Save to Firestore
      final docRef = await _firestore.collection(POSTS_COLLECTION).add(post.toFirestore());
      final savedPost = post.copyWith(id: docRef.id);

      // 8. Find immediate matches
      final matches = await findBestMatches(savedPost);

      return CreatePostResult(
        post: savedPost,
        matches: matches,
        needsClarification: _needsClarification(intentAnalysis),
      );
    } catch (e) {
      debugPrint('Error creating smart post: $e');
      throw e;
    }
  }

  /// Analyze user's context from their history
  Future<Map<String, dynamic>> _analyzeUserContext(String userId) async {
    try {
      // Get user's recent posts
      final recentPosts = await _firestore
          .collection(POSTS_COLLECTION)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      // Get user's recent conversations
      final recentConversations = await _firestore
          .collection(CONVERSATIONS_COLLECTION)
          .where('participantIds', arrayContains: userId)
          .orderBy('lastMessageTime', descending: true)
          .limit(5)
          .get();

      // Get user's recent matches
      final recentMatches = await _firestore
          .collection(MATCHES_COLLECTION)
          .where('user1Id', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      return {
        'recentSearches': recentPosts.docs.map((doc) {
          final data = doc.data();
          return data['originalPrompt'] ?? '';
        }).toList(),
        'activeConversations': recentConversations.docs.length,
        'recentMatchTypes': recentMatches.docs.map((doc) {
          final data = doc.data();
          return data['matchType'] ?? '';
        }).toList(),
        'preferences': await _extractUserPreferences(userId),
      };
    } catch (e) {
      debugPrint('Error analyzing user context: $e');
      return {};
    }
  }

  /// Extract user preferences from their history
  Future<Map<String, dynamic>> _extractUserPreferences(String userId) async {
    try {
      // Analyze past interactions to understand preferences
      final posts = await _firestore
          .collection(POSTS_COLLECTION)
          .where('userId', isEqualTo: userId)
          .get();

      if (posts.docs.isEmpty) return {};

      final prompt = '''
      Analyze these user searches and extract their preferences:
      ${posts.docs.map((d) => d.data()['originalPrompt']).join(', ')}
      
      Return JSON with:
      {
        "priceRange": "budget/moderate/premium/varies",
        "locationPreference": "local/city-wide/remote/flexible",
        "urgency": "immediate/soon/flexible",
        "communicationStyle": "formal/casual/friendly",
        "interests": ["list of detected interests"]
      }
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? '{}';
      return Map<String, dynamic>.from(jsonDecode(text));
    } catch (e) {
      return {};
    }
  }

  /// Understand intent with full user context
  Future<Map<String, dynamic>> _understandIntentWithContext(
    String userInput,
    Map<String, dynamic> userProfile,
    LocationInfo? location,
    Map<String, dynamic> userContext,
  ) async {
    try {
      final prompt = '''
      Analyze this user request with their full context:

      REQUEST: "$userInput"

      USER PROFILE:
      - Name: ${userProfile['name'] ?? 'Unknown'}
      - Bio: ${userProfile['bio'] ?? 'No bio'}
      - Interests: ${(userProfile['interests'] as List?)?.join(', ') ?? 'None'}
      - Location: ${location?.address ?? 'Unknown'}
      - Verified: ${userProfile['isVerified'] ?? false}
      
      USER CONTEXT:
      - Recent searches: ${userContext['recentSearches']}
      - Preferences: ${userContext['preferences']}
      
      Provide comprehensive understanding in JSON:
      {
        "primary_intent": "clear description of what user wants",
        "action_type": "seeking/offering/neutral",
        "urgency_level": "immediate/soon/flexible",
        "entities": {
          "item": "specific item/service/person",
          "price": "exact price or range",
          "price_min": null or number,
          "price_max": null or number,
          "location": "specific location if different from user's",
          "distance_preference": "exact location/neighborhood/city/anywhere",
          "time": "when needed",
          "quantity": "how many",
          "condition": "new/used/any",
          "brand": "specific brand if mentioned",
          "specifications": {}
        },
        "matching_criteria": {
          "must_match": ["essential criteria for a match"],
          "should_match": ["preferred criteria"],
          "must_not_match": ["deal breakers"]
        },
        "clarifications_needed": ["missing important information"],
        "search_keywords": ["keywords for matching"],
        "complementary_intents": ["intents that would match well"],
        "suggested_price": "AI suggestion based on market",
        "location_importance": "critical/important/flexible/irrelevant",
        "profile_requirements": {
          "verification_needed": true/false,
          "minimum_rating": null or number,
          "preferred_interests": ["relevant interests"]
        }
      }
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? '{}';
      return Map<String, dynamic>.from(jsonDecode(text));
    } catch (e) {
      debugPrint('Error understanding intent: $e');
      return {
        'primary_intent': userInput,
        'action_type': 'neutral',
        'entities': {},
        'search_keywords': userInput.split(' '),
      };
    }
  }

  /// Find the best matching profiles
  Future<List<SmartMatch>> findBestMatches(AIPostModel userPost) async {
    try {
      // Get all active posts from other users
      final snapshot = await _firestore
          .collection(POSTS_COLLECTION)
          .where('userId', isNotEqualTo: userPost.userId)
          .where('isActive', isEqualTo: true)
          .get();

      List<SmartMatch> matches = [];

      for (var doc in snapshot.docs) {
        final otherPost = AIPostModel.fromFirestore(doc);
        
        // Get the other user's profile
        final otherProfileData = await _profileService.getUserProfile(otherPost.userId);
        if (otherProfileData == null) continue;

        // Convert Map to UserProfile
        final otherProfile = UserProfile.fromMap(otherProfileData, otherPost.userId);

        // Calculate comprehensive match score
        final matchAnalysis = await _analyzeMatch(userPost, otherPost, otherProfile);

        if (matchAnalysis.score > 0.5) {
          matches.add(SmartMatch(
            profile: otherProfile,
            post: otherPost,
            analysis: matchAnalysis,
          ));
        }
      }

      // Sort by score (best matches first)
      matches.sort((a, b) => b.analysis.score.compareTo(a.analysis.score));
      
      // Limit to top 20 matches
      return matches.take(20).toList();
    } catch (e) {
      debugPrint('Error finding matches: $e');
      return [];
    }
  }

  /// Analyze match between two posts and profiles
  Future<MatchAnalysis> _analyzeMatch(
    AIPostModel userPost,
    AIPostModel otherPost,
    UserProfile otherProfile,
  ) async {
    try {
      final userIntent = userPost.intentAnalysis;
      final otherIntent = otherPost.intentAnalysis;

      // 1. Check intent compatibility
      final intentScore = await _checkIntentCompatibility(userIntent, otherIntent);
      
      // 2. Check location compatibility
      final locationScore = _calculateLocationScore(userPost, otherPost, userIntent, otherIntent);
      
      // 3. Check price compatibility
      final priceScore = _calculatePriceScore(userIntent, otherIntent);
      
      // 4. Check profile compatibility
      final profileScore = await _calculateProfileScore(
        userPost.metadata['userProfile'] ?? {},
        otherProfile,
        userIntent,
      );
      
      // 5. Semantic similarity
      final semanticScore = _calculateSemanticSimilarity(userPost.embedding, otherPost.embedding);
      
      // 6. Timing score
      final timingScore = _calculateTimingScore(userPost, otherPost, userIntent, otherIntent);

      // Calculate weighted total score
      final totalScore = (
        intentScore * 0.35 +
        locationScore * 0.20 +
        priceScore * 0.15 +
        profileScore * 0.15 +
        semanticScore * 0.10 +
        timingScore * 0.05
      ).clamp(0.0, 1.0);

      // Generate explanation
      final explanation = await _generateMatchExplanation(
        userPost,
        otherPost,
        otherProfile,
        totalScore,
      );

      return MatchAnalysis(
        score: totalScore,
        intentScore: intentScore,
        locationScore: locationScore,
        priceScore: priceScore,
        profileScore: profileScore,
        semanticScore: semanticScore,
        timingScore: timingScore,
        explanation: explanation,
        conversationStarter: await _generateConversationStarter(userPost, otherPost, otherProfile),
      );
    } catch (e) {
      debugPrint('Error analyzing match: $e');
      return MatchAnalysis(score: 0);
    }
  }

  /// Check if two intents are compatible
  Future<double> _checkIntentCompatibility(
    Map<String, dynamic> intent1,
    Map<String, dynamic> intent2,
  ) async {
    try {
      final prompt = '''
      Are these two intents compatible for matching?
      
      Intent 1: ${intent1['primary_intent']}
      Action: ${intent1['action_type']}
      Details: ${intent1['entities']}
      
      Intent 2: ${intent2['primary_intent']}
      Action: ${intent2['action_type']}
      Details: ${intent2['entities']}
      
      Return a compatibility score from 0.0 to 1.0 and explain why.
      Consider if they are complementary (buyer-seller, seeker-provider).
      
      Return JSON: {"score": 0.0-1.0, "reason": "explanation"}
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? '{}';
      final result = Map<String, dynamic>.from(jsonDecode(text));
      return (result['score'] ?? 0.0).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  /// Calculate location compatibility score
  double _calculateLocationScore(
    AIPostModel post1,
    AIPostModel post2,
    Map<String, dynamic> intent1,
    Map<String, dynamic> intent2,
  ) {
    // Check location importance
    final loc1Importance = intent1['location_importance'] ?? 'flexible';
    final loc2Importance = intent2['location_importance'] ?? 'flexible';
    
    if (loc1Importance == 'irrelevant' || loc2Importance == 'irrelevant') {
      return 1.0;
    }

    // Calculate distance if both have coordinates
    if (post1.latitude != null && post2.latitude != null) {
      final distance = _calculateDistance(
        post1.latitude!,
        post1.longitude!,
        post2.latitude!,
        post2.longitude!,
      );

      // Score based on distance and importance
      if (loc1Importance == 'critical' || loc2Importance == 'critical') {
        if (distance < 2) return 1.0;
        if (distance < 5) return 0.8;
        if (distance < 10) return 0.5;
        return 0.2;
      } else if (loc1Importance == 'important' || loc2Importance == 'important') {
        if (distance < 5) return 1.0;
        if (distance < 15) return 0.8;
        if (distance < 30) return 0.6;
        return 0.3;
      } else {
        // Flexible
        if (distance < 10) return 1.0;
        if (distance < 30) return 0.8;
        if (distance < 50) return 0.6;
        return 0.4;
      }
    }

    // No location data available
    return 0.5;
  }

  /// Calculate price compatibility
  double _calculatePriceScore(
    Map<String, dynamic> intent1,
    Map<String, dynamic> intent2,
  ) {
    final entities1 = intent1['entities'] ?? {};
    final entities2 = intent2['entities'] ?? {};
    
    // Extract prices
    final price1 = _parsePrice(entities1['price']);
    final priceMin1 = entities1['price_min']?.toDouble();
    final priceMax1 = entities1['price_max']?.toDouble();
    
    final price2 = _parsePrice(entities2['price']);
    final priceMin2 = entities2['price_min']?.toDouble();
    final priceMax2 = entities2['price_max']?.toDouble();
    
    // If no price info, assume compatible
    if (price1 == null && price2 == null && 
        priceMin1 == null && priceMin2 == null) {
      return 1.0;
    }
    
    // Check if one is selling and other is buying
    if (intent1['action_type'] == 'offering' && intent2['action_type'] == 'seeking') {
      if (price1 != null && priceMax2 != null) {
        if (price1 <= priceMax2) return 1.0;
        // Calculate how close they are
        final diff = (price1 - priceMax2) / price1;
        return max(0, 1.0 - diff);
      }
    } else if (intent1['action_type'] == 'seeking' && intent2['action_type'] == 'offering') {
      if (price2 != null && priceMax1 != null) {
        if (price2 <= priceMax1) return 1.0;
        final diff = (price2 - priceMax1) / price2;
        return max(0, 1.0 - diff);
      }
    }
    
    return 0.5;
  }

  /// Calculate profile compatibility
  Future<double> _calculateProfileScore(
    Map<String, dynamic> userProfile,
    UserProfile otherProfile,
    Map<String, dynamic> intent,
  ) async {
    double score = 0.5; // Base score
    
    // Check verification requirement
    final requirements = intent['profile_requirements'] ?? {};
    if (requirements['verification_needed'] == true) {
      if (otherProfile.isVerified) {
        score += 0.2;
      } else {
        score -= 0.3;
      }
    }
    
    // Check interest overlap
    final preferredInterests = List<String>.from(requirements['preferred_interests'] ?? []);
    if (preferredInterests.isNotEmpty) {
      final overlap = preferredInterests
          .where((i) => otherProfile.interests.contains(i))
          .length;
      score += (overlap / preferredInterests.length) * 0.3;
    }
    
    return score.clamp(0.0, 1.0);
  }

  /// Calculate semantic similarity between embeddings
  double _calculateSemanticSimilarity(List<double> emb1, List<double> emb2) {
    if (emb1.isEmpty || emb2.isEmpty || emb1.length != emb2.length) return 0.5;
    
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    
    for (int i = 0; i < emb1.length; i++) {
      dotProduct += emb1[i] * emb2[i];
      norm1 += emb1[i] * emb1[i];
      norm2 += emb2[i] * emb2[i];
    }
    
    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;
    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  /// Calculate timing score
  double _calculateTimingScore(
    AIPostModel post1,
    AIPostModel post2,
    Map<String, dynamic> intent1,
    Map<String, dynamic> intent2,
  ) {
    final urgency1 = intent1['urgency_level'] ?? 'flexible';
    final urgency2 = intent2['urgency_level'] ?? 'flexible';
    
    // Check time difference
    final timeDiff = post1.createdAt.difference(post2.createdAt).inHours.abs();
    
    if (urgency1 == 'immediate' || urgency2 == 'immediate') {
      if (timeDiff < 1) return 1.0;
      if (timeDiff < 6) return 0.8;
      if (timeDiff < 24) return 0.5;
      return 0.2;
    } else if (urgency1 == 'soon' || urgency2 == 'soon') {
      if (timeDiff < 24) return 1.0;
      if (timeDiff < 72) return 0.8;
      if (timeDiff < 168) return 0.6;
      return 0.3;
    } else {
      // Flexible timing
      if (timeDiff < 168) return 1.0;
      if (timeDiff < 336) return 0.8;
      return 0.6;
    }
  }

  /// Generate match explanation
  Future<String> _generateMatchExplanation(
    AIPostModel userPost,
    AIPostModel otherPost,
    UserProfile otherProfile,
    double score,
  ) async {
    try {
      final prompt = '''
      Explain why these two users are a ${score > 0.8 ? 'great' : score > 0.6 ? 'good' : 'potential'} match:
      
      User 1 wants: ${userPost.intentAnalysis['primary_intent']}
      User 2 offers: ${otherPost.intentAnalysis['primary_intent']}
      
      Match score: ${(score * 100).toInt()}%
      
      Write a brief, friendly explanation (1-2 sentences) that would appear in a notification.
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Found a match based on your needs!';
    } catch (e) {
      return 'Found a ${score > 0.8 ? 'great' : 'good'} match for you!';
    }
  }

  /// Generate conversation starter
  Future<String> _generateConversationStarter(
    AIPostModel userPost,
    AIPostModel otherPost,
    UserProfile otherProfile,
  ) async {
    try {
      final prompt = '''
      Generate a friendly, personalized conversation starter:
      
      You want: ${userPost.intentAnalysis['primary_intent']}
      They have: ${otherPost.intentAnalysis['primary_intent']}
      Their name: ${otherProfile.name}
      
      Write a natural message (under 50 words) that references their specific offer/need.
      Be friendly but not overly casual. Include a specific detail from their post.
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Hi! I saw your post and I think we might be able to help each other.';
    } catch (e) {
      return 'Hi ${otherProfile.name}! I saw your post about "${otherPost.originalPrompt}" and I\'m interested.';
    }
  }

  /// Generate embedding for semantic search
  Future<List<double>> _generateEmbedding(Map<String, dynamic> intentAnalysis) async {
    try {
      final text = '${intentAnalysis['primary_intent']} ${intentAnalysis['search_keywords']?.join(' ') ?? ''}';
      final response = await _embeddingModel.embedContent(Content.text(text));
      return response.embedding.values;
    } catch (e) {
      debugPrint('Error generating embedding: $e');
      return List.filled(768, 0.0);
    }
  }

  /// Helper functions
  double? _parsePrice(dynamic price) {
    if (price == null) return null;
    if (price is num) return price.toDouble();
    if (price is String) {
      final cleaned = price.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned);
    }
    return null;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final double dLat = (lat2 - lat1) * pi / 180;
    final double dLon = (lon2 - lon1) * pi / 180;
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  bool _needsClarification(Map<String, dynamic> intentAnalysis) {
    final clarifications = intentAnalysis['clarifications_needed'] ?? [];
    return clarifications.isNotEmpty;
  }

  /// Create or get conversation and send initial message
  Future<String> startConversation(
    String otherUserId,
    String initialMessage,
  ) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw Exception('Not authenticated');

      // Create or get conversation
      final conversationId = await _conversationService.createOrGetConversation(
        currentUserId,
        otherUserId,
      );

      // Send initial message
      await _conversationService.sendMessage(
        conversationId: conversationId,
        text: initialMessage,
      );

      return conversationId;
    } catch (e) {
      debugPrint('Error starting conversation: $e');
      throw e;
    }
  }
}

/// Result of creating a post
class CreatePostResult {
  final AIPostModel post;
  final List<SmartMatch> matches;
  final bool needsClarification;

  CreatePostResult({
    required this.post,
    required this.matches,
    required this.needsClarification,
  });
}

/// Smart match with analysis
class SmartMatch {
  final UserProfile profile;
  final AIPostModel post;
  final MatchAnalysis analysis;

  SmartMatch({
    required this.profile,
    required this.post,
    required this.analysis,
  });
}

/// Detailed match analysis
class MatchAnalysis {
  final double score;
  final double intentScore;
  final double locationScore;
  final double priceScore;
  final double profileScore;
  final double semanticScore;
  final double timingScore;
  final String explanation;
  final String conversationStarter;

  MatchAnalysis({
    required this.score,
    this.intentScore = 0,
    this.locationScore = 0,
    this.priceScore = 0,
    this.profileScore = 0,
    this.semanticScore = 0,
    this.timingScore = 0,
    this.explanation = '',
    this.conversationStarter = '',
  });
}

/// Location information
class LocationInfo {
  final double latitude;
  final double longitude;
  final String address;
  final String city;
  final String country;

  LocationInfo({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
    required this.country,
  });
}