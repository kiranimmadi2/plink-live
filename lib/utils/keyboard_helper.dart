import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyboardHelper {
  static void keepKeyboardOpen(BuildContext context) {
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }
  
  static void hideKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }
  
  static void requestFocus(BuildContext context, FocusNode focusNode) {
    FocusScope.of(context).requestFocus(focusNode);
  }
  
  static Widget buildPersistentTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    String? hintText,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    TextInputType? keyboardType,
    int? maxLines,
    bool autofocus = false,
    EdgeInsetsGeometry? contentPadding,
    InputDecoration? decoration,
  }) {
    return PopScope(
      canPop: !focusNode.hasFocus,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && focusNode.hasFocus) {
          focusNode.unfocus();
        }
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        keyboardType: keyboardType ?? TextInputType.text,
        maxLines: maxLines ?? 1,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTap: () {
          // Ensure keyboard stays open
          SystemChannels.textInput.invokeMethod('TextInput.show');
        },
        decoration: decoration ?? InputDecoration(
          hintText: hintText,
          contentPadding: contentPadding ?? const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class PersistentKeyboardTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final int? maxLines;
  final bool autofocus;
  final InputDecoration? decoration;

  const PersistentKeyboardTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.maxLines,
    this.autofocus = false,
    this.decoration,
  });

  @override
  State<PersistentKeyboardTextField> createState() => _PersistentKeyboardTextFieldState();
}

class _PersistentKeyboardTextFieldState extends State<PersistentKeyboardTextField> {
  late FocusNode _focusNode;
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    
    // Auto-focus if requested
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      setState(() => _keyboardVisible = true);
      // Keep keyboard open
      SystemChannels.textInput.invokeMethod('TextInput.show');
    } else {
      setState(() => _keyboardVisible = false);
    }
  }

  void _requestFocus() {
    FocusScope.of(context).requestFocus(_focusNode);
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _requestFocus,
      behavior: HitTestBehavior.translucent,
      child: AbsorbPointer(
        absorbing: false,
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          keyboardType: widget.keyboardType ?? TextInputType.text,
          maxLines: widget.maxLines ?? 1,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          onTap: () {
            // Prevent keyboard from closing
            if (!_focusNode.hasFocus) {
              _requestFocus();
            }
          },
          decoration: widget.decoration ?? InputDecoration(
            hintText: widget.hintText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: _keyboardVisible 
              ? Colors.blue.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.05),
          ),
        ),
      ),
    );
  }
}