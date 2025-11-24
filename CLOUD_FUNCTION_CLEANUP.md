# Firebase Cloud Function - Auto-Cleanup Old Messages

## Purpose

This Cloud Function automatically deletes messages older than 30 days from Firebase Firestore to save storage costs. Messages are kept permanently on users' devices (SQLite), but removed from the cloud after delivery.

## Implementation

### Step 1: Initialize Firebase Functions (if not already done)

```bash
# In your project root
firebase init functions

# Select:
# - Use an existing project
# - JavaScript or TypeScript
# - Install dependencies with npm
```

### Step 2: Create the Cleanup Function

**File**: `functions/index.js`

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

/**
 * Auto-Cleanup Old Messages
 *
 * Runs daily at midnight (UTC) to delete messages older than 30 days from Firestore.
 * Messages are kept permanently in users' local SQLite databases.
 *
 * Benefits:
 * - Reduces Firestore storage costs by 80-90%
 * - Keeps only recent messages for sync
 * - Users still see all messages (from local storage)
 */
exports.cleanupOldMessages = functions.pubsub
  .schedule('every 24 hours')
  .timeZone('UTC')
  .onRun(async (context) => {
    const thirtyDaysAgo = Date.now() - (30 * 24 * 60 * 60 * 1000);

    console.log(`Starting cleanup of messages older than ${new Date(thirtyDaysAgo).toISOString()}`);

    let deletedCount = 0;
    const batchSize = 500; // Firestore batch limit

    try {
      // Get all conversations
      const conversationsSnapshot = await db.collection('conversations').get();

      console.log(`Found ${conversationsSnapshot.size} conversations to check`);

      for (const conversationDoc of conversationsSnapshot.docs) {
        const conversationId = conversationDoc.id;

        // Get old messages in this conversation
        const messagesSnapshot = await db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('timestamp', '<', new Date(thirtyDaysAgo))
          .limit(batchSize)
          .get();

        if (messagesSnapshot.empty) {
          continue; // No old messages in this conversation
        }

        // Delete in batches
        const batch = db.batch();
        messagesSnapshot.docs.forEach(doc => {
          batch.delete(doc.ref);
        });

        await batch.commit();
        deletedCount += messagesSnapshot.docs.length;

        console.log(`Deleted ${messagesSnapshot.docs.length} old messages from conversation ${conversationId}`);
      }

      console.log(`✅ Cleanup completed. Deleted ${deletedCount} messages total`);
      return null;

    } catch (error) {
      console.error(`❌ Cleanup failed:`, error);
      throw error;
    }
  });

/**
 * Cleanup Old Messages for Specific Conversation
 *
 * Can be triggered manually via HTTP for testing or specific cleanup needs.
 *
 * Usage:
 * POST https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/cleanupConversationMessages
 * Body: { "conversationId": "user1_user2", "daysOld": 30 }
 */
exports.cleanupConversationMessages = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  const { conversationId, daysOld = 30 } = req.body;

  if (!conversationId) {
    return res.status(400).send('Missing conversationId');
  }

  const cutoffDate = Date.now() - (daysOld * 24 * 60 * 60 * 1000);

  try {
    const messagesSnapshot = await db
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .where('timestamp', '<', new Date(cutoffDate))
      .get();

    if (messagesSnapshot.empty) {
      return res.status(200).json({
        success: true,
        deletedCount: 0,
        message: 'No old messages to delete'
      });
    }

    const batch = db.batch();
    messagesSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });

    await batch.commit();

    return res.status(200).json({
      success: true,
      deletedCount: messagesSnapshot.docs.length,
      message: `Deleted ${messagesSnapshot.docs.length} old messages`
    });

  } catch (error) {
    console.error('Error cleaning up conversation:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});
```

### Step 3: Update package.json

**File**: `functions/package.json`

```json
{
  "name": "functions",
  "description": "Cloud Functions for Firebase",
  "scripts": {
    "serve": "firebase emulators:start --only functions",
    "shell": "firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "engines": {
    "node": "18"
  },
  "main": "index.js",
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0"
  },
  "devDependencies": {
    "firebase-functions-test": "^3.1.0"
  },
  "private": true
}
```

### Step 4: Deploy the Function

```bash
cd functions
npm install
cd ..

# Deploy only functions
firebase deploy --only functions

# Or deploy specific function
firebase deploy --only functions:cleanupOldMessages
```

### Step 5: Verify Deployment

```bash
# Check function logs
firebase functions:log --only cleanupOldMessages

# Test manually (one-time run)
# Go to Firebase Console > Functions > cleanupOldMessages > Test
```

## Cost Savings

### Before Auto-Cleanup
```
Messages stored: All messages forever
Storage cost: $0.18 per GB/month
100K users × 1000 messages each = 100M messages
Estimated size: 100 GB
Cost: $18/month just for message storage
```

### After Auto-Cleanup
```
Messages stored: Only last 30 days
Storage cost: $0.18 per GB/month
100K users × 100 recent messages each = 10M messages
Estimated size: 10 GB
Cost: $1.80/month ✅ 10x cheaper!
```

## Testing

### Test Locally (Firebase Emulator)

```bash
cd functions
npm install
firebase emulators:start --only functions

# In another terminal, test the function
curl -X POST http://localhost:5001/YOUR_PROJECT/us-central1/cleanupConversationMessages \
  -H "Content-Type: application/json" \
  -d '{"conversationId": "test_user1_user2", "daysOld": 30}'
```

### Test in Production

```bash
# Trigger manually via Firebase Console
# Go to: Firebase Console > Functions > cleanupOldMessages > Test

# Or use gcloud CLI
gcloud functions call cleanupOldMessages --region=us-central1
```

## Monitoring

### View Logs

```bash
# Real-time logs
firebase functions:log --only cleanupOldMessages

# Or in Firebase Console
# Go to: Firebase Console > Functions > cleanupOldMessages > Logs
```

### Set Up Alerts

In Firebase Console:
1. Go to Functions > cleanupOldMessages
2. Click "Add Alert"
3. Set alert for:
   - Function errors
   - Execution time > 30 seconds
   - Memory usage > 80%

## Configuration Options

### Change Cleanup Schedule

```javascript
// Run every 12 hours
exports.cleanupOldMessages = functions.pubsub
  .schedule('every 12 hours')
  ...

// Run once a week (Sunday at 2 AM)
exports.cleanupOldMessages = functions.pubsub
  .schedule('0 2 * * 0')
  ...

// Run daily at specific time (3 AM UTC)
exports.cleanupOldMessages = functions.pubsub
  .schedule('0 3 * * *')
  ...
```

### Change Retention Period

```javascript
// Keep messages for 60 days instead of 30
const sixtyDaysAgo = Date.now() - (60 * 24 * 60 * 60 * 1000);

// Keep messages for 7 days (more aggressive cleanup)
const sevenDaysAgo = Date.now() - (7 * 24 * 60 * 60 * 1000);
```

## Troubleshooting

### Function Not Running

```bash
# Check if function is deployed
firebase functions:list

# Check logs for errors
firebase functions:log --only cleanupOldMessages --limit 50

# Redeploy
firebase deploy --only functions:cleanupOldMessages
```

### Permission Errors

Make sure Firebase Admin SDK has proper permissions:

```javascript
// In functions/index.js
const admin = require('firebase-admin');
admin.initializeApp(); // This gives full admin access
```

### Too Many Messages to Delete

If you have millions of messages, the function might timeout. Solution:

```javascript
// Process in smaller batches with pagination
const batchSize = 100;
let lastDoc = null;

do {
  let query = db
    .collection('conversations')
    .doc(conversationId)
    .collection('messages')
    .where('timestamp', '<', cutoffDate)
    .limit(batchSize);

  if (lastDoc) {
    query = query.startAfter(lastDoc);
  }

  const snapshot = await query.get();

  if (snapshot.empty) break;

  const batch = db.batch();
  snapshot.docs.forEach(doc => batch.delete(doc.ref));
  await batch.commit();

  lastDoc = snapshot.docs[snapshot.docs.length - 1];
} while (lastDoc);
```

## Alternative: Firestore TTL (Time To Live)

Firebase now supports automatic TTL for documents. You can use this instead of Cloud Functions:

```javascript
// When creating a message, set TTL
await db.collection('conversations').doc(conversationId).collection('messages').add({
  text: 'Hello',
  timestamp: FieldValue.serverTimestamp(),
  expireAt: FieldValue.serverTimestamp() + (30 * 24 * 60 * 60 * 1000) // 30 days
});

// Then in Firestore Console, set up TTL policy on 'expireAt' field
// Go to: Firestore > Select Collection > TTL Policy > Create
```

## Summary

✅ **Implemented**: Auto-cleanup Cloud Function
✅ **Savings**: 10x reduction in storage costs
✅ **User Experience**: No impact (messages stay on device)
✅ **Deployment**: `firebase deploy --only functions`
✅ **Monitoring**: Available in Firebase Console

Your messaging system now automatically cleans up old messages from the cloud while keeping them forever on users' devices! 🚀
