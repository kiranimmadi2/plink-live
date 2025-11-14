import 'package:flutter/material.dart';
import '../services/unified_matching_service.dart';

/// Dynamic clarification dialog using AI
/// NO hardcoded categories - questions generated based on AI understanding
class EnhancedClarificationDialog extends StatefulWidget {
  final String initialPrompt;
  final IntentAnalysis? intentAnalysis;
  final Function(Map<String, dynamic>) onComplete;

  const EnhancedClarificationDialog({
    super.key,
    required this.initialPrompt,
    this.intentAnalysis,
    required this.onComplete,
  });

  @override
  State<EnhancedClarificationDialog> createState() => _EnhancedClarificationDialogState();
}

class _EnhancedClarificationDialogState extends State<EnhancedClarificationDialog> {
  int _currentStep = 0;
  final Map<String, dynamic> _answers = {};
  List<ClarifyingQuestion> _questions = [];
  bool _isLoading = true;
  final UnifiedMatchingService _matchingService = UnifiedMatchingService();

  @override
  void initState() {
    super.initState();
    _generateQuestionsWithAI();
  }

  Future<void> _generateQuestionsWithAI() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get or analyze intent
      IntentAnalysis intent;
      if (widget.intentAnalysis != null) {
        intent = widget.intentAnalysis!;
      } else {
        intent = await _matchingService.analyzeIntent(widget.initialPrompt);
      }

      // Generate clarifying questions using AI
      _questions = await _matchingService.generateClarifyingQuestions(
        widget.initialPrompt,
        intent,
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error generating questions: $e');
      setState(() {
        _isLoading = false;
        // Add a generic question if AI fails
        _questions = [
          ClarifyingQuestion(
            id: 'location',
            question: 'Where are you located?',
            type: 'text',
            importance: 'helpful',
            reason: 'Helps find nearby matches',
          ),
        ];
      });
    }
  }

  // All question generation now handled by AI - no more hardcoded category logic!

  Widget _buildCurrentQuestion() {
    // Show loading state
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing your request...'),
          ],
        ),
      );
    }

    // Show summary if all questions answered
    if (_currentStep >= _questions.length) {
      return _buildSummary();
    }

    final question = _questions[_currentStep];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress indicator
        LinearProgressIndicator(
          value: (_currentStep + 1) / _questions.length,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
        ),
        const SizedBox(height: 24),

        // Question with importance badge
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (question.importance == 'essential')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Required',
                  style: TextStyle(fontSize: 10, color: Colors.red[900]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        Text(
          question.question,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),

        // Show reason if provided
        if (question.reason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            question.reason,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],

        const SizedBox(height: 24),

        // Answer input
        _buildAnswerInput(question),

        const SizedBox(height: 24),

        // Navigation buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentStep > 0)
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                },
                child: const Text('Back'),
              )
            else
              const SizedBox.shrink(),

            Row(
              children: [
                if (question.importance != 'essential')
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _currentStep++;
                      });
                    },
                    child: const Text('Skip'),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_validateAnswer(question)) {
                      setState(() {
                        _currentStep++;
                      });
                    }
                  },
                  child: Text(_currentStep < _questions.length - 1 ? 'Next' : 'Finish'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnswerInput(ClarifyingQuestion question) {
    // Dynamic answer input based on AI-determined question type
    switch (question.type.toLowerCase()) {
      case 'choice':
        if (question.options == null || question.options!.isEmpty) {
          return _buildTextInput(question);
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: question.options!.map((option) {
            final isSelected = _answers[question.id] == option;
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _answers[question.id] = selected ? option : null;
                });
              },
            );
          }).toList(),
        );

      case 'range':
        return Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Min',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final range = _answers[question.id] as Map? ?? {};
                  range['min'] = value;
                  _answers[question.id] = range;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Max',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final range = _answers[question.id] as Map? ?? {};
                  range['max'] = value;
                  _answers[question.id] = range;
                },
              ),
            ),
          ],
        );

      case 'yes_no':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Yes'),
              selected: _answers[question.id] == 'yes',
              onSelected: (selected) {
                setState(() {
                  _answers[question.id] = selected ? 'yes' : null;
                });
              },
            ),
            const SizedBox(width: 16),
            ChoiceChip(
              label: const Text('No'),
              selected: _answers[question.id] == 'no',
              onSelected: (selected) {
                setState(() {
                  _answers[question.id] = selected ? 'no' : null;
                });
              },
            ),
          ],
        );

      case 'text':
      default:
        return _buildTextInput(question);
    }
  }

  Widget _buildTextInput(ClarifyingQuestion question) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Enter your answer',
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) {
        _answers[question.id] = value;
      },
    );
  }

  bool _validateAnswer(ClarifyingQuestion question) {
    // Validate essential questions
    if (question.importance == 'essential') {
      return _answers[question.id] != null && _answers[question.id].toString().isNotEmpty;
    }
    return true;
  }

  Widget _buildSummary() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Great! Here\'s what we\'ve gathered:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"${widget.initialPrompt}"',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              ..._answers.entries.map((entry) {
                final question = _questions.firstWhere((q) => q.id == entry.key);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check, size: 16, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${question.question}: ${_formatAnswer(entry.value)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _currentStep = 0;
                });
              },
              child: const Text('Edit Answers'),
            ),
            ElevatedButton(
              onPressed: () {
                widget.onComplete(_answers);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Post Now'),
            ),
          ],
        ),
      ],
    );
  }

  String _formatAnswer(dynamic value) {
    if (value is List) {
      return value.join(', ');
    } else if (value is Map) {
      if (value.containsKey('min') && value.containsKey('max')) {
        return '${value['min']} - ${value['max']}';
      }
      return value.toString();
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: _buildCurrentQuestion(),
        ),
      ),
    );
  }
}

// No more hardcoded question types or categories!
// Everything is handled dynamically by AI through UnifiedMatchingService