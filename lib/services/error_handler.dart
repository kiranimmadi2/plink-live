import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Global error handler for the app
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  // Error tracking
  final List<AppError> _recentErrors = [];
  static const int maxErrorHistory = 50;
  
  /// Initialize error handling
  static void initialize() {
    // Set up Flutter error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kDebugMode) {
        FlutterError.dumpErrorToConsole(details);
      } else {
        // In release mode, report to Crashlytics
        // FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
      
      _instance._logError(
        AppError(
          message: details.exceptionAsString(),
          stackTrace: details.stack,
          isFatal: true,
          context: details.context?.toString(),
        ),
      );
    };
    
    // Set up async error handling
    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) {
        debugPrint('Async error: $error');
        debugPrint('Stack trace: $stack');
      } else {
        // In release mode, report to Crashlytics
        // FirebaseCrashlytics.instance.recordError(error, stack);
      }
      
      _instance._logError(
        AppError(
          message: error.toString(),
          stackTrace: stack,
          isFatal: false,
        ),
      );
      
      return true;
    };
  }
  
  /// Log an error
  void _logError(AppError error) {
    _recentErrors.add(error);
    if (_recentErrors.length > maxErrorHistory) {
      _recentErrors.removeAt(0);
    }
  }
  
  /// Handle and log errors with context
  static Future<T?> handleError<T>(
    Future<T> Function() operation, {
    String? context,
    bool showSnackbar = true,
    VoidCallback? onError,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Error in $context: $error');
        debugPrint('Stack trace: $stackTrace');
      }
      
      _instance._logError(
        AppError(
          message: error.toString(),
          stackTrace: stackTrace,
          context: context,
          isFatal: false,
        ),
      );
      
      onError?.call();
      
      if (showSnackbar && _instance._context != null) {
        _instance.showErrorSnackbar(
          _instance._context!,
          _getUserFriendlyMessage(error),
        );
      }
      
      return null;
    }
  }
  
  /// Handle sync errors
  static T? handleSyncError<T>(
    T Function() operation, {
    String? context,
    T? defaultValue,
  }) {
    try {
      return operation();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Sync error in $context: $error');
        debugPrint('Stack trace: $stackTrace');
      }
      
      _instance._logError(
        AppError(
          message: error.toString(),
          stackTrace: stackTrace,
          context: context,
          isFatal: false,
        ),
      );
      
      return defaultValue;
    }
  }
  
  /// Get user-friendly error message
  static String _getUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || 
        errorString.contains('connection') ||
        errorString.contains('socket')) {
      return 'Network connection error. Please check your internet connection.';
    }
    
    if (errorString.contains('permission') || 
        errorString.contains('denied')) {
      return 'Permission denied. Please check your app permissions.';
    }
    
    if (errorString.contains('not found') || 
        errorString.contains('404')) {
      return 'The requested resource was not found.';
    }
    
    if (errorString.contains('timeout')) {
      return 'Operation timed out. Please try again.';
    }
    
    if (errorString.contains('invalid') || 
        errorString.contains('format')) {
      return 'Invalid data format. Please try again.';
    }
    
    if (errorString.contains('authentication') || 
        errorString.contains('unauthorized')) {
      return 'Authentication error. Please sign in again.';
    }
    
    if (errorString.contains('quota') || 
        errorString.contains('limit')) {
      return 'Service limit reached. Please try again later.';
    }
    
    return 'An unexpected error occurred. Please try again.';
  }
  
  /// Show error snackbar
  void showErrorSnackbar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  /// Show success snackbar
  void showSuccessSnackbar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  /// Get recent errors for debugging
  List<AppError> get recentErrors => List.unmodifiable(_recentErrors);
  
  /// Clear error history
  void clearErrorHistory() {
    _recentErrors.clear();
  }
  
  // Store context for showing snackbars
  BuildContext? _context;
  void setContext(BuildContext context) => _context = context;
  
  /// Retry operation with exponential backoff
  static Future<T?> retryOperation<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    String? context,
  }) async {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await operation();
      } catch (error) {
        if (attempt == maxAttempts - 1) {
          // Last attempt failed
          if (kDebugMode) {
            debugPrint('All retry attempts failed for $context: $error');
          }
          rethrow;
        }

        // Wait before retrying with exponential backoff
        final delay = initialDelay * (attempt + 1);
        if (kDebugMode) {
          debugPrint('Retry attempt ${attempt + 1} for $context after ${delay.inSeconds}s');
        }
        await Future.delayed(delay);
      }
    }
    return null;
  }
}

/// App error model
class AppError {
  final String message;
  final StackTrace? stackTrace;
  final String? context;
  final bool isFatal;
  final DateTime timestamp;
  
  AppError({
    required this.message,
    this.stackTrace,
    this.context,
    this.isFatal = false,
  }) : timestamp = DateTime.now();
  
  @override
  String toString() {
    return 'AppError: $message${context != null ? ' (Context: $context)' : ''} at $timestamp';
  }
}

/// Widget for error boundary
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stack)? errorBuilder;
  
  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
  });
  
  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;
  
  @override
  void initState() {
    super.initState();
    ErrorWidget.builder = (FlutterErrorDetails details) {
      if (mounted) {
        setState(() {
          _error = details.exception;
          _stackTrace = details.stack;
        });
      }
      
      return widget.errorBuilder?.call(details.exception, details.stack) ??
          _buildDefaultErrorWidget(details.exception);
    };
  }
  
  Widget _buildDefaultErrorWidget(Object error) {
    return Material(
      child: Container(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 60,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  kDebugMode ? error.toString() : 'Please try again later',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _stackTrace = null;
                    });
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(_error!, _stackTrace) ??
          _buildDefaultErrorWidget(_error!);
    }
    return widget.child;
  }
}