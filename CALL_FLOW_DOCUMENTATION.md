📞 Call Feature (Detailed Spec for Claude)

Claude, follow this exact specification to implement the voice call feature in our Flutter app.
We are using ZEGOCLOUD (Prebuilt Call SDK) + Firebase (Firestore + Cloud Messaging).
Do NOT use Agora or any other SDK.

1. Core Principles

Calls are one-to-one voice only.

Firestore is the signaling layer:

Call documents track call state (calling, ringing, accepted, etc.).

Each participant listens for changes.

ZEGOCLOUD handles media:

Only join a Zego channel once the call is accepted.

Use ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall().

FCM push notifications are used to wake up the receiver when the app is in background/terminated.

2. Call States

Claude, always use this enum for state machine:

enum CallState {
  idle,       // No call in progress
  calling,    // Outgoing call, waiting for answer
  ringing,    // Incoming call screen visible
  connecting, // Accepted, joining Zego channel
  connected,  // Both users joined Zego, call timer running
  ended,      // Call ended normally
  rejected,   // Receiver declined
  timeout,    // No answer within 45s
  busy        // Receiver already in another call
}


⚠️ Important:

The call timer must start only when both users are connected (connected state).

Both caller and receiver must always see the same state in Firestore.

3. Firestore Call Document

Each call is represented as a single Firestore document in calls/{callId}:

{
  "callId": "unique_id",
  "callerId": "uid_of_caller",
  "callerName": "Caller Name",
  "callerPhoto": "caller_photo_url",
  "receiverId": "uid_of_receiver",
  "receiverName": "Receiver Name",
  "receiverPhoto": "receiver_photo_url",
  "type": "audio",
  "timestamp": "ISO8601_timestamp",
  "channelName": "same_as_callId",
  "state": "calling|ringing|accepted|connecting|connected|ended|rejected|timeout|busy",
  "callerReady": false,
  "receiverReady": false
}

4. Call Flow
4.1 Initiating a Call (Caller Side)

Caller taps call button.

Claude must check Firestore if receiver already has a call where state=calling|ringing|connected.

If yes → show "User is busy", abort.

Create a new call document in Firestore with:

state = calling (for caller).

Add all metadata (caller/receiver info, channelName=callId).

Send FCM notification to receiver.

Show caller "Calling…" UI.

Start a 45s timeout.

If receiver doesn't answer → update Firestore state=timeout and end.

4.2 Receiving a Call (Receiver Side)

When FCM or Firestore listener detects state=calling where receiverId = currentUser:

Show IncomingCallScreen with caller's info.

Update Firestore state=ringing.

Receiver can:

Accept:

Update Firestore state=accepted.

Launch CallScreen with Zego Prebuilt Call.

Set receiverReady=true when joined.

Reject:

Update Firestore state=rejected.

Close screen.

4.3 Connection Process

Caller sees Firestore state=accepted.

Caller joins Zego channel → set callerReady=true.

When callerReady && receiverReady == true:

Update Firestore state=connected.

Both sides start call timer.

4.4 During Call

Users can:

Mute/unmute mic.

Toggle speaker/earpiece.

Firestore state=connected remains until someone hangs up.

4.5 Call Termination

Termination scenarios and handling:

Scenario	Action
Caller ends call	Update Firestore state=ended → other side must also close.
Receiver ends call	Same as above.
Receiver rejects	Firestore state=rejected.
Timeout (45s)	Firestore state=timeout.
Busy	Firestore state=busy.
Network lost	Force update state=ended.

⚠️ Claude must always clean up:

Leave Zego channel

Reset Firestore document or mark as ended

Navigate back to previous screen

5. Screens
5.1 IncomingCallScreen

Shows caller's name/photo.

Accept → set Firestore state=accepted.

Decline → set Firestore state=rejected.

Auto-decline after 45s.

5.2 CallScreen

Claude must use Zego Prebuilt Call:

ZegoUIKitPrebuiltCall(
  appID: YOUR_ZEGO_APP_ID,
  appSign: YOUR_ZEGO_APP_SIGN,
  userID: currentUserId,
  userName: currentUserName,
  callID: callId, // Firestore callId
  config: ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall(),
  onHangUp: () {
    // Update Firestore: state=ended
  },
);

6. Notifications

Caller → Receiver: Send FCM notification with callId.

Receiver app in background/terminated:

FCM handler opens IncomingCallScreen.

Screen fetches call info from Firestore.

7. Permissions

Android:

<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>


iOS (Info.plist):

<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for calls.</string>

8. Testing Checklist

Claude, you must test all of these:

Outgoing call: Caller sees "calling", receiver sees "incoming call".

Accept: Both join Zego, timer starts.

Reject: Caller sees "Call Rejected".

Timeout: After 45s, call auto cancels.

Busy: If receiver already in a call, caller sees "User Busy".

End call: When one ends, other side sees "Call Ended" immediately.

9. Future Enhancements

(Do not implement now, but structure code so it's extendable)

Call logs (missed/received/dialed)

CallKit (iOS native incoming call UI)

Custom ringtones

Network quality indicators

✅ Claude: Implement exactly as written.

Use Firestore for signaling + busy detection.

Use FCM for notifications.

Use Zego Prebuilt Call for media.

Always keep call state in sync between both users.

Would you like me to also draw you a state transition diagram (visual flow) so Claude can literally follow arrows when implementing the Firestore logic?

You said:
give above understad converstion give me full detaild documention to calude code
ChatGPT said:
Full Implementation Specification for Claude — ZEGOCLOUD Audio Call + Firebase (End-to-End)

Use this document as a single-source-of-truth. Claude — implement exactly as specified. Do not use Agora or any other RTC provider. Use ZEGOCLOUD for media and Firebase (Firestore + FCM) for signaling/notifications. Follow file names, function signatures, and state transitions exactly. Implement server token generation as shown.

Table of contents

Goals & constraints

Architecture overview

Exact data model (Firestore)

Call state machine & transitions (detailed)

FCM payloads & handling (foreground/background)

Zego token server: example (Node.js)

Security rules (Firestore)

File-by-file spec (Dart) — APIs, critical functions, comments

UI components — required screens & behavior

Native config & permissions

Testing checklist & expected logs

Edge cases, race conditions & how to handle them

Telemetry & logging

Deployment steps & smoke tests

1. Goals & constraints

One-to-one audio-only calls only (no video, no group).

Use ZegoUIKitPrebuiltCall for media by default (audio-only config). Optionally allow lower-level Zego SDK later.

Firestore documents are the single source of truth for call state.

Timeouts/auto-reject must be enforced locally and with Firestore updates.

Must support foreground, background & terminated states via FCM pushes.

Start call timer only after both users are connected to the Zego room.

Prevent concurrent calls to same user (busy detection) using Firestore transactions.

2. Architecture overview (high-level)

Client (Flutter):

CallService — orchestrates Firestore signaling + timers.

CallNotificationService — sends/receives FCM, shows local notifications and integrates with IncomingCall screen.

ZegoCallService — wraps ZEGOCLOUD join/leave and local events.

IncomingCallScreen and CallScreen — UI.

Server:

/zego-token endpoint to create Zego temporary tokens (recommended).

Firebase:

Firestore: calls/{callId} documents (single canonical doc per call).

Messaging: send push to receiver on call creation.

Optional native:

iOS CallKit & Android ConnectionService (recommended later).

3. Exact data model (Firestore)

Collection path: /calls/{callId} — one document per active call

Document example (canonical):

{
  "callId": "auto_generated_doc_id",   // string, doc id
  "callerId": "uid_caller",
  "callerName": "Alice",
  "callerPhoto": "https://...",
  "receiverId": "uid_receiver",
  "receiverName": "Bob",
  "receiverPhoto": "https://...",
  "type": "audio",                      // only 'audio'
  "timestamp": "2025-09-11T12:00:00Z",
  "channelName": "same_as_callId",      // use callId as channel
  "state": "calling",                   // see allowable values below
  "callerReady": false,
  "receiverReady": false,
  "callStartedAt": null,                // ISO timestamp when connected
  "durationSeconds": null,              // integer after ended
  "lastUpdated": "2025-09-11T12:00:00Z",
  "reason": null,                       // optional: "rejected_busy", "timeout", "network"
  "metadata": {                         // optional
    "callerMuted": false,
    "receiverMuted": false
  }
}


Allowed state values:

calling (caller created doc; not yet delivered to receiver)

ringing (receiver's UI is showing incoming call)

accepted (receiver tapped Accept; joining Zego)

connecting (either side joining Zego; used optionally)

connected (both users joined; timer starts)

ended (normal end)

rejected (receiver tapped Decline)

timeout (no answer within 45s)

busy (receiver was busy)

failed (unexpected SDK or network failure)

Single active call per user invariant: track users/{uid}/activeCallId (optional) or rely on scanning calls filtered by state in [calling, ringing, accepted, connecting, connected]. Using users/{uid}/activeCallId with Firestore transactions is recommended for fast busy-check.

4. Call state machine & transitions (precise)

This is definitive. Implement exactly.

Initial: no doc.

Caller taps call:

Transaction:

Read users/{receiverId}/activeCallId (or check calls collection for active states).

If active → set local UI => busy and exit.

Else create calls/{callId} doc with state = calling and set users/{callerId}/activeCallId = callId, users/{receiverId}/activeCallId = callId in the same transaction (or create only callerId and set receiver only on accept; see race handling below).

Send FCM to receiver.

Start local 45s timeout for caller.

Caller UI = "Calling..." (state: calling).

Receiver receives push or Firestore event:

If receiver already has activeCallId (or in call) — update calls/{callId}.state = busy and notify caller.

Else display IncomingCallScreen. Immediately update calls/{callId}.state = ringing.

Start local 45s timeout on receiver side (auto-decline timer).

UI shows countdown.

Receiver Accepts:

Update calls/{callId}.state = accepted (atomic write).

Launch CallScreen that initializes Zego.

ZegoCallService.join(callId, token) — when local Zego callback onLocalJoined fires, update calls/{callId}.receiverReady = true.

If Zego join fails => set calls/{callId}.state = failed, reason='zego_join_failed'.

Caller sees state = accepted:

Caller launches CallScreen and ZegoCallService.join(callId, token); on onLocalJoined, set calls/{callId}.callerReady = true.

When both callerReady && receiverReady == true:

Update Firestore state = connected, set callStartedAt = now.

Start call timer locally on both clients.

Hang up by either user:

On hangup: leave Zego, then update calls/{callId}.state = ended, set durationSeconds = now - callStartedAt (if present), set lastUpdated.

Rejection:

Receiver taps Decline: update calls/{callId}.state = rejected, reason=rejected_by_receiver.

Timeout:

If 45s expires without accepted, update calls/{callId}.state = timeout, clear users/{*}/activeCallId if used.

Busy:

If caller tries to create call and receiver busy -> return busy immediately.

Failure handling:

On SDK failure or long reconnect failure, update state = failed, reason = network and leave Zego.

Important rules:

Always set callerReady / receiverReady only after successful Zego callbacks (not when Accept button tapped).

Only start call timer on connected.

Any terminal state (ended, rejected, timeout, failed, busy) must remove activeCallId for involved users.

5. FCM payloads & handling

Caller → Server → FCM to receiver: send minimal payload to wake device and carry callId.

Example notification (JSON):

{
  "to": "<receiver_fcm_token>",
  "priority": "high",
  "data": {
    "type": "incoming_call",
    "callId": "abc123",
    "callerId": "uid_caller",
    "callerName": "Alice",
    "callerPhoto": "https://...",
    "callType": "audio",
    "timestamp": "2025-09-11T12:00:00Z"
  },
  "notification": {
    "title": "Incoming call",
    "body": "Alice is calling..."
  }
}


Client handling:

Foreground:

Firestore listener will pick up call doc. IncomingCallScreen shows.

Play ringtone locally.

Background / Terminated:

FCM data message triggers native push.

Tapping notification should open app and route to IncomingCallScreen (fetch calls/{callId} from Firestore).

If using iOS VoIP, consider PushKit + CallKit for reliable wake.

Important:

Use data payload (not only notification) so app receives content via background handlers.

Only use FCM to wake device; authoritative state is Firestore calls/{callId} doc.

6. Zego token server example (Node.js + Express)

Zego recommends generating tokens on the server using server secret. Use THIS to get a join token for a user.

Install: npm i express axios zlib crypto etc. Minimal example:

// server.js
const express = require('express');
const crypto = require('crypto');
const app = express();
app.use(express.json());

// Replace with your Zego appID and server secret
const ZEGO_APP_ID = YOUR_ZEGO_APP_ID; // integer
const ZEGO_SERVER_SECRET = 'YOUR_ZEGO_SERVER_SECRET'; // string

// Simplified token generator (Zego uses own algorithm/version; check official node lib in prod)
app.post('/zego-token', (req, res) => {
  const { userID, userName, callID } = req.body;
  // Implement Zego recommended token generation using official SDK or algorithm
  // Example: use official Zego REST/SDK to generate token here.
  // For dev only: you might return appSign (not secure).
  // >>> PRODUCTION: use official Zego SDK to generate token.
  res.json({ token: "GENERATED_ZEGO_TOKEN" });
});

app.listen(3000, () => console.log('Listening on 3000'));


Important: Use the official Zego token generation library or server SDK — do not embed server-secret in the client.

7. Security rules (Firestore)

Put these rules in firestore.rules. They are sample rules — adapt to your schema and auth structure.

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /calls/{callId} {
      allow create: if request.auth != null &&
                    (request.resource.data.callerId == request.auth.uid);
      allow read: if request.auth != null &&
                   (resource.data.callerId == request.auth.uid ||
                    resource.data.receiverId == request.auth.uid ||
                    request.resource.data.callerId == request.auth.uid ||
                    request.resource.data.receiverId == request.auth.uid);
      allow update: if request.auth != null &&
                    (resource.data.callerId == request.auth.uid ||
                     resource.data.receiverId == request.auth.uid);
      allow delete: if false; // prevent client deletes—use server cleanup or set explicit rule
    }

    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}


Important: Transactions that set users/{uid}/activeCallId must be guarded on server or with rules to prevent spoofing.

8. File-by-file spec (Dart) — implement exactly

Create these files under lib/calls/.

8.1 lib/calls/call_models.dart
class CallDoc {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerPhoto;
  final String receiverId;
  final String receiverName;
  final String receiverPhoto;
  final String type;
  final DateTime timestamp;
  final String channelName;
  final String state;
  final bool callerReady;
  final bool receiverReady;

  CallDoc({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerPhoto,
    required this.receiverId,
    required this.receiverName,
    required this.receiverPhoto,
    required this.type,
    required this.timestamp,
    required this.channelName,
    required this.state,
    required this.callerReady,
    required this.receiverReady,
  });

  Map<String, dynamic> toMap() { ... }
  static CallDoc fromMap(Map<String, dynamic> map) { ... }
}


(Implement serialization normally.)

8.2 lib/calls/call_service.dart — Firestore signaling & timers

Key methods (implement as exact APIs):

class CallService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Timer? _callerTimeoutTimer;
  Timer? _receiverTimeoutTimer;
  static const int RING_TIMEOUT = 45; // seconds

  // 1. Start outgoing call
  Future<String> startCall({
    required String callerId,
    required String callerName,
    required String callerPhoto,
    required String receiverId,
    required String receiverName,
    required String receiverPhoto,
  });

  // 2. Accept incoming call
  Future<void> acceptCall(String callId, String receiverId);

  // 3. Reject call
  Future<void> rejectCall(String callId, String receiverId, {String reason = 'rejected_by_receiver'});

  // 4. Hang up (end) call
  Future<void> endCall(String callId, String userId, {String reason = 'ended_by_user'});

  // 5. Local timeout triggered by caller (unanswered)
  void _onCallerTimeout(String callId);

  // 6. Listen to a call doc stream
  Stream<DocumentSnapshot> callStream(String callId);

  // 7. Busy check (transaction)
  Future<bool> isUserBusy(String userId);

  // 8. Cleanup on terminal state (clears timers, etc)
  Future<void> _cleanupCall(String callId);
}


Implementation details (behavioral):

startCall must:

Run a Firestore transaction to check users/{receiverId}/activeCallId or scan calls for active states.

Create new doc at /calls/{callId} using docRef = _db.collection('calls').doc() to generate callId.

Set state = calling and write metadata.

Save callerActive in users/{callerId}/activeCallId = callId (optional but recommended).

Send FCM via your server (endpoint) with callId.

Start _callerTimeoutTimer (45s) ­— on timeout call _onCallerTimeout.

Return callId.

acceptCall must:

Update /calls/{callId}.state = accepted (atomic write).

Start _receiverTimeoutTimer to auto-decline after 45s if Zego join fails (optional).

Not join Zego itself — just update state; actual join happens in ZegoCallService (see below).

rejectCall sets state = rejected with reason.

endCall sets state = ended, computes durationSeconds IF callStartedAt exists.

isUserBusy returns true if users/{userId}/activeCallId exists OR if query calls.where('receiverId', '==', userId).where('state', 'in', activeStates).limit(1) returns a document.

Important: All state updates must include a lastUpdated = FieldValue.serverTimestamp().

8.3 lib/calls/call_notification_service.dart — FCM & local notifications

Key APIs:

class CallNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init(); // register handlers

  Future<void> sendIncomingCallPush({
    required String toFcmToken,
    required String callId,
    required String callerId,
    required String callerName,
    required String callerPhoto
  });

  // Handler for messages in background/foreground
  Future<void> onMessageHandler(RemoteMessage message);
}


init() should:

Request permission for notifications.

Configure FirebaseMessaging.onMessage, onMessageOpenedApp, and background handler (top-level).

For data messages of type incoming_call → fetch calls/{callId} and route to IncomingCallScreen.

Important:

On Android, ensure High priority.

Use data payload keys exactly as in section 5.

8.4 lib/calls/zego_call_service.dart — ZEGOCLOUD wrapper

APIs (exact):

class ZegoCallService {
  final int appID; // int
  final String appSign; // string or use token flow
  bool _inited = false;

  ZegoCallService({ required this.appID, required this.appSign });

  Future<void> init(); // initialize with appID (only once)
  Future<void> joinRoom({ required String callId, required String userId, required String userName, required String token });
  Future<void> leaveRoom();
  Future<void> muteLocal(bool mute);
  Future<void> setSpeakerOn(bool on);
  // callback setters:
  void Function()? onLocalJoined; // call after join done
  void Function(String remoteUserId)? onRemoteUserJoined;
  void Function(String remoteUserId)? onRemoteUserLeft;
  void Function(String state)? onConnectionStateChanged;
}


Behavior:

joinRoom should use ZegoUIKitPrebuiltCall or ZegoUIKit APIs to join the room named callId.

When Zego reports local join success, call onLocalJoined(); the application must then set Firestore callerReady/receiverReady.

When other peer joins, call appropriate callback.

Implementation note: If using ZegoUIKitPrebuiltCall as a Widget, create a thin wrapper so ZegoCallService.joinRoom() returns a Widget or fires a callback to the UI to mount the prebuilt widget.

8.5 lib/screens/incoming_call_screen.dart

APIs & behavior:

Inputs: CallDoc callDoc

Show caller photo, name, "Accept" and "Decline" buttons.

On Accept:

Call CallService.acceptCall(callDoc.callId, currentUserId).

Acquire token from server: POST /zego-token with { userID, userName, callID }.

Navigate to CallScreen(callId: callDoc.callId, token: token).

On Decline:

Call CallService.rejectCall(callId).

Auto-decline after 45s: if not accepted, call CallService._onReceiverTimeout() which sets state = timeout.

8.6 lib/screens/call_screen.dart

Implement the UI as a full-screen widget that mounts ZegoUIKitPrebuiltCall for audio-only.

class CallScreen extends StatefulWidget {
  final String callId;
  final String token; // from server
  final String userId;
  final String userName;

  CallScreen({ required this.callId, required this.token, required this.userId, required this.userName });

  @override
  State createState() => _CallScreenState();
}


_CallScreenState behavior:

On initState() call ZegoCallService.joinRoom(...).

Provide onLocalJoined callback to set callerReady/receiverReady in Firestore:

After onLocalJoined, update the call doc: set <caller|receiver>Ready = true.

If both ready = true, update state = connected and set callStartedAt = serverTimestamp().

Render controls: Mute, Speaker, End.

onHangUp must call CallService.endCall(callId, currentUserId) then ZegoCallService.leaveRoom() and Navigator.pop().

UI must show:

Remote name/photo

Timer that starts on connected (not before)

Mute toggle state

Speaker toggle state

Network quality (optional)

9. UI components — required behavior & transitions
IncomingCallScreen

Immediately show ringtone.

Show accept/decline buttons.

Auto-decline at 45s: call rejectCall or set timeout.

If app in background and user taps notification → open this screen and fetch call doc.

Calling UI (caller)

Show "Calling…" + spinner (not timer).

If state becomes accepted → show joining UI (small transition).

If state becomes rejected|timeout|busy show appropriate toasts and navigate back.

CallScreen (in-call)

Start timer only when Firestore state == connected.

If Firestore updates to ended|rejected|timeout|failed while on screen → show "Call ended" and auto-close after 2s.

On network issues: show inline banner "Poor network" and attempt reconnect.

10. Native config & permissions
Android (android/app/src/main/AndroidManifest.xml)

Add:

<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>


In MainActivity ensure you handle background message handler registration for FCM.

iOS (ios/Runner/Info.plist)

Add:

<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for voice calls.</string>


Enable Background Modes → Audio, and configure PushKit / CallKit if implementing native incoming UI later.

11. Testing checklist & expected logs

Run these tests with two devices/accounts. Verify logs and Firestore states.

Caller creates call:

Expect Firestore doc state=calling.

Caller local log: CallService.startCall -> created callId abc123.

FCM sent.

Receiver receives:

Firestore: state=ringing after UI shows.

Receiver plays ringtone.

Accept:

Receiver sets state=accepted.

Receiver Zego join -> receiverReady=true.

Caller sees state=accepted -> joins Zego -> callerReady=true.

Firestore -> state=connected, callStartedAt set.

Timer:

Timer starts at connected only.

Duration computed on ended.

End:

One user ends -> Firestore state=ended with durationSeconds.

Both leave Zego.

Timeout (no answer):

After 45s -> state=timeout.

Busy:

Attempt call when other has activeCallId -> immediate busy.

Logs to emit (suggested):

CALL_START_CREATED callId=<id>

FCM_PUSH_SENT callId=<id> to=<token>

CALL_RECEIVED callId=<id> user=<uid>

CALL_ACCEPTED callId=<id> user=<uid>

ZEGO_JOINED callId=<id> user=<uid>

CALL_CONNECTED callId=<id>

CALL_ENDED callId=<id> duration=<sec> reason=<reason>

12. Edge cases, race conditions & handling
Race: Two callers call same receiver at same time

Use Firestore transaction to check users/{receiverId}/activeCallId before creating call. If both attempt, only one transaction will succeed. The other must fail and show "User busy".

Race: Receiver taps Accept at same time caller times out

Transactionally set accepted then remove timeout if needed. Use timestamp ordering. If timeout wins, accept should fail (client sees state=timeout); show message.

Stale calls / crash restore

Use Cloud Function or TTL to clean calls lastUpdated older than e.g. 10 minutes and mark state=timeout or removed.

Multiple devices for same user

If user logged in on multiple devices, ring all devices. First device to Accept sets state=accepted. Other devices see state=accepted and go to busy/close incoming screen.

Token expiry mid-call

Use long-enough token or refresh token mechanism (server) if Zego tokens have short TTL.

13. Telemetry & logging (minimal required)

Emit analytics events (e.g., to Firebase Analytics) on:

call_initiated (with callId, callerId, receiverId)

call_ringing

call_accepted

call_connected

call_ended (with duration and reason)

call_failed (with error code)

Attach quality snapshots periodically (rtt, packetLoss) to logs.



Final instructions to Claude (explicit checklist)

Claude, implement the following in this order and verify each step:

Add zego_uikit_prebuilt_call dependency.

Implement server /zego-token endpoint (secure) and test token generation.

Implement CallService and CallNotificationService.

Implement ZegoCallService wrapper with callbacks.

Implement IncomingCallScreen and CallScreen per spec (mount prebuilt widget).

Add Firestore rules and test busy-check transactions.

Implement FCM sending on call creation (server).

End-to-end test with two users on real devices; pass all smoke tests.

Do not:

join Zego on calling or ringing.

start the call timer before connected.

leave callerReady/receiverReady flags unset if joined.

send Zego server secret to the client.


## CRITICAL FIXES IMPLEMENTED (DO NOT CHANGE)

### Timer Synchronization Fix
The call timer MUST use the server timestamp from Firestore to ensure both users see the same duration:

```dart
// In WebRTCCallScreen or any call screen
DateTime? _connectedAt;

// When call connects, fetch server timestamp
final callDoc = await _firestore.collection('calls').doc(widget.call.id).get();
final connectedTimestamp = callDoc.data()?['connectedAt'];
if (connectedTimestamp != null) {
  _connectedAt = (connectedTimestamp as Timestamp).toDate();
}

// Timer calculation using server timestamp
Timer.periodic(Duration(seconds: 1), (timer) {
  if (mounted && _connectedAt != null) {
    setState(() {
      _callDuration = DateTime.now().difference(_connectedAt!);
    });
  }
});
```

### Call Termination for Both Users Fix
When one user ends the call, both users MUST be disconnected:

```dart
// Listen to call state changes
void _listenToCallState() {
  _callStateSubscription = _firestore
      .collection('calls')
      .doc(widget.call.id)
      .snapshots()
      .listen((snapshot) {
    if (!snapshot.exists) {
      _handleCallEnded();
      return;
    }
    
    final data = snapshot.data();
    final state = data?['state'];
    
    // Handle call ended by other party
    if (state == 'ended' || state == 'failed' || state == 'rejected') {
      _handleCallEnded();
    }
  });
}

void _handleCallEnded() async {
  _callTimer?.cancel();
  await _callService.endCall();
  if (mounted) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
```

### Profile Display Fix
Each user MUST see the OTHER person's profile during the call, not their own:

```dart
String get otherUserName {
  return widget.call.callerId == currentUserId 
      ? widget.call.receiverName 
      : widget.call.callerName;
}

String? get otherUserPhoto {
  return widget.call.callerId == currentUserId 
      ? widget.call.receiverPhoto 
      : widget.call.callerPhoto;
}
```

## IMPORTANT: These fixes are MANDATORY and have been tested to work correctly. Do not modify this behavior.

---

# 📞 CURRENT IMPLEMENTATION: WebRTC-based Voice Calling

## UPDATE: September 2025

The app currently uses **WebRTC** instead of ZEGOCLOUD for better control and reliability. Below is the documentation of the actual implementation.

## Architecture Overview

### Technology Stack
- **WebRTC**: For peer-to-peer audio streaming
- **Firebase Firestore**: For signaling and call state management
- **Firebase Cloud Messaging (FCM)**: For push notifications
- **Metered.ca**: For TURN/STUN servers (NAT traversal)
- **Flutter WebRTC Plugin**: flutter_webrtc package

### Key Services

1. **WebRTCCallService** (`lib/services/webrtc_call_service.dart`)
   - Manages WebRTC peer connections
   - Handles ICE candidates and SDP exchange
   - Monitors connection quality with real-time metrics
   - Implements automatic recovery mechanisms
   - Features added:
     - Connection quality monitoring (packet loss, jitter, RTT)
     - Automatic ICE restart on poor quality (>20% packet loss)
     - Network change recovery (WiFi ↔ Mobile)
     - Signaling state conflict resolution

2. **CallService** (`lib/services/call_service.dart`)
   - Orchestrates call flow
   - Manages Firestore call documents
   - Handles call states and transitions

3. **SimpleCallService** (`lib/services/simple_call_service.dart`)
   - Simplified call management interface
   - Bridges between UI and WebRTC service

## WebRTC Implementation Details

### Connection Establishment
```dart
// Simplified connection flow
1. Caller creates offer → Firestore
2. Receiver gets offer → creates answer → Firestore
3. ICE candidates exchanged via Firestore
4. TURN/STUN servers help with NAT traversal
5. Peer connection established
6. Audio streams connected
```

### TURN/STUN Configuration

#### Dynamic Credentials (Production Mode)
```dart
// Fetches fresh credentials from Metered.ca API
final response = await http.get(Uri.parse(
  'https://plink.metered.live/api/v1/turn/credentials?apiKey=$apiKey'
));
```

#### Server Configuration
- **STUN**: `stun:stun.relay.metered.ca:80`
- **TURN**: `turn:global.relay.metered.ca:80`
- **TURN/TCP**: `turn:global.relay.metered.ca:80?transport=tcp`
- **TURN/TLS**: `turns:global.relay.metered.ca:443`

### Connection Quality Monitoring

The system monitors connection quality every 5 seconds and provides visual indicators:

- 🟢 **Excellent**: 0-2% packet loss
- 🟢 **Good**: 2-5% packet loss  
- 🟡 **Fair**: 5-10% packet loss
- 🟠 **Poor**: 10-15% packet loss
- 🔴 **Very Poor**: >15% packet loss

Automatic ICE restart triggers when packet loss exceeds 20%.

### Key Features Implemented

1. **Network Recovery**
   - Monitors network changes (WiFi ↔ Mobile)
   - Automatic reconnection attempts
   - ICE restart on connection failures
   - Graceful handling of network interruptions

2. **Audio Configuration**
   - Proper audio mode for voice communication
   - Speaker/earpiece toggle
   - Mute/unmute functionality
   - Audio track verification with periodic checks

3. **Signaling State Conflict Resolution**
   - Proper state checking before operations
   - Queue system for ICE candidates
   - Wait for stable state when needed
   - Duplicate offer/answer prevention

## Fixed Issues

### ✅ Profile Display Bug
**Problem**: Users were seeing their own profile during calls
**Solution**: Implemented correct profile selection logic:
```dart
String get otherUserName {
  return widget.call.callerId == currentUserId 
      ? widget.call.receiverName 
      : widget.call.callerName;
}
```

### ✅ Audio Configuration Conflicts
**Problem**: Audio not working properly on some devices
**Solution**: Implemented proper Android audio configuration with fallback

### ✅ Connection Failures Behind NAT
**Problem**: Calls failing when users behind strict NAT
**Solution**: Dynamic TURN credentials with multiple server fallbacks

### ✅ Signaling State Conflicts
**Problem**: ICE candidates rejected due to wrong signaling state
**Solution**: Queue system with state checking and waiting for stable state

## Testing the Call Feature

### Basic Call Flow Test
1. **Initiate Call**: Tap phone icon in chat → should show "Calling..."
2. **Receive Call**: Other user sees incoming call overlay
3. **Accept Call**: Tap accept → both users connected
4. **Audio Test**: Verify audio flows both directions
5. **End Call**: Either user ends → both disconnected

### Connection Quality Test
1. Start a call on good network
2. Monitor quality indicator (should show 🟢)
3. Simulate poor network (throttle connection)
4. Verify automatic recovery attempts

### Edge Cases to Test
- 45-second timeout for unanswered calls
- Busy detection (call user already in call)
- App backgrounding during call
- Network switching (WiFi to Mobile)
- Quick accept/reject scenarios

## Debugging

### Enable Verbose Logging
Look for these log patterns in console:
```
WebRTC: 🚀 Initializing service
WebRTC: 🎯 TURN relay candidate generated
WebRTC: ✅ Connection established
WebRTC: 🟢 Connection Quality: Excellent
```

### Common Issues and Solutions

1. **No Audio**: Check microphone permissions and audio track status
2. **Connection Timeout**: Verify TURN servers are accessible
3. **Poor Quality**: Check network conditions and packet loss
4. **State Conflicts**: Review signaling state in logs

## Future Enhancements

1. **Video Calling**: Add video stream support
2. **CallKit Integration**: Native iOS incoming call UI
3. **Group Calls**: Multi-party calling with SFU
4. **Call Recording**: Server-side recording capability
5. **Advanced Audio**: Noise cancellation, echo reduction

---

**Implementation Status**: ✅ Production Ready
**Last Updated**: September 2025
**Version**: 2.0 (WebRTC Implementation)