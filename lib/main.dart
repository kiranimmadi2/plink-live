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
import 'package:supper/screens/home/home_screen.dart';
import 'package:supper/screens/login/onboarding_screen.dart';

import 'firebase_options.dart';
import 'screens/login/splash_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/home/main_navigation_screen.dart';

import 'services/auth_service.dart';
import 'services/profile_service.dart';
import 'services/user_manager.dart';
import 'services/notification_service.dart';
import 'services/conversation_service.dart';
import 'services/location_service.dart';
import 'services/connectivity_service.dart';
import 'services/user_migration_service.dart';
import 'services/conversation_migration_service.dart';
import 'services/video_preload_service.dart';
import 'providers/theme_provider.dart';
import 'utils/app_optimizer.dart';
import 'utils/memory_manager.dart';

// FCM background handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background FCM message: ${message.messageId}');
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
        ' Image decode error (suppressed): ${details.exceptionAsString()}',
      );
      return; // Don't propagate
    }
    // For other errors, use default handler
    FlutterError.presentError(details);
  };

  // Load environment variables
  await dotenv.load(fileName: ".env");

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
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // Start video preload immediately - before app renders
  // This ensures video is ready when splash screen opens
  unawaited(VideoPreloadService().preload());

  // Run app immediately - defer ALL heavy initializations
  runApp(const ProviderScope(child: MyApp()));

  // Defer all non-critical initialization to AFTER first frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeServicesInBackground();
  });
}

/// Initialize non-critical services after app has started rendering
Future<void> _initializeServicesInBackground() async {
  // Longer delay to let UI fully render and become responsive
  await Future.delayed(const Duration(milliseconds: 500));

  // FCM background handler - set up after app is responsive
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize utilities in sequence with small delays to prevent jank
  await AppOptimizer.initialize();
  await Future.delayed(const Duration(milliseconds: 50));

  MemoryManager().initialize();
  await Future.delayed(const Duration(milliseconds: 50));

  UserManager().initialize();
  await Future.delayed(const Duration(milliseconds: 50));

  // Initialize notification service (can run in parallel, but don't block)
  unawaited(
    NotificationService().initialize().catchError((e) {
      debugPrint('NotificationService init error (non-fatal): $e');
    }),
  );

  // Initialize connectivity service after a small delay
  await Future.delayed(const Duration(milliseconds: 100));
  unawaited(
    ConnectivityService().initialize().catchError((e) {
      debugPrint('ConnectivityService init error (non-fatal): $e');
    }),
  );

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
      theme: themeNotifier.themeData.copyWith(
        scaffoldBackgroundColor: const Color(0xFF0f0f23),
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(), // <-- Use AuthWrapper here
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

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final LocationService _locationService = LocationService();
  final ConversationService _conversationService = ConversationService();

  bool _hasInitializedServices = false;
  String? _lastInitializedUserId;
  bool _isInitializing = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading only on initial connection
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        // Handle errors in auth stream
        if (snapshot.hasError) {
          debugPrint('AuthWrapper: Auth stream error: ${snapshot.error}');
          return _buildErrorScreen(snapshot.error.toString());
        }

        if (snapshot.hasData && snapshot.data != null) {
          String uid = snapshot.data!.uid;

          // Initialize user-dependent services only once per session
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

        // Reset when user logs out
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

      // Ensure profile exists with timeout
      try {
        await _profileService.ensureProfileExists().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint(' Profile service timed out');
          },
        );
      } catch (e) {
        debugPrint(' Profile service error (non-fatal): $e');
      }

      await Future.delayed(const Duration(milliseconds: 100));
      _locationService.initializeLocation();
      _locationService.startPeriodicLocationUpdates();
      _conversationService.cleanupDuplicateConversations();

      // Run migrations now that user is authenticated
      _runMigrationsInBackground();

      debugPrint('✓ AuthWrapper: User services initialized');
    } catch (e) {
      debugPrint("User services init failed: $e");
    }
  }

  /// Run database migrations in background after user is authenticated
  void _runMigrationsInBackground() {
    Future.delayed(const Duration(milliseconds: 300), () async {
      // Run user migration
      try {
        final userMigration = UserMigrationService();
        await userMigration.checkAndRunMigration();
      } catch (e) {
        debugPrint('User migration failed (non-fatal): $e');
      }

      // Run conversation migration
      try {
        final conversationMigration = ConversationMigrationService();
        final isCompleted = await conversationMigration.isMigrationCompleted();
        if (!isCompleted) {
          final result = await conversationMigration.runMigration();
          debugPrint('Conversation migration result: $result');
        }
      } catch (e) {
        debugPrint('Conversation migration failed (non-fatal): $e');
      }
    });
  }
}
