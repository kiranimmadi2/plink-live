import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum FirestoreErrorType {
  missingIndex,
  permissionDenied,
  documentNotFound,
  networkError,
  quotaExceeded,
  unknown
}

class FirestoreErrorHandler {
  static FirestoreErrorType getErrorType(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'failed-precondition':
          return FirestoreErrorType.missingIndex;
        case 'permission-denied':
          return FirestoreErrorType.permissionDenied;
        case 'not-found':
          return FirestoreErrorType.documentNotFound;
        case 'unavailable':
        case 'network-request-failed':
          return FirestoreErrorType.networkError;
        case 'resource-exhausted':
          return FirestoreErrorType.quotaExceeded;
        default:
          return FirestoreErrorType.unknown;
      }
    }
    
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('index')) {
      return FirestoreErrorType.missingIndex;
    } else if (errorString.contains('permission')) {
      return FirestoreErrorType.permissionDenied;
    } else if (errorString.contains('network')) {
      return FirestoreErrorType.networkError;
    }
    
    return FirestoreErrorType.unknown;
  }
  
  static String getErrorMessage(FirestoreErrorType errorType) {
    switch (errorType) {
      case FirestoreErrorType.missingIndex:
        return 'Missing Firestore index. Please create the required composite index in Firebase Console.';
      case FirestoreErrorType.permissionDenied:
        return 'Permission denied. Please check your Firestore security rules.';
      case FirestoreErrorType.documentNotFound:
        return 'Document not found.';
      case FirestoreErrorType.networkError:
        return 'Network error. Please check your connection.';
      case FirestoreErrorType.quotaExceeded:
        return 'Firestore quota exceeded. Please check your usage and billing.';
      case FirestoreErrorType.unknown:
        return 'An unexpected error occurred with Firestore.';
    }
  }
  
  static String? getIndexUrl(FirebaseException error) {
    if (error.code == 'failed-precondition' && error.message != null) {
      final regex = RegExp(r'https://console\.firebase\.google\.com/[^\s]+');
      final match = regex.firstMatch(error.message!);
      return match?.group(0);
    }
    return null;
  }
  
  static Future<T?> handleFirestoreOperation<T>({
    required Future<T> Function() operation,
    T? Function()? fallback,
    void Function(FirestoreErrorType, String?)? onError,
    bool logErrors = true,
  }) async {
    try {
      return await operation();
    } catch (error) {
      final errorType = getErrorType(error);
      final message = getErrorMessage(errorType);
      
      if (logErrors) {
        debugPrint('Firestore Error: $message');
        if (error is FirebaseException) {
          debugPrint('Error code: ${error.code}');
          debugPrint('Error details: ${error.message}');

          if (errorType == FirestoreErrorType.missingIndex) {
            final indexUrl = getIndexUrl(error);
            if (indexUrl != null) {
              debugPrint('Create index here: $indexUrl');
            }
          }
        }
      }
      
      String? additionalInfo;
      if (error is FirebaseException && errorType == FirestoreErrorType.missingIndex) {
        additionalInfo = getIndexUrl(error);
      }
      
      onError?.call(errorType, additionalInfo);
      
      return fallback?.call();
    }
  }
  
  static Future<QuerySnapshot<Map<String, dynamic>>?> safeQuery({
    required Query<Map<String, dynamic>> query,
    QuerySnapshot<Map<String, dynamic>>? Function()? fallback,
  }) async {
    return handleFirestoreOperation(
      operation: () => query.get(),
      fallback: fallback,
      onError: (errorType, info) {
        if (errorType == FirestoreErrorType.missingIndex && info != null) {
          debugPrint('Please create the index at: $info');
        }
      },
    );
  }
  
  static Future<DocumentSnapshot<Map<String, dynamic>>?> safeGet({
    required DocumentReference<Map<String, dynamic>> docRef,
    DocumentSnapshot<Map<String, dynamic>>? Function()? fallback,
  }) async {
    return handleFirestoreOperation(
      operation: () => docRef.get(),
      fallback: fallback,
    );
  }
  
  static Future<void> safeSet({
    required DocumentReference<Map<String, dynamic>> docRef,
    required Map<String, dynamic> data,
    SetOptions? options,
    void Function()? onSuccess,
    void Function(FirestoreErrorType)? onError,
  }) async {
    await handleFirestoreOperation(
      operation: () async {
        await docRef.set(data, options ?? SetOptions());
        onSuccess?.call();
      },
      onError: (errorType, _) => onError?.call(errorType),
    );
  }
}