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

import 'firebase_options.dart';
import 'screens/login_screen.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

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
    final themeNotifier = ref.read(themeProvider.notifier);

    return MaterialApp(
      title: 'Supper',
      theme: themeNotifier.themeData,
      home: const AuthWrapper(),
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final currentUserId = snapshot.data!.uid;

          // Initialize user-dependent services only once per session
          if (!_hasInitializedServices ||
              _lastInitializedUserId != currentUserId) {
            _hasInitializedServices = true;
            _lastInitializedUserId = currentUserId;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _initializeUserServices();
            });
          }

          return const MainNavigationScreen();
        }

        // Reset when user logs out
        _hasInitializedServices = false;
        _lastInitializedUserId = null;

        return const LoginScreen();
      },
    );
  }

  Future<void> _initializeUserServices() async {
    try {
      await _profileService.ensureProfileExists();
      await Future.delayed(const Duration(milliseconds: 100));
      _locationService.initializeLocation();
      _locationService.startPeriodicLocationUpdates();
      _conversationService.cleanupDuplicateConversations();
    } catch (e) {
      debugPrint('Error initializing user services: $e');
    }
  }
}
