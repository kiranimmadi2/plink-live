# Firebase Project Structure

**Project:** suuper2
**Generated:** 2025-12-18
**Framework:** Flutter 3.35.7 + Firebase

---

## Cloud Firestore

### Collection: users
- **Sample Document ID:** `{firebase_auth_uid}` (e.g., `abc123XYZ...`)
- **Fields:**
  - `name`: string
  - `email`: string
  - `profileImageUrl`: string | null
  - `photoUrl`: string | null *(backward compatibility)*
  - `phone`: string | null
  - `location`: string | null
  - `latitude`: number | null
  - `longitude`: number | null
  - `createdAt`: timestamp
  - `lastSeen`: timestamp
  - `isOnline`: boolean
  - `isVerified`: boolean
  - `showOnlineStatus`: boolean
  - `bio`: string
  - `interests`: array<string>
  - `fcmToken`: string | null
  - `additionalInfo`: map | null
  - `accountType`: string (`personal` | `professional` | `business`)
  - `accountStatus`: string (`active` | `pending_verification` | `suspended`)
  - `discoveryModeEnabled`: boolean
  - `gender`: string | null
  - `city`: string | null
  - `blockedUsers`: array<string>
  - `reportCount`: number
  - `professionalProfile`: map | null
    - `businessName`: string | null
    - `category`: string | null
    - `specializations`: array<string>
    - `hourlyRate`: number | null
    - `currency`: string | null
    - `yearsOfExperience`: number | null
    - `portfolioUrls`: array<string>
    - `certifications`: array<string>
    - `servicesOffered`: array<string>
  - `businessProfile`: map | null
    - `companyName`: string | null
    - `registrationNumber`: string | null
    - `taxId`: string | null
    - `industry`: string | null
    - `companySize`: string | null
    - `website`: string | null
    - `foundedYear`: number | null
    - `description`: string | null
    - `teamMembers`: array<string>
    - `adminUsers`: array<string>
  - `verification`: map
    - `status`: string (`none` | `pending` | `verified` | `rejected`)
    - `verifiedAt`: timestamp | null
    - `rejectionReason`: string | null
- **Subcollections:**
  - `private/{documentId}`
    - *(User's private data)*
  - `blocked/{blockedUserId}`
    - `blockedAt`: timestamp
  - `securityEvents/{eventId}`
    - `type`: string
    - `timestamp`: timestamp
    - `metadata`: map

---

### Collection: posts
- **Sample Document ID:** `{auto_generated_id}` (e.g., `AbC123xYz...`)
- **Fields:**
  - `userId`: string
  - `originalPrompt`: string
  - `title`: string
  - `description`: string
  - `intentAnalysis`: map
    - `primary_intent`: string
    - `action_type`: string (`seeking` | `offering` | `neutral` | `selling` | `buying` | etc.)
    - `domain`: string
    - `entities`: map
    - `complementary_intents`: array<string>
    - `search_keywords`: array<string>
    - `emotional_tone`: string
    - `clarifications_needed`: array<string> | null
  - `images`: array<string> | null
  - `metadata`: map
  - `createdAt`: timestamp
  - `expiresAt`: timestamp | null
  - `lastUpdated`: timestamp
  - `isActive`: boolean
  - `embedding`: array<number> *(768 dimensions)*
  - `keywords`: array<string> | null
  - `similarityScore`: number | null
  - `location`: string | null
  - `latitude`: number | null
  - `longitude`: number | null
  - `price`: number | null
  - `priceMin`: number | null
  - `priceMax`: number | null
  - `currency`: string | null
  - `viewCount`: number
  - `matchedUserIds`: array<string>
  - `clarificationAnswers`: map
  - `gender`: string | null
  - `ageRange`: string | null
  - `condition`: string | null
  - `brand`: string | null
- **Subcollections:**
  - `comments/{commentId}`
    - `userId`: string
    - `text`: string
    - `createdAt`: timestamp
  - `likes/{likeId}`
    - `userId`: string
    - `createdAt`: timestamp

---

### Collection: conversations
- **Sample Document ID:** `{auto_generated_id}` or `{sorted_participant_ids}`
- **Fields:**
  - `participants`: array<string>
  - `participantIds`: array<string> *(alternative field)*
  - `participantNames`: map<string, string>
  - `participantPhotos`: map<string, string | null>
  - `lastMessage`: string | null
  - `lastMessageTime`: timestamp | null
  - `lastMessageSenderId`: string | null
  - `unreadCount`: map<string, number>
  - `isTyping`: map<string, boolean>
  - `isGroup`: boolean
  - `groupName`: string | null
  - `groupPhoto`: string | null
  - `admins`: array<string> | null *(for groups)*
  - `createdAt`: timestamp
  - `lastSeen`: map<string, timestamp | null>
  - `isArchived`: boolean
  - `isMuted`: boolean
  - `metadata`: map | null
- **Subcollections:**
  - `messages/{messageId}`
    - `senderId`: string
    - `receiverId`: string
    - `chatId`: string
    - `text`: string | null
    - `type`: number (0=text, 1=image, 2=video, 3=audio, 4=file, 5=location, 6=sticker, 7=gif)
    - `status`: number (0=sending, 1=sent, 2=delivered, 3=read, 4=failed)
    - `timestamp`: timestamp
    - `isDeleted`: boolean
    - `mediaUrl`: string | null
    - `localPath`: string | null
    - `fileName`: string | null
    - `fileSize`: number | null
    - `thumbnailUrl`: string | null
    - `metadata`: map | null
    - `replyToMessageId`: string | null
    - `reactions`: array<string> | null
    - `isEdited`: boolean
    - `editedAt`: timestamp | null
    - `isRead`: boolean
    - `readAt`: timestamp | null
    - `read`: boolean

---

### Collection: calls
- **Sample Document ID:** `{auto_generated_id}`
- **Fields:**
  - `callerId`: string
  - `callerName`: string
  - `receiverId`: string
  - `receiverName`: string
  - `participants`: array<string>
  - `status`: string (`ringing` | `connected` | `ended` | `missed` | `declined`)
  - `state`: string
  - `timestamp`: timestamp
  - `startedAt`: timestamp | null
  - `endedAt`: timestamp | null
  - `duration`: number *(seconds)*

---

### Collection: connection_requests
- **Sample Document ID:** `{auto_generated_id}`
- **Fields:**
  - `senderId`: string
  - `receiverId`: string
  - `status`: string (`pending` | `accepted` | `rejected` | `cancelled`)
  - `createdAt`: timestamp
  - `updatedAt`: timestamp | null
  - `message`: string | null

---

### Collection: matches
- **Sample Document ID:** `{auto_generated_id}`
- **Fields:**
  - `user1Id`: string
  - `user2Id`: string
  - `userIds`: array<string>
  - `users`: map<string, boolean>
  - `matchedAt`: timestamp
  - `post1Id`: string | null
  - `post2Id`: string | null
  - `similarityScore`: number | null
  - `status`: string

---

### Collection: businesses
- **Sample Document ID:** `{auto_generated_id}`
- **Fields:**
  - `userId`: string
  - `ownerId`: string
  - `businessName`: string
  - `legalName`: string | null
  - `businessType`: string
  - `industry`: string | null
  - `description`: string | null
  - `logo`: string | null
  - `coverImage`: string | null
  - `contact`: map
    - `phone`: string | null
    - `email`: string | null
    - `website`: string | null
    - `whatsapp`: string | null
  - `address`: map | null
    - `street`: string | null
    - `city`: string | null
    - `state`: string | null
    - `country`: string | null
    - `postalCode`: string | null
    - `latitude`: number | null
    - `longitude`: number | null
  - `hours`: map | null
    - `schedule`: map<string, map>
      - `{day}`: map
        - `open`: string
        - `close`: string
        - `isClosed`: boolean
    - `timezone`: string | null
  - `images`: array<string>
  - `services`: array<string>
  - `products`: array<string>
  - `socialLinks`: map<string, string>
  - `isVerified`: boolean
  - `isActive`: boolean
  - `rating`: number
  - `reviewCount`: number
  - `followerCount`: number
  - `createdAt`: timestamp
  - `updatedAt`: timestamp

---

### Collection: business_listings
- **Sample Document ID:** `{auto_generated_id}`
- **Fields:**
  - `businessId`: string
  - `businessOwnerId`: string
  - `type`: string (`product` | `service`)
  - `name`: string
  - `description`: string | null
  - `price`: number | null
  - `currency`: string
  - `images`: array<string>
  - `isAvailable`: boolean
  - `isActive`: boolean
  - `createdAt`: timestamp

---

### Collection: business_reviews
- **Sample Document ID:** `{auto_generated_id}`
- **Fields:**
  - `businessId`: string
  - `userId`: string
  - `reviewerId`: string
  - `userName`: string
  - `userPhoto`: string | null
  - `rating`: number
  - `comment`: string | null
  - `images`: array<string>
  - `createdAt`: timestamp
  - `reply`: string | null
  - `replyAt`: timestamp | null

---

### Collection: business_followers
- **Sample Document ID:** `{auto_generated_id}`
- **Fields:**
  - `businessId`: string
  - `followerId`: string
  - `followedAt`: timestamp

---

### Collection: blocks
- **Sample Document ID:** `{auto_generated_id}`
- **Fields:**
  - `blockerId`: string
  - `blockedUserId`: string
  - `createdAt`: timestamp
- **Subcollections:**
  - `blocked_users/{blockedId}`
    - `blockedAt`: timestamp

---

### Collection: reports
- **Sample Document ID:** `{auto_generated_id}`
- **Fields:**
  - `reporterId`: string
  - `reportedUserId`: string
  - `reason`: string
  - `description`: string | null
  - `createdAt`: timestamp
  - `status`: string

---

### Collection: feedback
- **Sample Document ID:** `{auto_generated_id}`
- **Fields:**
  - `userId`: string
  - `type`: string
  - `message`: string
  - `createdAt`: timestamp

---

### Collection: intent_clarifications
- **Sample Document ID:** `{auto_generated_id}`
- **Fields:**
  - `userId`: string
  - `originalInput`: string
  - `question`: string
  - `answer`: string
  - `createdAt`: timestamp

---

### Collection: notifications
- **Sample Document ID:** `{user_id}`
- **Fields:**
  - *(Parent document may be empty or contain user notification settings)*
- **Subcollections:**
  - `items/{notificationId}`
    - `type`: string
    - `title`: string
    - `body`: string
    - `data`: map | null
    - `read`: boolean
    - `createdAt`: timestamp

---

### Collection: status
- **Sample Document ID:** `{user_id}`
- **Fields:**
  - `isOnline`: boolean
  - `lastSeen`: timestamp

---

### Collection: search_index
- **Sample Document ID:** `{document_id}`
- **Fields:**
  - *(Server-side managed - structure varies)*

---

### Collection: config
- **Sample Document ID:** `{config_key}`
- **Fields:**
  - *(Application configuration - read-only)*

---

### Collection: temp
- **Sample Document ID:** `{auto_generated_id}`
- **Fields:**
  - *(Temporary documents for ID generation)*

---

### Deprecated Collections (Read-Only)
- `intents` - *Migrated to posts*
- `user_intents` - *Migrated to posts*
- `processed_intents` - *Migrated to posts*
- `embeddings` - *Now stored in posts.embedding*

---

## Firestore Indexes

### Composite Indexes

| Collection | Fields | Query Scope |
|------------|--------|-------------|
| businesses | ownerId (ASC), createdAt (DESC) | Collection |
| business_listings | businessOwnerId (ASC), createdAt (DESC) | Collection |
| business_listings | businessId (ASC), isActive (ASC), createdAt (DESC) | Collection |
| business_reviews | businessId (ASC), createdAt (DESC) | Collection |
| business_followers | businessId (ASC), followedAt (DESC) | Collection |
| messages | receiverId (ASC), timestamp (DESC) | Collection |
| messages | senderId (ASC), timestamp (DESC) | Collection |
| messages | timestamp (DESC) | Collection |
| calls | receiverId (ASC), state (ASC), timestamp (DESC) | Collection |
| calls | callerId (ASC), state (ASC), timestamp (DESC) | Collection |
| users | isOnline (ASC), lastSeen (DESC) | Collection |
| users | discoveryModeEnabled (ASC), city (ASC) | Collection |
| users | discoveryModeEnabled (ASC), gender (ASC) | Collection |
| users | discoveryModeEnabled (ASC), city (ASC), gender (ASC) | Collection |
| conversations | participants (ARRAY_CONTAINS), lastMessageTime (DESC) | Collection |
| connection_requests | receiverId (ASC), status (ASC), createdAt (DESC) | Collection |
| connection_requests | senderId (ASC), status (ASC), createdAt (DESC) | Collection |
| connection_requests | senderId (ASC), receiverId (ASC), status (ASC) | Collection |
| posts | userId (ASC), createdAt (DESC) | Collection |
| posts | isActive (ASC), createdAt (ASC), userId (ASC) | Collection |
| posts | isActive (ASC), userId (ASC), createdAt (DESC) | Collection |
| matches | userId (ASC), matchedAt (DESC) | Collection |

---

## Firestore Security Rules

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ============================================================
    // HELPER FUNCTIONS
    // ============================================================

    function isAuthenticated() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }

    function isParticipant(conversationData) {
      return isAuthenticated() &&
        (request.auth.uid in conversationData.participants ||
         (conversationData.participantIds != null && request.auth.uid in conversationData.participantIds));
    }

    function isValidString(str, minLen, maxLen) {
      return str is string && str.size() >= minLen && str.size() <= maxLen;
    }

    function isGroupAdmin(admins) {
      return isAuthenticated() && admins != null && request.auth.uid in admins;
    }

    // ============================================================
    // USERS COLLECTION
    // ============================================================
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create: if isOwner(userId);
      allow update: if isOwner(userId);
      allow delete: if isOwner(userId);

      match /private/{document=**} {
        allow read, write: if isOwner(userId);
      }

      match /blocked/{blockedUserId} {
        allow read, write: if isOwner(userId);
      }

      match /securityEvents/{eventId} {
        allow read: if isOwner(userId);
        allow create: if isOwner(userId);
        allow update, delete: if false;
      }
    }

    // ============================================================
    // POSTS COLLECTION
    // ============================================================
    match /posts/{postId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() &&
        request.resource.data.userId == request.auth.uid;
      allow update: if isAuthenticated() &&
        resource.data.userId == request.auth.uid;
      allow delete: if isAuthenticated() &&
        resource.data.userId == request.auth.uid;

      match /comments/{commentId} {
        allow read: if isAuthenticated();
        allow create: if isAuthenticated() &&
          request.resource.data.userId == request.auth.uid;
        allow update, delete: if isAuthenticated() &&
          resource.data.userId == request.auth.uid;
      }

      match /likes/{likeId} {
        allow read: if isAuthenticated();
        allow write: if isAuthenticated() && likeId == request.auth.uid;
      }
    }

    // ============================================================
    // CONVERSATIONS COLLECTION
    // ============================================================
    match /conversations/{conversationId} {
      allow read: if isAuthenticated() &&
        (resource == null ||
         request.auth.uid in resource.data.participants ||
         (resource.data.participantIds != null && request.auth.uid in resource.data.participantIds));
      allow create: if isAuthenticated() &&
        (request.auth.uid in request.resource.data.participants ||
         (request.resource.data.participantIds != null && request.auth.uid in request.resource.data.participantIds));
      allow update: if isAuthenticated() &&
        (request.auth.uid in resource.data.participants ||
         (resource.data.participantIds != null && request.auth.uid in resource.data.participantIds));
      allow delete: if isAuthenticated() &&
        (request.auth.uid in resource.data.participants ||
         (resource.data.participantIds != null && request.auth.uid in resource.data.participantIds) ||
         (resource.data.isGroup == true && isGroupAdmin(resource.data.admins)));

      match /messages/{messageId} {
        allow read: if isAuthenticated() &&
          isParticipant(get(/databases/$(database)/documents/conversations/$(conversationId)).data);
        allow create: if isAuthenticated() &&
          request.resource.data.senderId == request.auth.uid &&
          isParticipant(get(/databases/$(database)/documents/conversations/$(conversationId)).data);
        allow update: if isAuthenticated() &&
          isParticipant(get(/databases/$(database)/documents/conversations/$(conversationId)).data) &&
          (resource.data.senderId == request.auth.uid ||
           request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isRead', 'readAt', 'read', 'status', 'reactions']));
        allow delete: if isAuthenticated() &&
          resource.data.senderId == request.auth.uid;
      }
    }

    // ============================================================
    // CALLS COLLECTION
    // ============================================================
    match /calls/{callId} {
      allow read: if isAuthenticated() &&
        (resource.data.callerId == request.auth.uid ||
         resource.data.receiverId == request.auth.uid);
      allow create: if isAuthenticated() &&
        request.resource.data.callerId == request.auth.uid;
      allow update: if isAuthenticated() &&
        (resource.data.callerId == request.auth.uid ||
         resource.data.receiverId == request.auth.uid);
      allow delete: if isAuthenticated() &&
        (resource.data.callerId == request.auth.uid ||
         resource.data.receiverId == request.auth.uid);
    }

    // ============================================================
    // CONNECTION REQUESTS COLLECTION
    // ============================================================
    match /connection_requests/{requestId} {
      allow read: if isAuthenticated() &&
        (resource.data.senderId == request.auth.uid ||
         resource.data.receiverId == request.auth.uid);
      allow create: if isAuthenticated() &&
        request.resource.data.senderId == request.auth.uid &&
        request.resource.data.senderId != request.resource.data.receiverId;
      allow update: if isAuthenticated() &&
        (resource.data.receiverId == request.auth.uid ||
         resource.data.senderId == request.auth.uid);
      allow delete: if isAuthenticated() &&
        (resource.data.senderId == request.auth.uid ||
         resource.data.receiverId == request.auth.uid);
    }

    // ============================================================
    // MATCHES COLLECTION
    // ============================================================
    match /matches/{matchId} {
      allow read: if isAuthenticated() &&
        (resource.data.user1Id == request.auth.uid ||
         resource.data.user2Id == request.auth.uid ||
         (resource.data.users != null && resource.data.users[request.auth.uid] == true) ||
         (resource.data.userIds != null && request.auth.uid in resource.data.userIds));
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() &&
        (resource.data.user1Id == request.auth.uid ||
         resource.data.user2Id == request.auth.uid ||
         (resource.data.users != null && resource.data.users[request.auth.uid] == true) ||
         (resource.data.userIds != null && request.auth.uid in resource.data.userIds));
      allow delete: if isAuthenticated() &&
        (resource.data.user1Id == request.auth.uid ||
         resource.data.user2Id == request.auth.uid);
    }

    // ============================================================
    // BUSINESSES COLLECTION
    // ============================================================
    match /businesses/{businessId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() &&
        request.resource.data.ownerId == request.auth.uid;
      allow update: if isAuthenticated() &&
        resource.data.ownerId == request.auth.uid;
      allow delete: if isAuthenticated() &&
        resource.data.ownerId == request.auth.uid;
    }

    // ============================================================
    // BUSINESS LISTINGS COLLECTION
    // ============================================================
    match /business_listings/{listingId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() &&
        request.resource.data.businessOwnerId == request.auth.uid;
      allow update: if isAuthenticated() &&
        resource.data.businessOwnerId == request.auth.uid;
      allow delete: if isAuthenticated() &&
        resource.data.businessOwnerId == request.auth.uid;
    }

    // ============================================================
    // BUSINESS REVIEWS COLLECTION
    // ============================================================
    match /business_reviews/{reviewId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() &&
        request.resource.data.reviewerId == request.auth.uid;
      allow update: if isAuthenticated() &&
        resource.data.reviewerId == request.auth.uid;
      allow delete: if isAuthenticated() &&
        resource.data.reviewerId == request.auth.uid;
    }

    // ============================================================
    // BUSINESS FOLLOWERS COLLECTION
    // ============================================================
    match /business_followers/{followId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() &&
        request.resource.data.followerId == request.auth.uid;
      allow delete: if isAuthenticated() &&
        resource.data.followerId == request.auth.uid;
    }

    // ============================================================
    // BLOCKS COLLECTION
    // ============================================================
    match /blocks/{blockId} {
      allow read: if isAuthenticated() &&
        resource.data.blockerId == request.auth.uid;
      allow create: if isAuthenticated() &&
        request.resource.data.blockerId == request.auth.uid;
      allow delete: if isAuthenticated() &&
        resource.data.blockerId == request.auth.uid;

      match /blocked_users/{blockedId} {
        allow read, write: if isAuthenticated() &&
          blockId == request.auth.uid;
      }
    }

    // ============================================================
    // REPORTS COLLECTION
    // ============================================================
    match /reports/{reportId} {
      allow read: if isAuthenticated() &&
        resource.data.reporterId == request.auth.uid;
      allow create: if isAuthenticated() &&
        request.resource.data.reporterId == request.auth.uid;
      allow update, delete: if false;
    }

    // ============================================================
    // FEEDBACK COLLECTION
    // ============================================================
    match /feedback/{feedbackId} {
      allow read: if isAuthenticated() &&
        resource.data.userId == request.auth.uid;
      allow create: if isAuthenticated() &&
        request.resource.data.userId == request.auth.uid;
      allow update, delete: if false;
    }

    // ============================================================
    // INTENT CLARIFICATIONS COLLECTION
    // ============================================================
    match /intent_clarifications/{clarificationId} {
      allow read: if isAuthenticated() &&
        resource.data.userId == request.auth.uid;
      allow create: if isAuthenticated() &&
        request.resource.data.userId == request.auth.uid;
      allow update, delete: if false;
    }

    // ============================================================
    // NOTIFICATIONS COLLECTION
    // ============================================================
    match /notifications/{userId} {
      allow read: if isOwner(userId);
      allow write: if isAuthenticated();

      match /items/{notificationId} {
        allow read: if isOwner(userId);
        allow create: if isAuthenticated();
        allow update, delete: if isOwner(userId);
      }
    }

    // ============================================================
    // USER STATUS/PRESENCE
    // ============================================================
    match /status/{userId} {
      allow read: if isAuthenticated();
      allow write: if isOwner(userId);
    }

    // ============================================================
    // SEARCH INDEX (Server-side only)
    // ============================================================
    match /search_index/{document=**} {
      allow read: if isAuthenticated();
      allow write: if false;
    }

    // ============================================================
    // GLOBAL CONFIG (Read-only)
    // ============================================================
    match /config/{document=**} {
      allow read: if isAuthenticated();
      allow write: if false;
    }

    // ============================================================
    // DEPRECATED COLLECTIONS
    // ============================================================
    match /intents/{intentId} {
      allow read: if isAuthenticated();
      allow write: if false;
    }

    match /user_intents/{intentId} {
      allow read: if isAuthenticated();
      allow write: if false;
    }

    match /processed_intents/{intentId} {
      allow read: if isAuthenticated();
      allow write: if false;
    }

    match /embeddings/{embeddingId} {
      allow read: if isAuthenticated();
      allow write: if false;
    }

    // ============================================================
    // TEMP COLLECTION
    // ============================================================
    match /temp/{docId} {
      allow read, write: if isAuthenticated();
    }
  }
}
```

---

## Firebase Storage Structure

```
/users/
  /{userId}/
    /profile/
      profile_image.jpg
      cover_image.jpg
    /posts/
      {postId}/
        image_0.jpg
        image_1.jpg
    /messages/
      {messageId}/
        media.jpg
        video.mp4
        audio.m4a
        file.pdf

/businesses/
  /{businessId}/
    logo.jpg
    cover.jpg
    /images/
      image_0.jpg
    /listings/
      {listingId}/
        image_0.jpg

/groups/
  /{groupId}/
    group_photo.jpg

/temp/
  /{userId}/
    temp_upload.jpg
```

---

## Firebase Authentication

- **Providers Enabled:**
  - Email/Password
  - Google Sign-In
  - Apple Sign-In (iOS)
  - Phone Authentication

---

## Firebase Cloud Messaging (FCM)

- **Token Storage:** `users/{userId}.fcmToken`
- **Used For:**
  - New message notifications
  - Incoming call notifications
  - Connection request notifications
  - Match notifications

---

## Notes

1. **Single Source of Truth:** All user posts are stored in the `posts` collection only. Legacy collections (`intents`, `user_intents`, `processed_intents`) are deprecated.

2. **Semantic Matching:** Posts use 768-dimension embeddings stored in `posts.embedding` for AI-powered matching.

3. **Voice-Only Calling:** The app supports voice calls only (no video calling).

4. **Account Types:** Users can have `personal`, `professional`, or `business` account types with corresponding profile data.
