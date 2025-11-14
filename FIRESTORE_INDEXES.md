# Firestore Index Configuration

## Required Composite Indexes

Based on the error logs, your application requires the following composite indexes in Firestore:

### 1. Messages Collection Index
Create an index for the `messages` collection with:
- **Field 1:** `receiverId` (Ascending)
- **Field 2:** `timestamp` (Descending)
- **Field 3:** `__name__` (Descending)

### 2. Messages Status Index
Create an index for the `messages` collection with:
- **Field 1:** `receiverId` (Ascending)
- **Field 2:** `status` (Ascending)
- **Field 3:** `__name__` (Descending)

## How to Create Indexes

### Option 1: Using Firebase Console (Recommended)
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Firestore Database** → **Indexes**
4. Click **Create Index**
5. Add the fields as specified above
6. Click **Create**

### Option 2: Using the Error Links
When you run the app and encounter index errors, Firebase provides direct links in the error messages. These links will automatically configure the required index:
- Look for URLs like: `https://console.firebase.google.com/v1/r/project/...`
- Click the link to automatically create the index

### Option 3: Using Firebase CLI
Create a `firestore.indexes.json` file:

```json
{
  "indexes": [
    {
      "collectionGroup": "messages",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "receiverId", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "messages",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "receiverId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" }
      ]
    }
  ]
}
```

Then deploy using:
```bash
firebase deploy --only firestore:indexes
```

## Index Build Time
- Indexes typically take 1-5 minutes to build
- You'll receive an email when the index is ready
- Check the status in Firebase Console → Firestore → Indexes

## Monitoring Index Usage
- Go to Firebase Console → Firestore → Indexes
- View usage statistics for each index
- Remove unused indexes to optimize performance