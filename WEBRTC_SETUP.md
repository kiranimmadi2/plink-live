# WebRTC Video/Audio Calling Setup Guide

## Overview
This application now includes a fully functional WebRTC-based video and audio calling feature using:
- **Agora RTC Engine** for real-time communication
- **Firebase Firestore** for signaling
- **Firebase Cloud Messaging** for call notifications

## Architecture

### Components
1. **WebRTC Service** (`lib/services/webrtc_service.dart`)
   - Manages Agora RTC Engine
   - Handles call initiation, acceptance, and termination
   - Manages audio/video streams

2. **Call Screen** (`lib/screens/call_screen.dart`)
   - UI for ongoing calls
   - Controls for mute, speaker, camera switching
   - Video preview and remote video display

3. **Incoming Call Overlay** (`lib/widgets/incoming_call_overlay.dart`)
   - Shows incoming call notifications
   - Accept/Reject call options

4. **Call Manager** (`lib/widgets/call_manager.dart`)
   - Global listener for incoming calls
   - Manages call state across the app

## Setup Instructions

### 1. Agora Setup
1. Create an account at [Agora.io](https://www.agora.io/)
2. Create a new project in the Agora Console
3. Copy your App ID from the project settings
4. Update `lib/config/agora_config.dart`:
   ```dart
   static const String appId = 'YOUR_ACTUAL_AGORA_APP_ID';
   ```

### 2. Firebase Configuration
Ensure your Firebase project has the following Firestore structure:

```
calls/
  {userId}/
    callId: string
    callerId: string
    callerName: string
    callerPhoto: string
    receiverId: string
    receiverName: string
    receiverPhoto: string
    type: 'audio' | 'video'
    state: 'calling' | 'ringing' | 'connected' | 'ended' | 'rejected'
    channelName: string
    timestamp: ISO string
```

### 3. Permissions (Android)
The following permissions are already configured in the Android manifest:
- `INTERNET`
- `RECORD_AUDIO`
- `CAMERA`
- `MODIFY_AUDIO_SETTINGS`
- `ACCESS_NETWORK_STATE`
- `BLUETOOTH`

### 4. Permissions (iOS)
Add to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for voice and video calls</string>
```

## How It Works

### Making a Call
1. User taps the voice or video call button in chat
2. App requests necessary permissions
3. Creates a call document in Firestore
4. Initiates Agora RTC connection
5. Waits for receiver to accept/reject

### Receiving a Call
1. Call Manager listens for incoming calls
2. Shows incoming call overlay
3. User accepts/rejects
4. If accepted, joins the Agora channel

### Call Flow
```
Caller                    Firebase                    Receiver
  |                          |                           |
  |-- Create Call Doc ------>|                           |
  |                          |-- Notify Receiver ------->|
  |                          |                           |
  |<-- Listen for Accept ----|<-- Accept/Reject ---------|
  |                          |                           |
  |-- Join Channel ---------->|<-- Join Channel ---------|
  |                          |                           |
  |<===== WebRTC P2P Connection via Agora =============>|
```

## Testing

### Local Testing
1. Use two devices or emulators
2. Sign in with different accounts
3. Start a chat between the accounts
4. Tap the call button to initiate a call

### Test Checklist
- [ ] Voice call initiation
- [ ] Video call initiation
- [ ] Incoming call notification
- [ ] Accept/Reject functionality
- [ ] Mute/Unmute microphone
- [ ] Enable/Disable camera
- [ ] Switch camera (front/back)
- [ ] Speaker/Earpiece toggle
- [ ] Call timer
- [ ] End call functionality
- [ ] Automatic cleanup after call ends

## Production Considerations

### 1. Token Authentication
For production, implement token-based authentication:
1. Set up a token server
2. Update `AgoraConfig.tokenServerUrl`
3. Modify `WebRTCService._joinChannel()` to use tokens

### 2. TURN Servers
For better connectivity behind firewalls:
1. Set up TURN servers
2. Add to `AgoraConfig.iceServers`

### 3. Call Quality
Adjust in `lib/config/agora_config.dart`:
- Video bitrate
- Frame rate
- Resolution
- Audio quality

### 4. Error Handling
- Network disconnection recovery
- Permission denial handling
- Call timeout management

## Troubleshooting

### Common Issues

1. **"Failed to initialize call"**
   - Check Agora App ID is correct
   - Verify internet connection
   - Check permissions are granted

2. **No video/audio**
   - Verify camera/microphone permissions
   - Check if another app is using the camera/mic
   - Restart the app

3. **Call not connecting**
   - Check Firebase rules allow read/write
   - Verify both users are authenticated
   - Check network connectivity

4. **Poor call quality**
   - Check network bandwidth
   - Adjust video quality settings
   - Consider using audio-only mode

## Additional Features to Consider

1. **Call History**
   - Store call logs in Firestore
   - Show missed/received/dialed calls

2. **Group Calls**
   - Implement SFU/MCU for multiple participants
   - Update UI for grid view

3. **Screen Sharing**
   - Add screen capture functionality
   - Update UI controls

4. **Call Recording**
   - Implement server-side recording
   - Add playback functionality

5. **Background Calls**
   - Implement CallKit (iOS) / ConnectionService (Android)
   - Handle calls when app is in background

## Support

For issues or questions:
- Agora Documentation: https://docs.agora.io/
- Firebase Documentation: https://firebase.google.com/docs
- Flutter Documentation: https://flutter.dev/docs