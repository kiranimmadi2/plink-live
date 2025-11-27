import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PersistentKeyboardWrapper extends StatefulWidget {
  final Widget child;
  final bool persistKeyboard;

  const PersistentKeyboardWrapper({
    super.key,
    required this.child,
    this.persistKeyboard = true,
  });

  @override
  State<PersistentKeyboardWrapper> createState() =>
      _PersistentKeyboardWrapperState();
}

class _PersistentKeyboardWrapperState extends State<PersistentKeyboardWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    if (widget.persistKeyboard) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void dispose() {
    if (widget.persistKeyboard) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (widget.persistKeyboard) {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final bottomInset = view.viewInsets.bottom;
      // If keyboard was visible and is now hiding, show it again
      if (bottomInset == 0) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            final focusScope = FocusScope.of(context);
            if (focusScope.hasFocus || focusScope.hasPrimaryFocus) {
              SystemChannels.textInput.invokeMethod('TextInput.show');
            }
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Prevent keyboard from closing on tap outside
        if (widget.persistKeyboard) {
          final currentFocus = FocusScope.of(context);
          if (!currentFocus.hasPrimaryFocus &&
              currentFocus.focusedChild != null) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
        }
      },
      child: widget.child,
    );
  }
}
