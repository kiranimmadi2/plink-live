import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/unified_matching_service.dart';

/// Simple intent dialog using AI
/// NO hardcoded categories - dynamic understanding based on user input
class SimpleIntentDialog extends StatefulWidget {
  final String initialInput;
  final Function(String) onComplete;

  const SimpleIntentDialog({
    Key? key,
    required this.initialInput,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<SimpleIntentDialog> createState() => _SimpleIntentDialogState();
}

class _SimpleIntentDialogState extends State<SimpleIntentDialog> {
  final UnifiedMatchingService _matchingService = UnifiedMatchingService();
  IntentAnalysis? _intentAnalysis;
  bool _isLoading = true;
  String? _refinedIntent;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _analyzeIntent();
  }

  Future<void> _analyzeIntent() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final analysis = await _matchingService.analyzeIntent(widget.initialInput);
      setState(() {
        _intentAnalysis = analysis;
        _isLoading = false;

        // If AI understood the intent clearly (no clarifications needed), go to refinement
        if (analysis.clarificationsNeeded.isEmpty) {
          _currentStep = 1;
        }
      });
    } catch (e) {
      debugPrint('Error analyzing intent: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildAnalysisView() {
    if (_isLoading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Understanding your request...'),
        ],
      );
    }

    if (_intentAnalysis == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.orange),
          const SizedBox(height: 16),
          const Text('Could not analyze your request'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              widget.onComplete(widget.initialInput);
              Navigator.of(context).pop();
            },
            child: const Text('Continue Anyway'),
          ),
        ],
      );
    }

    // Show AI understanding
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'I understand you\'re:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            _intentAnalysis!.primaryIntent,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Show action type
        Row(
          children: [
            Icon(
              _getActionIcon(_intentAnalysis!.actionType),
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              _formatActionType(_intentAnalysis!.actionType),
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Proceed button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              widget.onComplete(widget.initialInput);
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.search),
            label: const Text('Find Matches'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getActionIcon(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'seeking':
      case 'buying':
        return Icons.search;
      case 'offering':
      case 'selling':
        return Icons.sell;
      case 'lost':
        return Icons.help_outline;
      case 'found':
        return Icons.check_circle_outline;
      default:
        return Icons.info_outline;
    }
  }

  String _formatActionType(String actionType) {
    final formatted = actionType.replaceAll('_', ' ');
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: isDarkMode ? const Color(0xFF1F2C33) : Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI Understanding',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.initialInput,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            _buildAnalysisView(),
            const SizedBox(height: 16),
            if (!_isLoading && _intentAnalysis != null)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDarkMode ? Colors.blue[300] : Colors.blue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// No more hardcoded category detection!
// Everything is handled by AI through UnifiedMatchingService