import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'gemini_service.dart';
import 'universal_intent_service.dart';
import 'intent_clarification_service.dart';
import '../models/user_profile.dart';

class UnifiedIntentProcessor {
  static final UnifiedIntentProcessor _instance = UnifiedIntentProcessor._internal();
  factory UnifiedIntentProcessor() => _instance;
  UnifiedIntentProcessor._internal();

  final GeminiService _geminiService = GeminiService();
  final UniversalIntentService _universalService = UniversalIntentService();
  final IntentClarificationService _clarificationService = IntentClarificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Clarification patterns for common ambiguous inputs
  final Map<String, List<String>> _clarificationPatterns = {
    'iphone': ['Do you want to buy or sell an iPhone?', 'Buy', 'Sell'],
    'room': ['Are you looking to rent or offering a room?', 'Looking to rent', 'Offering a room'],
    'designer': ['Are you offering a job for a designer or looking for a job as a designer?', 'Hiring a designer', 'Looking for designer job'],
    'friend': ['Do you prefer male, female, or anyone as a friend?', 'Male', 'Female', 'Anyone'],
    'date': ['Do you prefer to date male, female, or anyone?', 'Male', 'Female', 'Anyone'],
    'bicycle': ['Do you want to buy or sell a bicycle?', 'Buy', 'Sell'],
    'car': ['Do you want to buy, sell, or rent a car?', 'Buy', 'Sell', 'Rent'],
    'apartment': ['Are you looking to rent or offering an apartment?', 'Looking to rent', 'Offering'],
    'job': ['Are you looking for a job or hiring?', 'Looking for job', 'Hiring'],
    'tutor': ['Do you need a tutor or are you offering tutoring services?', 'Need a tutor', 'Offering tutoring'],
  };

  // Check if intent needs clarification
  Future<Map<String, dynamic>?> checkClarificationNeeded(String input) async {
    final lowerInput = input.toLowerCase().trim();
    
    // Check for exact single-word ambiguous inputs
    if (_clarificationPatterns.containsKey(lowerInput)) {
      return {
        'needsClarification': true,
        'question': _clarificationPatterns[lowerInput]![0],
        'options': _clarificationPatterns[lowerInput]!.sublist(1),
        'originalInput': input,
      };
    }

    // Use AI to detect ambiguity with better context understanding
    try {
      final prompt = '''
Analyze this user input carefully and determine if it needs clarification:
"$input"

IMPORTANT RULES:
1. Understand the actual intent - don't ask nonsensical questions
2. If someone says "selling for dog" they likely mean selling dog-related items
3. If someone says "looking for friend" they might want to find a friend
4. Focus on what information is ACTUALLY missing to create a match

Check if the intent truly needs clarification. Consider:
- Is the core intent clear even if details are missing?
- Would a clarifying question actually help find better matches?
- Is the question grammatically sensible and relevant?

Examples of GOOD clarifications:
- "iPhone" → "Do you want to buy or sell an iPhone?"
- "room" → "Are you looking to rent or offering a room?"
- "dog" → "Are you looking for a dog, dog services, or dog products?"

Examples of BAD clarifications:
- "I am selling for dog" → Don't ask "What are you selling for your dog?" 
  Instead understand they're selling dog-related items

Respond with JSON:
{
  "needsClarification": true/false,
  "confidence": 0.0-1.0,
  "intentUnderstood": "what you understand the user wants",
  "missingInfo": "what specific info would help match better",
  "question": "natural, sensible clarifying question if truly needed",
  "options": ["relevant option 1", "relevant option 2", "relevant option 3"],
  "reason": "why this clarification would improve matching"
}

If the intent is clear enough to find matches (even if not perfect), set needsClarification to false.
''';

      final response = await _geminiService.generateContent(prompt);
      if (response != null && response.isNotEmpty) {
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0)!;
          final result = _parseJson(jsonStr);
          
          // Only show clarification if truly needed and confidence is high
          if (result['needsClarification'] == true && result['confidence'] > 0.8) {
            return {
              'needsClarification': true,
              'question': result['question'] ?? 'Could you please provide more details?',
              'options': result['options'] ?? ['Option 1', 'Option 2', 'Other'],
              'originalInput': input,
              'reason': result['reason'],
              'intentUnderstood': result['intentUnderstood'],
            };
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking clarification: $e');
    }

    return null;
  }

  // Process intent with clarification if needed
  Future<Map<String, dynamic>> processWithClarification(
    String input,
    BuildContext context,
  ) async {
    // First check if clarification is needed
    final clarification = await checkClarificationNeeded(input);
    
    if (clarification != null && clarification['needsClarification'] == true) {
      // Show clarification dialog
      final answer = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Quick Clarification'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(clarification['question']),
                SizedBox(height: 16),
                ...List.generate(
                  clarification['options'].length,
                  (index) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(clarification['options'][index]);
                        },
                        child: Text(clarification['options'][index]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (answer != null) {
        // Combine original input with clarification answer
        final clarifiedIntent = _buildClarifiedIntent(input, answer, clarification['question']);
        return await _processIntent(clarifiedIntent);
      }
    }

    // Process directly if no clarification needed
    return await _processIntent(input);
  }

  String _buildClarifiedIntent(String original, String answer, String question) {
    // Build a more complete intent from the clarification
    if (question.contains('buy or sell')) {
      if (answer.toLowerCase().contains('buy')) {
        return 'I want to buy $original';
      } else {
        return 'I want to sell $original';
      }
    } else if (question.contains('rent or offering')) {
      if (answer.toLowerCase().contains('looking')) {
        return 'Looking for $original to rent';
      } else {
        return 'Offering $original for rent';
      }
    } else if (question.contains('hiring')) {
      if (answer.toLowerCase().contains('hiring')) {
        return 'Hiring a $original';
      } else {
        return 'Looking for $original job';
      }
    } else if (question.contains('gender') || question.contains('prefer')) {
      return '$original, preference: $answer';
    }
    
    // Default combination
    return '$original - $answer';
  }

  Future<Map<String, dynamic>> _processIntent(String intent) async {
    try {
      // Process with universal intent service
      final result = await _universalService.processIntent(intent);
      
      // Store the processed intent
      await _storeProcessedIntent(intent, result);
      
      // Find matches
      final matches = await _universalService.findMatches(result['intent']);
      
      return {
        'success': true,
        'intent': result['intent'],
        'matches': matches,
        'message': 'Found ${matches.length} matches',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to process intent',
      };
    }
  }

  Future<void> _storeProcessedIntent(String originalInput, Map<String, dynamic> result) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore.collection('processed_intents').add({
      'userId': userId,
      'originalInput': originalInput,
      'processedIntent': result['intent'],
      'timestamp': FieldValue.serverTimestamp(),
      'hasMatches': result['matches']?.isNotEmpty ?? false,
    });
  }

  Map<String, dynamic> _parseJson(String jsonStr) {
    try {
      // Clean up the JSON string
      jsonStr = jsonStr.replaceAll(RegExp(r'[\n\r\t]'), ' ');
      jsonStr = jsonStr.replaceAll(RegExp(r'\s+'), ' ');
      
      // Manual parsing for common fields
      final needsClarification = jsonStr.contains('"needsClarification": true') || 
                                jsonStr.contains('"needsClarification":true');
      
      final confidenceMatch = RegExp(r'"confidence":\s*([0-9.]+)').firstMatch(jsonStr);
      final confidence = confidenceMatch != null ? double.tryParse(confidenceMatch.group(1)!) ?? 0.0 : 0.0;
      
      final questionMatch = RegExp(r'"question":\s*"([^"]+)"').firstMatch(jsonStr);
      final question = questionMatch?.group(1);
      
      final intentUnderstoodMatch = RegExp(r'"intentUnderstood":\s*"([^"]+)"').firstMatch(jsonStr);
      final intentUnderstood = intentUnderstoodMatch?.group(1);
      
      final missingInfoMatch = RegExp(r'"missingInfo":\s*"([^"]+)"').firstMatch(jsonStr);
      final missingInfo = missingInfoMatch?.group(1);
      
      // Parse options array
      final optionsMatch = RegExp(r'"options":\s*\[([^\]]+)\]').firstMatch(jsonStr);
      List<String> options = [];
      if (optionsMatch != null) {
        final optionsStr = optionsMatch.group(1)!;
        options = optionsStr.split(',')
            .map((s) => s.trim().replaceAll('"', ''))
            .where((s) => s.isNotEmpty)
            .toList();
      }
      
      final reasonMatch = RegExp(r'"reason":\s*"([^"]+)"').firstMatch(jsonStr);
      final reason = reasonMatch?.group(1);
      
      return {
        'needsClarification': needsClarification,
        'confidence': confidence,
        'question': question,
        'options': options,
        'reason': reason,
        'intentUnderstood': intentUnderstood,
        'missingInfo': missingInfo,
      };
    } catch (e) {
      debugPrint('Error parsing JSON: $e');
      return {};
    }
  }
}