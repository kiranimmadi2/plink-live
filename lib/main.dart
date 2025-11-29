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

// FCM background handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background FCM message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

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

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await AppOptimizer.initialize();
  MemoryManager().initialize();
  UserManager().initialize();
  await NotificationService().initialize();
  await ConnectivityService().initialize();

  // User migration
  try {
    final userMigration = UserMigrationService();
    await userMigration.checkAndRunMigration();
  } catch (e) {
    debugPrint('User migration failed: $e');
  }

  // Conversation migration
  try {
    final conversationMigration = ConversationMigrationService();
    if (!await conversationMigration.isMigrationCompleted()) {
      await conversationMigration.runMigration();
    }
  } catch (e) {
    debugPrint('Conversation migration failed: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return MaterialApp(
      title: 'Supper',
      theme: themeNotifier.themeData,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(), // <-- Use AuthWrapper here
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

  bool _initialized = false;
  String? _lastUserId;

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
          String uid = snapshot.data!.uid;

          if (!_initialized || _lastUserId != uid) {
            _initialized = true;
            _lastUserId = uid;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _initUserServices();
            });
          }

          return const MainNavigationScreen();
        }

        // User not logged in
        _initialized = false;
        _lastUserId = null;
        return const OnboardingScreen(); // <-- Show LoginScreen if not logged in
      },
    );
  }

  Future<void> _initUserServices() async {
    try {
      await _profileService.ensureProfileExists();
      await Future.delayed(const Duration(milliseconds: 120));

      _locationService.initializeLocation();
      _locationService.startPeriodicLocationUpdates();
      _conversationService.cleanupDuplicateConversations();
    } catch (e) {
      debugPrint("User services init failed: $e");
    }
  }
}
