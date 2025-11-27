import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
// REMOVED: Call feature imports (feature deleted)
// import '../models/call_model.dart';
// import 'simple_call_service.dart' as call_svc;

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
  }

  Future<void> _configureFCM() async {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
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
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
      // Continue without crashing the app
    }

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
        }
      } catch (e) {
        debugPrint('Error refreshing FCM token: $e');
        // Continue without crashing the app
      }
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message received: ${message.messageId}');

    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? 'New Message',
        body: message.notification!.body ?? '',
        payload: jsonEncode(message.data),
      );
    }
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('Background message opened: ${message.messageId}');

    if (message.data['conversationId'] != null) {
      // Navigate to chat screen
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
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

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      if (data['conversationId'] != null) {
        // Navigate to chat screen
      }
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _showLocalNotification(title: title, body: body, payload: payload);
  }

  // REMOVED: Call feature methods (feature deleted)
  /*
  Future<void> showIncomingCallNotification({
    required String callerName,
    required CallType callType,
    required String callId,
  }) async {
    await _localNotifications.show(
      callId.hashCode,
      'Incoming Audio Call',
      '$callerName is calling you',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'call_channel',
          'Incoming Calls',
          channelDescription: 'Notifications for incoming calls',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.call,
          ongoing: true,
          autoCancel: false,
          timeoutAfter: 30000,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: 'CALL_CATEGORY',
        ),
      ),
    );
  }

  Future<void> sendCallNotification({
    required String recipientToken,
    required String callerName,
    required CallType callType,
    required String callId,
  }) async {
    if (recipientToken.isEmpty) return;

    try {
      // In production, this would send through FCM
      debugPrint('📞 Call notification sent:');
      debugPrint('   To: $recipientToken');
      debugPrint('   From: $callerName');
      debugPrint('   Type: Audio');
      debugPrint('   Call ID: $callId');
    } catch (e) {
      debugPrint('Error sending call notification: $e');
    }
  }
  */

  Future<void> sendMessageNotification({
    required String recipientToken,
    required String senderName,
    required String message,
    String? conversationId,
  }) async {
    if (recipientToken.isEmpty) return;

    try {
      // In production, this would send through Firebase Cloud Functions to the recipient
      // The notification will be shown on the RECEIVER's device via FCM
      // DO NOT show local notification here as this runs on the SENDER's device

      debugPrint('📬 Message notification prepared for sending:');
      debugPrint('   To: $recipientToken');
      debugPrint('   From: $senderName');
      debugPrint('   Message: $message');
      debugPrint('   Conversation: $conversationId');

      // TODO: Implement actual FCM push notification sending via backend/Cloud Functions
      // For now, this is just a placeholder that logs the notification details
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  Future<void> sendQuickReplyNotification({
    required String recipientToken,
    required String senderName,
    required String message,
    required String conversationId,
    required List<String> quickReplies,
  }) async {
    if (recipientToken.isEmpty) return;

    try {
      // Send notification with quick reply actions
      // This would be implemented with platform-specific notification actions
      debugPrint('Quick reply notification would be sent to: $recipientToken');
    } catch (e) {
      debugPrint('Error sending quick reply notification: $e');
    }
  }

  Future<void> updateBadgeCount(int count) async {
    if (kIsWeb) {
      // Badge count not supported on web
      return;
    }

    try {
      if (Platform.isIOS) {
        // Update app badge on iOS
        await _localNotifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(badge: true);
      }
    } catch (e) {
      // Platform check failed (likely on web), ignore
      debugPrint('Badge count update not supported on this platform');
    }
  }

  Future<void> sendPushNotification({
    required String recipientToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (recipientToken.isEmpty) return;

    try {
      // In production, this would send through FCM
      debugPrint('📱 Push notification sent:');
      debugPrint('   To: $recipientToken');
      debugPrint('   Title: $title');
      debugPrint('   Body: $body');
      debugPrint('   Data: $data');

      // For now, show local notification
      await _showLocalNotification(
        title: title,
        body: body,
        payload: data != null ? jsonEncode(data) : null,
      );
    } catch (e) {
      debugPrint('Error sending push notification: $e');
    }
  }

  Future<void> sendNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await sendPushNotification(
      recipientToken: token,
      title: title,
      body: body,
      data: data,
    );
  }

  Future<void> clearNotifications() async {
    await _localNotifications.cancelAll();
    await updateBadgeCount(0);
  }

  Future<void> clearChatNotifications(String conversationId) async {
    // Clear notifications for specific chat
    // Implementation depends on how notification IDs are structured
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
}

// Top-level function for background message handling
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.messageId}');
}
