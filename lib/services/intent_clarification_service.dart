import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../config/api_config.dart';

class IntentClarificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final GenerativeModel _model;

  IntentClarificationService() {
    _model = GenerativeModel(
      model: ApiConfig.geminiFlashModel,
      apiKey: ApiConfig.geminiApiKey,
    );
  }

  // Generate clarifying questions based on initial user input
  Future<Map<String, dynamic>> generateClarifyingQuestions(String userInput) async {
    try {
      final prompt = '''
You are an intelligent assistant that helps clarify user intent in a marketplace/matching app.
The user has entered: "$userInput"

Generate clarifying questions to understand exactly what the user wants.
Return a JSON response with multiple choice questions to clarify their intent.

IMPORTANT RULES:
1. Generate 1-2 relevant questions maximum
2. Each question should have 3-5 clear options
3. Always include "Other" option with ability to type custom answer
4. Questions should be contextual and help determine:
   - Are they buying/selling/looking for services?
   - What specific variant/type they want?
   - What's their budget/timeline?
   - Any specific preferences?

Return ONLY valid JSON in this exact format:
{
  "questions": [
    {
      "id": "q1",
      "question": "What would you like to do?",
      "options": [
        {"id": "opt1", "text": "Buy", "value": "buy"},
        {"id": "opt2", "text": "Sell", "value": "sell"},
        {"id": "opt3", "text": "Trade", "value": "trade"},
        {"id": "other", "text": "Other", "value": "other", "allowCustomInput": true}
      ]
    }
  ],
  "context": "Brief explanation of what we understood from the input"
}

Examples:
- If user types "iPhone" -> Ask if they want to buy, sell, repair, or find accessories
- If user types "looking for job" -> Ask about job type, experience level, location preference
- If user types "need plumber" -> Ask about urgency, type of work, budget range
- If user types "selling car" -> Ask about car details, price range, condition

User input: "$userInput"

Generate appropriate clarifying questions:
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text ?? '';
      
      // Clean the response to get valid JSON
      String cleanedResponse = responseText;
      if (responseText.contains('```json')) {
        cleanedResponse = responseText.split('```json')[1].split('```')[0].trim();
      } else if (responseText.contains('```')) {
        cleanedResponse = responseText.split('```')[1].split('```')[0].trim();
      }
      
      try {
        final jsonResponse = json.decode(cleanedResponse);
        return {
          'success': true,
          'data': jsonResponse,
        };
      } catch (e) {
        debugPrint('Error parsing JSON response: $e');
        debugPrint('Cleaned response: $cleanedResponse');
        
        // Fallback questions if parsing fails
        return {
          'success': true,
          'data': _getFallbackQuestions(userInput),
        };
      }
    } catch (e) {
      debugPrint('Error generating clarifying questions: $e');
      return {
        'success': false,
        'error': e.toString(),
        'data': _getFallbackQuestions(userInput),
      };
    }
  }

  // Process user's answers to clarifying questions
  Future<String> processAnswersToIntent(
    String originalInput, 
    List<Map<String, dynamic>> questionsWithAnswers,
  ) async {
    try {
      // Build a refined intent based on original input and answers
      final answersJson = json.encode(questionsWithAnswers);
      
      final prompt = '''
Based on the user's original input and their answers to clarifying questions, 
generate a clear, detailed intent statement that captures exactly what they want.

Original input: "$originalInput"
Answers to questions: $answersJson

Generate a clear, natural language intent statement that includes all relevant details.
The statement should be specific and actionable.

Example outputs:
- "I want to buy an iPhone 14 Pro in good condition within budget of \$800"
- "I'm looking to sell my 2020 Honda Civic with 30,000 miles for around \$18,000"
- "I need an experienced plumber for emergency pipe repair today"
- "I'm seeking a software developer position in San Francisco with 5 years Python experience"

Return only the refined intent statement, nothing else:
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final refinedIntent = response.text?.trim() ?? originalInput;
      
      return refinedIntent;
    } catch (e) {
      debugPrint('Error processing answers: $e');
      return originalInput; // Fallback to original input
    }
  }

  // Get fallback questions if Gemini fails
  Map<String, dynamic> _getFallbackQuestions(String userInput) {
    final lowerInput = userInput.toLowerCase();
    
    // Detect common patterns and provide appropriate questions
    if (lowerInput.contains('iphone') || lowerInput.contains('phone') || 
        lowerInput.contains('samsung') || lowerInput.contains('android')) {
      return {
        'questions': [
          {
            'id': 'q1',
            'question': 'What would you like to do with the phone?',
            'options': [
              {'id': 'buy', 'text': 'Buy', 'value': 'buy'},
              {'id': 'sell', 'text': 'Sell', 'value': 'sell'},
              {'id': 'repair', 'text': 'Repair', 'value': 'repair'},
              {'id': 'trade', 'text': 'Trade', 'value': 'trade'},
              {'id': 'accessories', 'text': 'Find accessories', 'value': 'accessories'},
              {'id': 'other', 'text': 'Other', 'value': 'other', 'allowCustomInput': true}
            ]
          }
        ],
        'context': 'Helping you with phone-related needs'
      };
    } else if (lowerInput.contains('job') || lowerInput.contains('work') || 
               lowerInput.contains('hire') || lowerInput.contains('employ')) {
      return {
        'questions': [
          {
            'id': 'q1',
            'question': 'Are you looking to hire or find work?',
            'options': [
              {'id': 'find_job', 'text': 'Find a job', 'value': 'find_job'},
              {'id': 'hire', 'text': 'Hire someone', 'value': 'hire'},
              {'id': 'freelance', 'text': 'Freelance/Contract work', 'value': 'freelance'},
              {'id': 'internship', 'text': 'Internship', 'value': 'internship'},
              {'id': 'other', 'text': 'Other', 'value': 'other', 'allowCustomInput': true}
            ]
          }
        ],
        'context': 'Helping you with employment-related needs'
      };
    } else if (lowerInput.contains('car') || lowerInput.contains('vehicle') || 
               lowerInput.contains('bike')) {
      return {
        'questions': [
          {
            'id': 'q1',
            'question': 'What would you like to do?',
            'options': [
              {'id': 'buy', 'text': 'Buy', 'value': 'buy'},
              {'id': 'sell', 'text': 'Sell', 'value': 'sell'},
              {'id': 'rent', 'text': 'Rent', 'value': 'rent'},
              {'id': 'repair', 'text': 'Repair/Service', 'value': 'repair'},
              {'id': 'other', 'text': 'Other', 'value': 'other', 'allowCustomInput': true}
            ]
          }
        ],
        'context': 'Helping you with vehicle-related needs'
      };
    } else {
      // Generic fallback
      return {
        'questions': [
          {
            'id': 'q1',
            'question': 'What are you looking to do?',
            'options': [
              {'id': 'buy', 'text': 'Buy something', 'value': 'buy'},
              {'id': 'sell', 'text': 'Sell something', 'value': 'sell'},
              {'id': 'find_service', 'text': 'Find a service', 'value': 'find_service'},
              {'id': 'offer_service', 'text': 'Offer a service', 'value': 'offer_service'},
              {'id': 'connect', 'text': 'Connect with someone', 'value': 'connect'},
              {'id': 'other', 'text': 'Other', 'value': 'other', 'allowCustomInput': true}
            ]
          }
        ],
        'context': 'Help us understand what you\'re looking for'
      };
    }
  }

  // Store clarification session for analytics
  Future<void> storeClarificationSession({
    required String originalInput,
    required Map<String, dynamic> questions,
    required List<Map<String, dynamic>> answers,
    required String refinedIntent,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('intent_clarifications').add({
        'userId': userId,
        'originalInput': originalInput,
        'questions': questions,
        'answers': answers,
        'refinedIntent': refinedIntent,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error storing clarification session: $e');
    }
  }
}