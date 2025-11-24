# 🔥 Firestore Index Setup for Connection Requests

## ❌ Current Error

```
Failed to load requests
[cloud_firestore/failed-precondition] The query requires an index.
```

This error appears because the Firestore database needs **composite indexes** for the connection requests queries.

---

## ✅ SOLUTION: Create Firestore Indexes

You have **2 options** to fix this:

---

### **Option 1: Click the Auto-Generated Link** (EASIEST)

1. **Look at the error message in your app** - it contains a link like:
   ```
   https://console.firebase.google.com/v1/r/project/supper2/firestore/indexes?create_composite=...
   ```

2. **Copy that entire URL** from your phone/emulator screen

3. **Open it in your browser**

4. **Click "Create Index"** button

5. **Wait 1-2 minutes** for the index to build

6. **Refresh your app** - the error should be gone!

---

### **Option 2: Create Manually in Firebase Console**

If the link doesn't work, create the indexes manually:

#### Step 1: Go to Firebase Console

1. Open: https://console.firebase.google.com
2. Select your project: **supper2**
3. Click **Firestore Database** (left sidebar)
4. Click **Indexes** tab (top)

#### Step 2: Create Index #1 (Pending Requests)

Click **"Create Index"** and enter:

**Collection ID**: `connection_requests`

**Fields to index**:
1. **receiverId** → Ascending
2. **status** → Ascending
3. **createdAt** → Descending

**Query scope**: Collection

Click **"Create"**

#### Step 3: Create Index #2 (Sent Requests)

Click **"Create Index"** again and enter:

**Collection ID**: `connection_requests`

**Fields to index**:
1. **senderId** → Ascending
2. **status** → Ascending
3. **createdAt** → Descending

**Query scope**: Collection

Click **"Create"**

#### Step 4: Wait for Indexes to Build

- Status will show "Building..." (usually 1-2 minutes)
- When complete, status shows "Enabled" with green checkmark
- You'll see both indexes in the list

---

## 📋 Index Configuration Details

### Index 1: Pending Connection Requests Query
```
Collection: connection_requests
Fields:
  - receiverId (Ascending)
  - status (Ascending)
  - createdAt (Descending)
```

**Used for**: Getting all pending requests **received** by current user

**Query**:
```dart
_firestore
  .collection('connection_requests')
  .where('receiverId', isEqualTo: currentUserId)
  .where('status', isEqualTo: 'pending')
  .orderBy('createdAt', descending: true)
```

---

### Index 2: Sent Connection Requests Query
```
Collection: connection_requests
Fields:
  - senderId (Ascending)
  - status (Ascending)
  - createdAt (Descending)
```

**Used for**: Getting all pending requests **sent** by current user

**Query**:
```dart
_firestore
  .collection('connection_requests')
  .where('senderId', isEqualTo: currentUserId)
  .where('status', isEqualTo: 'pending')
  .orderBy('createdAt', descending: true)
```

---

## 🎯 After Creating Indexes

1. **Wait for "Enabled" status** (green checkmark)
2. **Close and reopen your app**
3. **Navigate to Connection Requests screen**
4. **Error should be gone!**

---

## 🧪 Testing

After indexes are created, test these scenarios:

### Test 1: Empty State
1. Open Connection Requests screen
2. Should show: "No Connection Requests" (empty state)
3. No error message

### Test 2: Receive Request
1. Have someone send you a connection request
2. Badge appears on Live Connect screen (👥 with count)
3. Open Connection Requests screen
4. Should show the request with Accept/Reject buttons

### Test 3: Accept Request
1. Tap "Accept" button
2. Should see success message
3. Request disappears from list
4. Badge count decreases

---

## ⏱️ Index Build Time

- **Small database** (< 1000 documents): ~30 seconds
- **Medium database** (1000-10000 docs): ~2-5 minutes
- **Large database** (> 10000 docs): ~5-10 minutes

Your database is likely small, so it should be ready in **under 1 minute**.

---

## 🔍 Verify Indexes Are Working

After creating indexes, check:

1. **Firebase Console → Firestore → Indexes**
   - Should see 2 indexes for `connection_requests`
   - Both should show "Enabled" status

2. **App Connection Requests Screen**
   - No error message
   - Shows empty state or list of requests

3. **Live Connect Badge**
   - Shows count if requests exist
   - Tapping opens screen without errors

---

## 📝 Index Definition (for reference)

This has been added to `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "connection_requests",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "receiverId", "order": "ASCENDING"},
        {"fieldPath": "status", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "connection_requests",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "senderId", "order": "ASCENDING"},
        {"fieldPath": "status", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    }
  ]
}
```

To deploy via CLI (if Firebase CLI is installed):
```bash
firebase deploy --only firestore:indexes
```

---

## ❓ Common Issues

### Issue: "Index already exists"
**Solution**: An index with the same configuration already exists. Check the Indexes tab.

### Issue: "Permission denied"
**Solution**: You need Owner or Editor permissions on the Firebase project.

### Issue: Index stuck on "Building"
**Solution**: Wait up to 10 minutes. If still stuck, delete and recreate.

### Issue: Error persists after index creation
**Solution**:
1. Force close your app completely
2. Reopen the app
3. Navigate to Connection Requests
4. Clear app cache if error continues

---

## ✅ Summary

**Quick Fix Steps**:
1. Open the auto-generated link from error message
2. Click "Create Index" button
3. Wait 1-2 minutes
4. Refresh app
5. Error gone! ✨

**Or manually**:
1. Firebase Console → Firestore → Indexes
2. Create 2 indexes (details above)
3. Wait for "Enabled" status
4. Refresh app

**That's it!** Once indexes are created, the Connection Requests feature will work perfectly.

---

**Need help?** The error message contains a direct link to create the index - just click it!
