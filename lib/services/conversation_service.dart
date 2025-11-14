import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/conversation_model.dart';
import '../models/user_profile.dart';

class ConversationService {
  static final ConversationService _instance = ConversationService._internal();
  factory ConversationService() => _instance;
  ConversationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generate consistent conversation ID between two users
  String generateConversationId(String userId1, String userId2) {
    // Always sort user IDs to ensure consistency
    final sortedIds = [userId1, userId2]..sort();
    final conversationId = '${sortedIds[0]}_${sortedIds[1]}';
    return conversationId;
  }

  // Get or create conversation between current user and another user
  Future<String> getOrCreateConversation(UserProfile otherUser) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('No authenticated user');
    }

    // Generate consistent conversation ID
    final conversationId = generateConversationId(currentUserId, otherUser.uid);
    
    try {
      // First, try to get existing conversation
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (conversationDoc.exists) {
        // Conversation exists, update participant info if needed
        await _updateParticipantInfo(conversationId, currentUserId, otherUser);
        return conversationId;
      }

      // Conversation doesn't exist, create it
      await _createConversation(conversationId, currentUserId, otherUser);
      return conversationId;
      
    } catch (e) {
      throw e;
    }
  }

  // Create a new conversation
  Future<void> _createConversation(
    String conversationId,
    String currentUserId,
    UserProfile otherUser,
  ) async {
    final currentUserDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .get();
    
    final currentUserData = currentUserDoc.data() ?? {};
    final currentUserName = currentUserData['name'] ?? 
                            _auth.currentUser?.displayName ?? 
                            'User';
    final currentUserPhoto = currentUserData['photoUrl'] ?? 
                            _auth.currentUser?.photoURL;

    await _firestore.collection('conversations').doc(conversationId).set({
      'id': conversationId,
      'participantIds': [currentUserId, otherUser.uid],
      'participantNames': {
        currentUserId: currentUserName,
        otherUser.uid: otherUser.name,
      },
      'participantPhotos': {
        currentUserId: currentUserPhoto,
        otherUser.uid: otherUser.profileImageUrl,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageTime': null,
      'lastMessage': null,
      'lastMessageSenderId': null,
      'unreadCount': {
        currentUserId: 0,
        otherUser.uid: 0,
      },
      'isTyping': {
        currentUserId: false,
        otherUser.uid: false,
      },
      'isGroup': false,
      'lastSeen': {
        currentUserId: FieldValue.serverTimestamp(),
        otherUser.uid: null,
      },
      'isArchived': false,
      'isMuted': false,
    });
  }

  // Update participant information in existing conversation
  Future<void> _updateParticipantInfo(
    String conversationId,
    String currentUserId,
    UserProfile otherUser,
  ) async {
    final currentUserDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .get();
    
    final currentUserData = currentUserDoc.data() ?? {};
    final currentUserName = currentUserData['name'] ?? 
                            _auth.currentUser?.displayName ?? 
                            'User';
    final currentUserPhoto = currentUserData['photoUrl'] ?? 
                            _auth.currentUser?.photoURL;

    // Update participant info to ensure it's current
    await _firestore.collection('conversations').doc(conversationId).update({
      'participantNames.${currentUserId}': currentUserName,
      'participantNames.${otherUser.uid}': otherUser.name,
      'participantPhotos.${currentUserId}': currentUserPhoto,
      'participantPhotos.${otherUser.uid}': otherUser.profileImageUrl,
      'lastSeen.${currentUserId}': FieldValue.serverTimestamp(),
    });
  }

  // Check if conversation exists between two users
  Future<bool> conversationExists(String userId1, String userId2) async {
    final conversationId = generateConversationId(userId1, userId2);
    final doc = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .get();
    return doc.exists;
  }

  // Get conversation by ID
  Future<ConversationModel?> getConversation(String conversationId) async {
    try {
      final doc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      
      if (doc.exists) {
        return ConversationModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      // Error getting conversation
      return null;
    }
  }

  // Create or get conversation with user IDs (overloaded method)
  Future<String> createOrGetConversation(String currentUserId, String otherUserId) async {
    // Generate consistent conversation ID
    final conversationId = generateConversationId(currentUserId, otherUserId);
    
    try {
      // First, try to get existing conversation
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (conversationDoc.exists) {
        return conversationId;
      }

      // Get other user's profile
      final otherUserDoc = await _firestore
          .collection('users')
          .doc(otherUserId)
          .get();
      
      if (!otherUserDoc.exists) {
        throw Exception('Other user not found');
      }

      final otherUserData = otherUserDoc.data()!;
      final otherUser = UserProfile(
        uid: otherUserId,
        name: otherUserData['name'] ?? 'User',
        email: otherUserData['email'] ?? '',
        profileImageUrl: otherUserData['profileImageUrl'] ?? otherUserData['photoUrl'],
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      // Create conversation
      await _createConversation(conversationId, currentUserId, otherUser);
      return conversationId;
      
    } catch (e) {
      throw e;
    }
  }

  // Send a message to a conversation
  Future<void> sendMessage({
    required String conversationId,
    required String text,
    String? imageUrl,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('No authenticated user');
    }

    try {
      // Create message document
      final messageRef = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'text': text,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'isEdited': false,
      });

      // Update conversation with last message
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUserId,
      });

      // Update unread count for other participants
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      
      if (conversationDoc.exists) {
        final participantIds = List<String>.from(conversationDoc.data()!['participantIds']);
        final otherUserIds = participantIds.where((id) => id != currentUserId);
        
        final updates = <String, dynamic>{};
        for (final userId in otherUserIds) {
          updates['unreadCount.$userId'] = FieldValue.increment(1);
        }
        
        if (updates.isNotEmpty) {
          await _firestore.collection('conversations').doc(conversationId).update(updates);
        }
      }
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Get all conversations for current user
  Stream<List<ConversationModel>> getUserConversations() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('conversations')
        .where('participantIds', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
          final conversations = snapshot.docs
              .map((doc) => ConversationModel.fromFirestore(doc))
              .toList();
          
          // Sort by lastMessageTime (conversations with messages first)
          conversations.sort((a, b) {
            if (a.lastMessageTime == null && b.lastMessageTime == null) {
              return b.createdAt.compareTo(a.createdAt);
            }
            if (a.lastMessageTime == null) return 1;
            if (b.lastMessageTime == null) return -1;
            return b.lastMessageTime!.compareTo(a.lastMessageTime!);
          });
          
          return conversations;
        });
  }

  // Delete duplicate conversations (cleanup utility)
  Future<void> cleanupDuplicateConversations() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final conversations = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: currentUserId)
          .get();

      // Group conversations by participants
      final Map<String, List<QueryDocumentSnapshot>> groupedConversations = {};
      
      for (var doc in conversations.docs) {
        final participants = List<String>.from(doc.data()['participantIds']);
        participants.sort();
        final key = participants.join('_');
        
        if (!groupedConversations.containsKey(key)) {
          groupedConversations[key] = [];
        }
        groupedConversations[key]!.add(doc);
      }

      // Find and merge duplicates
      for (var entry in groupedConversations.entries) {
        if (entry.value.length > 1) {
          // Sort by last message time, keep the most recent
          entry.value.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['lastMessageTime'] as Timestamp?;
            final bTime = bData['lastMessageTime'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          // Keep the first (most recent) and delete others
          for (int i = 1; i < entry.value.length; i++) {
            await _mergeAndDeleteConversation(
              entry.value[0].id,  // Keep this one
              entry.value[i].id,  // Delete this one
            );
          }
        }
      }
    } catch (e) {
      // Error cleaning up duplicate conversations
    }
  }

  // Merge messages from duplicate conversation and delete it
  Future<void> _mergeAndDeleteConversation(
    String keepConversationId,
    String deleteConversationId,
  ) async {
    try {
      // Get all messages from the conversation to be deleted
      final messagesToMove = await _firestore
          .collection('conversations')
          .doc(deleteConversationId)
          .collection('messages')
          .get();

      // Move messages to the conversation we're keeping
      final batch = _firestore.batch();
      
      for (var messageDoc in messagesToMove.docs) {
        final newMessageRef = _firestore
            .collection('conversations')
            .doc(keepConversationId)
            .collection('messages')
            .doc(messageDoc.id);
        
        batch.set(newMessageRef, messageDoc.data());
      }

      // Delete the duplicate conversation
      batch.delete(_firestore.collection('conversations').doc(deleteConversationId));
      
      await batch.commit();
      
      // Merged and deleted duplicate conversation
    } catch (e) {
      // Error merging conversation
    }
  }

  // Update last seen timestamp
  Future<void> updateLastSeen(String conversationId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    await _firestore.collection('conversations').doc(conversationId).update({
      'lastSeen.${currentUserId}': FieldValue.serverTimestamp(),
    });
  }
}