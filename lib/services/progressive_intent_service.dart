import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../config/api_config.dart';

class ProgressiveIntentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final GenerativeModel _model;

  // Track conversation state
  String originalInput = '';
  List<Map<String, dynamic>> conversationHistory = [];
  Map<String, dynamic> userContext = {};

  ProgressiveIntentService() {
    _model = GenerativeModel(
      model: ApiConfig.geminiFlashModel,
      apiKey: ApiConfig.geminiApiKey,
    );
  }

  // Initialize a new conversation
  void startNewConversation(String input) {
    originalInput = input;
    conversationHistory = [];
    userContext = {};
  }

  // Generate the next question based on conversation history
  Future<Map<String, dynamic>> getNextQuestion({
    required String userInput,
    Map<String, dynamic>? previousAnswer,
  }) async {
    try {
      // Add previous answer to history if exists
      if (previousAnswer != null) {
        conversationHistory.add(previousAnswer);
      }

      // Build conversation context
      final conversationJson = json.encode(conversationHistory);
      
      final prompt = '''
Understand what the user wants QUICKLY. Maximum 1-2 ESSENTIAL questions only!

User said: "$userInput"
Previous conversation: $conversationJson

RULES:
1. If intent is CLEAR, mark complete immediately - NO unnecessary questions
2. Only ask if something CRITICAL is missing (like price for expensive items, location for services)
3. NEVER ask about categories, types, or obvious things
4. Be smart - "selling iPhone" doesn't need more questions
5. "need plumber" might need "when?" but nothing else

Examples of good understanding:
- "selling iPhone 13" = Complete! They want to sell iPhone 13
- "need plumber urgently" = Complete! They need urgent plumber service
- "looking for roommate" = Maybe ask location, then complete
- "want to buy car" = Maybe ask budget range, then complete

If intent is clear enough to match with others, mark complete.
Only ask if you truly cannot match them without that info.

Return ONLY valid JSON in this format:

For next question:
{
  "complete": false,
  "question": {
    "text": "The question to ask",
    "context": "Why we're asking this",
    "options": [
      {"id": "1", "text": "Option 1", "value": "value1"},
      {"id": "2", "text": "Option 2", "value": "value2"},
      {"id": "other", "text": "Something else", "value": "other", "allowInput": true}
    ]
  }
}

For completion:
{
  "complete": true,
  "finalIntent": "Clear, detailed description of what user wants",
  "summary": {
    "action": "buy/sell/find/etc",
    "item": "what they want",
    "details": "specific requirements"
  }
}

Generate the next step:
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text ?? '';
      
      // Parse response
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
        print('Error parsing JSON: $e');
        // Fallback to manual flow
        return _getManualNextQuestion(userInput);
      }
    } catch (e) {
      print('Error generating next question: $e');
      return _getManualNextQuestion(userInput);
    }
  }

  // Manual fallback for common patterns
  Map<String, dynamic> _getManualNextQuestion(String userInput) {
    final lowerInput = userInput.toLowerCase();
    
    // If no conversation history, ask the first question
    if (conversationHistory.isEmpty) {
      // Detect intent from keywords
      if (lowerInput.contains('sell') || lowerInput.contains('selling')) {
        return {
          'success': true,
          'data': {
            'complete': false,
            'question': {
              'text': 'What are you selling?',
              'context': 'Let\'s get details about your item',
              'options': [
                {'id': '1', 'text': 'Electronics', 'value': 'electronics'},
                {'id': '2', 'text': 'Vehicle', 'value': 'vehicle'},
                {'id': '3', 'text': 'Property', 'value': 'property'},
                {'id': '4', 'text': 'Service', 'value': 'service'},
                {'id': 'other', 'text': 'Something else', 'value': 'other', 'allowInput': true}
              ]
            }
          }
        };
      } else if (lowerInput.contains('buy') || lowerInput.contains('looking for') || 
                 lowerInput.contains('need') || lowerInput.contains('want')) {
        return {
          'success': true,
          'data': {
            'complete': false,
            'question': {
              'text': 'What are you looking for?',
              'context': 'Help us understand your needs',
              'options': [
                {'id': '1', 'text': 'Product to buy', 'value': 'buy_product'},
                {'id': '2', 'text': 'Service provider', 'value': 'find_service'},
                {'id': '3', 'text': 'Job opportunity', 'value': 'find_job'},
                {'id': '4', 'text': 'Place to rent', 'value': 'find_rental'},
                {'id': 'other', 'text': 'Something else', 'value': 'other', 'allowInput': true}
              ]
            }
          }
        };
      } else if (lowerInput.contains('job') || lowerInput.contains('hire') || 
                 lowerInput.contains('work')) {
        return {
          'success': true,
          'data': {
            'complete': false,
            'question': {
              'text': 'Are you hiring or looking for work?',
              'context': 'Understanding your role',
              'options': [
                {'id': '1', 'text': 'I\'m hiring', 'value': 'hiring'},
                {'id': '2', 'text': 'Looking for job', 'value': 'job_seeking'},
                {'id': '3', 'text': 'Freelance work', 'value': 'freelance'},
                {'id': '4', 'text': 'Internship', 'value': 'internship'},
                {'id': 'other', 'text': 'Other', 'value': 'other', 'allowInput': true}
              ]
            }
          }
        };
      }
      
      // Generic first question
      return {
        'success': true,
        'data': {
          'complete': false,
          'question': {
            'text': 'What would you like to do?',
            'context': 'Let\'s understand your needs',
            'options': [
              {'id': '1', 'text': 'Buy something', 'value': 'buy'},
              {'id': '2', 'text': 'Sell something', 'value': 'sell'},
              {'id': '3', 'text': 'Find a service', 'value': 'find_service'},
              {'id': '4', 'text': 'Offer a service', 'value': 'offer_service'},
              {'id': 'other', 'text': 'Something else', 'value': 'other', 'allowInput': true}
            ]
          }
        }
      };
    }
    
    // Based on conversation depth, decide if complete
    if (conversationHistory.length >= 3) {
      return {
        'success': true,
        'data': {
          'complete': true,
          'finalIntent': _buildFinalIntent(),
          'summary': _buildSummary()
        }
      };
    }
    
    // Generate follow-up based on last answer
    return _generateFollowUpQuestion();
  }

  Map<String, dynamic> _generateFollowUpQuestion() {
    if (conversationHistory.isEmpty) {
      return _getManualNextQuestion(originalInput);
    }
    
    final lastAnswer = conversationHistory.last;
    final answerValue = lastAnswer['answer'] ?? '';
    
    // Follow-up questions based on previous answers
    if (answerValue.contains('buy') || answerValue.contains('product')) {
      return {
        'success': true,
        'data': {
          'complete': false,
          'question': {
            'text': 'What\'s your budget range?',
            'context': 'This helps find matches in your price range',
            'options': [
              {'id': '1', 'text': 'Under \$100', 'value': 'budget_low'},
              {'id': '2', 'text': '\$100 - \$500', 'value': 'budget_mid'},
              {'id': '3', 'text': '\$500 - \$1000', 'value': 'budget_high'},
              {'id': '4', 'text': 'Above \$1000', 'value': 'budget_premium'},
              {'id': 'other', 'text': 'Specify amount', 'value': 'other', 'allowInput': true}
            ]
          }
        }
      };
    } else if (answerValue.contains('sell')) {
      return {
        'success': true,
        'data': {
          'complete': false,
          'question': {
            'text': 'What condition is it in?',
            'context': 'Buyers want to know the condition',
            'options': [
              {'id': '1', 'text': 'Brand new', 'value': 'new'},
              {'id': '2', 'text': 'Like new', 'value': 'like_new'},
              {'id': '3', 'text': 'Good', 'value': 'good'},
              {'id': '4', 'text': 'Fair', 'value': 'fair'},
              {'id': 'other', 'text': 'Other', 'value': 'other', 'allowInput': true}
            ]
          }
        }
      };
    } else if (answerValue.contains('service')) {
      return {
        'success': true,
        'data': {
          'complete': false,
          'question': {
            'text': 'When do you need this?',
            'context': 'Understanding your timeline',
            'options': [
              {'id': '1', 'text': 'Today/Urgent', 'value': 'urgent'},
              {'id': '2', 'text': 'This week', 'value': 'this_week'},
              {'id': '3', 'text': 'This month', 'value': 'this_month'},
              {'id': '4', 'text': 'Flexible', 'value': 'flexible'},
              {'id': 'other', 'text': 'Specific date', 'value': 'other', 'allowInput': true}
            ]
          }
        }
      };
    }
    
    // Default to marking as complete if we can't determine next question
    return {
      'success': true,
      'data': {
        'complete': true,
        'finalIntent': _buildFinalIntent(),
        'summary': _buildSummary()
      }
    };
  }

  String _buildFinalIntent() {
    // Build a natural language intent from conversation history
    String intent = originalInput;
    
    for (var qa in conversationHistory) {
      final answer = qa['answerText'] ?? qa['answer'] ?? '';
      if (answer.isNotEmpty && answer != 'other') {
        intent += ' - $answer';
      }
    }
    
    return intent;
  }

  Map<String, dynamic> _buildSummary() {
    Map<String, dynamic> summary = {
      'originalInput': originalInput,
      'clarifications': []
    };
    
    for (var qa in conversationHistory) {
      summary['clarifications'].add({
        'question': qa['question'] ?? '',
        'answer': qa['answerText'] ?? qa['answer'] ?? ''
      });
    }
    
    return summary;
  }

  // Save completed conversation for learning
  Future<void> saveConversation(String finalIntent) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('intent_conversations').add({
        'userId': userId,
        'originalInput': originalInput,
        'conversation': conversationHistory,
        'finalIntent': finalIntent,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving conversation: $e');
    }
  }

  // Get smart suggestions based on partial input
  Future<List<String>> getSmartSuggestions(String partialInput) async {
    if (partialInput.length < 2) return [];
    
    try {
      final prompt = '''
Generate 3-5 smart autocomplete suggestions for this partial input in a marketplace app:
"$partialInput"

Consider common searches like:
- Buying/selling items
- Finding services
- Job searching
- Dating/relationships
- Events/activities

Return ONLY a JSON array of suggestions:
["suggestion 1", "suggestion 2", "suggestion 3"]
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text ?? '';
      
      // Clean and parse
      String cleanedResponse = responseText;
      if (responseText.contains('[')) {
        final start = responseText.indexOf('[');
        final end = responseText.lastIndexOf(']') + 1;
        cleanedResponse = responseText.substring(start, end);
      }
      
      final suggestions = json.decode(cleanedResponse) as List<dynamic>;
      return suggestions.map((s) => s.toString()).toList();
    } catch (e) {
      print('Error getting suggestions: $e');
      // Fallback suggestions
      return _getFallbackSuggestions(partialInput);
    }
  }

  List<String> _getFallbackSuggestions(String partial) {
    final lower = partial.toLowerCase();
    final suggestions = <String>[];
    
    final commonSearches = [
      'iPhone for sale',
      'looking for apartment',
      'need plumber urgently',
      'selling my car',
      'web developer needed',
      'dating in my area',
      'buy used laptop',
      'house cleaning service',
      'freelance graphic designer',
      'room for rent',
    ];
    
    for (var search in commonSearches) {
      if (search.toLowerCase().contains(lower)) {
        suggestions.add(search);
      }
    }
    
    return suggestions.take(5).toList();
  }
}