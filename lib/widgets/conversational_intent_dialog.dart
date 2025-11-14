import 'package:flutter/material.dart';
import '../services/progressive_intent_service.dart';

class ConversationalIntentDialog extends StatefulWidget {
  final String initialInput;
  final Function(String finalIntent) onComplete;

  const ConversationalIntentDialog({
    Key? key,
    required this.initialInput,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<ConversationalIntentDialog> createState() => _ConversationalIntentDialogState();
}

class _ConversationalIntentDialogState extends State<ConversationalIntentDialog> 
    with SingleTickerProviderStateMixin {
  final ProgressiveIntentService _service = ProgressiveIntentService();
  final TextEditingController _customInputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _conversationSteps = [];
  Map<String, dynamic>? _currentQuestion;
  bool _isLoading = true;
  bool _isComplete = false;
  String _finalIntent = '';
  String? _selectedOption;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    
    _service.startNewConversation(widget.initialInput);
    _loadFirstQuestion();
  }

  @override
  void dispose() {
    _customInputController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstQuestion() async {
    final result = await _service.getNextQuestion(
      userInput: widget.initialInput,
    );
    
    if (result['success'] == true && result['data'] != null) {
      setState(() {
        _currentQuestion = result['data']['question'];
        _isComplete = result['data']['complete'] ?? false;
        if (_isComplete) {
          _finalIntent = result['data']['finalIntent'] ?? widget.initialInput;
        }
        _isLoading = false;
      });
      _animationController.forward();
    }
  }

  Future<void> _submitAnswer() async {
    if (_selectedOption == null && _customInputController.text.isEmpty) return;
    
    // Get the answer text
    String answerText = _selectedOption ?? '';
    String answerValue = _selectedOption ?? '';
    
    // If "other" is selected, use custom input
    if (_selectedOption == 'other') {
      answerText = _customInputController.text.trim();
      answerValue = answerText;
    } else {
      // Find the option text
      final options = _currentQuestion?['options'] as List<dynamic>? ?? [];
      final selectedOpt = options.firstWhere(
        (opt) => opt['value'] == _selectedOption,
        orElse: () => <String, Object>{'text': _selectedOption ?? ''},
      );
      answerText = selectedOpt['text'] ?? _selectedOption ?? '';
    }
    
    // Add to conversation history
    setState(() {
      _conversationSteps.add({
        'question': _currentQuestion?['text'] ?? '',
        'answer': answerValue,
        'answerText': answerText,
      });
      _isLoading = true;
      _currentQuestion = null;
      _selectedOption = null;
    });
    
    _customInputController.clear();
    _animationController.reset();
    
    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    
    // Get next question
    final result = await _service.getNextQuestion(
      userInput: widget.initialInput,
      previousAnswer: {
        'question': _conversationSteps.last['question'],
        'answer': answerValue,
        'answerText': answerText,
      },
    );
    
    if (result['success'] == true && result['data'] != null) {
      final data = result['data'];
      setState(() {
        _isComplete = data['complete'] ?? false;
        
        if (_isComplete) {
          _finalIntent = data['finalIntent'] ?? widget.initialInput;
          _handleCompletion();
        } else {
          _currentQuestion = data['question'];
          _isLoading = false;
          _animationController.forward();
        }
      });
    }
  }

  void _handleCompletion() async {
    // Save conversation for analytics
    _service.saveConversation(_finalIntent);
    
    // Don't close the dialog - instead process the intent and show matches
    setState(() {
      _isLoading = true;
    });
    
    // Process intent and get matches
    widget.onComplete(_finalIntent);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.chat,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Let me help you',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Answer a few questions to get better matches',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Conversation area
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Initial user input
                    _buildChatBubble(
                      widget.initialInput,
                      isUser: true,
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 16),
                    
                    // Previous Q&A
                    ..._buildConversationHistory(isDarkMode),
                    
                    // Current question or completion
                    if (_isComplete)
                      _buildCompletionMessage(isDarkMode)
                    else if (_isLoading)
                      _buildLoadingIndicator(isDarkMode)
                    else if (_currentQuestion != null)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildCurrentQuestion(isDarkMode),
                      ),
                  ],
                ),
              ),
            ),
            
            // Action area (only show if not complete and has question)
            if (!_isComplete && _currentQuestion != null)
              _buildActionArea(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(String text, {required bool isUser, required bool isDarkMode}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).primaryColor
              : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : (isDarkMode ? Colors.white : Colors.black87),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildConversationHistory(bool isDarkMode) {
    final widgets = <Widget>[];
    
    for (var step in _conversationSteps) {
      // Bot question
      widgets.add(_buildChatBubble(
        step['question'],
        isUser: false,
        isDarkMode: isDarkMode,
      ));
      widgets.add(const SizedBox(height: 8));
      
      // User answer
      widgets.add(_buildChatBubble(
        step['answerText'],
        isUser: true,
        isDarkMode: isDarkMode,
      ));
      widgets.add(const SizedBox(height: 16));
    }
    
    return widgets;
  }

  Widget _buildCurrentQuestion(bool isDarkMode) {
    final question = _currentQuestion!;
    final options = question['options'] as List<dynamic>? ?? [];
    final questionContext = question['context'] as String? ?? '';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question bubble
        _buildChatBubble(
          question['text'] ?? '',
          isUser: false,
          isDarkMode: isDarkMode,
        ),
        
        if (questionContext.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              questionContext,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
        
        const SizedBox(height: 16),
        
        // Options
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final value = option['value'] as String;
            final text = option['text'] as String;
            final allowInput = option['allowInput'] == true;
            final isSelected = _selectedOption == value;
            
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedOption = value;
                  if (!allowInput) {
                    _customInputController.clear();
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (allowInput)
                      Icon(
                        Icons.edit,
                        size: 16,
                        color: isSelected ? Colors.white : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    if (allowInput) const SizedBox(width: 4),
                    Text(
                      text,
                      style: TextStyle(
                        color: isSelected ? Colors.white : (isDarkMode ? Colors.white : Colors.black87),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        
        // Custom input field if "Other" is selected
        if (_selectedOption == 'other') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customInputController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Type your answer...',
              filled: true,
              fillColor: isDarkMode ? Colors.grey[850] : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onSubmitted: (_) => _submitAnswer(),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingIndicator(bool isDarkMode) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Thinking...',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionMessage(bool isDarkMode) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Got it! I understand what you need.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Finding the best matches for you...',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionArea(bool isDarkMode) {
    final canSubmit = _selectedOption != null && 
                      (_selectedOption != 'other' || _customInputController.text.isNotEmpty);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip'),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: canSubmit ? _submitAnswer : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Continue'),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}