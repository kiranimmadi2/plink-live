class ZegoConfig {
  // ZEGOCLOUD App ID and App Sign from console.zegocloud.com
  static const int appID = 1306642094; // Your ZEGOCLOUD App ID
  static const String appSign = 'a19ce103092d2b85ce0adfcef8dd1d6bbc94898d5b6a9155bd9a1521b00e9ae3'; // Your ZEGOCLOUD App Sign
  
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
 * 4. Replace the values above with your actual credentials
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