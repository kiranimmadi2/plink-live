import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ConversationalClarificationDialog extends StatefulWidget {
  final String originalInput;
  final String question;
  final List<String> options;
  final String? reason;

  const ConversationalClarificationDialog({
    Key? key,
    required this.originalInput,
    required this.question,
    required this.options,
    this.reason,
  }) : super(key: key);

  static Future<String?> show(
    BuildContext context, {
    required String originalInput,
    required String question,
    required List<String> options,
    String? reason,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConversationalClarificationDialog(
        originalInput: originalInput,
        question: question,
        options: options,
        reason: reason,
      ),
    );
  }

  @override
  State<ConversationalClarificationDialog> createState() =>
      _ConversationalClarificationDialogState();
}

class _ConversationalClarificationDialogState
    extends State<ConversationalClarificationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final TextEditingController _customController = TextEditingController();
  bool _showCustomInput = false;
  String? _selectedOption;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 24,
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: theme.dialogBackgroundColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.primaryColor,
                            theme.primaryColor.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.help_outline,
                            color: Colors.white,
                            size: 32,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Quick Clarification',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Container(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Original input chip
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.primaryColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.format_quote,
                                  size: 16,
                                  color: theme.primaryColor,
                                ),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    widget.originalInput,
                                    style: TextStyle(
                                      color: theme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),

                          // Question
                          Text(
                            widget.question,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          if (widget.reason != null) ...[
                            SizedBox(height: 8),
                            Text(
                              widget.reason!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withOpacity(0.7),
                              ),
                            ),
                          ],

                          SizedBox(height: 20),

                          // Options
                          if (!_showCustomInput) ...[
                            ...widget.options.map((option) {
                              final isSelected = _selectedOption == option;
                              return Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _selectedOption = option;
                                      });
                                      Future.delayed(
                                        Duration(milliseconds: 200),
                                        () {
                                          Navigator.of(context).pop(option);
                                        },
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 200),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? theme.primaryColor
                                                .withOpacity(0.1)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? theme.primaryColor
                                              : theme.dividerColor,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          AnimatedContainer(
                                            duration:
                                                Duration(milliseconds: 200),
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected
                                                    ? theme.primaryColor
                                                    : theme.dividerColor,
                                                width: 2,
                                              ),
                                              color: isSelected
                                                  ? theme.primaryColor
                                                  : Colors.transparent,
                                            ),
                                            child: isSelected
                                                ? Icon(
                                                    Icons.check,
                                                    size: 12,
                                                    color: Colors.white,
                                                  )
                                                : null,
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              option,
                                              style: TextStyle(
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: isSelected
                                                    ? theme.primaryColor
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),

                            // Custom input option
                            SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showCustomInput = true;
                                });
                              },
                              icon: Icon(Icons.edit),
                              label: Text('Type my own answer'),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.primaryColor,
                              ),
                            ),
                          ] else ...[
                            // Custom input field
                            TextField(
                              controller: _customController,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: 'Type your answer...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: theme.primaryColor,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Icon(Icons.edit),
                              ),
                              onSubmitted: (value) {
                                if (value.isNotEmpty) {
                                  Navigator.of(context).pop(value);
                                }
                              },
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _showCustomInput = false;
                                      _customController.clear();
                                    });
                                  },
                                  child: Text('Back to options'),
                                ),
                                Spacer(),
                                ElevatedButton(
                                  onPressed: () {
                                    if (_customController.text.isNotEmpty) {
                                      Navigator.of(context)
                                          .pop(_customController.text);
                                    }
                                  },
                                  child: Text('Submit'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}