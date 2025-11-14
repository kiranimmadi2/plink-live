import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_error_handler.dart';
import '../utils/network_utils.dart';

class SafeFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Future<QuerySnapshot<Map<String, dynamic>>?> getMessages({
    required String receiverId,
    int limit = 50,
  }) async {
    final hasConnection = await NetworkUtils.hasNetworkConnection();
    if (!hasConnection) {
      print('Cannot fetch messages - no network connection');
      return null;
    }

    final query = _firestore
        .collection('messages')
        .where('receiverId', isEqualTo: receiverId)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    return FirestoreErrorHandler.safeQuery(
      query: query,
      fallback: () {
        print('Using cached data or empty result');
        return null;
      },
    );
  }
  
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    await NetworkUtils.performNetworkOperation(
      operation: () async {
        final docRef = _firestore.collection('messages').doc();
        
        await FirestoreErrorHandler.safeSet(
          docRef: docRef,
          data: {
            'senderId': senderId,
            'receiverId': receiverId,
            'message': message,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'sent',
            ...?metadata,
          },
          onSuccess: () {
            print('Message sent successfully');
          },
          onError: (errorType) {
            if (errorType == FirestoreErrorType.permissionDenied) {
              print('User does not have permission to send messages');
            } else if (errorType == FirestoreErrorType.quotaExceeded) {
              print('Firestore quota exceeded - please check billing');
            }
          },
        );
      },
      operationName: 'Send message',
      onNoConnection: () {
        print('Message queued for sending when connection is restored');
      },
    );
  }
  
  Future<DocumentSnapshot<Map<String, dynamic>>?> getUserProfile(String userId) async {
    return FirestoreErrorHandler.safeGet(
      docRef: _firestore.collection('users').doc(userId),
      fallback: () => null,
    );
  }
  
  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String userId) {
    return _firestore
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .handleError((error) {
          final errorType = FirestoreErrorHandler.getErrorType(error);
          print('Stream error: ${FirestoreErrorHandler.getErrorMessage(errorType)}');
          
          if (errorType == FirestoreErrorType.missingIndex && error is FirebaseException) {
            final indexUrl = FirestoreErrorHandler.getIndexUrl(error);
            if (indexUrl != null) {
              print('Create index at: $indexUrl');
            }
          }
        });
  }
  
  Future<void> batchUpdate(List<Map<String, dynamic>> documents) async {
    final batch = _firestore.batch();
    
    for (final doc in documents) {
      final docRef = _firestore.collection('posts').doc(doc['id']);
      batch.update(docRef, doc);
    }
    
    await FirestoreErrorHandler.handleFirestoreOperation(
      operation: () => batch.commit(),
      onError: (errorType, _) {
        print('Batch update failed: ${FirestoreErrorHandler.getErrorMessage(errorType)}');
      },
    );
  }
}