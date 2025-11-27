import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'gemini_service.dart';
import 'unified_post_service.dart';
import '../config/api_config.dart';
import '../models/post_model.dart';

class UniversalIntentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeminiService _geminiService = GeminiService();
  late final GenerativeModel _model; // ignore: unused_field

  UniversalIntentService() {
    _model = GenerativeModel(
      model: ApiConfig.geminiFlashModel,
      apiKey: ApiConfig.geminiApiKey,
    );
  }

  // No more rigid role mappings - we use semantic matching now
  // The AI understands complementary intents naturally

  // Wrapper method for unified processor
  Future<Map<String, dynamic>> processIntent(String text) async {
    return await processIntentAndMatch(text);
  }

  // Find matches for a given intent
  Future<List<Map<String, dynamic>>> findMatches(
    Map<String, dynamic> intent,
  ) async {
    // Use the intent to find matches
    final intents = await FirebaseFirestore.instance
        .collection('intents')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .limit(20)
        .get();

    List<Map<String, dynamic>> matches = [];
    final intentEmbedding = intent['embedding'] as List<double>?;

    if (intentEmbedding != null) {
      for (var doc in intents.docs) {
        final data = doc.data();
        final docEmbedding = List<double>.from(data['embedding'] ?? []);

        if (docEmbedding.isNotEmpty) {
          final similarity = _geminiService.calculateSimilarity(
            intentEmbedding,
            docEmbedding,
          );
          if (similarity > 0.65) {
            data['id'] = doc.id;
            data['similarity'] = similarity;
            matches.add(data);
          }
        }
      }
    }

    // Sort by similarity
    matches.sort(
      (a, b) => (b['similarity'] ?? 0).compareTo(a['similarity'] ?? 0),
    );
    return matches.take(10).toList();
  }

  // UPDATED: Process user intent and find matches using UnifiedPostService
  Future<Map<String, dynamic>> processIntentAndMatch(String userInput) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Get user profile for context
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userProfile = userDoc.data() ?? {};

      debugPrint('📝 Processing intent: $userInput');

      // Import and use UnifiedPostService
      final unifiedService = UnifiedPostService();

      // Create post using unified service (stores in posts collection only)
      final result = await unifiedService.createPost(
        originalPrompt: userInput,
        location: userProfile['location'],
        latitude: userProfile['latitude']?.toDouble(),
        longitude: userProfile['longitude']?.toDouble(),
      );

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Failed to create post');
      }

      final postId = result['postId'];
      debugPrint('✅ Post created: $postId');

      // Find matches using unified service
      final matches = await unifiedService.findMatches(postId);
      debugPrint('🔍 Found ${matches.length} matches');

      // Convert matches to format expected by UI
      final matchesWithProfile = await _enrichMatchesWithProfiles(matches);

      return {
        'success': true,
        'intent': result['post'],
        'postId': postId,
        'matches': matchesWithProfile,
      };
    } catch (e) {
      debugPrint('❌ Error processing intent: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Helper to enrich matches with user profiles
  Future<List<Map<String, dynamic>>> _enrichMatchesWithProfiles(
    List<PostModel> matches,
  ) async {
    List<Map<String, dynamic>> enrichedMatches = [];

    for (var match in matches) {
      // Get user profile
      final userDoc = await _firestore
          .collection('users')
          .doc(match.userId)
          .get();

      if (userDoc.exists) {
        final userProfile = userDoc.data();

        enrichedMatches.add({
          'id': match.id,
          'userId': match.userId,
          'title': match.title,
          'description': match.description,
          'originalPrompt': match.originalPrompt,
          'intentAnalysis': match.intentAnalysis,
          'location': match.location,
          'latitude': match.latitude,
          'longitude': match.longitude,
          'price': match.price,
          'matchScore': match.similarityScore ?? 0.0,
          'userProfile': userProfile,
          'createdAt': match.createdAt,
        });
      }
    }

    return enrichedMatches;
  }

  // ignore: unused_element
  String _buildIntentPrompt(
    String userInput,
    Map<String, dynamic> userProfile,
  ) {
    return '''
Understand what the user wants and find what would match them. BE SMART - understand ANY request.

User is in: ${userProfile['city'] ?? 'Unknown city'}, ${userProfile['location'] ?? 'Unknown location'}
User says: "$userInput"

DO NOT force categories! Understand the REAL intent. Examples:
- "selling iPhone" → needs someone buying iPhone
- "need plumber" → needs plumber offering service  
- "lost cat" → needs people who found cats or can help
- "have extra tickets" → needs people wanting tickets
- "learning guitar" → needs guitar teacher
- "bored tonight" → needs activity partners
- ANYTHING else → figure out what they need!

Return ONLY valid JSON:
{
  "what_user_wants": "simple description of what they want",
  "looking_for": "what kind of person/thing would match them",
  "match_keywords": "keywords to find matches",
  "title": "short title",
  "urgency": "low|medium|high",
  "tags": ["relevant", "tags"],
  "embedding_text": "full searchable description"
}

Examples:
- "selling iPhone 13" → what_user_wants: "sell iPhone 13", looking_for: "people who want to buy iPhone 13"
- "need a plumber" → what_user_wants: "plumber service", looking_for: "plumbers offering service"
- "lost my dog" → what_user_wants: "find lost dog", looking_for: "people who found dogs or can help search"
- ANY REQUEST → understand and match intelligently
''';
  }

  // ignore: unused_element
  Map<String, dynamic> _parseGeminiResponse(String response) {
    try {
      // Clean the response to get only JSON
      String cleanedResponse = response;

      // Find JSON content between curly braces
      final startIndex = response.indexOf('{');
      final endIndex = response.lastIndexOf('}');

      if (startIndex != -1 && endIndex != -1) {
        cleanedResponse = response.substring(startIndex, endIndex + 1);
      }

      final parsed = json.decode(cleanedResponse);

      // Convert new format to work with existing code
      return {
        'intent_type': 'UNIVERSAL',
        'user_role': 'USER',
        'match_role': 'MATCH',
        'title': parsed['title'] ?? 'User request',
        'description': parsed['what_user_wants'] ?? response,
        'looking_for': parsed['looking_for'] ?? '',
        'match_keywords': parsed['match_keywords'] ?? '',
        'category': 'General',
        'urgency': parsed['urgency'] ?? 'medium',
        'embedding_text': parsed['embedding_text'] ?? response,
        'tags': parsed['tags'] ?? [],
      };
    } catch (e) {
      debugPrint('Error parsing Gemini response: $e');
      // Return default structure if parsing fails
      return {
        'intent_type': 'UNIVERSAL',
        'user_role': 'USER',
        'match_role': 'MATCH',
        'title': 'User request',
        'description': response,
        'looking_for': '',
        'embedding_text': response,
        'tags': [],
      };
    }
  }

  // ignore: unused_element
  Future<Map<String, dynamic>> _storeIntent(
    Map<String, dynamic> intentData,
    String userId,
  ) async {
    try {
      // Generate embeddings using Gemini
      final embeddings = await _generateEmbeddings(
        intentData['embedding_text'] ?? intentData['title'],
      );

      // Prepare document for Firestore
      final intentDoc = {
        'userId': userId,
        'intentType': 'UNIVERSAL',
        'title': intentData['title'],
        'description': intentData['description'],
        'lookingFor': intentData['looking_for'] ?? '',
        'tags': intentData['tags'] ?? [],
        'embeddings': embeddings,
        'embeddingText': intentData['embedding_text'],
        'urgency': intentData['urgency'] ?? 'medium',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 30)),
        ),
      };

      // Store in Firestore
      final docRef = await _firestore.collection('user_intents').add(intentDoc);
      intentDoc['id'] = docRef.id;

      // Update user's active intents count
      await _firestore.collection('users').doc(userId).update({
        'activeIntents': FieldValue.increment(1),
        'lastIntentAt': FieldValue.serverTimestamp(),
      });

      return intentDoc;
    } catch (e) {
      debugPrint('Error storing intent: $e');
      rethrow;
    }
  }

  Future<List<double>> _generateEmbeddings(String text) async {
    try {
      // Use GeminiService to generate actual embeddings
      return await _geminiService.generateEmbedding(text);
    } catch (e) {
      debugPrint('Error generating embeddings: $e');
      // Return random embeddings as fallback
      return List.generate(768, (i) => (i * 0.001) % 1);
    }
  }

  // ignore: unused_element
  Future<List<Map<String, dynamic>>> _findComplementaryMatches(
    Map<String, dynamic> intentData,
  ) async {
    try {
      // Get current user's location
      final currentUserId = _auth.currentUser?.uid;
      double? userLat;
      double? userLon;

      if (currentUserId != null) {
        final currentUserDoc = await _firestore
            .collection('users')
            .doc(currentUserId)
            .get();
        if (currentUserDoc.exists) {
          final userData = currentUserDoc.data();
          userLat = userData?['latitude']?.toDouble();
          userLon = userData?['longitude']?.toDouble();
        }
      }

      // Get what user is looking for to find semantic matches
      final lookingFor =
          intentData['looking_for'] ?? intentData['description'] ?? '';
      final tags = List<String>.from(intentData['tags'] ?? []); // ignore: unused_local_variable

      // Generate embedding for semantic search
      final searchEmbedding = await _generateEmbeddings(lookingFor);

      // Query all active intents - we'll use semantic matching
      // Simple query without orderBy to avoid index requirement
      Query query = _firestore
          .collection('user_intents')
          .where('status', isEqualTo: 'active');

      // Get potential matches
      final querySnapshot = await query.limit(200).get();

      List<Map<String, dynamic>> matches = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Skip own intents
        if (data['userId'] == _auth.currentUser?.uid) continue;

        // Calculate semantic similarity score using embeddings
        double matchScore = 0.0;
        final storedEmbedding = List<double>.from(data['embeddings'] ?? []);

        if (storedEmbedding.isNotEmpty && searchEmbedding.isNotEmpty) {
          matchScore = _geminiService.calculateSimilarity(
            searchEmbedding,
            storedEmbedding,
          );
        }

        // Only include good semantic matches (similarity > 0.65)
        if (matchScore > 0.65) {
          data['matchScore'] = matchScore;
          matches.add(data);
        }
      }

      // Get user details for all matches (before sorting)
      for (var match in matches) {
        final userDoc = await _firestore
            .collection('users')
            .doc(match['userId'])
            .get();

        if (userDoc.exists) {
          final userProfile = userDoc.data();
          match['userProfile'] = userProfile;

          // Calculate distance if locations are available
          if (userLat != null && userLon != null && userProfile != null) {
            final matchLat = userProfile['latitude']?.toDouble();
            final matchLon = userProfile['longitude']?.toDouble();

            if (matchLat != null && matchLon != null) {
              match['distance'] = _calculateDistance(
                userLat,
                userLon,
                matchLat,
                matchLon,
              );
            }
          }
        }
      }

      // Sort by location first (if available), then by match score
      matches.sort((a, b) {
        final distA = a['distance'] as double?;
        final distB = b['distance'] as double?;

        // If both have distances, sort by distance
        if (distA != null && distB != null) {
          final distComparison = distA.compareTo(distB);
          // If distances are similar (within 5km), sort by match score
          if ((distA - distB).abs() < 5) {
            return (b['matchScore'] as double).compareTo(
              a['matchScore'] as double,
            );
          }
          return distComparison;
        }

        // If only one has distance, prioritize the one with distance
        if (distA != null) return -1;
        if (distB != null) return 1;

        // Otherwise sort by match score
        return (b['matchScore'] as double).compareTo(a['matchScore'] as double);
      });

      return matches.take(10).toList();
    } catch (e) {
      debugPrint('Error finding matches: $e');
      return [];
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (3.14159265359 / 180);
  }

  // ignore: unused_element
  double _calculateMatchScore(
    Map<String, dynamic> userIntent,
    Map<String, dynamic> matchIntent,
    List<String> userTags,
    List<String> matchTags,
  ) {
    double score = 0.0;

    // Role compatibility (most important)
    if (userIntent['match_role'] == matchIntent['user_role']) {
      score += 0.4;
    }

    // Category match
    if (userIntent['category'] == matchIntent['category']) {
      score += 0.2;
    }

    // Subcategory match
    if (userIntent['subcategory'] == matchIntent['subcategory']) {
      score += 0.1;
    }

    // Tag overlap
    final commonTags = userTags.toSet().intersection(matchTags.toSet());
    if (commonTags.isNotEmpty) {
      score += 0.1 * (commonTags.length / userTags.length);
    }

    // Price compatibility (if applicable)
    final userPrice = userIntent['entities']?['price'];
    final matchPrice = matchIntent['entities']?['price'];
    if (userPrice != null && matchPrice != null) {
      score += _calculatePriceCompatibility(userPrice, matchPrice) * 0.1;
    }

    // Location proximity (if applicable)
    // TODO: Implement location-based scoring

    // Temporal relevance
    final matchCreatedAt = matchIntent['createdAt'];
    if (matchCreatedAt != null && matchCreatedAt is Timestamp) {
      final daysSinceCreation = DateTime.now()
          .difference(matchCreatedAt.toDate())
          .inDays;
      if (daysSinceCreation < 7) {
        score += 0.1;
      }
    }

    return score.clamp(0.0, 1.0);
  }

  double _calculatePriceCompatibility(
    Map<String, dynamic> userPrice,
    Map<String, dynamic> matchPrice,
  ) {
    final userAmount = userPrice['amount']?.toDouble() ?? 0.0;
    final matchAmount = matchPrice['amount']?.toDouble() ?? 0.0;

    if (userAmount == 0 || matchAmount == 0) return 0.5;

    // Check if prices are within reasonable range
    final difference = (userAmount - matchAmount).abs();
    final average = (userAmount + matchAmount) / 2;

    if (difference / average < 0.2) {
      return 1.0; // Very compatible
    } else if (difference / average < 0.5) {
      return 0.5; // Somewhat compatible
    } else {
      return 0.0; // Not compatible
    }
  }

  // UPDATED: Get user's active posts (changed from user_intents to posts)
  Future<List<Map<String, dynamic>>> getUserIntents(String userId) async {
    try {
      debugPrint('📋 Getting user posts from posts collection');

      final querySnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting user posts: $e');
      return [];
    }
  }

  // UPDATED: Deactivate a post (uses posts collection)
  Future<void> deactivateIntent(String intentId) async {
    try {
      debugPrint('🗑️ Deactivating post: $intentId');
      final unifiedService = UnifiedPostService();
      await unifiedService.deactivatePost(intentId);
      debugPrint('✅ Post deactivated');
    } catch (e) {
      debugPrint('❌ Error deactivating post: $e');
    }
  }

  // UPDATED: Permanently delete a post (uses posts collection)
  Future<bool> deleteIntent(String intentId) async {
    try {
      debugPrint('🗑️ Deleting post: $intentId');
      final unifiedService = UnifiedPostService();
      final result = await unifiedService.deletePost(intentId);

      if (result) {
        debugPrint('✅ Post deleted successfully');
      } else {
        debugPrint('⚠️ Post deletion failed');
      }

      return result;
    } catch (e) {
      debugPrint('❌ Error deleting post: $e');
      return false;
    }
  }
}
