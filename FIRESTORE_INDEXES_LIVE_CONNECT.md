# Firestore Indexes for Live Connect Feature

## ⚠️ CRITICAL: These indexes are required for the Live Connect feature to work properly!

Without these indexes, users will see errors or extremely slow performance.

---

## Required Composite Indexes

### 1. **Discovery Mode + City Filter**

**Collection:** `users`
**Fields:**
- `discoveryModeEnabled` (Ascending)
- `city` (Ascending)

**Used when:** User applies "City" location filter

**Create via Firebase Console:**
```
Collection ID: users
Fields indexed:
  - discoveryModeEnabled: Ascending
  - city: Ascending
Query Scope: Collection
```

**Create via Command:**
```bash
# Add to firestore.indexes.json
{
  "collectionGroup": "users",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "discoveryModeEnabled", "order": "ASCENDING" },
    { "fieldPath": "city", "order": "ASCENDING" }
  ]
}
```

---

### 2. **Discovery Mode + Gender Filter**

**Collection:** `users`
**Fields:**
- `discoveryModeEnabled` (Ascending)
- `gender` (Ascending)

**Used when:** User applies gender filter (single gender)

**Create via Firebase Console:**
```
Collection ID: users
Fields indexed:
  - discoveryModeEnabled: Ascending
  - gender: Ascending
Query Scope: Collection
```

**Create via Command:**
```bash
# Add to firestore.indexes.json
{
  "collectionGroup": "users",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "discoveryModeEnabled", "order": "ASCENDING" },
    { "fieldPath": "gender", "order": "ASCENDING" }
  ]
}
```

---

### 3. **Discovery Mode + City + Gender (Combined Filter)**

**Collection:** `users`
**Fields:**
- `discoveryModeEnabled` (Ascending)
- `city` (Ascending)
- `gender` (Ascending)

**Used when:** User applies both city AND gender filters simultaneously

**Create via Firebase Console:**
```
Collection ID: users
Fields indexed:
  - discoveryModeEnabled: Ascending
  - city: Ascending
  - gender: Ascending
Query Scope: Collection
```

**Create via Command:**
```bash
# Add to firestore.indexes.json
{
  "collectionGroup": "users",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "discoveryModeEnabled", "order": "ASCENDING" },
    { "fieldPath": "city", "order": "ASCENDING" },
    { "fieldPath": "gender", "order": "ASCENDING" }
  ]
}
```

---

## Already Existing (Connection Requests)

These indexes should already exist for the connection feature:

### 4. **Connection Requests - Pending Received**

**Collection:** `connection_requests`
**Fields:**
- `receiverId` (Ascending)
- `status` (Ascending)
- `createdAt` (Descending)

### 5. **Connection Requests - Pending Sent**

**Collection:** `connection_requests`
**Fields:**
- `senderId` (Ascending)
- `status` (Ascending)
- `createdAt` (Descending)

---

## 🚀 Quick Setup Guide

### Method 1: Firebase Console (Easiest)

1. Go to **Firebase Console** → **Firestore Database** → **Indexes** tab
2. Click **"Create Index"**
3. For each index above:
   - Enter Collection ID: `users`
   - Add each field with its order (Ascending)
   - Click **"Create"**
4. Wait for indexes to build (usually 1-5 minutes)

### Method 2: Using firestore.indexes.json

1. Open or create `firestore.indexes.json` in your project root
2. Add all indexes from above
3. Deploy:
   ```bash
   firebase deploy --only firestore:indexes
   ```

### Method 3: From Error Messages (Lazy Method)

1. Run the app
2. Apply filters in Live Connect
3. Firebase will show error with index creation link
4. Click link to create index automatically
5. Wait for index to build

---

## Complete firestore.indexes.json

Here's the complete file content:

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

---

## ⏱️ Index Build Time

- **Small databases** (<1000 documents): 1-2 minutes
- **Medium databases** (1K-10K documents): 5-10 minutes
- **Large databases** (>10K documents): 15-30 minutes

You can continue development while indexes are building, but queries will fail until they're complete.

---

## 🧪 Verification

After creating indexes, test:

1. ✅ Apply "City" filter → Should load users in same city
2. ✅ Apply gender filter → Should filter by gender
3. ✅ Apply both → Should filter by both criteria
4. ✅ No errors in console

---

## 📊 Performance Impact

**Without indexes:**
- Query time: 5-10+ seconds (or fails)
- Firestore reads: 100-1000+ documents scanned

**With indexes:**
- Query time: <500ms
- Firestore reads: Only matching documents (20-50)

**Cost savings: 10-100x fewer document reads!**

---

## ❗ Common Errors

### "The query requires an index"
**Solution:** Create the index using the link provided in error message

### "Index is still building"
**Solution:** Wait a few minutes and try again

### "Insufficient permissions"
**Solution:** Ensure you're logged in with Firebase CLI: `firebase login`

---

**Created:** 2025-11-21
**Status:** Required for Live Connect feature
**Priority:** P0 - Must create before deploying
