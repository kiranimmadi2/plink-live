import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'location services/gemini_service.dart';

class SmartPromptParser {
  final GenerativeModel _model;
  
  SmartPromptParser() : _model = GenerativeModel(
    model: 'gemini-1.5-flash-latest',
    apiKey: GeminiService.apiKey,
  );

  // Extract all information from the initial prompt
  Future<Map<String, dynamic>> extractFromPrompt(String userInput) async {
    try {
      final prompt = '''
Extract ALL information from this user input. Be smart and understand context.
User input: "$userInput"

Extract and return ONLY valid JSON:
{
  "intent_type": "product|service|job|rental|other",
  "action": "buy|sell|offer|need|find|other",
  "product": "extracted product name or null",
  "service": "extracted service type or null", 
  "budget": {
    "amount": extracted number or null,
    "currency": "INR|USD|EUR or detected currency",
    "range": "exact|under|over|between"
  },
  "location": {
    "area": "extracted area/locality or null",
    "city": "extracted city or null",
    "distance": "extracted distance preference or null"
  },
  "urgency": "immediate|today|thisweek|flexible",
  "quantity": extracted quantity or null,
  "condition": "new|used|any or null",
  "brand": "extracted brand or null",
  "model": "extracted model or null",
  "specifications": {
    "color": "extracted color or null",
    "size": "extracted size or null",
    "capacity": "extracted capacity or null",
    "other_specs": []
  },
  "time_preference": "morning|afternoon|evening|anytime or null",
  "duration": "extracted duration or null",
  "contact_preference": "call|message|either or null"
}

Examples:
- "i am looking for iphone for 30000" → intent_type: "product", action: "buy", product: "iPhone", budget: {amount: 30000, currency: "INR", range: "exact"}
- "selling macbook pro 2020 45000 negotiable" → intent_type: "product", action: "sell", product: "MacBook Pro", model: "2020", budget: {amount: 45000, currency: "INR", range: "exact"}
- "need plumber urgently in koramangala" → intent_type: "service", action: "need", service: "plumber", urgency: "immediate", location: {area: "koramangala"}
- "looking for 2bhk flat rent under 25k whitefield" → intent_type: "rental", action: "find", budget: {amount: 25000, range: "under"}, location: {area: "whitefield"}

Be intelligent - extract everything possible!
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final text = response.text ?? '{}';
      
      // Parse JSON response
      return _parseExtractedData(text);
    } catch (e) {
      debugPrint('Error extracting from prompt: $e');
      return {'extracted': false};
    }
  }

  Map<String, dynamic> _parseExtractedData(String response) {
    try {
      // Clean response to get JSON
      final startIdx = response.indexOf('{');
      final endIdx = response.lastIndexOf('}');
      if (startIdx == -1 || endIdx == -1) {
        return {'extracted': false};
      }
      
      final jsonStr = response.substring(startIdx, endIdx + 1);
      final data = json.decode(jsonStr);
      
      // Mark as successfully extracted if we have meaningful data
      data['extracted'] = _hasExtractedData(data);
      return data;
    } catch (e) {
      debugPrint('Error parsing extracted data: $e');
      return {'extracted': false};
    }
  }

  bool _hasExtractedData(Map<String, dynamic> data) {
    // Check if we extracted at least some meaningful information
    return (data['intent_type'] != null && data['intent_type'] != 'other') ||
           data['product'] != null ||
           data['service'] != null ||
           (data['budget']?['amount'] != null) ||
           (data['location']?['area'] != null) ||
           (data['location']?['city'] != null);
  }

  // Determine what information is still missing
  List<Map<String, dynamic>> getMissingFields(Map<String, dynamic> extractedData) {
    final missing = <Map<String, dynamic>>[];
    final intentType = extractedData['intent_type'];
    
    // Only ask for truly missing critical information
    if (intentType == null || intentType == 'other') {
      missing.add({
        'field': 'intent_type',
        'question': 'What are you looking for?',
        'options': [
          {'value': 'product', 'text': 'Product to buy'},
          {'value': 'service', 'text': 'Service provider'},
          {'value': 'job', 'text': 'Job opportunity'},
          {'value': 'rental', 'text': 'Place to rent'},
          {'value': 'other', 'text': 'Something else', 'allowInput': true}
        ]
      });
    }
    
    // For products, only ask if product name is missing
    if (intentType == 'product' && extractedData['product'] == null) {
      missing.add({
        'field': 'product',
        'question': 'What product are you looking for?',
        'type': 'text'
      });
    }
    
    // For services, only ask if service type is missing
    if (intentType == 'service' && extractedData['service'] == null) {
      missing.add({
        'field': 'service', 
        'question': 'What service do you need?',
        'type': 'text'
      });
    }
    
    // Only ask for budget if it's critical and missing
    if (extractedData['budget']?['amount'] == null && 
        (intentType == 'product' || intentType == 'rental')) {
      missing.add({
        'field': 'budget',
        'question': "What's your budget range?",
        'context': 'This helps find matches in your price range',
        'options': [
          {'value': 'under_100', 'text': 'Under \$100'},
          {'value': '100_500', 'text': '\$100 - \$500'},
          {'value': '500_1000', 'text': '\$500 - \$1000'},
          {'value': 'above_1000', 'text': 'Above \$1000'},
          {'value': 'other', 'text': 'Specify amount', 'allowInput': true}
        ]
      });
    }
    
    // Only ask for location if completely missing
    if (extractedData['location']?['area'] == null && 
        extractedData['location']?['city'] == null) {
      missing.add({
        'field': 'location',
        'question': 'Where are you looking?',
        'context': 'Helps find nearby matches',
        'type': 'text',
        'optional': true
      });
    }
    
    return missing;
  }
  
  // Build final intent from extracted and collected data
  String buildFinalIntent(Map<String, dynamic> extractedData, Map<String, String> answers) {
    final parts = <String>[];
    
    // Add action
    final action = extractedData['action'] ?? 'looking for';
    parts.add('I am $action');
    
    // Add product/service
    if (extractedData['product'] != null) {
      parts.add(extractedData['product']);
    } else if (extractedData['service'] != null) {
      parts.add('${extractedData['service']} service');
    } else if (answers['product'] != null) {
      parts.add(answers['product']!);
    } else if (answers['service'] != null) {
      parts.add('${answers['service']} service');
    }
    
    // Add specifications
    if (extractedData['brand'] != null) {
      parts.add('(${extractedData['brand']})');
    }
    if (extractedData['model'] != null) {
      parts.add(extractedData['model']);
    }
    
    // Add budget
    if (extractedData['budget']?['amount'] != null) {
      final amount = extractedData['budget']['amount'];
      final range = extractedData['budget']['range'] ?? 'for';
      parts.add('$range $amount');
    } else if (answers['budget'] != null) {
      parts.add('budget: ${answers['budget']}');
    }
    
    // Add location
    if (extractedData['location']?['area'] != null) {
      parts.add('in ${extractedData['location']['area']}');
    } else if (extractedData['location']?['city'] != null) {
      parts.add('in ${extractedData['location']['city']}');  
    } else if (answers['location'] != null) {
      parts.add('in ${answers['location']}');
    }
    
    // Add urgency if present
    if (extractedData['urgency'] == 'immediate') {
      parts.add('(urgent)');
    }
    
    return parts.join(' ');
  }
}