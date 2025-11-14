# Firestore Index Setup

## Required Index for user_intents Collection

The app requires a composite index for the `user_intents` collection to support the following query:

```
collection: user_intents
Query filters:
- userId == [userId]
- status == 'active'
Order by: createdAt (descending)
```

## How to Create the Index

### Option 1: Use the Direct Link from Error Message
Click on this link from the error message:
https://console.firebase.google.com/v1/r/project/suuper2/firestore/indexes?create_composite=Ckxwcm9qZWN0cy9zdXVwZXIyL2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy91c2VyX2ludGVudHMvaW5kZXhlcy9fEAEaCgoGc3RhdHVzEAEaCgoGdXNlcklkEAEaDQoJY3JlYXRlZEF0EAIaDAoIX19uYW1lX18QAg

### Option 2: Create Manually in Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **suuper2**
3. Navigate to Firestore Database → Indexes
4. Click "Create Index"
5. Configure the index:
   - Collection ID: `user_intents`
   - Fields to index:
     - Field: `userId` → Order: Ascending
     - Field: `status` → Order: Ascending
     - Field: `createdAt` → Order: Descending
   - Query scope: Collection
6. Click "Create"

## Alternative: Modify Query (Temporary Fix)
If you need a quick fix while the index is building, you can modify the query in `lib/services/universal_intent_service.dart`:

Change from:
```dart
final querySnapshot = await _firestore
    .collection('user_intents')
    .where('userId', isEqualTo: userId)
    .where('status', isEqualTo: 'active')
    .orderBy('createdAt', descending: true)
    .get();
```

To (remove orderBy temporarily):
```dart
final querySnapshot = await _firestore
    .collection('user_intents')
    .where('userId', isEqualTo: userId)
    .where('status', isEqualTo: 'active')
    .get();
    
// Then sort in memory
final docs = querySnapshot.docs;
docs.sort((a, b) => (b.data()['createdAt'] as Timestamp?)?.compareTo(
    a.data()['createdAt'] as Timestamp? ?? Timestamp.now()) ?? 0);
```

## Index Building Time
- The index will take a few minutes to build depending on the amount of data
- You can check the status in the Firebase Console
- The app will work once the index status shows "Enabled"