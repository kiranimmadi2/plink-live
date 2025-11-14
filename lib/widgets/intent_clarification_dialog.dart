import 'package:flutter/material.dart';

class IntentClarificationDialog extends StatefulWidget {
  final Map<String, dynamic> clarificationData;
  final Function(List<Map<String, dynamic>>) onAnswersSubmit;

  const IntentClarificationDialog({
    Key? key,
    required this.clarificationData,
    required this.onAnswersSubmit,
  }) : super(key: key);

  @override
  State<IntentClarificationDialog> createState() => _IntentClarificationDialogState();
}

class _IntentClarificationDialogState extends State<IntentClarificationDialog> {
  final Map<String, String> _selectedAnswers = {};
  final Map<String, TextEditingController> _customInputControllers = {};
  final Map<String, bool> _showCustomInput = {};

  @override
  void initState() {
    super.initState();
    // Initialize controllers for potential custom inputs
    final questions = widget.clarificationData['questions'] as List<dynamic>? ?? [];
    for (var question in questions) {
      final questionId = question['id'] as String;
      _customInputControllers[questionId] = TextEditingController();
      _showCustomInput[questionId] = false;
    }
  }

  @override
  void dispose() {
    for (var controller in _customInputControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.clarificationData['questions'] as List<dynamic>? ?? [];
    final contextText = widget.clarificationData['context'] as String? ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Help us understand better',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            
            if (contextText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  contextText,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Questions
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: questions.map((question) {
                    final questionId = question['id'] as String;
                    final questionText = question['question'] as String;
                    final options = question['options'] as List<dynamic>;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            questionText,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Options
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: options.map((option) {
                              final optionId = option['id'] as String;
                              final optionText = option['text'] as String;
                              final optionValue = option['value'] as String;
                              final allowCustom = option['allowCustomInput'] == true;
                              final isSelected = _selectedAnswers[questionId] == optionValue;
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedAnswers[questionId] = optionValue;
                                        
                                        // Show custom input if "Other" is selected
                                        if (allowCustom) {
                                          _showCustomInput[questionId] = true;
                                        } else {
                                          _showCustomInput[questionId] = false;
                                          _customInputControllers[questionId]?.clear();
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Theme.of(context).primaryColor
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(25),
                                        border: Border.all(
                                          color: isSelected
                                              ? Theme.of(context).primaryColor
                                              : Colors.grey[300]!,
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (allowCustom)
                                            Icon(
                                              Icons.edit,
                                              size: 16,
                                              color: isSelected 
                                                  ? Colors.white 
                                                  : Colors.grey[600],
                                            ),
                                          if (allowCustom) const SizedBox(width: 4),
                                          Text(
                                            optionText,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.grey[800],
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  // Custom input field for "Other"
                                  if (allowCustom && _showCustomInput[questionId] == true) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      child: TextField(
                                        controller: _customInputControllers[questionId],
                                        decoration: InputDecoration(
                                          hintText: 'Please specify...',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey[50],
                                        ),
                                        style: const TextStyle(fontSize: 14),
                                        maxLines: 2,
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Skip'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _canSubmit() ? _submitAnswers : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _canSubmit() {
    final questions = widget.clarificationData['questions'] as List<dynamic>? ?? [];
    
    // Check if at least one question is answered
    for (var question in questions) {
      final questionId = question['id'] as String;
      if (_selectedAnswers.containsKey(questionId)) {
        // If "Other" is selected, check if custom input is provided
        if (_selectedAnswers[questionId] == 'other') {
          final customInput = _customInputControllers[questionId]?.text.trim() ?? '';
          if (customInput.isNotEmpty) {
            return true;
          }
        } else {
          return true;
        }
      }
    }
    return false;
  }

  void _submitAnswers() {
    final List<Map<String, dynamic>> answers = [];
    final questions = widget.clarificationData['questions'] as List<dynamic>? ?? [];
    
    for (var question in questions) {
      final questionId = question['id'] as String;
      final questionText = question['question'] as String;
      
      if (_selectedAnswers.containsKey(questionId)) {
        final selectedValue = _selectedAnswers[questionId]!;
        String answerText = selectedValue;
        
        // If "Other" is selected, use custom input
        if (selectedValue == 'other') {
          answerText = _customInputControllers[questionId]?.text.trim() ?? selectedValue;
        } else {
          // Find the option text for the selected value
          final options = question['options'] as List<dynamic>;
          final selectedOption = options.firstWhere(
            (opt) => opt['value'] == selectedValue,
            orElse: () => {'text': selectedValue},
          );
          answerText = selectedOption['text'] as String;
        }
        
        answers.add({
          'questionId': questionId,
          'question': questionText,
          'answer': selectedValue,
          'answerText': answerText,
        });
      }
    }
    
    Navigator.of(context).pop();
    widget.onAnswersSubmit(answers);
  }
}