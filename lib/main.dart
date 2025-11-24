import 'dart:async';
// ignore: avoid_web_libraries_in_flutter

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
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
import 'services/database_cleanup_service.dart';
import 'services/user_migration_service.dart';
import 'services/conversation_migration_service.dart';
import 'providers/theme_provider.dart';
import 'utils/app_optimizer.dart';
import 'utils/memory_manager.dart';

// Background message handler - MUST be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already initialized
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('Background message received: ${message.data}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  
  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize Firebase with optimizations
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firestore offline persistence for better UX and caching
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // Set up FCM background handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Initialize app optimizer
  await AppOptimizer.initialize();
  
  // Initialize memory manager
  MemoryManager().initialize();
  
  // Initialize services sequentially
  UserManager().initialize();
  await NotificationService().initialize();
  await ConnectivityService().initialize();

  // REMOVED: Database cleanup was deleting the posts collection
  // The posts collection is actively used and should NOT be deleted

  // Run user migration (adds missing fields to existing users)
  try {
    final UserMigrationService migrationService = UserMigrationService();
    await migrationService.checkAndRunMigration();
  } catch (e) {
    debugPrint('⚠️ User migration error (non-fatal): $e');
  }

  // Run conversation migration (fixes corrupted participants arrays)
  // This ensures all conversations appear in the Messages screen
  try {
    final ConversationMigrationService conversationMigrationService = ConversationMigrationService();

    // Only run if migration hasn't been completed before
    final isCompleted = await conversationMigrationService.isMigrationCompleted();
    if (!isCompleted) {
      debugPrint('🔧 Running conversation migration...');
      final result = await conversationMigrationService.runMigration();

      if (result['success']) {
        debugPrint('✅ Conversation migration completed successfully');
        debugPrint('   - Scanned: ${result['scanned']} conversations');
        debugPrint('   - Fixed: ${result['fixed']} conversations');
        if (result['errors'].isNotEmpty) {
          debugPrint('   - Errors: ${result['errors'].length}');
        }
      } else {
        debugPrint('⚠️ Conversation migration completed with errors');
        debugPrint('   - Fixed: ${result['fixed']} conversations');
        debugPrint('   - Errors: ${result['errors']}');
      }
    } else {
      debugPrint('✓ Conversation migration already completed');
    }
  } catch (e) {
    debugPrint('⚠️ Conversation migration error (non-fatal): $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Supper',
            theme: themeProvider.themeData,
            home: const AuthWrapper(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
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

  // Flags to ensure initialization happens only ONCE per session
  bool _hasInitializedServices = false;
  String? _lastInitializedUserId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final currentUserId = snapshot.data!.uid;

          // CRITICAL: Only initialize services ONCE per user session
          // This prevents duplicate calls on StreamBuilder rebuilds
          if (!_hasInitializedServices || _lastInitializedUserId != currentUserId) {
            _hasInitializedServices = true;
            _lastInitializedUserId = currentUserId;

            // Defer heavy initialization to after first frame renders
            // This prevents frame skipping during app startup
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _initializeUserServices();
            });
          }

          return const MainNavigationScreen();
        }

        // Reset flags when user logs out
        _hasInitializedServices = false;
        _lastInitializedUserId = null;

        return const LoginScreen();
      },
    );
  }

  /// Initialize all user-dependent services
  /// Called ONCE per user session, deferred to after first frame
  Future<void> _initializeUserServices() async {
    try {
      // Ensure profile exists
      await _profileService.ensureProfileExists();

      // Small delay to prevent overwhelming the main thread
      await Future.delayed(const Duration(milliseconds: 100));

      // Initialize location SILENTLY in background
      _locationService.initializeLocation();

      // Start periodic location updates (has internal guard against duplicates)
      _locationService.startPeriodicLocationUpdates();

      // Clean up duplicate conversations (runs in background)
      _conversationService.cleanupDuplicateConversations();
    } catch (e) {
      debugPrint('AuthWrapper: Error initializing services: $e');
    }
  }
}
