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
import 'package:supper/screens/login/splash_screen.dart';

import 'firebase_options.dart';
import 'screens/login/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/auth_service.dart';
import 'services/profile_service.dart';
import 'services/user_manager.dart';
import 'services/notification_service.dart';
import 'services/conversation_service.dart';
import 'services/location_service.dart';
import 'services/connectivity_service.dart';
import 'services/user_migration_service.dart';
import 'services/conversation_migration_service.dart';
import 'providers/theme_provider.dart';
import 'utils/app_optimizer.dart';
import 'utils/memory_manager.dart';

// Top-level background handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Only print data; do NOT initialize Firebase here
  debugPrint('Background message received: ${message.messageId}');
}

/// Validate that Firebase configuration is loaded from .env
void _validateFirebaseConfig() {
  final projectId = dotenv.env['FIREBASE_WEB_PROJECT_ID'];
  final apiKey = dotenv.env['FIREBASE_ANDROID_API_KEY'] ?? dotenv.env['FIREBASE_WEB_API_KEY'];

  if (projectId == null || projectId.isEmpty) {
    debugPrint('⚠️ WARNING: Firebase project ID is missing!');
    debugPrint('   Please ensure .env file exists with FIREBASE_WEB_PROJECT_ID');
  }

  if (apiKey == null || apiKey.isEmpty) {
    debugPrint('⚠️ WARNING: Firebase API key is missing!');
    debugPrint('   Please ensure .env file exists with FIREBASE_ANDROID_API_KEY or FIREBASE_WEB_API_KEY');
  }

  if ((projectId?.isNotEmpty ?? false) && (apiKey?.isNotEmpty ?? false)) {
    debugPrint('✓ Firebase configuration loaded successfully');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Lock orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // System UI overlay
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Firestore offline persistence (mobile only)
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // FCM background handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize utilities and services
  await AppOptimizer.initialize();
  MemoryManager().initialize();
  UserManager().initialize();
  await NotificationService().initialize();
  await ConnectivityService().initialize();

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
    } else {
      debugPrint('Conversation migration already completed');
    }
  } catch (e) {
    debugPrint('Conversation migration failed (non-fatal): $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch theme to trigger rebuilds on theme change
    ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return MaterialApp(
      title: 'Supper',
      theme: themeNotifier.themeData,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
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
          final currentUserId = snapshot.data!.uid;

          // Initialize user-dependent services only once per session
          if (!_hasInitializedServices ||
              _lastInitializedUserId != currentUserId) {
            if (!_isInitializing) {
              _isInitializing = true;
              _hasInitializedServices = true;
              _lastInitializedUserId = currentUserId;

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

        return const LoginScreen();
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade400,
              Colors.purple.shade400,
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
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
            debugPrint('⚠️ Profile service timed out');
          },
        );
      } catch (e) {
        debugPrint('⚠️ Profile service error (non-fatal): $e');
      }

      await Future.delayed(const Duration(milliseconds: 100));
      _locationService.initializeLocation();
      _locationService.startPeriodicLocationUpdates();
      _conversationService.cleanupDuplicateConversations();

      debugPrint('✓ AuthWrapper: User services initialized');
    } catch (e) {
      debugPrint('Error initializing user services: $e');
    }
  }
}
