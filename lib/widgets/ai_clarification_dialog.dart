import 'package:flutter/material.dart';
import '../services/ai_intent_engine.dart';

/// AI-driven clarification dialog that dynamically generates questions
class AIClarificationDialog extends StatefulWidget {
  final String userPrompt;
  final IntentAnalysis intentAnalysis;
  final Function(Map<String, dynamic>) onComplete;

  const AIClarificationDialog({
    super.key,
    required this.userPrompt,
    required this.intentAnalysis,
    required this.onComplete,
  });

  @override
  State<AIClarificationDialog> createState() => _AIClarificationDialogState();
}

class _AIClarificationDialogState extends State<AIClarificationDialog> {
  final AIIntentEngine _intentEngine = AIIntentEngine();
  List<ClarifyingQuestion> _questions = [];
  Map<String, dynamic> _answers = {};
  int _currentQuestionIndex = 0;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // Generate questions based on AI analysis
      final questions = await _intentEngine.generateClarifyingQuestions(
        widget.userPrompt,
        widget.intentAnalysis,
      );

      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to generate questions. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      // All questions answered, complete the flow
      widget.onComplete(_answers);
      Navigator.of(context).pop();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  void _skipQuestion() {
    // Mark as skipped and move to next
    final question = _questions[_currentQuestionIndex];
    _answers[question.id] = null;
    _nextQuestion();
  }

  Widget _buildQuestionCard(ClarifyingQuestion question) {
    return Card(
      elevation: 0,
      color: Theme.of(context).primaryColor.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Question importance badge
            if (question.importance == 'essential')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Important',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            
            // Question text
            Text(
              question.question,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Reason for asking (tooltip)
            if (question.reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                question.reason,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Answer input
            _buildAnswerInput(question),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerInput(ClarifyingQuestion question) {
    final currentAnswer = _answers[question.id];

    switch (question.type) {
      case 'choice':
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: (question.options ?? []).map((option) {
            final isSelected = currentAnswer == option;
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _answers[question.id] = selected ? option : null;
                });
              },
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
            );
          }).toList(),
        );

      case 'yes_no':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Yes'),
              selected: currentAnswer == true,
              onSelected: (selected) {
                setState(() {
                  _answers[question.id] = selected ? true : null;
                });
              },
              selectedColor: Colors.green.withOpacity(0.2),
            ),
            const SizedBox(width: 16),
            ChoiceChip(
              label: const Text('No'),
              selected: currentAnswer == false,
              onSelected: (selected) {
                setState(() {
                  _answers[question.id] = selected ? false : null;
                });
              },
              selectedColor: Colors.red.withOpacity(0.2),
            ),
          ],
        );

      case 'range':
        return Column(
          children: [
            Text(
              'Select a range',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Min',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final range = (_answers[question.id] as Map<String, dynamic>?) ?? {};
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final range = (_answers[question.id] as Map<String, dynamic>?) ?? {};
                      range['max'] = value;
                      _answers[question.id] = range;
                    },
                  ),
                ),
              ],
            ),
          ],
        );

      case 'text':
      default:
        return TextField(
          decoration: InputDecoration(
            hintText: 'Type your answer...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          maxLines: 2,
          onChanged: (value) {
            _answers[question.id] = value;
          },
        );
    }
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: (_currentQuestionIndex + 1) / _questions.length,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
        ),
        const SizedBox(height: 8),
        Text(
          'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    final question = _questions[_currentQuestionIndex];
    final hasAnswer = _answers[question.id] != null;
    final isLastQuestion = _currentQuestionIndex == _questions.length - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back button
        if (_currentQuestionIndex > 0)
          TextButton.icon(
            onPressed: _previousQuestion,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
          )
        else
          const SizedBox(width: 80),

        // Skip button (only for non-essential questions)
        if (question.importance != 'essential')
          TextButton(
            onPressed: _skipQuestion,
            child: const Text('Skip'),
          )
        else
          const SizedBox.shrink(),

        // Next/Complete button
        ElevatedButton.icon(
          onPressed: hasAnswer ? _nextQuestion : null,
          icon: Icon(isLastQuestion ? Icons.check : Icons.arrow_forward),
          label: Text(isLastQuestion ? 'Complete' : 'Next'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.auto_awesome,
          size: 64,
          color: Colors.amber,
        ),
        const SizedBox(height: 16),
        const Text(
          'All set! 🎉',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'AI understood your intent:',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"${widget.userPrompt}"',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Intent: ${widget.intentAnalysis.primaryIntent}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                'Action: ${widget.intentAnalysis.actionType}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _currentQuestionIndex = 0;
                });
              },
              child: const Text('Review Answers'),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(
          maxWidth: 450,
          maxHeight: 600,
        ),
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('AI is analyzing your request...'),
                  ],
                ),
              )
            : _error.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(_error),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadQuestions,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  )
                : _questions.isEmpty
                    ? _buildSummaryView()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Progress indicator
                          _buildProgressIndicator(),
                          const SizedBox(height: 24),
                          
                          // Question card
                          Expanded(
                            child: SingleChildScrollView(
                              child: _buildQuestionCard(_questions[_currentQuestionIndex]),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Navigation buttons
                          _buildNavigationButtons(),
                        ],
                      ),
      ),
    );
  }
}