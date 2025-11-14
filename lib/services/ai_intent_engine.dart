import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../config/api_config.dart';

/// AI-powered intent understanding and matching engine
/// No hardcoded categories - pure AI understanding
class AIIntentEngine {
  static final AIIntentEngine _instance = AIIntentEngine._internal();
  factory AIIntentEngine() => _instance;
  AIIntentEngine._internal();

  late GenerativeModel _model;
  late GenerativeModel _embeddingModel;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  /// Understand user intent from their input without categories
  Future<IntentAnalysis> analyzeIntent(String userInput) async {
    try {
      final prompt = '''
      Analyze this user input and extract their intent WITHOUT using predefined categories:
      "$userInput"
      
      Return a JSON object with:
      {
        "primary_intent": "what the user wants to do in simple terms",
        "action_type": "seeking" or "offering" or "neutral",
        "entities": {
          "item": "what item/service/person if mentioned",
          "price": "price or price range if mentioned",
          "location": "location if mentioned",
          "time": "time/urgency if mentioned",
          "quantity": "quantity if mentioned",
          "condition": "condition/quality if mentioned",
          "preferences": "any preferences mentioned"
        },
        "complementary_intents": ["list of intents that would match well with this"],
        "clarifications_needed": ["list of important missing information"],
        "search_keywords": ["keywords for matching"],
        "emotional_tone": "urgent/casual/serious/friendly/professional",
        "match_criteria": {
          "must_have": ["essential matching criteria"],
          "nice_to_have": ["optional matching criteria"],
          "deal_breakers": ["things that would prevent a match"]
        }
      }
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? '{}';
      final json = jsonDecode(text);
      
      return IntentAnalysis.fromJson(json);
    } catch (e) {
      debugPrint('Error analyzing intent: $e');
      return IntentAnalysis.fallback(userInput);
    }
  }

  /// Generate smart clarifying questions based on intent
  Future<List<ClarifyingQuestion>> generateClarifyingQuestions(
    String userInput,
    IntentAnalysis intent,
  ) async {
    try {
      final prompt = '''
      The user said: "$userInput"
      
      We understood their intent as: ${intent.primaryIntent}
      Missing information: ${intent.clarificationsNeeded.join(', ')}
      
      Generate 3-5 natural, conversational questions to clarify their needs.
      Make questions specific to their situation, not generic.
      
      Return JSON:
      {
        "questions": [
          {
            "id": "unique_id",
            "question": "the question text",
            "type": "text/choice/range/yes_no",
            "options": ["array of options if type is choice"],
            "importance": "essential/helpful/optional",
            "reason": "why we're asking this"
          }
        ]
      }
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? '{}';
      final json = jsonDecode(text);
      
      return (json['questions'] as List)
          .map((q) => ClarifyingQuestion.fromJson(q))
          .toList();
    } catch (e) {
      debugPrint('Error generating questions: $e');
      return [];
    }
  }

  /// Find best matching users using AI understanding
  Future<List<MatchResult>> findBestMatches(
    String userId,
    IntentAnalysis userIntent,
    Map<String, dynamic> userAnswers,
  ) async {
    try {
      // Get user's embedding
      final userEmbedding = await generateEmbedding(
        '${userIntent.primaryIntent} ${userIntent.searchKeywords.join(' ')}'
      );
      
      // Get all active posts from other users
      final snapshot = await _firestore
          .collection('posts')
          .where('userId', isNotEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();
      
      List<MatchResult> matches = [];
      
      for (var doc in snapshot.docs) {
        final postData = doc.data();
        final postIntent = postData['intent_analysis'] as Map<String, dynamic>?;
        
        if (postIntent == null) continue;
        
        // Use AI to determine match compatibility
        final compatibility = await analyzeCompatibility(
          userIntent,
          IntentAnalysis.fromJson(postIntent),
          userAnswers,
          postData['clarification_answers'] ?? {},
        );
        
        if (compatibility.score > 0.5) {
          matches.add(MatchResult(
            postId: doc.id,
            userId: postData['userId'],
            score: compatibility.score,
            reasons: compatibility.reasons,
            postData: postData,
          ));
        }
      }
      
      // Sort by score
      matches.sort((a, b) => b.score.compareTo(a.score));
      
      return matches.take(20).toList();
    } catch (e) {
      debugPrint('Error finding matches: $e');
      return [];
    }
  }

  /// Analyze compatibility between two intents using AI
  Future<CompatibilityAnalysis> analyzeCompatibility(
    IntentAnalysis intent1,
    IntentAnalysis intent2,
    Map<String, dynamic> answers1,
    Map<String, dynamic> answers2,
  ) async {
    try {
      final prompt = '''
      Analyze compatibility between two users:
      
      User 1:
      - Intent: ${intent1.primaryIntent}
      - Action: ${intent1.actionType}
      - Details: ${jsonEncode(intent1.entities)}
      - Answers: ${jsonEncode(answers1)}
      
      User 2:
      - Intent: ${intent2.primaryIntent}
      - Action: ${intent2.actionType}
      - Details: ${jsonEncode(intent2.entities)}
      - Answers: ${jsonEncode(answers2)}
      
      Determine if these users would be a good match.
      Consider:
      1. Are their intents complementary? (buyer-seller, lost-found, etc.)
      2. Do their requirements align?
      3. Are there any deal-breakers?
      4. Location compatibility
      5. Price compatibility
      6. Timing compatibility
      
      Return JSON:
      {
        "score": 0.0 to 1.0,
        "is_match": true/false,
        "match_type": "complementary/similar/neutral",
        "reasons": ["list of reasons why they match"],
        "concerns": ["potential issues"],
        "suggestions": ["how to improve the match"]
      }
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? '{}';
      final json = jsonDecode(text);
      
      return CompatibilityAnalysis.fromJson(json);
    } catch (e) {
      debugPrint('Error analyzing compatibility: $e');
      return CompatibilityAnalysis(score: 0, isMatch: false, reasons: []);
    }
  }

  /// Generate embedding for semantic search
  Future<List<double>> generateEmbedding(String text) async {
    try {
      final response = await _embeddingModel.embedContent(
        Content.text(text),
      );
      return response.embedding.values;
    } catch (e) {
      debugPrint('Error generating embedding: $e');
      return List.filled(768, 0.0); // Return zero vector on error
    }
  }

  /// Generate a natural language summary of a match
  Future<String> generateMatchSummary(
    IntentAnalysis userIntent,
    IntentAnalysis matchIntent,
    CompatibilityAnalysis compatibility,
  ) async {
    try {
      final prompt = '''
      Create a friendly, concise summary explaining why these two users match:
      
      You want: ${userIntent.primaryIntent}
      They have: ${matchIntent.primaryIntent}
      
      Match reasons: ${compatibility.reasons.join(', ')}
      
      Write a 1-2 sentence explanation that would appear in a notification.
      Make it encouraging and clear why they should connect.
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Found a great match for you!';
    } catch (e) {
      debugPrint('Error generating summary: $e');
      return 'Found a potential match based on your needs!';
    }
  }

  /// Learn from user feedback to improve matching
  Future<void> recordFeedback(
    String userId,
    String matchId,
    bool wasHelpful,
    String? feedback,
  ) async {
    try {
      await _firestore.collection('match_feedback').add({
        'userId': userId,
        'matchId': matchId,
        'wasHelpful': wasHelpful,
        'feedback': feedback,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // This feedback can be used to fine-tune the matching algorithm
      // In a production system, you might use this to improve the AI model
    } catch (e) {
      debugPrint('Error recording feedback: $e');
    }
  }

  /// Generate conversation starter for matched users
  Future<String> generateConversationStarter(
    IntentAnalysis intent1,
    IntentAnalysis intent2,
  ) async {
    try {
      final prompt = '''
      Two users just matched:
      User 1 wants: ${intent1.primaryIntent}
      User 2 has: ${intent2.primaryIntent}
      
      Generate a friendly conversation starter message that User 1 could send to User 2.
      Make it specific to their match, not generic.
      Keep it under 50 words.
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Hi! I saw your post and I think we might be able to help each other.';
    } catch (e) {
      debugPrint('Error generating conversation starter: $e');
      return 'Hi! I think we have a match. Let\'s chat!';
    }
  }
}

/// Intent analysis result from AI
class IntentAnalysis {
  final String primaryIntent;
  final String actionType;
  final Map<String, dynamic> entities;
  final List<String> complementaryIntents;
  final List<String> clarificationsNeeded;
  final List<String> searchKeywords;
  final String emotionalTone;
  final MatchCriteria matchCriteria;

  IntentAnalysis({
    required this.primaryIntent,
    required this.actionType,
    required this.entities,
    required this.complementaryIntents,
    required this.clarificationsNeeded,
    required this.searchKeywords,
    required this.emotionalTone,
    required this.matchCriteria,
  });

  factory IntentAnalysis.fromJson(Map<String, dynamic> json) {
    return IntentAnalysis(
      primaryIntent: json['primary_intent'] ?? '',
      actionType: json['action_type'] ?? 'neutral',
      entities: json['entities'] ?? {},
      complementaryIntents: List<String>.from(json['complementary_intents'] ?? []),
      clarificationsNeeded: List<String>.from(json['clarifications_needed'] ?? []),
      searchKeywords: List<String>.from(json['search_keywords'] ?? []),
      emotionalTone: json['emotional_tone'] ?? 'casual',
      matchCriteria: MatchCriteria.fromJson(json['match_criteria'] ?? {}),
    );
  }

  factory IntentAnalysis.fallback(String input) {
    return IntentAnalysis(
      primaryIntent: input,
      actionType: 'neutral',
      entities: {},
      complementaryIntents: [],
      clarificationsNeeded: ['More details needed'],
      searchKeywords: input.split(' '),
      emotionalTone: 'casual',
      matchCriteria: MatchCriteria.empty(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primary_intent': primaryIntent,
      'action_type': actionType,
      'entities': entities,
      'complementary_intents': complementaryIntents,
      'clarifications_needed': clarificationsNeeded,
      'search_keywords': searchKeywords,
      'emotional_tone': emotionalTone,
      'match_criteria': matchCriteria.toJson(),
    };
  }
}

/// Match criteria for finding compatible users
class MatchCriteria {
  final List<String> mustHave;
  final List<String> niceToHave;
  final List<String> dealBreakers;

  MatchCriteria({
    required this.mustHave,
    required this.niceToHave,
    required this.dealBreakers,
  });

  factory MatchCriteria.fromJson(Map<String, dynamic> json) {
    return MatchCriteria(
      mustHave: List<String>.from(json['must_have'] ?? []),
      niceToHave: List<String>.from(json['nice_to_have'] ?? []),
      dealBreakers: List<String>.from(json['deal_breakers'] ?? []),
    );
  }

  factory MatchCriteria.empty() {
    return MatchCriteria(
      mustHave: [],
      niceToHave: [],
      dealBreakers: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'must_have': mustHave,
      'nice_to_have': niceToHave,
      'deal_breakers': dealBreakers,
    };
  }
}

/// Clarifying question generated by AI
class ClarifyingQuestion {
  final String id;
  final String question;
  final String type;
  final List<String>? options;
  final String importance;
  final String reason;

  ClarifyingQuestion({
    required this.id,
    required this.question,
    required this.type,
    this.options,
    required this.importance,
    required this.reason,
  });

  factory ClarifyingQuestion.fromJson(Map<String, dynamic> json) {
    return ClarifyingQuestion(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      type: json['type'] ?? 'text',
      options: json['options'] != null ? List<String>.from(json['options']) : null,
      importance: json['importance'] ?? 'helpful',
      reason: json['reason'] ?? '',
    );
  }
}

/// Match result with scoring and reasons
class MatchResult {
  final String postId;
  final String userId;
  final double score;
  final List<String> reasons;
  final Map<String, dynamic> postData;

  MatchResult({
    required this.postId,
    required this.userId,
    required this.score,
    required this.reasons,
    required this.postData,
  });
}

/// Compatibility analysis between two intents
class CompatibilityAnalysis {
  final double score;
  final bool isMatch;
  final String matchType;
  final List<String> reasons;
  final List<String> concerns;
  final List<String> suggestions;

  CompatibilityAnalysis({
    required this.score,
    required this.isMatch,
    this.matchType = 'neutral',
    required this.reasons,
    this.concerns = const [],
    this.suggestions = const [],
  });

  factory CompatibilityAnalysis.fromJson(Map<String, dynamic> json) {
    return CompatibilityAnalysis(
      score: (json['score'] ?? 0).toDouble(),
      isMatch: json['is_match'] ?? false,
      matchType: json['match_type'] ?? 'neutral',
      reasons: List<String>.from(json['reasons'] ?? []),
      concerns: List<String>.from(json['concerns'] ?? []),
      suggestions: List<String>.from(json['suggestions'] ?? []),
    );
  }
}