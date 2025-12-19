import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../screens/home/messenger_chat_screen.dart';

/// Global navigator key for notification navigation
/// Set this in main.dart MaterialApp
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Callback type for handling notification navigation
typedef NotificationNavigationCallback = void Function(
  String type,
  Map<String, dynamic> data,
);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _fcmToken;

  /// Optional callback for custom navigation handling
  NotificationNavigationCallback? onNotificationTap;

  Future<void> initialize() async {
    try {
      await _requestPermissions();
      await _configureLocalNotifications();
      await _configureFCM();
      await _updateFCMToken();
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
      // Continue app execution even if notifications fail
    }
  }

  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('Notification permissions: ${settings.authorizationStatus}');
  }

  Future<void> _configureLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    if (kIsWeb) return;

    try {
      if (Platform.isAndroid) {
        final androidPlugin =
            _localNotifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          // Chat messages channel
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'chat_messages',
              'Chat Messages',
              description: 'Notifications for new chat messages',
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            ),
          );

          // Call channel
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'calls',
              'Incoming Calls',
              description: 'Notifications for incoming voice calls',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );

          // Inquiries channel (for professionals)
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'inquiries',
              'Service Inquiries',
              description: 'Notifications for new service inquiries',
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            ),
          );

          // Connection requests channel
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'connections',
              'Connection Requests',
              description: 'Notifications for connection requests',
              importance: Importance.defaultImportance,
              playSound: true,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating notification channels: $e');
    }
  }

  Future<void> _configureFCM() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle when app is opened from background via notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // Handle when app is launched from terminated state via notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      // Delay navigation to ensure app is fully loaded
      Future.delayed(const Duration(milliseconds: 1000), () {
        _handleNotificationOpen(initialMessage);
      });
    }
  }

  Future<void> _updateFCMToken() async {
    try {
      _fcmToken = await _fcm.getToken();

      if (_fcmToken != null && _auth.currentUser != null) {
        // Add a small delay to ensure Firestore auth is ready
        await Future.delayed(const Duration(milliseconds: 500));

        await _firestore.collection('users').doc(_auth.currentUser!.uid).update(
          {
            'fcmToken': _fcmToken,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          },
        );
        debugPrint('FCM token updated successfully');
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
      // Continue without crashing the app
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) async {
      try {
        _fcmToken = newToken;
        if (_auth.currentUser != null) {
          await _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .update({
            'fcmToken': newToken,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          debugPrint('FCM token refreshed successfully');
        }
      } catch (e) {
        debugPrint('Error refreshing FCM token: $e');
      }
    });
  }

  /// Handle messages when app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message received: ${message.messageId}');
    debugPrint('Data: ${message.data}');

    final data = message.data;
    final type = data['type'] as String?;

    // Don't show notification for messages in the current chat
    // This would require checking if user is currently viewing that conversation
    // For now, show all notifications

    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? 'New Notification',
        body: message.notification!.body ?? '',
        payload: jsonEncode(data),
        channelId: _getChannelIdForType(type),
      );
    }
  }

  /// Handle when user taps notification and app opens from background
  void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('Notification opened: ${message.messageId}');
    debugPrint('Data: ${message.data}');

    final data = message.data;
    _navigateBasedOnNotificationType(data);
  }

  /// Get appropriate channel ID based on notification type
  String _getChannelIdForType(String? type) {
    switch (type) {
      case 'call':
        return 'calls';
      case 'inquiry':
        return 'inquiries';
      case 'connection_request':
        return 'connections';
      case 'message':
      default:
        return 'chat_messages';
    }
  }

  /// Navigate to appropriate screen based on notification type
  Future<void> _navigateBasedOnNotificationType(Map<String, dynamic> data) async {
    final type = data['type'] as String?;

    // If custom callback is set, use it
    if (onNotificationTap != null) {
      onNotificationTap!(type ?? 'unknown', data);
      return;
    }

    // Default navigation handling
    switch (type) {
      case 'message':
        await _navigateToChat(data);
        break;
      case 'call':
        await _navigateToCall(data);
        break;
      case 'inquiry':
        await _navigateToInquiries(data);
        break;
      case 'connection_request':
        await _navigateToConnections(data);
        break;
      default:
        debugPrint('Unknown notification type: $type');
    }
  }

  /// Navigate to chat screen
  Future<void> _navigateToChat(Map<String, dynamic> data) async {
    final conversationId = data['conversationId'] as String?;
    final senderId = data['senderId'] as String?;

    if (conversationId == null || senderId == null) {
      debugPrint('Missing conversationId or senderId for chat navigation');
      return;
    }

    try {
      // Fetch sender's profile
      final userDoc = await _firestore.collection('users').doc(senderId).get();
      if (!userDoc.exists) {
        debugPrint('Sender user not found: $senderId');
        return;
      }

      final otherUser = UserProfile.fromFirestore(userDoc);

      // Navigate using global navigator key
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => MessengerChatScreen(
              otherUser: otherUser,
              chatId: conversationId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error navigating to chat: $e');
    }
  }

  /// Navigate to call screen (placeholder - implement when call feature is ready)
  Future<void> _navigateToCall(Map<String, dynamic> data) async {
    final callId = data['callId'] as String?;
    debugPrint('Navigate to call: $callId');
    // TODO: Navigate to call screen when WebRTC is implemented
  }

  /// Navigate to inquiries screen (for professionals)
  Future<void> _navigateToInquiries(Map<String, dynamic> data) async {
    debugPrint('Navigate to inquiries');
    // TODO: Navigate to inquiries screen
  }

  /// Navigate to connections/requests screen
  Future<void> _navigateToConnections(Map<String, dynamic> data) async {
    debugPrint('Navigate to connections');
    // TODO: Navigate to connections screen
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'chat_messages',
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == 'chat_messages'
          ? 'Chat Messages'
          : channelId == 'calls'
              ? 'Incoming Calls'
              : channelId == 'inquiries'
                  ? 'Service Inquiries'
                  : 'Notifications',
      channelDescription: 'Notification channel',
      importance: channelId == 'calls' ? Importance.max : Importance.high,
      priority: channelId == 'calls' ? Priority.max : Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(body),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigateBasedOnNotificationType(data);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  /// Show a local notification (public API)
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _showLocalNotification(title: title, body: body, payload: payload);
  }

  /// Send notification to another user via Firestore
  /// The receiving user's app will pick this up and show a local notification
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      // Store notification in Firestore for the target user
      await _firestore.collection('notifications').add({
        'userId': userId,
        'senderId': currentUserId,
        'title': title,
        'body': body,
        'type': type ?? 'general',
        'data': data ?? {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Notification sent to user: $userId');
    } catch (e) {
      debugPrint('❌ Error sending notification to user: $e');
    }
  }

  /// Listen for notifications for the current user
  Stream<List<Map<String, dynamic>>> getUserNotificationsStream() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    // Simple query without compound index requirement
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      final notifications = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort locally instead of in query (avoids index requirement)
      notifications.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return notifications;
    });
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
      });
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  /// Process and show new notifications (call this from a listener)
  Future<void> processNewNotification(Map<String, dynamic> notification) async {
    final title = notification['title'] as String? ?? 'Notification';
    final body = notification['body'] as String? ?? '';
    final notificationId = notification['id'] as String?;

    // Show local notification
    await _showLocalNotification(
      title: title,
      body: body,
      payload: jsonEncode(notification['data'] ?? {}),
      channelId: _getChannelIdForType(notification['type'] as String?),
    );

    // Mark as read after showing
    if (notificationId != null) {
      await markNotificationAsRead(notificationId);
    }
  }

  /// Clear FCM token on logout
  Future<void> clearFcmToken() async {
    try {
      if (_auth.currentUser != null) {
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update(
          {
            'fcmToken': FieldValue.delete(),
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          },
        );
      }
      await _fcm.deleteToken();
      _fcmToken = null;
      debugPrint('FCM token cleared');
    } catch (e) {
      debugPrint('Error clearing FCM token: $e');
    }
  }

  Future<void> updateBadgeCount(int count) async {
    if (kIsWeb) return;

    try {
      if (Platform.isIOS) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(badge: true);
      }
    } catch (e) {
      debugPrint('Badge count update not supported on this platform');
    }
  }

  Future<void> clearNotifications() async {
    await _localNotifications.cancelAll();
    await updateBadgeCount(0);
  }

  Future<void> clearChatNotifications(String conversationId) async {
    // Clear notifications for specific chat
    // Could be enhanced to track notification IDs per conversation
  }

  Future<int> getUnreadMessageCount() async {
    if (_auth.currentUser == null) return 0;

    try {
      final conversations = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: _auth.currentUser!.uid)
          .get();

      int totalUnread = 0;
      for (var doc in conversations.docs) {
        final data = doc.data();
        final unreadCount = data['unreadCount']?[_auth.currentUser!.uid] ?? 0;
        totalUnread += unreadCount as int;
      }

      return totalUnread;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
  }

  /// Get current FCM token (for debugging)
  String? get fcmToken => _fcmToken;
}

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background FCM message: ${message.messageId}');
  debugPrint('Background FCM data: ${message.data}');
}
