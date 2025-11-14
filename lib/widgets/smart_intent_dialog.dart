import 'package:flutter/material.dart';
import '../services/smart_prompt_parser.dart';
import '../services/universal_intent_service.dart';

class SmartIntentDialog extends StatefulWidget {
  final String initialInput;
  final Function(Map<String, dynamic>) onComplete;

  const SmartIntentDialog({
    Key? key,
    required this.initialInput,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<SmartIntentDialog> createState() => _SmartIntentDialogState();
}

class _SmartIntentDialogState extends State<SmartIntentDialog> 
    with SingleTickerProviderStateMixin {
  final SmartPromptParser _parser = SmartPromptParser();
  final UniversalIntentService _intentService = UniversalIntentService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  Map<String, dynamic> _extractedData = {};
  List<Map<String, dynamic>> _missingFields = [];
  Map<String, String> _userAnswers = {};
  int _currentFieldIndex = 0;
  bool _isLoading = true;
  bool _isProcessing = false;
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
    
    _extractInitialData();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _extractInitialData() async {
    // Extract all possible data from initial prompt
    _extractedData = await _parser.extractFromPrompt(widget.initialInput);
    
    // Get list of missing fields
    _missingFields = _parser.getMissingFields(_extractedData);
    
    setState(() {
      _isLoading = false;
    });
    
    // If no missing fields, process immediately
    if (_missingFields.isEmpty) {
      _processIntent();
    } else {
      _animationController.forward();
    }
  }
  
  void _submitAnswer() {
    final currentField = _missingFields[_currentFieldIndex];
    String answer = '';
    
    if (_selectedOption != null) {
      if (_selectedOption == 'other') {
        answer = _inputController.text.trim();
      } else {
        answer = _selectedOption!;
      }
    } else if (currentField['type'] == 'text') {
      answer = _inputController.text.trim();
    }
    
    if (answer.isEmpty) return;
    
    // Store answer
    _userAnswers[currentField['field']] = answer;
    
    // Move to next field or process
    setState(() {
      _currentFieldIndex++;
      _selectedOption = null;
      _inputController.clear();
    });
    
    if (_currentFieldIndex >= _missingFields.length) {
      _processIntent();
    } else {
      _animationController.reset();
      _animationController.forward();
    }
    
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
  }
  
  void _skipField() {
    final currentField = _missingFields[_currentFieldIndex];
    
    // Only allow skipping optional fields
    if (currentField['optional'] == true) {
      setState(() {
        _currentFieldIndex++;
        _selectedOption = null;
        _inputController.clear();
      });
      
      if (_currentFieldIndex >= _missingFields.length) {
        _processIntent();
      } else {
        _animationController.reset();
        _animationController.forward();
      }
    }
  }
  
  Future<void> _processIntent() async {
    setState(() {
      _isProcessing = true;
    });
    
    // Build final intent string
    final finalIntent = _parser.buildFinalIntent(_extractedData, _userAnswers);
    
    // Process through intent service
    final result = await _intentService.processIntentAndMatch(finalIntent);
    
    // Pass result back to parent
    widget.onComplete(result);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Understanding your request...'),
            ],
          ),
        ),
      );
    }
    
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
            _buildHeader(isDarkMode),
            
            // Content area
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show initial input
                    _buildUserBubble(widget.initialInput, isDarkMode),
                    const SizedBox(height: 16),
                    
                    // Show extracted data summary if we extracted something
                    if (_extractedData['extracted'] == true)
                      _buildExtractedSummary(isDarkMode),
                    
                    // Show answered questions
                    ..._buildAnsweredQuestions(isDarkMode),
                    
                    // Current question or processing
                    if (_isProcessing)
                      _buildProcessingIndicator(isDarkMode)
                    else if (_currentFieldIndex < _missingFields.length)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildCurrentQuestion(isDarkMode),
                      ),
                  ],
                ),
              ),
            ),
            
            // Action buttons
            if (!_isProcessing && _currentFieldIndex < _missingFields.length)
              _buildActionArea(isDarkMode),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader(bool isDarkMode) {
    return Container(
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
              Icons.auto_awesome,
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
                  'Smart Assistant',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  _missingFields.isEmpty 
                      ? 'I understand your request!'
                      : 'Let me clarify a few details',
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
    );
  }
  
  Widget _buildUserBubble(String text, bool isDarkMode) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }
  
  Widget _buildExtractedSummary(bool isDarkMode) {
    final extracted = <String>[];
    
    if (_extractedData['product'] != null) {
      extracted.add('Product: ${_extractedData['product']}');
    }
    if (_extractedData['service'] != null) {
      extracted.add('Service: ${_extractedData['service']}');
    }
    if (_extractedData['budget']?['amount'] != null) {
      extracted.add('Budget: ${_extractedData['budget']['amount']}');
    }
    if (_extractedData['location']?['area'] != null) {
      extracted.add('Location: ${_extractedData['location']['area']}');
    }
    
    if (extracted.isEmpty) return const SizedBox.shrink();
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'I understood:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    ...extracted.map((item) => Text(
                      '• $item',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
  
  List<Widget> _buildAnsweredQuestions(bool isDarkMode) {
    final widgets = <Widget>[];
    
    for (int i = 0; i < _currentFieldIndex && i < _missingFields.length; i++) {
      final field = _missingFields[i];
      final answer = _userAnswers[field['field']];
      
      if (answer != null) {
        // Question
        widgets.add(
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(
                field['question'],
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
        widgets.add(const SizedBox(height: 8));
        
        // Answer
        widgets.add(_buildUserBubble(answer, isDarkMode));
        widgets.add(const SizedBox(height: 16));
      }
    }
    
    return widgets;
  }
  
  Widget _buildCurrentQuestion(bool isDarkMode) {
    final field = _missingFields[_currentFieldIndex];
    final options = field['options'] as List<dynamic>?;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question bubble
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field['question'],
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 14,
                  ),
                ),
                if (field['context'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    field['context'],
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Options or text input
        if (options != null && options.isNotEmpty) ...[
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
                      _inputController.clear();
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
                          size: 14,
                          color: isSelected ? Colors.white : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      if (allowInput) const SizedBox(width: 4),
                      Text(
                        text,
                        style: TextStyle(
                          color: isSelected ? Colors.white : (isDarkMode ? Colors.white : Colors.black87),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          
          // Custom input for "other" option
          if (_selectedOption == 'other') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _inputController,
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
        ] else ...[
          // Text input field
          TextField(
            controller: _inputController,
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
  
  Widget _buildProcessingIndicator(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Processing your request...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Finding the best matches for you',
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
    );
  }
  
  Widget _buildActionArea(bool isDarkMode) {
    final currentField = _missingFields[_currentFieldIndex];
    final isOptional = currentField['optional'] == true;
    final canSubmit = _selectedOption != null && 
                      (_selectedOption != 'other' || _inputController.text.isNotEmpty) ||
                      (currentField['type'] == 'text' && _inputController.text.isNotEmpty);
    
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
          if (isOptional)
            TextButton(
              onPressed: _skipField,
              child: const Text('Skip'),
            )
          else
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
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
                Text(_currentFieldIndex == _missingFields.length - 1 ? 'Find Matches' : 'Continue'),
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