# Live Connect Feature - Complete Documentation

## Overview

Live Connect is a real-time user discovery feature that allows users to find and connect with nearby people based on interests, activities, and connection preferences. It provides a Tinder-like card interface with advanced filtering capabilities.

### Key Features
- User Discovery with card-based UI
- Advanced Filtering (Interests, Activities, Connection Types, Gender, Location)
- Connection Request System (Send/Accept/Reject)
- Block & Report System for safety
- Real-time Online Status
- Discovery Mode (visibility toggle)

---

## Architecture

### Data Flow
```
User Opens Live Connect
        |
        v
Load Nearby People Query (Firestore)
        |
        v
Apply Filters (Discovery Mode, Location, Gender)
        |
        v
Client-side Filtering (Interests, Activities, Connection Types, Blocked Users)
        |
        v
Display User Cards
        |
        v
User Taps Card -> Profile Bottom Sheet
        |
        v
Connect / Message / Block / Report
```

### Key Files

| File | Purpose |
|------|---------|
| `lib/screens/live_connect_tab_screen.dart` | Main screen with user cards and filters |
| `lib/screens/my_connections_screen.dart` | View pending requests and connections |
| `lib/widgets/profile_detail_bottom_sheet.dart` | User profile modal |
| `lib/widgets/edit_profile_bottom_sheet.dart` | Edit profile modal |
| `lib/services/connection_service.dart` | Connection request logic |
| `lib/services/block_report_service.dart` | Block and report logic |
| `lib/services/presence_service.dart` | Online status tracking |
| `lib/models/extended_user_profile.dart` | User profile model |

---

## Features

### 1. User Discovery

Users are displayed in a card-based UI with:
- Profile photo (full-screen background)
- Name overlay
- Online status indicator (green dot)
- Tap to view full profile

**Query Logic:**
```dart
Query<Map<String, dynamic>> usersQuery = _firestore.collection('users');

// Filter by discovery mode
usersQuery = usersQuery.where('discoveryModeEnabled', isEqualTo: true);

// Filter by location (if enabled)
if (_locationFilter == 'City' && userCity != null) {
  usersQuery = usersQuery.where('city', isEqualTo: userCity);
}

// Filter by gender (if enabled)
if (_filterByGender && _selectedGenders.length == 1) {
  usersQuery = usersQuery.where('gender', isEqualTo: _selectedGenders.first);
}

usersQuery = usersQuery.limit(_pageSize);
```

### 2. Filters

#### Interests Filter
- Toggle on/off with switch
- Multi-select chip UI
- 15+ predefined interests: Fitness, Travel, Music, Photography, etc.
- Uses `arrayContainsAny` for matching

#### Connection Types Filter (30 Options)
Organized into 6 groups:

| Group | Options |
|-------|---------|
| Social | Dating, Friendship, Casual Hangout, Travel Buddy, Nightlife Partner |
| Professional | Networking, Mentorship, Business Partner, Career Advice, Collaboration |
| Activities | Workout Partner, Sports Partner, Hobby Partner, Event Companion, Study Group |
| Learning | Language Exchange, Skill Sharing, Book Club, Learning Partner, Creative Workshop |
| Creative | Music Jam, Art Collaboration, Photography, Content Creation, Performance |
| Other | Roommate, Pet Playdate, Community Service, Gaming, Online Friends |

**UI:** Expandable sections with chip-style selection (green when selected)

#### Activities Filter (30 Options)
Organized into 4 groups:

| Group | Options |
|-------|---------|
| Sports | Tennis, Badminton, Basketball, Football, Volleyball, Golf, Table Tennis, Squash |
| Fitness | Running, Gym, Yoga, Pilates, CrossFit, Cycling, Swimming, Dance |
| Outdoor | Hiking, Rock Climbing, Camping, Kayaking, Surfing, Mountain Biking, Trail Running |
| Creative | Photography, Painting, Music, Writing, Cooking, Crafts, Gaming |

**UI:** Expandable sections with chip-style selection (green when selected)

#### Gender Filter
- Options: Male, Female, Other
- Multi-select capability
- Single selection uses Firestore query
- Multiple selections use client-side filtering

#### Location Filter
- Options: "Near me", "City"
- "Near me": Distance-based calculation using lat/long
- "City": Exact city match query
- Distance calculated using Haversine formula

### 3. Connection Request System

**Service:** `lib/services/connection_service.dart`

**Features:**
- Send connection requests with optional message
- Accept/Reject incoming requests
- Cancel sent requests
- View pending/sent requests
- Remove established connections
- Real-time notifications

**Firestore Collection:** `connection_requests`
```javascript
{
  senderId: "user1",
  senderName: "John",
  senderPhoto: "url",
  receiverId: "user2",
  message: "Let's connect!",
  status: "pending", // pending, accepted, rejected
  createdAt: timestamp,
  updatedAt: timestamp
}
```

**Usage:**
```dart
final connectionService = ConnectionService();

// Send request
await connectionService.sendConnectionRequest(
  receiverId: "userId",
  message: "Let's connect!",
);

// Accept request
await connectionService.acceptConnectionRequest(requestId);

// Reject request
await connectionService.rejectConnectionRequest(requestId);

// Check if connected
final isConnected = await connectionService.areUsersConnected(user1, user2);
```

### 4. Block & Report System

**Service:** `lib/services/block_report_service.dart`

**Features:**
- Block users (bidirectional - neither sees the other)
- Unblock users
- Report users with categories
- Evidence attachment support
- Automatic filtering of blocked users

**Report Categories:**
1. Harassment or Bullying
2. Spam or Scam
3. Inappropriate Content
4. Fake Profile
5. Safety Concern
6. Other

**Firestore Collections:**

`blocks`
```javascript
{
  blockerId: "user1",
  blockedId: "user2",
  reason: "harassment",
  createdAt: timestamp
}
```

`reports`
```javascript
{
  reporterId: "user1",
  reportedUserId: "user2",
  category: "harassment",
  reason: "Description",
  additionalDetails: "...",
  evidenceUrls: [...],
  status: "pending", // pending, under_review, resolved, dismissed
  createdAt: timestamp
}
```

**Usage:**
```dart
final blockService = BlockReportService();

// Block user
await blockService.blockUser(blockedUserId: "userId", reason: "spam");

// Check if blocked
final isBlocked = await blockService.isUserBlocked("userId");

// Report user
await blockService.reportUser(
  reportedUserId: "userId",
  category: "harassment",
  reason: "Threatening messages",
);
```

### 5. Online Status / Presence

**Service:** `lib/services/presence_service.dart`

**Features:**
- Automatic online/offline status tracking
- Heartbeat every 30 seconds
- Last seen timestamp
- Real-time status streams
- "Recently active" detection (within 5 minutes)

**How it works:**
1. User logs in -> status = online
2. Every 30 seconds -> heartbeat updates `lastSeen`
3. User closes app -> status = offline
4. Other users see real-time green dot indicator

**Usage:**
```dart
final presenceService = PresenceService();

// Initialize after authentication
await presenceService.initialize();

// Get online status stream
presenceService.getOnlineStatusStream("userId").listen((isOnline) {
  print("User is ${isOnline ? 'online' : 'offline'}");
});

// Check recently active
final recentlyActive = await presenceService.isRecentlyActive("userId");

// Dispose when app closes
await presenceService.dispose();
```

### 6. Discovery Mode Toggle

**Location:** Settings Screen

**What it does:** Controls visibility in Live Connect

**User Profile Field:**
```javascript
{
  discoveryModeEnabled: true // Show me in Live Connect
}
```

**Behavior:**
- Toggle OFF: User disappears from Live Connect searches
- Toggle ON: User appears in searches
- Query automatically filters by this field

---

## Database Structure

### Firestore Collections

#### `users`
```javascript
{
  uid: string,
  name: string,
  email: string,
  photoUrl: string,
  bio: string,
  city: string,
  latitude: number,
  longitude: number,
  interests: ["Fitness", "Travel", ...],
  connectionTypes: ["Dating", "Friendship", ...],
  activities: ["Tennis", "Hiking", ...],
  gender: "Male" | "Female" | "Other",
  discoveryModeEnabled: boolean,
  blockedUsers: [userId, ...],
  connections: [userId, ...],
  connectionCount: number,
  isOnline: boolean,
  lastSeen: timestamp
}
```

#### `connection_requests`
```javascript
{
  senderId: string,
  senderName: string,
  senderPhoto: string,
  receiverId: string,
  message: string,
  status: "pending" | "accepted" | "rejected",
  createdAt: timestamp,
  updatedAt: timestamp
}
```

#### `blocks`
```javascript
{
  blockerId: string,
  blockedId: string,
  reason: string,
  createdAt: timestamp
}
```

#### `reports`
```javascript
{
  reporterId: string,
  reportedUserId: string,
  category: string,
  reason: string,
  additionalDetails: string,
  evidenceUrls: [string],
  status: "pending" | "under_review" | "resolved" | "dismissed",
  createdAt: timestamp
}
```

### Required Firestore Indexes

**CRITICAL:** These indexes must be created for queries to work.

#### Index 1: Discovery Mode + City
```
Collection: users
Fields:
  - discoveryModeEnabled (Ascending)
  - city (Ascending)
```

#### Index 2: Discovery Mode + Gender
```
Collection: users
Fields:
  - discoveryModeEnabled (Ascending)
  - gender (Ascending)
```

#### Index 3: Discovery Mode + City + Gender
```
Collection: users
Fields:
  - discoveryModeEnabled (Ascending)
  - city (Ascending)
  - gender (Ascending)
```

#### Index 4: Connection Requests (Received)
```
Collection: connection_requests
Fields:
  - receiverId (Ascending)
  - status (Ascending)
  - createdAt (Descending)
```

#### Index 5: Connection Requests (Sent)
```
Collection: connection_requests
Fields:
  - senderId (Ascending)
  - status (Ascending)
  - createdAt (Descending)
```

**Complete firestore.indexes.json:**
```json
{
  "indexes": [
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "discoveryModeEnabled", "order": "ASCENDING" },
        { "fieldPath": "city", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "discoveryModeEnabled", "order": "ASCENDING" },
        { "fieldPath": "gender", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "discoveryModeEnabled", "order": "ASCENDING" },
        { "fieldPath": "city", "order": "ASCENDING" },
        { "fieldPath": "gender", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "connection_requests",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "receiverId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "connection_requests",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "senderId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

**Deploy indexes:**
```bash
firebase deploy --only firestore:indexes
```

---

## Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Connection requests
    match /connection_requests/{requestId} {
      allow read: if request.auth != null &&
        (resource.data.senderId == request.auth.uid ||
         resource.data.receiverId == request.auth.uid);
      allow create: if request.auth != null &&
        request.resource.data.senderId == request.auth.uid;
      allow update: if request.auth != null &&
        resource.data.receiverId == request.auth.uid;
      allow delete: if request.auth != null &&
        resource.data.senderId == request.auth.uid;
    }

    // Blocks
    match /blocks/{blockId} {
      allow read: if request.auth != null &&
        resource.data.blockerId == request.auth.uid;
      allow write: if request.auth != null &&
        request.resource.data.blockerId == request.auth.uid;
    }

    // Reports
    match /reports/{reportId} {
      allow create: if request.auth != null &&
        request.resource.data.reporterId == request.auth.uid;
      allow read: if request.auth != null;
    }

    // Users
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null &&
        request.auth.uid == userId;
    }
  }
}
```

---

## UI Components

### Live Connect Tab Screen
- Card stack with user photos
- Filter button (top right)
- Connections badge (shows pending count)
- Pull-to-refresh
- Pagination (loads more on scroll)

### Filter Dialog
- Location filter (Near me / City)
- Gender filter (multi-select chips)
- Interests filter (toggle + chips)
- Connection Types filter (expandable groups)
- Activities filter (expandable groups)
- Apply / Clear buttons

### Profile Detail Bottom Sheet
- Full profile photo
- Name and bio
- "Looking to connect for:" section
- "Activities:" section
- "Interests & Hobbies:" section
- Connect / Message / Block / Report buttons

### My Connections Screen
Two sections:
1. **Pending Requests** (top, purple header)
   - User avatar, name, bio
   - Accept (green) / Reject (red) buttons

2. **My Connections** (bottom, green header)
   - User avatar, name, bio
   - "Connected" badge
   - Message / Remove buttons

---

## Initialization

### 1. Initialize Presence Service
Add to `main.dart` after authentication:
```dart
import 'package:supper/services/presence_service.dart';

// After user logs in
final presenceService = PresenceService();
await presenceService.initialize();

// When app closes
await presenceService.dispose();
```

### 2. Migrate Existing Users
Run once to add required fields:
```dart
Future<void> migrateExistingUsers() async {
  final firestore = FirebaseFirestore.instance;
  final usersSnapshot = await firestore.collection('users').get();
  final batch = firestore.batch();

  for (var doc in usersSnapshot.docs) {
    final data = doc.data();
    final updates = <String, dynamic>{};

    if (!data.containsKey('discoveryModeEnabled')) {
      updates['discoveryModeEnabled'] = true;
    }
    if (!data.containsKey('blockedUsers')) {
      updates['blockedUsers'] = [];
    }
    if (!data.containsKey('connections')) {
      updates['connections'] = [];
    }
    if (!data.containsKey('connectionCount')) {
      updates['connectionCount'] = 0;
    }

    if (updates.isNotEmpty) {
      batch.update(doc.reference, updates);
    }
  }

  await batch.commit();
}
```

---

## Testing Guide

### User Discovery
- [ ] Open Live Connect tab
- [ ] Verify user cards load
- [ ] Tap on card to see profile
- [ ] Verify online indicator (green dot) shows for online users
- [ ] Pull to refresh
- [ ] Scroll to load more users

### Filters
- [ ] Open filter dialog
- [ ] Toggle location filter (Near me / City)
- [ ] Select single gender - verify Firestore query
- [ ] Select multiple genders - verify client-side filter
- [ ] Enable interests filter and select interests
- [ ] Enable connection types filter and select options
- [ ] Enable activities filter and select options
- [ ] Apply filters - verify results match
- [ ] Clear filters - verify all users show

### Connection Requests
- [ ] Send connection request
- [ ] Receive notification on other device
- [ ] Accept request - verify both users connected
- [ ] Reject request - verify request removed
- [ ] Cancel sent request
- [ ] View pending requests count on badge
- [ ] View sent requests

### Block & Report
- [ ] Block user - verify they disappear from Live Connect
- [ ] Verify blocked user can't see you
- [ ] Unblock user - verify they reappear
- [ ] Report user with different categories
- [ ] View blocked users list

### Discovery Mode
- [ ] Toggle OFF in Settings
- [ ] Verify you disappear from other users' Live Connect
- [ ] Toggle ON - verify you reappear

### Online Status
- [ ] User goes online - verify status updates
- [ ] Verify heartbeat keeps user online
- [ ] Close app - verify status = offline
- [ ] Check last seen shows correct time

---

## Troubleshooting

### No users showing in Live Connect

**Cause 1:** Missing `discoveryModeEnabled` field
- Solution: Run migration script or remove the filter temporarily

**Cause 2:** Missing Firestore indexes
- Solution: Check console for index creation link, create required indexes

**Cause 3:** All users have `discoveryModeEnabled: false`
- Solution: Toggle on in Settings

### "The query requires an index" error
- Solution: Click the link in error message to create index, or use firestore.indexes.json

### Slow loading (5-10+ seconds)
- Cause: N+1 queries for block checking
- Solution: Batch load blocked users list instead of checking each user individually

### Connection request not received
- Check FCM token is registered
- Verify security rules allow the operation
- Check receiver's `discoveryModeEnabled` is true

### Filter not working
- Verify user has the field being filtered
- Check for typos in field names
- For array filters, verify data type matches

---

## Color Scheme

The feature uses a green/purple color scheme:

| Element | Color |
|---------|-------|
| Selected chips | Green (#00D67D) |
| Active switches | Green |
| Success messages | Green |
| My Connections header | Green |
| Accept/Message buttons | Green |
| Group headers | Purple (#9C27B0) |
| Pending Requests header | Purple |
| Filter icons | Purple |

---

## Performance Notes

### With proper indexes:
- Query time: <500ms
- Document reads: Only matching documents (20-50)

### Without indexes:
- Query time: 5-10+ seconds (or fails)
- Document reads: Scans all documents

### Optimization tips:
1. Always use `limit()` in queries
2. Prefer Firestore queries over client-side filtering when possible
3. Cache blocked users list instead of checking per-user
4. Use pagination for large result sets

---

**Version:** 2.0.0
**Last Updated:** 2025-11-21
**Status:** Production Ready
