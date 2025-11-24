import 'package:flutter_dotenv/flutter_dotenv.dart';

class ZegoConfig {
  // ZEGOCLOUD App ID and App Sign - loaded from environment variables
  static int get appID => int.tryParse(dotenv.env['ZEGO_APP_ID'] ?? '0') ?? 0;
  static String get appSign => dotenv.env['ZEGO_APP_SIGN'] ?? '';

  // Call configuration
  static const bool audioOnly = true; // Voice calls only
  static const bool turnOnCameraWhenJoining = false; // No camera for voice calls
  static const bool turnOnMicrophoneWhenJoining = true;

  // Call timeout settings (matching existing app behavior)
  static const Duration callRingingTimeout = Duration(seconds: 60);
  static const Duration callConnectionTimeout = Duration(seconds: 30);

  // Audio settings
  static const bool enableAEC = true; // Acoustic Echo Cancellation
  static const bool enableAGC = true; // Automatic Gain Control
  static const bool enableANS = true; // Automatic Noise Suppression

  // UI Configuration
  static const bool showSoundWaveInAudioCall = true;
  static const bool showMicrophoneStateOnView = true;
  static const bool showUserNameOnView = true;
}

/*
 * SETUP INSTRUCTIONS:
 *
 * 1. Sign up at https://console.zegocloud.com
 * 2. Create a new project
 * 3. Go to project dashboard and copy:
 *    - App ID (numeric value)
 *    - App Sign (string value)
 * 4. Add the values to your .env file:
 *    ZEGO_APP_ID=your_app_id
 *    ZEGO_APP_SIGN=your_app_sign
 *
 * IMPORTANT:
 * - App ID is a number (not a string)
 * - App Sign is a string
 * - For production, consider using server-side token generation
 *
 * Firebase Firestore Structure (unchanged):
 * calls/
 *   {callId}/
 *     callId: string
 *     callerId: string
 *     callerName: string
 *     callerPhoto: string
 *     receiverId: string
 *     receiverName: string
 *     receiverPhoto: string
 *     type: 'audio' (always audio for voice-only)
 *     state: 'calling' | 'ringing' | 'accepted' | 'connected' | 'ended' | 'rejected'
 *     channelName: string (use as ZEGO callID)
 *     timestamp: ISO string
 */
