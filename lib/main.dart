import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supper/screens/login/onboarding_screen.dart';

import 'firebase_options.dart';
import 'screens/login/splash_screen.dart';
import 'screens/home/main_navigation_screen.dart';
import 'screens/chat/voice_call_screen.dart';
import 'models/user_profile.dart';

import 'services/auth_service.dart';
import 'services/profile_service.dart';
import 'services/user_manager.dart';
import 'services/notification_service.dart';
import 'services/conversation_service.dart';
import 'services/location_service.dart';
import 'services/connectivity_service.dart';
import 'services/analytics_service.dart';
import 'services/error_tracking_service.dart';
import 'providers/theme_provider.dart';
import 'utils/app_optimizer.dart';
import 'utils/memory_manager.dart';

// FCM background handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background FCM message: ${message.messageId}');
  debugPrint('Background FCM data: ${message.data}');

  final data = message.data;
  final type = data['type'] as String?;

  // For call notifications, show high-priority notification
  if (type == 'call') {
    final callerName = data['callerName'] as String? ?? 'Someone';
    await _showCallNotification(
      title: 'Incoming Call',
      body: '$callerName is calling you',
      payload: message.data,
    );
  }
}

// Show call notification in background
Future<void> _showCallNotification({
  required String title,
  required String body,
  required Map<String, dynamic> payload,
}) async {
  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await localNotifications.initialize(initSettings);

  const androidDetails = AndroidNotificationDetails(
    'calls',
    'Incoming Calls',
    channelDescription: 'Notifications for incoming voice calls',
    importance: Importance.max,
    priority: Priority.max,
    showWhen: true,
    enableVibration: true,
    playSound: true,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.call,
  );

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    interruptionLevel: InterruptionLevel.timeSensitive,
  );

  const details = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  await localNotifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    details,
    payload: payload.toString(),
  );
}

/// Validate that Firebase configuration is loaded from .env
void _validateFirebaseConfig() {
  final projectId = dotenv.env['FIREBASE_WEB_PROJECT_ID'];
  final apiKey =
      dotenv.env['FIREBASE_ANDROID_API_KEY'] ??
      dotenv.env['FIREBASE_WEB_API_KEY'];

  if (projectId == null || projectId.isEmpty) {
    debugPrint('⚠️ WARNING: Firebase project ID is missing!');
    debugPrint(
      '   Please ensure .env file exists with FIREBASE_WEB_PROJECT_ID',
    );
  }

  if (apiKey == null || apiKey.isEmpty) {
    debugPrint('⚠️ WARNING: Firebase API key is missing!');
    debugPrint(
      '   Please ensure .env file exists with FIREBASE_ANDROID_API_KEY or FIREBASE_WEB_API_KEY',
    );
  }

  if ((projectId?.isNotEmpty ?? false) && (apiKey?.isNotEmpty ?? false)) {
    debugPrint('✓ Firebase configuration loaded successfully');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up global error handling for image decode errors
  FlutterError.onError = (FlutterErrorDetails details) {
    final exception = details.exception;
    // Suppress image decode errors - they're non-fatal
    if (exception.toString().contains('ImageDecoder') ||
        exception.toString().contains('Failed to decode image') ||
        exception.toString().contains('codec')) {
      debugPrint(
        '⚠️ Image decode error (suppressed): ${details.exceptionAsString()}',
      );
      return; // Don't propagate
    }
    // For other errors, use default handler
    FlutterError.presentError(details);
  };

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Sentry for error tracking (wraps the entire app)
  await ErrorTrackingService.initialize(() async {
    // Validate Firebase configuration
    _validateFirebaseConfig();

    // Initialize Firebase only once
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );

    if (!kIsWeb) {
      // Fixed: Changed from UNLIMITED to 50MB to prevent memory issues
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 50 * 1024 * 1024, // 50MB cache limit
      );
    }

    // Run app immediately - defer ALL heavy initializations
    runApp(const ProviderScope(child: MyApp()));

    // Defer all non-critical initialization to AFTER first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServicesInBackground();
    });
  });
}

/// Initialize non-critical services after app has started rendering
Future<void> _initializeServicesInBackground() async {
  // Shorter delay - reduced from 500ms to 200ms for faster startup
  await Future.delayed(const Duration(milliseconds: 200));

  // FCM background handler - set up after app is responsive
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Firebase Analytics
  unawaited(AnalyticsService().initialize().catchError((e) {
    debugPrint('AnalyticsService init error (non-fatal): $e');
  }));

  // Initialize utilities in sequence with small delays to prevent jank
  await AppOptimizer.initialize();
  await Future.delayed(const Duration(milliseconds: 50));

  MemoryManager().initialize();
  await Future.delayed(const Duration(milliseconds: 50));

  UserManager().initialize();
  await Future.delayed(const Duration(milliseconds: 50));

  // Initialize notification service (can run in parallel, but don't block)
  unawaited(NotificationService().initialize().catchError((e) {
    debugPrint('NotificationService init error (non-fatal): $e');
    ErrorTrackingService().captureException(e, message: 'NotificationService init failed');
  }));

  // Initialize connectivity service after a small delay
  await Future.delayed(const Duration(milliseconds: 100));
  unawaited(
    ConnectivityService().initialize().catchError((e) {
      debugPrint('ConnectivityService init error (non-fatal): $e');
    }),
  );

  // Log app open event
  unawaited(AnalyticsService().logAppOpen());

  // NOTE: Migrations are now run in AuthWrapper._initializeUserServices()
  // after the user is authenticated to avoid permission errors
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return MaterialApp(
      title: 'Supper',
      navigatorKey: navigatorKey,
      theme: themeNotifier.themeData.copyWith(
        scaffoldBackgroundColor: const Color(0xFF0f0f23),
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/voice-call') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => VoiceCallScreen(
              callId: args['callId'] as String,
              otherUser: args['otherUser'] as UserProfile,
              isOutgoing: args['isOutgoing'] as bool,
            ),
          );
        }
        return null;
      },
      builder: (context, child) {
        return Container(
          color: const Color(0xFF0f0f23),
          child: child,
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final LocationService _locationService = LocationService();
  final ConversationService _conversationService = ConversationService();
  final NotificationService _notificationService = NotificationService();

  bool _hasInitializedServices = false;
  String? _lastInitializedUserId;
  bool _isInitializing = false;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('AuthWrapper: App resumed - checking location freshness');
        if (_authService.currentUser != null) {
          _locationService.onAppResume();
        }
        break;
      case AppLifecycleState.paused:
        debugPrint('AuthWrapper: App paused');
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        if (snapshot.hasError) {
          debugPrint('AuthWrapper: Auth stream error: ${snapshot.error}');
          return _buildErrorScreen(snapshot.error.toString());
        }

        if (snapshot.hasData && snapshot.data != null) {
          String uid = snapshot.data!.uid;

          if (!_hasInitializedServices || _lastInitializedUserId != uid) {
            if (!_isInitializing) {
              _isInitializing = true;
              _hasInitializedServices = true;
              _lastInitializedUserId = uid;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _initializeUserServices().then((_) {
                  _isInitializing = false;
                });
              });
            }
          }

          return const MainNavigationScreen();
        }

        _hasInitializedServices = false;
        _lastInitializedUserId = null;
        _isInitializing = false;

        return const OnboardingScreen();
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f0f23),
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {});
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initializeUserServices() async {
    try {
      debugPrint('AuthWrapper: Initializing user services...');

      try {
        await _profileService.ensureProfileExists().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⚠️ Profile service timed out');
          },
        );
      } catch (e) {
        debugPrint('⚠️ Profile service error (non-fatal): $e');
      }

      await Future.delayed(const Duration(milliseconds: 100));
      _locationService.initializeLocation();
      _locationService.startPeriodicLocationUpdates();
      _locationService.startLocationStream();
      _conversationService.cleanupDuplicateConversations();

      // Start listening for notifications from other users
      _startNotificationListener();

      _runMigrationsInBackground();

      debugPrint('✓ AuthWrapper: User services initialized');
    } catch (e) {
      debugPrint("User services init failed: $e");
    }
  }

  /// Listen for notifications from Firestore and show them locally
  void _startNotificationListener() {
    _notificationSubscription?.cancel();
    _notificationSubscription = _notificationService.getUserNotificationsStream().listen(
      (notifications) async {
        for (final notification in notifications) {
          await _notificationService.processNewNotification(notification);
        }
      },
      onError: (e) {
        debugPrint('❌ Notification listener error: $e');
      },
    );
    debugPrint('✓ Notification listener started');
  }

  void _runMigrationsInBackground() {
    // Migration services removed - no longer needed
    debugPrint('✓ Migrations check skipped (already completed)');
  }
}
